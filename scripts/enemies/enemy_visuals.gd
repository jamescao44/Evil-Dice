extends RefCounted
## Artwork overrides and authored debris sets, separate from enemy combat rules.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const MAGE_SPRITE = preload("res://assets/art/enemies/mage/sprite.png")
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

## Select the custom normal mage while preserving the existing elite artwork.
static func art_key(enemy: Dictionary) -> String:
	if enemy.role == Catalog.Role.MAGE and not enemy.get("elite",false): return "mage_normal"
	return Catalog.ITEMS[enemy.role].art

## Describe sprite pieces at their original pixel scale for a supported enemy.
static func debris(enemy: Dictionary) -> Dictionary:
	if art_key(enemy) == "mage_normal":
		return {"textures":MAGE_PIECES,"origins":MAGE_ORIGINS,"source_size":Vector2(64,64)}
	return {}
