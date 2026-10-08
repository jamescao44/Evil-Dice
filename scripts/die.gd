extends Node2D
signal landed

var face: int = 1
var final_face: int = 1
var rolling: bool = false
var elapsed: float = 0.0
var duration: float = 1.0
var delay: float = 0.0
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

func _ready() -> void:
	cosmetic.randomize()
	resting = position
	scale = Vector2.ONE * base_scale

func stop_charge() -> void:
	charging = false
	position = resting
	rotation = 0
	scale = Vector2.ONE * base_scale

func charge(power: float) -> void:
	charging = true
	charge_power = clampf(power, 0, 1)
	marked = false
	glow = charge_power * 0.8
	tint = Color("dfb866")

func roll_to(value: int, index: int, speed: float, power: float = 0.0) -> void:
	stop_charge()
	throw_power = clampf(power, 0, 1)
	final_face = value
	duration = (0.9 + index * 0.24) / speed
	elapsed = 0
	delay = index * 0.05 / speed
	rolling = true
	glow = 0
	marked = false
	scale = Vector2.ONE * base_scale

func celebrate(color: Color, strong: bool) -> void:
	tint = color
	glow = 1.0
	marked = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * base_scale * (1.18 if strong else 1.09), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * base_scale, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if charging:
		charge_age += delta
		var intensity: float = charge_power * charge_power
		var tremor: float = 0 if reduced else 0.5 + intensity * 8
		position = resting + Vector2(sin(charge_age * 71 + resting.x), cos(charge_age * 83 + resting.y)) * tremor
		rotation = 0 if reduced else sin(charge_age * 47) * intensity * 0.12
		scale = Vector2.ONE * base_scale * (1.0 + intensity * 0.07)
	elif rolling:
		elapsed += delta * playback_rate
		if elapsed > delay:
			var progress := clampf((elapsed - delay) / duration, 0.0, 1.0)
			var strength: float = 0.0 if reduced else throw_power
			var lift: float = (sin(progress * PI) * 22 + absf(sin(progress * PI * 5)) * 11 * (1 - progress)) * (1.0 + strength * 1.8)
			position = resting + Vector2(sin(progress * TAU * 3) * 10 * (1 - progress) * (1 + strength * 2.5), -lift)
			rotation = sin(progress * TAU * 2.5) * 0.38 * (1 - progress) * (1 + strength * 2.5)
			if int(elapsed * 26) != int((elapsed - delta) * 26):
				face = cosmetic.randi_range(1, 6)
			if progress >= 1:
				rolling = false
				face = final_face
				position = resting
				rotation = 0
				var tween := create_tween()
				scale = Vector2(1.12 + strength * 0.18, 0.88 - strength * 0.15) * base_scale
				tween.tween_property(self, "scale", Vector2.ONE * base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				landed.emit()
	else:
		glow = maxf(0.28 if marked else 0.0, glow - delta * 0.32)
	queue_redraw()

func _draw() -> void:
	if glow > 0:
		for i in range(4, 0, -1):
			var extent: float = 54 + i * 5
			draw_rect(Rect2(-extent, -extent, extent * 2, extent * 2), Color(tint, glow * 0.035 * (5 - i)))
	draw_rect(Rect2(-49, -38, 98, 104), Color("211c17"))
	draw_rect(Rect2(-53, -44, 106, 90), Color("786343"))
	draw_rect(Rect2(-47, -50, 94, 108), Color("786343"))
	draw_rect(Rect2(-52, -48, 104, 89), Color("bca677"))
	draw_rect(Rect2(-46, -54, 92, 102), Color("bca677"))
	draw_rect(Rect2(-45, -48, 90, 88), Color("e5d5ac"))
	draw_rect(Rect2(-42, -48, 84, 5), Color("fff1c5"))
	draw_rect(Rect2(-42, 38, 84, 4), Color("b99d68"))
	# Small chips and ivory grain make the dice read as carved bone.
	for p in [Vector2(-32,-40),Vector2(28,-36),Vector2(-35,25),Vector2(32,32),Vector2(-10,34)]:
		draw_rect(Rect2(p, Vector2(4, 4)), Color("cdb98a"))
	for x in [-39, 39]:
		draw_rect(Rect2(x - 2, -44, 4, 4), Color("9e8050"))
		draw_rect(Rect2(x - 2, 34, 4, 4), Color("9e8050"))
	if glow > 0.1:
		draw_rect(Rect2(-53, -55, 106, 109), Color(tint, glow * 0.7), false, 3)
	var pips: Array = []
	match face:
		1: pips = [Vector2(0, 0)]
		2: pips = [Vector2(-24, -24), Vector2(24, 24)]
		3: pips = [Vector2(-24, -24), Vector2.ZERO, Vector2(24, 24)]
		4: pips = [Vector2(-24, -24), Vector2(24, -24), Vector2(-24, 24), Vector2(24, 24)]
		5: pips = [Vector2(-24, -24), Vector2(24, -24), Vector2.ZERO, Vector2(-24, 24), Vector2(24, 24)]
		6: pips = [Vector2(-24, -24), Vector2(24, -24), Vector2(-24, 0), Vector2(24, 0), Vector2(-24, 24), Vector2(24, 24)]
	for pip in pips:
		draw_rect(Rect2(pip + Vector2(-7, -9), Vector2(14, 14)), Color("51442e"))
		draw_rect(Rect2(pip + Vector2(-4, -6), Vector2(8, 5)), Color("30271e"))
