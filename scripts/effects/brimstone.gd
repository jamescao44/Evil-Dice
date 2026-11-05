extends RefCounted
## Final-form pillar and early-form lasers share combat-owned buildup and damage timing.
const SHEET = preload("res://assets/art/fx/brimstone.png")
const Storm = preload("res://scripts/effects/fire_storm.gd")
const Emitter = preload("res://scripts/effects/baked_emitter.gd")
const AttackStyle = preload("res://scripts/player/attack_presentation.gd")
const Laser = preload("res://scripts/effects/brimstone_laser.gd")
const CELL := 64
const BUILD_FRAMES := 24
const BUILD_FPS := 20.0
const BUILD_DURATION := BUILD_FRAMES/BUILD_FPS
const EXPAND_FRAMES := 14
const EXPAND_DURATION := EXPAND_FRAMES/BUILD_FPS
const LOOP_FIRST := 24
const LOOP_FRAMES := 8
const LOOP_REPEATS := 4
const LOOP_FPS := 16.0*1.3
const LOOP_DURATION := LOOP_FRAMES*LOOP_REPEATS/LOOP_FPS
const FADE_FIRST := 32
const FADE_FRAMES := 8
const FADE_FPS := 16.0
const FADE_DURATION := FADE_FRAMES/FADE_FPS
const CAST_DURATION := BUILD_DURATION+LOOP_DURATION+FADE_DURATION
const OPACITY := 0.7
const PORTRAIT_SIDE := 1024.0
const LANDSCAPE_SIDE := 1280.0
const SIZE_SCALE := 0.7
const GROUND_PIXEL := 61.0/64.0
const FLOOR_PADDING := 40.0
const GLOW_SCALE := 2.0

## Use individual grounded lasers for early forms, or a fixed-size pillar for the final form.
static func prepare(spell: Dictionary, portrait: bool, rng: RandomNumberGenerator) -> void:
	var points: Array = spell.get("world_health_bottoms",spell.get("world_feet",spell.world_targets))
	var anchor := Vector2.ZERO
	if not points.is_empty():
		var left: float = points[0].x
		var right: float = left
		anchor.y = points[0].y
		for point in points:
			left = minf(left,point.x); right = maxf(right,point.x)
			anchor.y = maxf(anchor.y,point.y)
		anchor.x = (left+right)*0.5
	spell.world_brimstone_anchor = anchor
	spell.brimstone_side = (PORTRAIT_SIDE if portrait else LANDSCAPE_SIDE)*SIZE_SCALE
	var emitters: Array = []
	if spell.form < 2:
		spell.world_brimstone_anchors = spell.get("world_feet",spell.world_targets).duplicate()
		spell.finish_on_last_hit = true
	for i in range(0 if spell.form < 2 else 1):
		emitters.append(Emitter.create("beam",rng.randi(),spell.style.particles))
	spell.brimstone = {"phase":"build","age":0.0,"total_age":0.0,"build_duration":BUILD_DURATION,"pulse":0.0,"emitters":emitters}
	spell.brimstone.merge(AttackStyle.loop_timing(spell.form,LOOP_FRAMES,LOOP_FPS,spell.ticks,Laser.TICK_INTERVAL if spell.form < 2 else 0.1))

## Spread ten hits across four faster loops, leaving over 100ms between ticks.
static func damage_tick_time(tick: int, count: int) -> float:
	return LOOP_DURATION*tick/maxi(1,count-1)

## Start the beam and damage together, after all twenty-four buildup frames.
static func begin_damage(spell: Dictionary) -> void:
	spell.brimstone.phase = "loop"
	spell.brimstone.age = 0.0
	spell.brimstone.pulse = 1.0

## Keep all eight closing frames and remaining sparks independent of the next skill.
static func finish(spell: Dictionary) -> void:
	spell.brimstone.phase = "fade"
	spell.brimstone.age = 0.0
	spell.erase("hold_damage")

## Follow battle time, including menu pauses and kill slow motion.
static func advance(spell: Dictionary, delta: float, _reduced: bool = false) -> bool:
	var state: Dictionary = spell.brimstone
	state.age += delta
	state.total_age += delta
	state.pulse = maxf(0,state.pulse-delta*8)
	if not spell.get("hold_damage",false):
		if state.phase == "build" and state.age >= state.build_duration: begin_damage(spell)
		elif state.phase == "loop" and state.age >= state.loop_duration: finish(spell)
	for emitter in state.emitters: Emitter.advance(emitter,delta,state.phase in ["build","loop"])
	var fade: float = Laser.FADE_DURATION if spell.form < 2 else FADE_DURATION
	return state.phase == "fade" and state.age >= fade and state.emitters.all(func(emitter): return emitter.packets.is_empty())

