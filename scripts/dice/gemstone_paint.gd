extends RefCounted
## Faceted pixel gemstones share silhouettes across inventory, sockets and enemy drops.
const Gems = preload("res://scripts/dice/gemstone_inventory.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const StatusPaint = preload("res://scripts/status/status_paint.gd")

static func paint(canvas: CanvasItem, at: Vector2, gem: Dictionary, radius: float, glow: bool = true) -> void:
	if not Gems.valid_gem(gem): return
	var color: Color = Gems.Catalog.color(gem.id)
	if glow:
		for i in range(3,0,-1): Pixel.disc(canvas,at,radius+i*radius*0.2,Color(color,0.05),2)
	var points := PackedVector2Array()
	for offset in [Vector2(-0.5,-0.85),Vector2(0.5,-0.85),Vector2(0.9,-0.2),Vector2(0,1),Vector2(-0.9,-0.2)]: points.append((at+offset*radius).snapped(Vector2.ONE*2))
	canvas.draw_colored_polygon(points,color.darkened(0.25))
	canvas.draw_colored_polygon(PackedVector2Array([points[0],points[1],points[2],points[4]]),color.lightened(0.28))
	canvas.draw_colored_polygon(PackedVector2Array([points[4],at+Vector2(radius*0.2,-radius*0.2),points[3]]),color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline,Color("182029"),maxf(2,radius*0.1))
	var center: Vector2 = at-Vector2(0,radius*0.16)
	var icon: String = Gems.Catalog.ITEMS[gem.id].icon
	if icon in ["plus","shield","sword","boost"]: StatusPaint.intent_icon(canvas,center,radius*0.3,icon,Color("173e43"))
	else: StatusPaint.icon(canvas,center,radius*0.3,icon,Color("3b3329"))
	for i in range(int(gem.level)):
		Pixel.disc(canvas,at+Vector2((i-(int(gem.level)-1)*0.5)*radius*0.4,radius*0.96),maxf(2,radius*0.1),Color("fff2c6"),2)
