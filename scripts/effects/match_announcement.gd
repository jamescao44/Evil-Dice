extends Node2D
## One localized callout per matching group; all motion is cosmetic and deterministic.
const LABELS := ["Double", "Triple", "Quadruple", "Quintuple", "Sextuple"]
const COLORS := [Color("fff1c5"), Color("ffd28c"), Color("ffb363"), Color("ff884f"), Color("ffe271")]
const FREQUENCIES := [0.0, 1.8, 4.8, 10.0, 16.0]
const ROTATIONS := [0.0, 0.06, 0.075, 0.06, 0.0]
const SHAKES := [0.0, 0.0, 1.5, 3.0, 5.2]
const RISE_TIME := 0.46
const PEAK_HOLD := 0.16
const FADE_TIME := 0.36
const FALL_TIME := 0.44
const POP_TIME := 0.12
const SETTLE_TIME := 0.20
const CombinationAudio = preload("res://scripts/dice/combination_audio.gd")
var battle
var count: int = 2
var age: float = -1.0
var release_age: float = -1.0

func _ready() -> void:
	z_index = BattleLayers.BANNER

## Start only at the first hit of a group, including multi-pulse ritual attacks.
func play(alikes: int) -> void:
	count = clampi(alikes, 2, 6)
	age = 0.0
	release_age = -1.0
	CombinationAudio.play(count,battle._sound)
	queue_redraw()

## Rare matches hold above the health bar until their full ritual has finished.
func finish() -> void:
	if age >= 0.0 and count >= 5 and release_age < 0.0:
		release_age = maxf(age,RISE_TIME+PEAK_HOLD)
		queue_redraw()

## Discard pending text when combat is cancelled or leaves the battlefield.
func clear() -> void:
	age = -1.0
	release_age = -1.0
	queue_redraw()

## Pause under menus without delaying attacks or advancing combat randomness.
func _process(delta: float) -> void:
	if battle.view_phase in ["over", "reward", "wave_reward", "collecting", "transition", "shop"]:
		if age >= 0.0: clear()
	visible = not battle._menus_open() and battle.inspecting_enemy < 0
	if not visible: return
	if age < 0.0: return
	age += delta
	if age >= fade_start()+fade_duration(): age = -1.0
	queue_redraw()

## Doubles vanish at the apex; triples and quadruples get a short falling exit.
func fade_duration() -> float:
	return FALL_TIME if count in [3,4] else FADE_TIME

## Wait for the ritual's completion signal before fading five- and six-alike labels.
func fade_start() -> float:
	return (release_age if release_age >= 0.0 else INF) if count >= 5 else RISE_TIME+PEAK_HOLD

## Fade into the upward pop, then out without moving the rare-match landing point.
func opacity() -> float:
	var fade: float = 0.0 if is_inf(fade_start()) else smoothstep(fade_start(),fade_start()+fade_duration(),age)
	return smoothstep(0,0.14,age)*(1.0-fade)

## Rise along the dice centerline to above player HP; middle tiers fall on the same axis.
func anchor(text_height: float) -> Vector2:
	var bar: Rect2 = battle.player_health_rect()
	var apex := Vector2(battle.DICE_CENTER.x,bar.position.y-text_height*0.5-16)
	var origin: Vector2 = battle.DICE_CENTER-Vector2(0,battle.DICE_RADIUS*0.3)
	var progress: float = clampf(age/RISE_TIME,0,1)
	var at: Vector2 = origin.lerp(apex,1.0-pow(1.0-progress,3))
	if count in [3,4] and age > fade_start():
		var fall: float = clampf((age-fade_start())/FALL_TIME,0,1)
		at.y += battle.DICE_RADIUS*0.65*fall*fall
	return at

## Scale up rapidly, settle, then fade; higher groups have a stronger entrance.
func pop_scale() -> float:
	if battle.reduced: return 1.0
	var peak: float = 1.10 + (count - 2) * 0.055
	if age < POP_TIME:
		return lerpf(0.45, peak, 1.0 - pow(1.0 - clampf(age / POP_TIME, 0, 1), 3))
	return lerpf(peak, 1.0, smoothstep(0, SETTLE_TIME, age - POP_TIME))

## Double stays steady, Triple sways slowly, and Sextuple trembles without tilting.
func motion() -> Vector3:
	if battle.reduced or count == 2: return Vector3.ZERO
	var tier: int = count - 2
	var phase: float = maxf(0.0, age - POP_TIME) * TAU * FREQUENCIES[tier]
	var envelope: float = 1.0 if is_inf(fade_start()) else 1.0-smoothstep(fade_start(),fade_start()+fade_duration(),age)
	return Vector3(sin(phase) * SHAKES[tier], sin(phase * 1.37) * SHAKES[tier] * 0.5,
		sin(phase) * ROTATIONS[tier]) * envelope

## Keep the rising label readable in both layouts and clear of the health bar at its apex.
func _draw() -> void:
	if age < 0.0: return
	var tier: int = count - 2
	var label: String = GameText.text(LABELS[tier])
	var font: Font = battle.description_font
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var size: int = roundi((40 + tier * 8) * (1.25 if portrait else 1.0))
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var max_width: float = battle.ARENA.size.x * 0.82 / 1.4
	if width > max_width:
		size = floori(size * max_width / width)
		width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var move := motion()
	var center: Vector2 = anchor(font.get_height(size))
	draw_set_transform(center + Vector2(move.x, move.y), move.z, Vector2.ONE * pop_scale())
	var alpha: float = opacity()
	var baseline := Vector2(-width * 0.5, (font.get_ascent(size) - font.get_descent(size)) * 0.5)
	draw_string_outline(font, baseline + Vector2(0, 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0.08, 0.04, 0.02, alpha))
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(COLORS[tier], alpha * 0.45))
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(COLORS[tier], alpha))
