extends RefCounted
## Shared card rendering. Full-resolution labels remain separate from pixel artwork.
const Catalog = preload("res://scripts/tarot_catalog.gd")
const GOLD := Color("dfc78d")
const LILAC := Color("cbb1f5")
static var ink: ShaderMaterial
static var textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if id.is_empty(): return Catalog.BACK
	if not textures.has(id): textures[id] = load(Catalog.ITEMS[id].art)
	return textures[id]

static func panel(canvas: CanvasItem, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	style.set_corner_radius_all(radius)
	style.corner_detail = 6
	canvas.draw_style_box(style,rect)

static func soften(canvas: CanvasItem) -> void:
	if ink == null:
		ink = ShaderMaterial.new()
		ink.shader = preload("res://scripts/tarot_ink.gdshader")
	canvas.material = ink

static func card(canvas: CanvasItem, id: String, at: Vector2, size: Vector2, angle: float = 0.0, flip: float = 1.0, glow: float = 0.0, alpha: float = 1.0) -> void:
	soften(canvas)
	canvas.draw_set_transform(at,angle,Vector2(maxf(0.015,absf(flip)),1))
	var rect := Rect2(-size/2,size)
	panel(canvas,Rect2(rect.position+Vector2(-1,3),rect.size+Vector2(8,8)),Color(0.015,0.01,0.04,alpha*0.65))
	if glow > 0:
		for i in range(5,0,-1): panel(canvas,rect.grow(i*3),Color(LILAC,alpha*glow*0.035),Color(LILAC,alpha*glow*0.055))
	canvas.draw_texture_rect(texture(id),rect,false,Color(1,1,1,alpha))
	if glow > 0: panel(canvas,rect.grow(3),Color.TRANSPARENT,Color(GOLD,alpha*glow))
	canvas.draw_set_transform(Vector2.ZERO)

static func text(canvas: CanvasItem, font: Font, at: Vector2, value: String, size: int, color: Color = GOLD, centered: bool = true) -> void:
	value = GameText.text(value)
	var width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	canvas.draw_string(font,(at-Vector2(width/2 if centered else 0,0)).round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

static func wrap(canvas: CanvasItem, font: Font, rect: Rect2, value: String, size: int, color: Color = Color("eee0d6"), centered: bool = false) -> float:
	var y: float = rect.position.y+size
	for line in GameText.lines(value,font,size,rect.size.x):
		if y > rect.end.y: break
		text(canvas,font,Vector2(rect.get_center().x if centered else rect.position.x,y),line,size,color,centered)
		y += size*1.3
	return y

static func sky(canvas: CanvasItem, size: Vector2, age: float, reduced: bool) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,size),Color("100f26"))
	for i in range(14,0,-1):
		canvas.draw_circle(Vector2(size.x*0.64,size.y*0.5),i*size.x*0.065,Color(0.22,0.12,0.36,0.023))
	# Deterministic placement keeps visual randomness separate from reward RNG.
	for i in range(150):
		var seed: float = float(i+1)
		var at := Vector2(fposmod(seed*0.618033,1)*size.x,fposmod(seed*0.414214,1)*size.y)
		var alpha: float = 0.3+0.55*(0.5 if reduced else sin(age*(0.6+fmod(seed,3)*0.2)+seed)*0.5+0.5)
		var side: float = 2.0 if i%4 else 3.0
		canvas.draw_rect(Rect2(at.round(),Vector2.ONE*side),Color(LILAC,alpha))
		if i%13 == 0:
			canvas.draw_line(at-Vector2(5,0),at+Vector2(5,0),Color(GOLD,alpha*0.8),1)
			canvas.draw_line(at-Vector2(0,5),at+Vector2(0,5),Color(GOLD,alpha*0.8),1)
