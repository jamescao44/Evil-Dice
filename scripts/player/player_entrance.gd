extends RefCounted
## Authored summoning clips and their ground light, silhouette release and ring reveal.
const Sprite = preload("res://scripts/player/player_sprite.gd")
const Circle = preload("res://scripts/player/player_cast_circle.gd")
const CLIPS := [
	{"first":50,"last":63},
	{"first":65,"last":80,"white_last":68},
	{"first":134,"last":149,"white_last":139,"ring":146}
]
const FADE := 0.45
var age := -1.0
var form := 0
var evolved := false
static var light: GradientTexture2D

## Start at the authored first cell; level entrances do not use an evolution silhouette.
func start(value: int, evolution: bool = false) -> void:
	form = clampi(value,0,2)
	evolved = evolution
	age = 0

func reset() -> void:
	age = -1

func active() -> bool:
	return age >= 0

func clip_duration() -> float:
	return float(CLIPS[form].last-CLIPS[form].first+1)/Sprite.IDLE_FPS

func duration() -> float:
	return clip_duration()+FADE

func advance(delta: float) -> void:
	if not active(): return
	age += delta
	if age >= duration(): age = -1

## Hold each entrance cell for the shared idle cadence, then settle into idle.
func frame_number(idle_frame: int) -> int:
	if not active() or age >= clip_duration(): return idle_frame
	return mini(CLIPS[form].last,CLIPS[form].first+floori(age*Sprite.IDLE_FPS+0.00001))

func white_release_time() -> float:
	return float(CLIPS[form].get("white_last",CLIPS[form].first)-CLIPS[form].first+1)/Sprite.IDLE_FPS

## Keep the requested cells completely white, then ease the authored color back in.
func white_alpha() -> float:
	if not active() or not evolved: return 0
	var fade: float = 0.50 if form == 2 else 0.32
	return 1-smoothstep(white_release_time(),white_release_time()+fade,age)

func ring_alpha() -> float:
	if not active() or form != 2: return 1
	var cue: float = float(CLIPS[form].ring-CLIPS[form].first)/Sprite.IDLE_FPS
	return 0 if age+0.00001 < cue else 1

func ring_flash() -> float:
	if not active() or form != 2: return 0
	var cue: float = float(CLIPS[form].ring-CLIPS[form].first)/Sprite.IDLE_FPS
	return 0 if age+0.00001 < cue else 1-smoothstep(cue,cue+0.45,age)

## One cached soft light provides a flat floor halo and an upward summoning column.
static func light_texture() -> GradientTexture2D:
	if light == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0,0.3,0.65,1])
		gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.7),Color(1,1,1,0.22),Color(1,1,1,0)])
		light = GradientTexture2D.new()
		light.width = 128; light.height = 128; light.gradient = gradient
		light.fill = GradientTexture2D.FILL_RADIAL
		light.fill_from = Vector2(0.5,0.5); light.fill_to = Vector2(1,0.5)
	return light

## Draw behind the character in battlefield coordinates so the summon stays on the floor.
func paint_ground(canvas: CanvasItem, rect: Rect2, reduced: bool, tint: Color) -> void:
	if not active(): return
	var bounds := Sprite.rest_bounds(form)
	var feet: Vector2 = Sprite.ground_anchor(rect,form)
	var radius: float = rect.size.x*maxf(0.23,bounds.size.x*0.63)
	var fade: float = 1-smoothstep(clip_duration(),duration(),age)
	var alpha: float = smoothstep(0,0.13,age)*fade*tint.a
	var floor_size := Vector2(radius*2.8,radius*0.80)
	canvas.draw_texture_rect(light_texture(),Rect2(feet-floor_size/2,floor_size),false,Color(1,0.56,0.12,alpha*0.65))
	Circle.ring(canvas,feet,radius,age*0.65,alpha,reduced)
	if form == 0: return
	var height: float = rect.size.y*bounds.size.y*(1.18 if form == 1 else 1.38)
	var strength: float = smoothstep(0,0.35,age)*fade*tint.a*(0.60 if form == 1 else 0.95)
	var beam_rect := Rect2(feet-Vector2(radius,height),Vector2(radius*2,height*1.35))
	canvas.draw_texture_rect(light_texture(),beam_rect,false,Color(1,0.70,0.23,strength))
	# Soft, tapered vertical bands add height without obscuring the authored sprite.
	for i in range(9 if form == 2 else 5):
		var x: float = sin(i*2.4)*radius*0.78
		var tall: float = height*(0.72+0.20*sin(i*1.7))
		var vertices := PackedVector2Array([feet+Vector2(x-3,0),feet+Vector2(x+3,0),feet+Vector2(x+1,-tall),feet+Vector2(x-1,-tall)])
		canvas.draw_polygon(vertices,PackedColorArray([Color(1,0.91,0.66,strength*0.45),Color(1,0.91,0.66,strength*0.45),Color(1,0.95,0.80,0),Color(1,0.95,0.80,0)]))

## White fragments peel away as the held silhouette reveals the new form.
func paint_release(canvas: CanvasItem, rect: Rect2, reduced: bool, tint: Color) -> void:
	if not active() or not evolved: return
	var elapsed: float = age-white_release_time()
	if elapsed < 0 or elapsed > 0.85: return
	var bounds := Sprite.rest_bounds(form)
	var visible := Rect2(rect.position+rect.size*bounds.position,rect.size*bounds.size)
	var count: int = (44 if form == 2 else 22) if not reduced else 8
	for i in range(count):
		var delay: float = fmod(i*0.061,0.18)
		var t: float = (elapsed-delay)/0.62
		if t < 0 or t > 1: continue
		var angle: float = i*2.39996
		var seed: Vector2 = Vector2(sin(i*4.13),cos(i*1.91))*visible.size*0.30
		var velocity: Vector2 = Vector2(cos(angle),sin(angle)-0.55)*visible.size.y*(0.65 if form == 2 else 0.48)
		var at: Vector2 = visible.get_center()+seed+velocity*t+Vector2(0,visible.size.y*0.18*t*t)
		var side: float = (3+i%4)*(1-t*0.65)*(1.25 if form == 2 else 1)
		var alpha: float = sin(t*PI)*(1-t)*tint.a
		canvas.draw_rect(Rect2(at-Vector2.ONE*side,Vector2.ONE*side*2),Color(1,0.95,0.85,alpha*0.18))
		canvas.draw_rect(Rect2(at-Vector2.ONE*side/2,Vector2.ONE*side),Color(1,1,1,alpha))
