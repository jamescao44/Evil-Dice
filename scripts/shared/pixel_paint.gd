extends RefCounted
## Shared stepped geometry: UI and spell effects use the same pixel grid.

static func line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, pixel: int = 3) -> void:
	var from := Vector2i((a / pixel).round())
	var to := Vector2i((b / pixel).round())
	var dx: int = absi(to.x - from.x)
	var dy: int = -absi(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var error: int = dx + dy
	while true:
		canvas.draw_rect(Rect2(Vector2(from * pixel), Vector2.ONE * pixel), color)
		if from == to:
			break
		var doubled: int = error * 2
		if doubled >= dy:
			error += dy
			from.x += sx
		if doubled <= dx:
			error += dx
			from.y += sy

static func circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color, pixel: int = 3, clip: Rect2 = Rect2()) -> void:
	var x: int = maxi(1, roundi(radius / pixel))
	var y: int = 0
	var error: int = 1 - x
	var origin := center.snapped(Vector2.ONE * pixel)
	while x >= y:
		for offset in [Vector2(x,y),Vector2(y,x),Vector2(-y,x),Vector2(-x,y),Vector2(-x,-y),Vector2(-y,-x),Vector2(y,-x),Vector2(x,-y)]:
			var dot := Rect2(origin + offset * pixel, Vector2.ONE * pixel)
			if clip.has_area(): dot = dot.intersection(clip)
			if dot.has_area(): canvas.draw_rect(dot, color)
		y += 1
		if error < 0:
			error += 2 * y + 1
		else:
			x -= 1
			error += 2 * (y - x) + 1

static func disc(canvas: CanvasItem, center: Vector2, radius: float, color: Color, pixel: int = 4, squash: float = 1.0) -> void:
	for y in range(-int(radius), int(radius) + 1, pixel):
		var half: float = floorf(sqrt(maxf(0, radius * radius - y * y)) / pixel) * pixel
		var top: float = floorf((center.y + y * squash) / 2.0) * 2
		var bottom: float = ceilf((center.y + (y + pixel) * squash) / 2.0) * 2
		canvas.draw_rect(Rect2(Vector2(center.x - half, top).round(), Vector2(half * 2, maxf(2, bottom - top))), color)
