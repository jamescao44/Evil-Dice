extends RefCounted
## Shared, cosmetic drag feedback. Keep the center clear and energy at the edges.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const OPACITY := 0.22
const SCALE := 1.35
var amount: float = 0.0
var clock: float = 0.0

func reset() -> void:
	amount = 0.0
	clock = 0.0

func advance(delta: float, dragging: bool, in_area: bool, reduced: bool) -> void:
	if not dragging:
		reset()
		return
	amount = move_toward(amount,1.0 if in_area else 0.0,delta*9)
	if not reduced: clock += delta

func strength() -> float:
	return smoothstep(0,1,amount)

func opacity() -> float:
	return lerpf(1.0,OPACITY,strength())

func scale_factor() -> float:
	return lerpf(1.0,SCALE,strength())

func paint(canvas: CanvasItem, at: Vector2, extent: Vector2, color: Color, reduced: bool) -> void:
	if amount <= 0: return
	var light: Color = color.lightened(0.4)
	for wave in range(1 if reduced else 2):
		var t: float = 0.12 if reduced else fposmod(clock/1.05+wave*0.5,1.0)
		var fade: float = strength()*(1-t)
		var radii: Vector2 = extent*(1.07+t*0.4)
		var points := PackedVector2Array()
		for i in range(49):
			points.append((at+Vector2.from_angle(i*TAU/48)*radii).snapped(Vector2.ONE*2))
		canvas.draw_polyline(points,Color(color,fade*0.07),8)
		canvas.draw_polyline(points,Color(light,fade*0.48),2)
		if reduced: continue
		for i in range(10):
			var angle: float = i*TAU/10+wave*0.29+clock*0.22
			var p: Vector2 = (at+Vector2.from_angle(angle)*radii).snapped(Vector2.ONE*2)
			canvas.draw_rect(Rect2(p-Vector2.ONE*5,Vector2.ONE*10),Color(color,fade*0.1))
			canvas.draw_rect(Rect2(p-Vector2.ONE*2,Vector2.ONE*4),Color(light,fade*0.95))
			if i%3 == 0:
				canvas.draw_line(p-Vector2(6,0),p+Vector2(6,0),Color(light,fade*0.65),2)
				canvas.draw_line(p-Vector2(0,6),p+Vector2(0,6),Color(light,fade*0.65),2)

static func paint_target(canvas: CanvasItem, bounds: Rect2, selected: bool, color: Color, portrait: bool) -> void:
	var rect: Rect2 = bounds.grow((16 if portrait else 10) if selected else (8 if portrait else 5))
	var tint := Color(color,1.0 if selected else 0.38)
	var size: float = (34 if portrait else 25) if selected else (22 if portrait else 15)
	var thickness: int = (5 if portrait else 4) if selected else 3
	if selected:
		canvas.draw_rect(rect,Color(color,0.04))
		Pixel.disc(canvas,Vector2(rect.get_center().x,rect.end.y),rect.size.x*0.55,Color(color,0.15),3,0.18)
	for x in [rect.position.x,rect.end.x]:
		for y in [rect.position.y,rect.end.y]:
			var p := Vector2(x,y)
			Pixel.line(canvas,p,p+Vector2(size if x == rect.position.x else -size,0),tint,thickness)
			Pixel.line(canvas,p,p+Vector2(0,size if y == rect.position.y else -size),tint,thickness)
	if selected:
		var p := Vector2(rect.get_center().x,rect.position.y-10)
		var tip := Vector2(17,12) if portrait else Vector2(12,9)
		Pixel.line(canvas,p-Vector2(tip.x,tip.y),p,tint,thickness)
		Pixel.line(canvas,p+Vector2(tip.x,-tip.y),p,tint,thickness)
