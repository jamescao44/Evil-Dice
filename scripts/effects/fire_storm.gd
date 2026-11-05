extends RefCounted
## Authored 64px storm frames; combat owns the loop's start and end.
const Emitter = preload("res://scripts/effects/baked_emitter.gd")
const AttackStyle = preload("res://scripts/player/attack_presentation.gd")
const SHEET = preload("res://assets/art/fx/fire_storm.png")
const CELL := 64
const BUILD_FRAMES := 7
const LOOP_FIRST := 7
const LOOP_FRAMES := 6
const FADE_FIRST := 13
const FADE_FRAMES := 5
const LOOP_FPS := 18.0
const LOOP_REPEATS := 4
const LOOP_DURATION := LOOP_FRAMES*LOOP_REPEATS/LOOP_FPS
const BUILD_DURATION := 0.63
const FADE_FPS := 20.0
const FADE_DURATION := FADE_FRAMES/FADE_FPS
const CAST_DURATION := BUILD_DURATION+LOOP_DURATION+FADE_DURATION
const VISUAL_SCALE := 1.5
const SIDE := 192.0
static var halo: GradientTexture2D

## Shuffle cosmetic offsets without consuming any gameplay randomness.
static func prepare(spell: Dictionary, rng: RandomNumberGenerator) -> void:
	var offsets: Array = []
	var bag: Array = []
	var emitters: Array = []
	var seed_value: int = rng.randi()
	for i in range(spell.targets.size()):
		if bag.is_empty(): bag = range(LOOP_FRAMES)
		offsets.append(bag.pop_at(rng.randi_range(0,bag.size()-1)))
		emitters.append(Emitter.create("storm",seed_value+i,spell.style.particles))
	spell.storm = {"phase":"build","age":0.0,"total_age":0.0,"build_duration":BUILD_DURATION,"offsets":offsets,"pulse":0.0,"emitters":emitters}
	spell.storm.merge(AttackStyle.loop_timing(spell.form,LOOP_FRAMES,LOOP_FPS,spell.ticks))

## Distribute all five damage pulses across the same four-cycle animation clock.
static func damage_tick_time(tick: int, count: int) -> float:
	return LOOP_DURATION*tick/maxi(1,count-1)

## Enter the randomized loop exactly when the first damage pulse lands.
static func begin_damage(spell: Dictionary) -> void:
	if not spell.has("storm"): return
	spell.storm.phase = "loop"
	spell.storm.age = 0.0
	spell.storm.pulse = 1.0

## Play every authored closing frame once after the form's complete loops.
static func finish(spell: Dictionary) -> void:
	if not spell.has("storm") or spell.storm.phase == "fade": return
	spell.storm.phase = "fade"
	spell.storm.age = 0.0
	spell.erase("hold_damage")

## Advance in battle time, keeping loops alive through slow motion and delayed ticks.
static func advance(spell: Dictionary, delta: float, _reduced: bool = false) -> bool:
	var state: Dictionary = spell.storm
	state.age += delta
	state.total_age += delta
	state.pulse = maxf(0,state.pulse-delta*7)
	# Standalone previews can use the ordinary duration without a combat controller.
	if not spell.get("hold_damage",false):
		if state.phase == "build" and state.age >= state.build_duration: begin_damage(spell)
		elif state.phase == "loop" and state.age >= state.loop_duration: finish(spell)
	for emitter in state.emitters: Emitter.advance(emitter,delta,state.phase == "loop")
	return state.phase == "fade" and state.age >= FADE_DURATION and state.emitters.all(func(emitter): return emitter.packets.is_empty())

## Use zero-based atlas cells while preserving the author's three frame ranges.
static func frame(spell: Dictionary, target: int) -> int:
	var state: Dictionary = spell.storm
	match state.phase:
		"build": return mini(BUILD_FRAMES-1,floori(state.age/maxf(0.001,state.build_duration)*BUILD_FRAMES))
		"loop": return LOOP_FIRST+(state.offsets[target]+mini(state.loop_frames-1,floori(state.age*state.loop_fps)))%LOOP_FRAMES
		_: return FADE_FIRST+mini(FADE_FRAMES-1,floori(state.age*FADE_FPS))

## Clip each cell to prevent bright neighboring frames bleeding into the sprite.
static func paint_frame(canvas: CanvasItem, cell: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(SHEET,rect,Rect2(cell*CELL,0,CELL,CELL),tint,false,true)

## Cache one soft halo texture; the original sprite stays sharp and unchanged.
static func glow_texture() -> GradientTexture2D:
	if halo == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.3,0.62,1.0])
		gradient.colors = PackedColorArray([Color(1,1,1,0.7),Color(1,1,1,0.42),Color(1,1,1,0.13),Color(1,1,1,0)])
		halo = GradientTexture2D.new()
		halo.width = 128; halo.height = 128
		halo.gradient = gradient
		halo.fill = GradientTexture2D.FILL_RADIAL
		halo.fill_from = Vector2(0.5,0.5); halo.fill_to = Vector2(1,0.5)
	return halo

## Surround the intact pixel tornado with golden light and rising orange embers.
static func paint(canvas: CanvasItem, spell: Dictionary, target: int, reduced: bool) -> void:
	var state: Dictionary = spell.storm
	var cell: int = frame(spell,target)
	var age: float = state.total_age+state.offsets[target]*0.17
	var strength: float = smoothstep(0,1,state.age/state.build_duration) if state.phase == "build" else 1.0
	if state.phase == "fade": strength = 1-smoothstep(0,FADE_DURATION,state.age)
	var pulse: float = 1.0 if reduced else 0.94+sin(age*17)*0.06+state.pulse*0.18
	var rect := Rect2(Vector2(-SIDE*0.5,-SIDE*0.6),Vector2.ONE*SIDE)
	var light: float = strength*(0.55 if reduced else 1.0)*spell.style.glow
	canvas.draw_texture_rect(glow_texture(),rect.grow(42),false,Color(1,0.62,0.035,light*pulse))
	canvas.draw_texture_rect(glow_texture(),rect.grow(8),false,Color(1,0.8,0.23,light*0.8))
	var visible_sprite: bool = state.phase != "fade" or state.age < FADE_DURATION
	if not reduced and visible_sprite:
		for i in range(8):
			var offset := Vector2.from_angle(i*TAU/8)*5
			paint_frame(canvas,cell,Rect2(rect.position+offset,rect.size),Color(1,0.74,0.2,0.16*strength))
	if visible_sprite: paint_frame(canvas,cell,rect)
	Emitter.paint(canvas,state.emitters[target],reduced)
