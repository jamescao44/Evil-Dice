extends RefCounted
## Artwork overrides and authored debris sets, separate from enemy combat rules.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const MAGE_PIECES := [
	preload("res://assets/art/enemies/mage/piece_02.png"),
	preload("res://assets/art/enemies/mage/piece_03.png"),
	preload("res://assets/art/enemies/mage/piece_04.png"),
	preload("res://assets/art/enemies/mage/piece_05.png"),
	preload("res://assets/art/enemies/mage/piece_06.png"),
	preload("res://assets/art/enemies/mage/piece_07.png"),
	preload("res://assets/art/enemies/mage/piece_08.png"),
	preload("res://assets/art/enemies/mage/piece_09.png"),
]
# Small fragments fan out from the body; the book and hat leave their own positions.
const MAGE_ORIGINS := [Vector2(0.39,0.86),Vector2(0.61,0.86),Vector2(0.40,0.61),Vector2(0.59,0.60),Vector2(0.45,0.37),Vector2(0.59,0.42),Vector2(0.40,0.49),Vector2(0.53,0.17)]

const DEBRIS := {"mage_normal":{"textures":MAGE_PIECES,"origins":MAGE_ORIGINS,"source_size":Vector2(64,64)}}

## Normal/elite artwork is selected by catalog metadata, not a role-specific branch.
static func art_key(enemy: Dictionary) -> String:
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	return data.art if enemy.get("elite",false) else data.get("normal_art",data.art)

## Enumerate every enemy texture once for home, battlefield and asset validation.
static func asset_paths() -> Dictionary:
	var paths: Dictionary = {}
	for data in Catalog.ITEMS.values():
		paths[data.art] = data.get("art_file","res://assets/art/fantasy/"+data.art+".png")
		if data.has("normal_art"): paths[data.normal_art] = data.normal_art_file
	return paths

## Register textures and optional elite silhouettes without editing either scene's asset list.
static func load_into(art: Dictionary, silhouettes: bool = false) -> void:
	var paths := asset_paths()
	for key in paths:
		art[key] = load(paths[key])
		if not silhouettes: continue
		var mask: Image = art[key].get_image()
		mask.convert(Image.FORMAT_RGBA8)
		for y in range(mask.get_height()):
			for x in range(mask.get_width()): mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
		art[key+"_glow"] = ImageTexture.create_from_image(mask)

static func is_enemy_art(key: String) -> bool:
	return asset_paths().has(key.trim_suffix("_glow"))

## Piece sets belong to visual identities, so another enemy can reuse existing artwork.
static func debris(enemy: Dictionary) -> Dictionary:
	return DEBRIS.get(art_key(enemy),{})
