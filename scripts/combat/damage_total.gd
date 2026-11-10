extends Node2D
## Presentation-only damage chain; each target hit contributes once at its visual impact.
const Feedback = preload("res://scripts/combat/damage_feedback.gd")
const LINGER := 2.0
const FADE_TIME := 0.3
const ADDITION_INTERVAL := 0.065
const COUNT_TIME := 0.12
const BOUNCE_TIME := 0.3
const WAVE_TIME := 0.22
const WAVE_SPREAD := 0.14
const FONT_FACTOR := 2
const CAPTION_ENTER_TIME := 0.28
var battle
var total: int = 0
var presented_total: int = 0
var additions: int = 0
var reference_health: float = 0.0
var pending_hits: Array = []
var idle_age: float = 0.0
var addition_wait: float = 0.0
var count_age: float = COUNT_TIME
var count_from: float = 0.0
var bounce_age: float = BOUNCE_TIME
var size_factor: float = 1.0
var motion_age: float = 0.0
var pulse_phase: float = 0.0
var waves: Array[float] = []

## Attach to the arena-clipped damage canvas, above spells and below modal visibility gates.
func _ready() -> void:
	name = "AccumulatedDamage"
	clear()

## Accept direct hit values, excluding Burning, executions and incoming player damage.
func add_event(event: Dictionary) -> bool:
	var target: int = event.get("target",-1)
	if target < -2 or target == -1 or event.get("type","") not in ["damage","shield_hit"] or event.get("instant_kill",false): return false
	var amount: int = maxi(0,int(event.get("display_amount",event.get("amount",0))))
	if amount == 0: return true
	if idle_age >= LINGER and pending_hits.is_empty(): clear()
	var health: float = 0.0
	if target >= 0 and target < battle.model.enemies.size():
		var enemy: Dictionary = battle.model.enemies[target]
		health = enemy.max_hp*(battle.Effects.BOSS_NUMBER_MAX_HEALTH_FRACTION if enemy.get("boss",false) else 1.0)
	elif target == -2 and battle.model.is_city():
		health = battle.model.CITY_MAX_HP*battle.Effects.BOSS_NUMBER_MAX_HEALTH_FRACTION
	reference_health = maxf(reference_health,health)
	total += amount
	idle_age = 0.0
	pending_hits.append(amount)
	if presented_total == 0 or (pending_hits.size() == 1 and addition_wait <= 0): _next_addition()
	visible = should_show()
	queue_redraw()
	return true

## Clear between encounters/restarts; ordinary skill cleanup deliberately preserves the chain.
func clear() -> void:
	total = 0
	presented_total = 0
	additions = 0
	reference_health = 0.0
	pending_hits.clear()
	idle_age = 0.0
	addition_wait = 0.0
	count_age = COUNT_TIME
	count_from = 0.0
	bounce_age = BOUNCE_TIME
	size_factor = 1.0
	motion_age = 0.0
	pulse_phase = 0.0
	waves.clear()
	visible = false
	queue_redraw()

## Keep the aggregate in the battlefield's lower-right middle, independent of target-camera motion.
func anchor() -> Vector2:
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	return battle.ARENA.position+battle.ARENA.size*Vector2(0.70,0.76 if portrait else 0.65)

## Share the standing formula's font size instead of duplicating portrait/desktop constants.
func text_size() -> int:
	return battle.damage_feedback.base_text_size()*FONT_FACTOR

## Use the same enemy-health/level curve as the top-left result, normalized to a 2x starting font.
func target_size_factor() -> float:
	return Feedback.damage_result_scale(presented_total,reference_health)/Feedback.MIN_RESULT_SCALE

## Counting up stays continuous even if another hit arrives before the previous pop finishes.
func displayed_value() -> float:
	return lerpf(count_from,float(presented_total),1-pow(1-clampf(count_age/COUNT_TIME,0,1),3))

func label() -> String:
	return str(roundi(displayed_value()))

func opacity() -> float:
	return 1.0-smoothstep(LINGER-FADE_TIME,LINGER,idle_age)

## A smaller localized caption enters once per chain and shares the number's decay.
func caption_size() -> int:
	return roundi(text_size()*0.42)

func caption_origin(number_scale: float) -> Vector2:
	var font: Font = GameText.description_font()
	var width: float = font.get_string_size(GameText.text("Total Damage"),HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size()).x
	var number_width: float = battle.pixel_font.get_string_size(label(),HORIZONTAL_ALIGNMENT_LEFT,-1,text_size()).x*number_scale
	var left: float = anchor().x+number_width*0.5-width
	var offset: float = 0.0 if battle.reduced else pow(1-clampf(motion_age/CAPTION_ENTER_TIME,0,1),3)*(battle.ARENA.end.x-left+16)
	var number_baseline: float = (battle.pixel_font.get_ascent(text_size())-battle.pixel_font.get_descent(text_size()))*0.5
	var y: float = anchor().y+number_baseline*number_scale+8+font.get_ascent(caption_size())
	return Vector2(left+offset,minf(y,battle.ARENA.end.y-12-font.get_descent(caption_size())))

