extends Node2D
## Presentation-only cast buildup. Model supplies immutable ordered damage steps.
## No combat calculations, random reward rolls or inventory mutation live here.
const Catalog = preload("res://scripts/relic_catalog.gd")
const Orb = preload("res://scripts/skill_orb_paint.gd")
const INTRO := 0.12
const STEP_TIME := 0.36
const FLIGHT_TIME := 0.25
const IMPACT_TIME := 0.38
var battle
var active: bool = false
var building: bool = false
var value: float = 1.0
var steps: Array = []
var cursor: int = -1
var age: float = 0
var impact_age: float = IMPACT_TIME
var impact_direction: int = 0
var impact_color := Color.WHITE
var fade_age: float = -1
var flight_from := Vector2.ZERO
var landed: bool = false

func _ready() -> void:
	z_index = 115
	battle.model.relic_activated.connect(_relic_activated)
	hide()

func start(values: Array) -> void:
	clear()
	steps = values.duplicate(true)
	active = true
	building = true
	visible = true

func clear() -> void:
	active = false
	building = false
	value = 1.0
	steps.clear()
	cursor = -1
	age = 0
	impact_age = IMPACT_TIME
	impact_direction = 0
	fade_age = -1
	landed = false
	hide()

func finish() -> void:
	building = false
	if active: fade_age = 0

func label() -> String:
	# Preserve small changes such as a 0.95x curse instead of rounding to 1.0.
	var number: String = "%.2f" % value
	if number.ends_with("0"): number = number.left(-1)
	return "DMG x " + number

func anchor() -> Vector2:
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	return battle.ARENA.position+Vector2(24 if portrait else 18,32 if portrait else 28)

func text_size() -> int:
	return 26 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 20

func impact_point() -> Vector2:
	return anchor()+Vector2(battle.pixel_font.get_string_size(label(),HORIZONTAL_ALIGNMENT_LEFT,-1,text_size()).x*0.65,-text_size()*0.4)

func motion() -> Vector2:
	if battle.reduced or impact_age >= IMPACT_TIME or impact_direction == 0: return Vector2.ZERO
	var t: float = impact_age/IMPACT_TIME
	if impact_direction < 0: return Vector2(sin(t*TAU*4)*5*(1-t),0)
	return Vector2(0,-sin(t*TAU)*9*(1-t))

func _impact(next: float, color: Color) -> void:
	impact_direction = 1 if next > value else -1 if next < value else 0
	value = next
	impact_age = 0
	impact_color = color
	if impact_direction != 0: battle._sound("drop_001",1.25 if impact_direction > 0 else 0.7,-22)

func sync_value(next: float) -> void:
	# Kills can change a Reaper's modifier between hits of one skill.
	if active and not building and not is_equal_approx(value,next): _impact(next,Color("dfb866"))

func _relic_activated(id: String) -> void:
	# A triggered modifier may grow during a multi-hit cast. Animate that change
	# before the next hit, without replaying unchanged relics or resetting to one.
	var skill: MultiHitSkill = battle.model.pending
	if not active or fade_age >= 0 or skill.is_empty() or skill.uses_left() <= 1 or not battle.model.outcome().is_empty(): return
	var next: float = battle.model.cast_damage_multiplier(skill)
	if is_equal_approx(value,next): return
	if building:
		# Several kills in one area hit can feed the same in-flight activation.
		if cursor >= 0 and cursor < steps.size() and steps[cursor].id == id and not landed: steps[cursor].after = next
		return
	steps = [{"source":"relic","id":id,"slot":battle.model.relics.index_of(id),"before":value,"after":next,"note":""}]
	cursor = -1
	building = true
	_advance()

func step_color(step: Dictionary) -> Color:
	if not step.id.is_empty(): return Catalog.color(step.id)
	return Color("c18ce8") if step.source == "darkness" else Color("dfb866")

