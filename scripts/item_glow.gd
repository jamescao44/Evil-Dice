extends RefCounted
## Steady rarity light beneath an item, separate from charged/activation feedback.
static var texture: GradientTexture2D

static func paint(canvas: CanvasItem, at: Vector2, radius: float, color: Color, clip: Rect2 = Rect2(), alpha: float = 1.0) -> void:
	if texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.5,0.8,1.0])
		gradient.colors = PackedColorArray([Color(1,1,1,0.75),Color(1,1,1,0.65),Color(1,1,1,0.24),Color(1,1,1,0)])
		texture = GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 128
		texture.height = 128
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5,0.5)
		texture.fill_to = Vector2(0.5,0)
	var size := Vector2(radius*3.05,radius*2.85)
	var rect := Rect2(at+Vector2(0,radius*0.12)-size/2,size)
	var visible_rect: Rect2 = rect.intersection(clip) if clip.has_area() else rect
	if not visible_rect.has_area(): return
	var source := Rect2((visible_rect.position-rect.position)/rect.size*texture.get_size(),visible_rect.size/rect.size*texture.get_size())
	canvas.draw_texture_rect_region(texture,visible_rect,source,Color(color,alpha))
