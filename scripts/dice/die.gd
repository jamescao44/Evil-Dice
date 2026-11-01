extends Node2D
signal landed

const Art = preload("res://scripts/dice/dice_art.gd")
const RollMotion = preload("res://scripts/dice/dice_roll_motion.gd")
var roll_motion := RollMotion.new()
var roll_center := Vector2.ZERO
var roll_radius: float = 0
var motion_tween: Tween

var face: int = 1
var socket_gem: Dictionary = {}
const GemPaint = preload("res://scripts/dice/gemstone_paint.gd")
var final_face: int = 1
var rolling: bool = false
var elapsed: float = 0.0
const ROLL_PLAYBACK_SPEED := 0.75
const REROLL_LOOPS := 2
const REROLL_SPEEDUP := 1.15
var duration: float = 1.0
var reveal_order: int = 0
var glow: float = 0.0
var marked: bool = false
var tint: Color = Color("aed085")
var base_scale: float = 0.75
var resting: Vector2
var playback_rate: float = 1.0
var cosmetic = RandomNumberGenerator.new()
var charging: bool = false
var charge_power: float = 0
var charge_age: float = 0
var throw_power: float = 0
var reduced: bool = false
var selection_emphasis: float = 0
var connection_glow: bool = false
var connection_color := Color.WHITE
var connection_fire: int = 0
var effect_age: float = 0
var rejection_age: float = 0.0
var idle_hint := Vector2.ZERO # Extra scale and tilt supplied by idle dice feedback.
const AUTO_ATTACK_PULSE_SECONDS := 0.30
var magician_hint: bool = false
var reroll_hint: bool = false
var auto_attack_active: bool = false
var auto_attack_pulse: float = 0.0
var tarot_glow: float = 0.0

## Brighten the whole matching group, then bounce each die again when it fires.
func pulse_auto_attack() -> void:
	auto_attack_pulse = AUTO_ATTACK_PULSE_SECONDS
	queue_redraw()

## Clear automatic-attack feedback on a new roll, restart or wave completion.
func clear_auto_attack() -> void:
	auto_attack_active = false
	auto_attack_pulse = 0

## Sample a quick lift and spring-back without changing the die's hitbox or origin.
func auto_attack_bounce() -> float:
	if reduced or auto_attack_pulse <= 0: return 0
	var t: float = 1.0-auto_attack_pulse/AUTO_ATTACK_PULSE_SECONDS
	return sin(t*PI*2)*pow(1-t,1.4)

## Give invalid taps a short sideways shake without moving the dice hitbox.
func reject_selection() -> void:
	rejection_age = 0.28

func _ready() -> void:
	cosmetic.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resting = position
	scale = Vector2.ONE * base_scale

func stop_charge() -> void:
	if motion_tween and motion_tween.is_running(): motion_tween.kill()
	charging = false
	position = resting
	rotation = 0
	scale = Vector2.ONE * base_scale

func charge(power: float) -> void:
	clear_auto_attack()
	charging = true
	charge_power = clampf(power, 0, 1)
	marked = false
	glow = charge_power * 0.8
	tint = Color("dfb866")

## Perfect dice snap together; ordinary throws land in counterclockwise order.
func roll_to(value: int, order: int, speed: float, power: float = 0.0, perfect: bool = false) -> void:
	stop_charge()
	clear_auto_attack()
	throw_power = 1.0 if perfect else clampf(power, 0, 1)
	final_face = value
	reveal_order = order
	var roll_seconds := 0.82 if perfect else 0.55+throw_power*0.15+order*0.055
	duration = roll_seconds / (speed*ROLL_PLAYBACK_SPEED) # Slow travel, spin and frame playback together.
	roll_motion.begin(cosmetic,resting,roll_center if roll_radius > 0 else resting,roll_radius if roll_radius > 0 else 64,roll_seconds,throw_power,perfect)
	elapsed = 0
	rolling = true
	glow = throw_power*0.65
	tint = Color("dfb866")
	marked = false
	idle_hint = Vector2.ZERO
	selection_emphasis = 0
	scale = Vector2.ONE * base_scale

