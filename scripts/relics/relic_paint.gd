extends RefCounted
## Shared ID-based sprites for inventory, reward cards and clipped chest reels.
## All magic stones use one neutral gem with data-driven element colors.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Glow = preload("res://scripts/shared/item_glow.gd")
const VECTOR_ICONS := ["three_leaf_clover", "four_leaf_clover", "five_leaf_clover", "ice_rose", "cursed_die_1", "cursed_die_2", "cursed_die_3", "cursed_die_4", "cursed_die_5", "cursed_die"]
const SPRITE_FILES := {"holy_grail":"holy_grail.svg","witch_ghost":"unidentified_ring.png","ticket":"ticket.svg","unknown_arm":"unknown_arm.svg","unknown_leg":"unknown_leg.svg","unknown_pelvis":"unknown_pelvis.svg","unknown_sternum":"unknown_sternum.svg","unknown_skull":"unknown_skull.svg","broken_blade":"broken_blade.svg","broken_hilt":"broken_hilt.svg","nightmare_totem":"nightmare_totem.svg","red_chip":"red_chip.svg","blue_chip":"blue_chip.svg","black_chip":"black_chip.svg","fries":"fries.tres","hamburger":"hamburger.tres","oreo_sundae":"oreo_sundae.tres",
	"pet_bat":"pet_food_bat.svg","pet_lizard":"pet_food_lizard.svg","pet_slime":"pet_food_slime.svg",
	"pet_ghost":"pet_food_ghost.svg","pet_dragon":"pet_food_dragon.svg","pet_orb":"pet_ball.svg"}
static var textures: Dictionary = {}
static var regions: Dictionary = {}
static var silhouettes: Dictionary = {}

static func paint(node: CanvasItem, id: String, at: Vector2, radius: float, glow: bool = true, item: Dictionary = {}, clip: Rect2 = Rect2(), tint: Color = Color.WHITE) -> void:
	if glow: Glow.paint(node,at,radius,Catalog.rarity_color(id),clip,tint.a)
	if id == "witch_ghost": Glow.paint(node,at,radius*0.92,Color("bc8bff"),clip,tint.a)
	if Catalog.Sets.uses_composite_art(id):
		for part in _set_parts(id,item,at,radius): paint(node,part.id,part.at,part.radius,false,{},clip,tint)
		return
	var stone: bool = id in Catalog.STONES or id == "prismatic_stone"
	var sprite: String = _load_sprite(id)
	var source: Rect2 = regions[sprite]
	var size: Vector2 = (source.size * (radius*2/maxf(source.size.x,source.size.y))).round()
	var rect := Rect2((at-size/2).round(),size)
	var visible_rect: Rect2 = rect.intersection(clip) if clip.has_area() else rect
	if not visible_rect.has_area(): return
	if id == "witch_ghost":
		for direction in range(8):
			var aura_rect := Rect2(rect.position+Vector2.from_angle(direction*TAU/8)*maxf(1,radius*0.08),rect.size)
			var aura_visible := aura_rect.intersection(clip) if clip.has_area() else aura_rect
			if not aura_visible.has_area(): continue
			var aura_source := Rect2(source.position+(aura_visible.position-aura_rect.position)/aura_rect.size*source.size,aura_visible.size/aura_rect.size*source.size)
			node.draw_texture_rect_region(textures[sprite],aura_visible,aura_source,Color(0.8,0.5,1,0.3)*tint)
	var fraction := Rect2((visible_rect.position-rect.position)/rect.size,visible_rect.size/rect.size)
	var cropped := Rect2(source.position+fraction.position*source.size,fraction.size*source.size)
	if id == "prismatic_stone":
		var uv := Rect2(cropped.position/textures[sprite].get_size(),cropped.size/textures[sprite].get_size())
		var colors := PackedColorArray()
		for point in _corners(fraction): colors.append(Color("8de8ff").lerp(Color("e8a1ff"),point.x).lerp(Color("9af6b2").lerp(Color("ffcc78"),point.x),point.y)*tint)
		node.draw_polygon(_corners(visible_rect),colors,_corners(uv),textures[sprite])
	else:
		node.draw_texture_rect_region(textures[sprite],visible_rect,cropped,(Catalog.color(id) if stone else Color.WHITE)*tint)

## Share identical component geometry between meal sprites and their rarity silhouettes.
static func _set_parts(id: String, item: Dictionary, at: Vector2, radius: float) -> Array:
	var ingredients: Array = Catalog.Sets.display_parts(id,item)
	var result: Array = []
	for i in range(ingredients.size()):
		var angle: float = -PI/2+TAU*i/ingredients.size()
		var offset: Vector2 = Vector2.from_angle(angle)*radius*0.52 if ingredients.size() > 2 else Vector2((i-0.5)*radius,0)
		result.append({"id":ingredients[i],"at":at+offset,"radius":radius*(0.49 if ingredients.size() > 3 else 0.58)})
	return result

## Load and trim each source once for inventory, chest and orbit rendering.
static func _load_sprite(id: String) -> String:
	var stone: bool = id in Catalog.STONES or id == "prismatic_stone"
	var sprite: String = "magic_gem" if stone else id
	if not textures.has(sprite):
		var file: String = SPRITE_FILES.get(sprite,sprite+(".svg" if stone or id in VECTOR_ICONS else ".png"))
		var texture: Texture2D = load("res://assets/art/relics/"+file)
		textures[sprite] = texture
		regions[sprite] = Rect2(texture.get_image().get_used_rect())
	return sprite

## Cache white alpha masks, then layer narrow offsets for a silhouette-shaped glow.
static func silhouette_glow(node: CanvasItem, id: String, at: Vector2, radius: float, color: Color, item: Dictionary = {}, strength: float = 0.0) -> void:
	if Catalog.Sets.uses_composite_art(id):
		for part in _set_parts(id,item,at,radius): silhouette_glow(node,part.id,part.at,part.radius,color,{},strength)
		return
	var sprite: String = _load_sprite(id)
	if not silhouettes.has(sprite):
		var mask: Image = textures[sprite].get_image()
		mask.convert(Image.FORMAT_RGBA8)
		for y in range(mask.get_height()):
			for x in range(mask.get_width()): mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
		silhouettes[sprite] = ImageTexture.create_from_image(mask)
	var source: Rect2 = regions[sprite]
	var size: Vector2 = (source.size*(radius*2/maxf(source.size.x,source.size.y))).round()
	var rect := Rect2((at-size/2).round(),size)
	var width: float = clampf(radius*0.075,1.0,2.5)
	for layer in [3,2,1]:
		var alpha: float = [0.0,0.70,0.16,0.05][layer]*(1+strength*0.35)
		for direction in range(8):
			var offset: Vector2 = Vector2.from_angle(direction*TAU/8)*width*layer
			node.draw_texture_rect_region(silhouettes[sprite],Rect2(rect.position+offset,rect.size),source,Color(color,alpha))

static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
