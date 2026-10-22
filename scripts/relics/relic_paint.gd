extends RefCounted
## Shared sprites for inventory, reward cards and the chest atlas.
## All magic stones use one neutral gem with data-driven element colors.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Glow = preload("res://scripts/shared/item_glow.gd")
const VECTOR_ICONS := ["four_leaf_clover", "five_leaf_clover", "ice_rose", "cursed_die_1", "cursed_die_2", "cursed_die_3", "cursed_die_4", "cursed_die_5", "cursed_die"]
const SPRITE_FILES := {"fries":"fries.tres","hamburger":"hamburger.tres","oreo_sundae":"oreo_sundae.tres"}
static var textures: Dictionary = {}
static var regions: Dictionary = {}

static func paint(node: CanvasItem, id: String, at: Vector2, radius: float, glow: bool = true, item: Dictionary = {}) -> void:
	if glow: Glow.paint(node,at,radius,Catalog.rarity_color(id))
	if Catalog.Sets.is_fused(id):
		var parts: Array = Catalog.Sets.display_parts(id,item)
		# Show the actual foods in collection order, arranged in a compact meal cluster.
		var count: int = parts.size()
		for i in range(count):
			var angle: float = -PI/2+TAU*i/count
			var offset: Vector2 = Vector2.from_angle(angle)*radius*0.52 if count > 2 else Vector2((i-0.5)*radius,0)
			paint(node,parts[i],at+offset,radius*(0.49 if count > 3 else 0.58),false)
		return
	var stone: bool = id in Catalog.STONES or id == "prismatic_stone"
	var sprite: String = "magic_gem" if stone else id
	if not textures.has(sprite):
		var file: String = SPRITE_FILES.get(sprite,sprite+(".svg" if stone or id in VECTOR_ICONS else ".png"))
		var texture: Texture2D = load("res://assets/art/relics/"+file)
		textures[sprite] = texture
		regions[sprite] = Rect2(texture.get_image().get_used_rect())
	var source: Rect2 = regions[sprite]
	var size: Vector2 = (source.size * (radius*2/maxf(source.size.x,source.size.y))).round()
	var rect := Rect2((at-size/2).round(),size)
	if id == "prismatic_stone":
		var uv := Rect2(source.position/textures[sprite].get_size(),source.size/textures[sprite].get_size())
		var colors := PackedColorArray([Color("8de8ff"),Color("e8a1ff"),Color("ffcc78"),Color("9af6b2")])
		node.draw_polygon(_corners(rect),colors,_corners(uv),textures[sprite])
	else:
		node.draw_texture_rect_region(textures[sprite],rect,source,Catalog.color(id) if stone else Color.WHITE)

static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
