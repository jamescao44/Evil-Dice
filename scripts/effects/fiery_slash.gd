extends RefCounted
## Authored 32px slash: five windup frames, then one impact on frame six.
const SHEET = preload("res://assets/art/fx/fiery_slash.png")
const Glow = preload("res://scripts/effects/fire_storm.gd")
const Embers = preload("res://scripts/effects/flame_particles.gd")
const CELL := 32
const FRAMES := 10
const IMPACT_FRAME := 5
const FPS := 18.0
const DAMAGE_SPEED := 0.7
const CAST_DURATION := IMPACT_FRAME/FPS+(FRAMES-IMPACT_FRAME)/(FPS*DAMAGE_SPEED)
const SIDE := 192.0

## Keep frame timing proportional to the cast speed without borrowing combat randomness.
static func prepare(spell: Dictionary) -> void:
	var fps: float = FPS*CAST_DURATION/maxf(0.001,spell.duration)
	spell.fiery_slash = {"phase":"build","age":0.0,"fps":fps,"damage_fps":fps*DAMAGE_SPEED,"build_duration":IMPACT_FRAME/fps}

## Reveal frame six on the same combat step that applies the area hit.
static func begin_damage(spell: Dictionary) -> void:
	spell.fiery_slash.phase = "fade"
	spell.fiery_slash.age = 0.0

## Detach the remaining frames so another cast cannot cut off the slash's ending.
static func finish(spell: Dictionary) -> void:
	spell.erase("hold_damage")

## Follow battle time and hold the windup until the combat controller confirms impact.
static func advance(spell: Dictionary, delta: float, _reduced: bool = false) -> bool:
	var state: Dictionary = spell.fiery_slash
	state.age += delta
	if state.phase == "build" and state.age >= state.build_duration and not spell.get("hold_damage",false):
		begin_damage(spell)
	return state.phase == "fade" and state.age >= (FRAMES-IMPACT_FRAME)/state.damage_fps

## Read intact atlas cells, with the last windup frame held during any combat delay.
static func frame(spell: Dictionary) -> int:
	var state: Dictionary = spell.fiery_slash
	var step: int = floori(state.age*(state.fps if state.phase == "build" else state.damage_fps))
	return mini(IMPACT_FRAME-1,step) if state.phase == "build" else mini(FRAMES-1,IMPACT_FRAME+step)

## Clip the cell edges to keep adjacent atlas frames out of the slash.
static func paint_frame(canvas: CanvasItem, cell: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(SHEET,rect,Rect2(cell*CELL,0,CELL,CELL),tint,false,true)

## Add orange light behind the unchanged pixel sprite, peaking when damage lands.
static func paint(canvas: CanvasItem, spell: Dictionary, reduced: bool) -> void:
	var state: Dictionary = spell.fiery_slash
	var strength: float = lerpf(0.1,1.0,smoothstep(0,state.build_duration,state.age)) if state.phase == "build" else 1.0-smoothstep(0,(FRAMES-IMPACT_FRAME)/state.damage_fps,state.age)
	var rect := Rect2(-Vector2.ONE*SIDE*0.5,Vector2.ONE*SIDE)
	var light: float = strength*(0.5 if reduced else 1.0)
	canvas.draw_texture_rect(Glow.glow_texture(),rect.grow(24),false,Color(1,0.29,0.025,light*0.7))
	var cell: int = frame(spell)
	if not reduced:
		for i in range(8):
			var offset := Vector2.from_angle(i*TAU/8)*4
			paint_frame(canvas,cell,Rect2(rect.position+offset,rect.size),Color(1,0.42,0.06,0.16*strength))
	paint_frame(canvas,cell,rect)
	if state.phase != "build":
		var progress: float = clampf(state.age*state.damage_fps/(FRAMES-IMPACT_FRAME),0,1)
		# Sparks peel off the slash's curved blade as its damage frame arrives.
		for i in range(18 if reduced else 104):
			var delay: float = fposmod(i*0.754877,1.0)*0.16
			if progress < delay: continue
			var travel: float = (progress-delay)/(1-delay)
			var angle: float = -PI*0.92+fposmod(i*0.618034,1.0)*PI*1.45
			var direction := Vector2.from_angle(angle)
			var scatter: float = fposmod(i*0.414214,1.0)
			var point: Vector2 = direction*Vector2(78,50)*(0.7+scatter*0.4)+direction*travel*(30+scatter*110)+Vector2(55,-35)*travel
			Embers.spark(canvas,point,2+i%4,Color("ffb448"),1-travel)