## Hold the final loop cell if combat is late; never silently add another cycle.
static func frame(spell: Dictionary) -> int:
	var state: Dictionary = spell.brimstone
	match state.phase:
		"build": return mini(BUILD_FRAMES-1,floori(state.age/state.build_duration*BUILD_FRAMES))
		"loop": return LOOP_FIRST+mini(state.loop_frames-1,floori(state.age*state.loop_fps))%LOOP_FRAMES
		_: return FADE_FIRST+mini(FADE_FRAMES-1,floori(state.age*FADE_FPS))

## Fade and expand from a small circle over exactly the first fourteen buildup frames.
static func buildup_progress(state: Dictionary) -> float:
	return smoothstep(0,state.get("build_duration",BUILD_DURATION)*EXPAND_FRAMES/BUILD_FRAMES,state.age) if state.phase == "build" else 1.0

## Fade the sprite itself, its halo and silhouettes together through all eight exit frames.
static func visual_alpha(state: Dictionary) -> float:
	return 1-smoothstep(0,FADE_DURATION,state.age) if state.phase == "fade" else buildup_progress(state)

## Keep the authored ground contact fixed as the circle grows into the pillar.
static func visual_rect(spell: Dictionary) -> Rect2:
	var side: float = spell.brimstone_side*lerpf(0.15,1.0,buildup_progress(spell.brimstone))
	return Rect2(spell.brimstone_anchor-Vector2(side*0.5,side*GROUND_PIXEL),Vector2.ONE*side)

## Render intact cells with a little transparency so the formation stays visible.
static func paint_frame(canvas: CanvasItem, cell: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(SHEET,rect,Rect2(cell*CELL,0,CELL,CELL),tint,false,true)

## Layer rich gold light around a single pillar without washing out its pixel edges.
static func paint(canvas: CanvasItem, spell: Dictionary, reduced: bool) -> void:
	if spell.form < 2:
		Laser.paint(canvas,spell,reduced)
		return
	paint_beam(canvas,spell,reduced,0)

## The final form retains the full authored pillar, halo and particle fountain.
static func paint_beam(canvas: CanvasItem, spell: Dictionary, reduced: bool, index: int) -> void:
	var state: Dictionary = spell.brimstone
	var rect: Rect2 = visual_rect(spell)
	var cell: int = frame(spell)
	var strength: float = visual_alpha(state)
	var light: float = strength*(0.55 if reduced else 1.0)*spell.style.glow
	var pulse: float = 1.0 if reduced else 0.95+sin(state.total_age*23)*0.05+state.pulse*0.1
	paint_sparks(canvas,spell,reduced,index)
	var halo_scale: float = GLOW_SCALE
	var spread_scale: float = spell.style.size
	for halo in [{"spread":52,"color":Color(1,0.65,0.04,light*0.8*pulse)},{"spread":12,"color":Color(1,0.84,0.28,light*0.6)}]:
		var glow: Rect2 = rect.grow(halo.spread*spread_scale)
		glow = Rect2(glow.get_center()-glow.size*halo_scale*0.5,glow.size*halo_scale)
		canvas.draw_texture_rect(Storm.glow_texture(),glow,false,halo.color)
	if not reduced and strength > 0:
		for i in range(12):
			var offset := Vector2.from_angle(i*TAU/12)*rect.size.x*0.015
			paint_frame(canvas,cell,Rect2(rect.position+offset,rect.size),Color(1,0.72,0.16,0.085*strength))
	if strength > 0: paint_frame(canvas,cell,rect,Color(1,1,1,OPACITY*strength))

## Draw rising debris behind the beam and its glow, retaining the natural fading tails.
static func paint_sparks(canvas: CanvasItem, spell: Dictionary, reduced: bool = false, index: int = 0) -> void:
	if index >= spell.brimstone.emitters.size(): return
	Emitter.paint(canvas,spell.brimstone.emitters[index],reduced,spell.brimstone_anchor,Vector2(spell.brimstone_side/900.0,1.0))
