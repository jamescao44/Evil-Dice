extends RefCounted
## Cached feathered ink panel: one nine-patch draw, with no hard border behind text.
static var style: StyleBoxTexture

static func paint(canvas: CanvasItem, rect: Rect2) -> void:
	if not rect.has_area(): return
	if style == null:
		var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var edge := Vector2(maxf(absf(x-31.5)-10,0),maxf(absf(y-31.5)-10,0))
				var alpha: float = (1-smoothstep(0,21,edge.length()))*0.88
				image.set_pixel(x,y,Color(0.025,0.025,0.04,alpha))
		style = StyleBoxTexture.new()
		style.texture = ImageTexture.create_from_image(image)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_texture_margin(side,24)
	canvas.draw_style_box(style,rect.grow(24))