## Single-die corrections play two complete atlas loops at 15% faster playback.
func reroll_to(value: int, speed: float) -> void:
	roll_to(value,0,speed,0.0,false)
	roll_motion.begin(cosmetic,resting,resting,48,0.34,0.0,false)
	roll_motion.seconds = Art.ROLL_COUNT*REROLL_LOOPS/roll_motion.frames_per_second
	duration = roll_motion.seconds/(speed*REROLL_SPEEDUP)

func celebrate(color: Color, strong: bool) -> void:
	tint = color
	glow = 1.0
	marked = true
	if motion_tween and motion_tween.is_running(): motion_tween.kill()
	motion_tween = create_tween()
	motion_tween.tween_property(self, "scale", Vector2.ONE * base_scale * (1.18 if strong else 1.09), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "scale", Vector2.ONE * base_scale, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	effect_age += delta
	tarot_glow = maxf(0,tarot_glow-delta*1.7)
	auto_attack_pulse = maxf(0,auto_attack_pulse-delta)
	rejection_age = maxf(0,rejection_age-delta)
	if charging:
		charge_age += delta
		var intensity: float = charge_power * charge_power
		var tremor: float = 0 if reduced else 0.5 + intensity * 8
		position = resting + Vector2(sin(charge_age * 71 + resting.x), cos(charge_age * 83 + resting.y)) * tremor
		rotation = 0 if reduced else sin(charge_age * 47) * intensity * 0.12
		scale = Vector2.ONE * base_scale * (1.0 + intensity * 0.07)
	elif rolling:
		elapsed += delta * playback_rate
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var strength: float = 0.0 if reduced else throw_power
		position = resting if reduced else roll_motion.position_at(progress)
		rotation = 0 if reduced else roll_motion.rotation_at(progress)
		scale = Vector2.ONE*base_scale*(1 if reduced else 1+sin(progress*PI)*(0.04+strength*0.04))
		if progress >= 1:
			rolling = false
			face = final_face
			position = resting
			rotation = 0
			if not reduced:
				scale = Vector2(1.12 + strength * 0.18, 0.88 - strength * 0.15) * base_scale
				motion_tween = create_tween()
				motion_tween.tween_property(self, "scale", Vector2.ONE * base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			landed.emit()
	else:
		glow = maxf(0.28 if marked else 0.0, glow - delta * 0.32)
	queue_redraw()

## Keep result faces separate from the purely cosmetic tumbling frames.
func sprite_frame() -> int:
	return roll_motion.frame_at(elapsed/duration) if rolling else clampi(face,1,6)-1

## Selected dice lift off their resting places and gently float while awaiting confirmation.
func selection_offset() -> Vector2:
	return Vector2(0,-selection_emphasis*(30.0+(0.0 if reduced else sin(effect_age*TAU/1.5)*3.0)))

func _draw() -> void:
	var rejection: float = sin(rejection_age*90)*10*(rejection_age/0.28)
	var bounce: float = auto_attack_bounce()
	var magic_scale: float = (0.1 if reduced else 0.1+0.08*sin(effect_age*TAU*1.8)) if magician_hint else 0.0
	var reroll_scale: float = (0.08 if reduced else 0.08+0.07*sin(effect_age*TAU*1.5)) if reroll_hint else 0.0
	draw_set_transform(selection_offset()+Vector2(rejection,-bounce*30),idle_hint.y,Vector2.ONE*(1+selection_emphasis*0.12+idle_hint.x+bounce*0.36+magic_scale+reroll_scale))
	if reroll_hint:
		for spread in range(4,0,-1):
			var extent: float = 55+spread*5
			draw_rect(Rect2(-extent,-extent,extent*2,extent*2),Color("ffe1a0",0.025+reroll_scale*0.3))
	if not socket_gem.is_empty(): _draw_socket_glow()
	if tarot_glow > 0:
		for layer in range(5,0,-1):
			var side: float = 56+layer*6
			draw_rect(Rect2(-side,-side,side*2,side*2),Color("bd75ff",tarot_glow*0.055))
	if auto_attack_active or auto_attack_pulse > 0: _draw_auto_attack_glow()
	if connection_fire > 0: _draw_connection_fire()
	if connection_glow:
		for spread in range(4,0,-1):
			draw_rect(Rect2(-55-spread*5,-57-spread*5,110+spread*10,114+spread*10),Color(1,1,1,0.065))
	if glow > 0:
		for i in range(4, 0, -1):
			var extent: float = 54 + i * 5
			draw_rect(Rect2(-extent, -extent, extent * 2, extent * 2), Color(tint, glow * 0.035 * (5 - i)))
	Art.paint_frame(self,sprite_frame(),Rect2(Vector2.ONE*(-Art.DRAW_SIDE/2),Vector2.ONE*Art.DRAW_SIDE))
	if tarot_glow > 0:
		draw_rect(Rect2(-53,-55,106,109),Color("c98aff",tarot_glow*0.23))
		draw_rect(Rect2(-53,-55,106,109),Color("e6baff",tarot_glow*0.9),false,3)
	if not socket_gem.is_empty():
		draw_rect(Rect2(-53,-55,106,109),Color(GemPaint.Gems.Catalog.color(socket_gem.id),0.6),false,3)
		GemPaint.paint(self,Vector2(40,43),socket_gem,13,false)
	if connection_glow:
		draw_rect(Rect2(-53,-55,106,109),Color(1,1,1,0.18))
		draw_rect(Rect2(-53,-55,106,109),Color.WHITE,false,3)
	if glow > 0.1:
		draw_rect(Rect2(-53, -55, 106, 109), Color(tint, glow * 0.7), false, 3)
	if auto_attack_active or auto_attack_pulse > 0:
		draw_rect(Rect2(-53,-55,106,109),Color("fff4c6",0.18 if auto_attack_active else auto_attack_pulse*0.3))
		draw_rect(Rect2(-53,-55,106,109),Color("ffdc87",0.9 if auto_attack_active else 0.85*auto_attack_pulse/AUTO_ATTACK_PULSE_SECONDS),false,3)

## Equipped color stays visible behind the neutral face and white selection outline.
func _draw_socket_glow() -> void:
	var color: Color = GemPaint.Gems.Catalog.color(socket_gem.id)
	var pulse: float = 1.0 if reduced else 0.9+sin(effect_age*TAU/2)*0.1
	for layer in range(5,0,-1):
		var side: float = 55+layer*5
		draw_rect(Rect2(-side,-side,side*2,side*2),Color(color,(0.05+0.008*int(socket_gem.level))*pulse))

## A layered amber halo distinguishes firing dice from idle selection hints.
func _draw_auto_attack_glow() -> void:
	var pulse: float = auto_attack_pulse/AUTO_ATTACK_PULSE_SECONDS
	var strength: float = 1.0 if auto_attack_active else pulse*0.65
	for spread in range(5,0,-1):
		var extent: float = 54+spread*7
		draw_rect(Rect2(-extent,-extent,extent*2,extent*2),Color("ffbb62",strength*0.035*(6-spread)))

## Pixel flame tongues stay behind the die face and rise higher with each tier.
func _draw_connection_fire() -> void:
	var tongues: int = 3+connection_fire*2
	var age: float = 0 if reduced else effect_age
	for i in range(tongues):
		var phase: float = i*2.3+resting.x*0.017
		var x: float = lerpf(-58,58,float(i)/maxi(1,tongues-1))
		var height: float = (24+connection_fire*17)*(0.7+0.3*sin(age*9+phase))
		var sway: float = 0 if reduced else sin(age*6+phase)*8
		for layer in range(3):
			var width: float = 22-layer*6+connection_fire*2
			var tip: float = -43-height*(1-layer*0.22)
			var tint: Color = connection_color.lightened(layer*0.25)
			for step in range(4):
				var t: float = float(step)/4
				var band: float = (45-tip)/4
				var left: float = snappedf(x+sway*(1-t)-width*(0.3+t*0.7)/2,3)
				draw_rect(Rect2(left,snappedf(tip+band*step,3),snappedf(width*(0.3+t*0.7),3),ceilf(band/3)*3),Color(tint,0.12+layer*0.12))
