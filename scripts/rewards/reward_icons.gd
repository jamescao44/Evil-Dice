extends RefCounted
## Public DCSS ruby/paper tiles with a code-drawn summoning seal.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")

static func paint(canvas: CanvasItem, art: Dictionary, key: String, rect: Rect2, clip: Rect2 = Rect2(), tint: Color = Color.WHITE) -> void:
	if key == "soul_bottle":
		# A sealed, opaque flask never hints at its hidden quantity through fill level.
		var u := minf(rect.size.x,rect.size.y)/24.0
		var at := rect.get_center()-Vector2(12,12)*u
		var rim := Color("81b7c8")*tint
		Pixel.disc(canvas,rect.get_center()+Vector2(0,2)*u,10*u,Color(0.5,0.85,1,0.1*tint.a),u)
		canvas.draw_rect(Rect2(at+Vector2(8,3)*u,Vector2(8,7)*u),rim)
		canvas.draw_rect(Rect2(at+Vector2(6,9)*u,Vector2(12,13)*u),rim)
		canvas.draw_rect(Rect2(at+Vector2(4,11)*u,Vector2(16,9)*u),rim)
		canvas.draw_rect(Rect2(at+Vector2(6,11)*u,Vector2(12,9)*u),Color("27384d")*tint)
		canvas.draw_rect(Rect2(at+Vector2(8,9)*u,Vector2(8,13)*u),Color("27384d")*tint)
		canvas.draw_rect(Rect2(at+Vector2(9,4)*u,Vector2(6,4)*u),Color("476478")*tint)
		paint(canvas,art,"soul",Rect2(at+Vector2(7,10)*u,Vector2.ONE*10*u),Rect2(),tint)
		canvas.draw_rect(Rect2(at+Vector2(7,2)*u,Vector2(10,3)*u),Color("96735c")*tint)
		canvas.draw_rect(Rect2(at+Vector2(8,2)*u,Vector2(6,1)*u),Color("dbc99e")*tint)
		canvas.draw_rect(Rect2(at+Vector2(5,12)*u,Vector2(1,5)*u),Color("e1f6fa")*tint)
		return
	if key == "soul":
		var at := rect.get_center()
		var unit := rect.size.x/12.0
		var pale := Color("bcecf5")*tint
		Pixel.disc(canvas,at-Vector2(0,unit),unit*4.8,Color(pale,0.15*tint.a),unit)
		Pixel.disc(canvas,at-Vector2(0,unit),unit*3.4,pale,unit)
		canvas.draw_rect(Rect2(at+Vector2(-unit*3,0),Vector2(unit*6,unit*3)),pale)
		for x in [-2,0,2]: canvas.draw_rect(Rect2(at+Vector2(x*unit,unit*3),Vector2.ONE*unit),pale)
		for x in [-1.5,1.5]: canvas.draw_rect(Rect2(at+Vector2(x*unit-unit/2,-unit*1.7),Vector2(unit,unit*1.5)),Color("29465f")*tint)
		return
	if key == "shop":
		var unit := rect.size.x/12.0
		var left := rect.position
		canvas.draw_rect(Rect2(left+Vector2(2,4)*unit,Vector2(8,7)*unit),Color("7c5940")*tint)
		canvas.draw_rect(Rect2(left+Vector2(1,2)*unit,Vector2(10,3)*unit),Color("d5ad74")*tint)
		for x in [1,5,9]: canvas.draw_rect(Rect2(left+Vector2(x,2)*unit,Vector2(2,3)*unit),Color("76556a")*tint)
		canvas.draw_rect(Rect2(left+Vector2(4,7)*unit,Vector2(4,4)*unit),Color("241e2a")*tint)
		return
	var texture: Texture2D = preload("res://assets/art/tarot/back.png") if key == "tarot" else art["contract" if key == "shard" else key]
	if key == "tarot":
		preload("res://scripts/tarot/tarot_paint.gd").soften(canvas)
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