## Separate simultaneous enemy hits into short additions; large groups speed up instead of queuing seconds.
func _next_addition() -> void:
	count_from = displayed_value()
	presented_total += int(pending_hits.pop_front())
	if additions == 0: count_from = presented_total
	additions += 1
	count_age = 0.0
	bounce_age = 0.0
	waves.append(0.0)
	addition_wait += ADDITION_INTERVAL/sqrt(maxi(1,pending_hits.size()))

func should_show() -> bool:
	return total > 0 and battle.BattlefieldRender.overlays_visible(battle)

## Real-second expiry ignores combat speed/kill slow motion, while inspection and pause freeze it.
func _process(delta: float) -> void:
	if not is_instance_valid(battle): return
	visible = should_show()
	if battle._menus_open() or battle.inspecting_enemy >= 0: return
	if total == 0: return
	idle_age += delta
	count_age += delta
	bounce_age += delta
	motion_age += delta
	for i in range(waves.size()-1,-1,-1):
		waves[i] += delta
		if waves[i] > WAVE_TIME+WAVE_SPREAD: waves.remove_at(i)
	addition_wait -= delta
	while not pending_hits.is_empty() and addition_wait <= 0: _next_addition()
	if pending_hits.is_empty(): addition_wait = maxf(0,addition_wait)
	size_factor = lerpf(size_factor,maxf(size_factor,target_size_factor()),1-exp(-delta*7))
	pulse_phase = fposmod(pulse_phase+delta*Feedback.damage_pulse_frequency(presented_total,reference_health),1.0)
	if idle_age >= LINGER and pending_hits.is_empty(): clear(); return
	queue_redraw()

## Bound wide totals and their bounce to the arena so portrait health/UI remain readable.
func fitted_scale(text: String, animation_scale: float = 1.0) -> float:
	var width: float = battle.pixel_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size()).x
	var available: float = minf(battle.ARENA.size.x*0.68,(battle.ARENA.end.x-anchor().x-18)*2)
	return minf(size_factor*animation_scale,available/maxf(1,width))

## Every addition launches its own left-to-right wave, so rapid hits never cancel the trailing digits.
func digit_wave(index: int, count: int) -> float:
	if battle.reduced: return 0.0
	var height: float = 0.0
	for wave_age in waves:
		var local: float = wave_age-index*WAVE_SPREAD/maxi(1,count-1)
		if local >= 0 and local <= WAVE_TIME: height += sin(local/WAVE_TIME*PI)
	return minf(1.5,height)

## A centered squash/pop, white flash and health-relative pulse make each added hit tangible.
func _draw() -> void:
	if total <= 0: return
	var text: String = label()
	var pop: float = sin(clampf(bounce_age/BOUNCE_TIME,0,1)*PI)*exp(-bounce_age*4) if not battle.reduced else 0.0
	var pulse: float = (1-cos(pulse_phase*TAU))*0.5*Feedback.PULSE_SCALE if not battle.reduced and Feedback.damage_pulse_frequency(presented_total,reference_health) > 0 else 0.0
	var scale_value: float = fitted_scale(text,1+pop*0.18+pulse)
	var tremble: float = 0.0 if battle.reduced else Feedback.damage_tremble_amplitude(presented_total,reference_health)*0.45
	var at: Vector2 = anchor()+Vector2(sin(motion_age*71),cos(motion_age*83))*tremble+Vector2(0,-pop*10)
	var size: Vector2 = battle.pixel_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size())
	var baseline: float = (battle.pixel_font.get_ascent(text_size())-battle.pixel_font.get_descent(text_size()))*0.5
	var origin := Vector2(-size.x*0.5,baseline)
	var alpha: float = opacity()
	var flash: float = 1-clampf(bounce_age/0.18,0,1)
	var tint := Color("ffe8b8").lerp(Color.WHITE,flash)
	tint.a = alpha
	var block_scale := Vector2(scale_value*(1-pop*0.035),scale_value*(1+pop*0.04))
	for i in range(text.length()):
		var width: float = battle.pixel_font.get_string_size(text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,text_size()).x
		var prefix: float = battle.pixel_font.get_string_size(text.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,text_size()).x
		var wave: float = digit_wave(i,text.length())
		var center := Vector2(origin.x+prefix+width*0.5,-wave*8)
		draw_set_transform(at+center*block_scale,0,block_scale*(1+wave*0.12))
		var glyph := Vector2(-width*0.5,baseline)
		draw_string_outline(battle.pixel_font,glyph,text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,text_size(),4,Color(0.09,0.035,0.025,alpha*0.95))
		draw_string(battle.pixel_font,glyph+Vector2(0,3),text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,text_size(),Color(0.25,0.07,0.015,alpha*0.8))
		draw_string(battle.pixel_font,glyph,text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,text_size(),tint)
	draw_set_transform(Vector2.ZERO)
	var caption: String = GameText.text("Total Damage")
	var caption_at: Vector2 = caption_origin(scale_value)
	var caption_font: Font = GameText.description_font()
	draw_string_outline(caption_font,caption_at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size(),3,Color(0.09,0.035,0.025,alpha*0.95))
	draw_string(caption_font,caption_at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size(),Color(0.96,0.83,0.64,alpha))
