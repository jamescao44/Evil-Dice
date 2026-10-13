extends RefCounted
## Cosmetic only: acquisition is already committed before this flight starts.
const Paint = preload("res://scripts/relic_paint.gd")
const Catalog = preload("res://scripts/relic_catalog.gd")
const Pixel = preload("res://scripts/pixel_paint.gd")
const LIFT_TIME := 0.10
const FLIGHT_TIME := 0.28
const LAND_TIME := LIFT_TIME + FLIGHT_TIME
const DURATION := LAND_TIME + 0.22
var active: bool = false
var landed: bool = false
var id: String = ""
var slot: int = -1
var origin := Vector2.ZERO
var radius: float = 40
var age: float = 0

func start(relic_id: String, destination: int, from: Vector2, icon_radius: float) -> void:
	id = relic_id
	slot = destination
	origin = from
	radius = icon_radius
	age = 0
	landed = false
	active = true

func clear() -> void:
	active = false
	landed = false
	slot = -1

func advance(delta: float) -> bool:
	if not active: return false
	age += delta
	var impact: bool = not landed and age >= LAND_TIME
	landed = age >= LAND_TIME
	if age >= DURATION: active = false
	return impact

func inventory_scale(index: int, reduced: bool) -> Vector2:
	if not active or not landed or index != slot or reduced: return Vector2.ONE
	var t: float = clampf((age-LAND_TIME)/(DURATION-LAND_TIME),0,1)
	var bounce: float = cos(t*PI*3)*(1-t)*(1-t)
	return Vector2(1+0.25*bounce,1-0.22*bounce)

func flight_position(target: Vector2, reduced: bool) -> Vector2:
	var lift := Vector2(0,-24)
	if reduced: return origin.lerp(target,clampf(age/LAND_TIME,0,1))
	if age < LIFT_TIME: return origin+lift*sin(age/LIFT_TIME*PI/2)
	var t: float = clampf((age-LIFT_TIME)/FLIGHT_TIME,0,1)
	# Accelerating into the bar gives the landing weight without shaking the UI.
	return (origin+lift).lerp(target,t*t)-Vector2(0,sin(t*PI)*26)

func paint(canvas: CanvasItem, target: Vector2, final_radius: float, reduced: bool) -> void:
	if not active: return
	var color: Color = Catalog.rarity_color(id).lightened(0.3)
	if not landed:
		var t: float = clampf((age-LIFT_TIME)/FLIGHT_TIME,0,1)
		var at: Vector2 = flight_position(target,reduced)
		var side: float = lerpf(radius,final_radius,t*t)
		if not reduced:
			side *= 1+sin(clampf(age/LAND_TIME,0,1)*PI)*0.15
			for i in range(3): canvas.draw_circle(at,side+4+i*5,Color(color,0.09-i*0.02))
			if t > 0:
				var direction: Vector2 = (target-origin).normalized()
				for i in range(3):
					var end: Vector2 = at-direction*(side+10+i*12)
					Pixel.line(canvas,end-direction*14,end,Color(color,0.5-i*0.12),3)
		canvas.draw_set_transform(at,0 if reduced else -sin(t*PI)*0.16)
		Paint.paint(canvas,id,Vector2.ZERO,side)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		var t: float = clampf((age-LAND_TIME)/(DURATION-LAND_TIME),0,1)
		var fade: float = 1-t
		if reduced:
			Pixel.circle(canvas,target,final_radius+5,Color(color,fade*0.6),2)
			return
		Pixel.circle(canvas,target,final_radius+4+t*30,Color(color,fade*0.8),3)
		for i in range(8):
			var direction := Vector2.from_angle(i*TAU/8)
			var at: Vector2 = target+direction*(final_radius+6+t*38)
			Pixel.line(canvas,at,at+direction*6*fade,Color("fff2c8",fade),3)
