extends RefCounted
## Shared tail-free arrowhead for closed chests and collectible rewards.

static func paint(canvas: CanvasItem, rect: Rect2, age: float, portrait: bool, reduced: bool) -> void:
	var scale: float = 1.35 if portrait else 1.0
	var bounce: float = 0 if reduced else absf(sin(age*PI*1.5))*9*scale
	var at := Vector2(rect.get_center().x,rect.position.y-23*scale-bounce)
	var points := PackedVector2Array([at+Vector2(-17,-7)*scale,at+Vector2(17,-7)*scale,at+Vector2(0,10)*scale])
	var shadow := PackedVector2Array()
	for point in points: shadow.append(point+Vector2(0,3)*scale)
	canvas.draw_colored_polygon(shadow,Color("30261b",0.8))
	canvas.draw_colored_polygon(points,Color("ffe3a0"))
