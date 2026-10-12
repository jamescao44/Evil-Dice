extends RefCounted
## Public DCSS ruby/paper tiles with a code-drawn summoning seal.
const Pixel = preload("res://scripts/pixel_paint.gd")

static func paint(canvas: CanvasItem, art: Dictionary, key: String, rect: Rect2, clip: Rect2 = Rect2(), tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = preload("res://assets/art/tarot/back.png") if key == "tarot" else art["contract" if key == "shard" else key]
	if key == "tarot":
		preload("res://scripts/tarot_paint.gd").soften(canvas)
		# Keep the tall card's proportions inside square treasure reels.
		var width: float = rect.size.y * texture.get_width() / texture.get_height()
		rect = Rect2(rect.get_center()-Vector2(width,rect.size.y)/2,Vector2(width,rect.size.y))
	# Isolate the gemstone from its necklace; retain the original source asset.
	var source := Rect2(12, 18, 12, 12) if key == "ruby" else Rect2(Vector2.ZERO, texture.get_size())
	var visible_rect: Rect2 = rect.intersection(clip) if clip.has_area() else rect
	if not visible_rect.has_area(): return
	var uv := Rect2(source.position+(visible_rect.position-rect.position)/rect.size*source.size, visible_rect.size/rect.size*source.size)
	canvas.draw_texture_rect_region(texture, visible_rect, uv, tint)
	if key == "shard" and (not clip.has_area() or clip.encloses(rect)):
		var at: Vector2 = rect.get_center()+Vector2(0, rect.size.y*0.03)
		var radius: float = rect.size.x*0.19
		var color := Color(Color("754790"), tint.a)
		Pixel.circle(canvas, at, radius, color, maxf(1, rect.size.x/50))
		for i in range(5):
			Pixel.line(canvas, at+Vector2.from_angle(i*TAU/5-PI/2)*radius, at+Vector2.from_angle((i+2)*TAU/5-PI/2)*radius, color, maxf(1, rect.size.x/65))