func _advance() -> void:
	cursor += 1
	age = 0
	landed = false
	if cursor >= steps.size():
		building = false
		return
	var step: Dictionary = steps[cursor]
	flight_from = battle._perfect_combo_center() if step.source == "combo" else battle._player_point()
	if step.slot >= 0:
		flight_from = battle.relic_ui.slot_rect(step.slot).get_center()
		battle.relic_ui.activate(step.id)

func _process(delta: float) -> void:
	if not is_instance_valid(battle): return
	visible = active and not battle._menus_open() and battle.view_phase == "resolving"
	if battle._menus_open(): return
	if not active: return
	var elapsed: float = delta*clampf(battle.speed,1,2)
	impact_age += elapsed
	if fade_age >= 0:
		fade_age += elapsed
		if fade_age >= 0.2: clear(); return
	if building:
		age += elapsed
		if cursor < 0:
			if age >= INTRO: _advance()
		else:
			if not landed and age >= FLIGHT_TIME:
				landed = true
				_impact(steps[cursor].after,step_color(steps[cursor]))
			if age >= STEP_TIME: _advance()
	queue_redraw()

func _draw() -> void:
	if not active: return
	var opacity: float = 1.0 if fade_age < 0 else clampf(1-fade_age/0.2,0,1)
	var point: Vector2 = anchor()+motion()
	var size: int = text_size()
	var text: String = label()
	# A phase offset per glyph makes increases roll through the text like a wave.
	var x: float = 0
	for character in text:
		var rise: float = 0
		if not battle.reduced and impact_direction > 0 and impact_age < IMPACT_TIME:
			rise = sin(impact_age/IMPACT_TIME*TAU-x*0.055)*3*(1-impact_age/IMPACT_TIME)
		var at: Vector2 = point+Vector2(x,rise)
		draw_string(battle.pixel_font,at+Vector2(2,2),character,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0.04,0.06,0.05,opacity))
		draw_string(battle.pixel_font,at,character,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(1,1,1,opacity))
		x += battle.pixel_font.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	if building and cursor >= 0 and cursor < steps.size():
		var step: Dictionary = steps[cursor]
		var color: Color = step_color(step)
		if not step.note.is_empty():
			var note: String = GameText.format(step.note,step.note_values) if not step.get("note_values",[]).is_empty() else GameText.text(step.note)
			draw_string(battle.pixel_font,flight_from+Vector2(-28,-30-age*16),note,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(color,1-age/STEP_TIME))
		# Flat base / extra-hit relics react, but do not pretend to raise DMG.
		if not is_equal_approx(step.before,step.after) and not battle.reduced:
			var particle_scale: float = 1.4 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 1.0
			for i in range(3):
				var delay: float = i*0.035
				var t: float = clampf((age-delay)/(FLIGHT_TIME-delay),0,1)
				if t <= 0 or t >= 1: continue
				var from: Vector2 = flight_from+Vector2(sin(i*2.1),cos(i*1.7))*12
				var target: Vector2 = impact_point()
				var at: Vector2 = from.lerp(target,pow(t,1.6))+Vector2(sin(t*PI)*32,-sin(t*PI)*54)
				var prior: float = maxf(0,t-0.06)
				var trail: Vector2 = from.lerp(target,pow(prior,1.6))+Vector2(sin(prior*PI)*32,-sin(prior*PI)*54)
				draw_line(trail,at,Color(color,0.3),12*particle_scale)
				draw_line(trail,at,Color("fff2c8",0.7),3*particle_scale)
				Orb.paint(self,at,(16-i*2)*particle_scale,color,true)
	if not battle.reduced and impact_age < 0.2 and impact_direction != 0:
		var t: float = impact_age/0.2
		draw_arc(impact_point(),8+t*28,0,TAU,24,Color(impact_color,(1-t)*0.65*opacity),2)
		for i in range(8):
			var at: Vector2 = impact_point()+Vector2.from_angle(i*TAU/8)*(6+t*25)
			draw_circle(at,2,Color(impact_color,(1-t)*opacity))
