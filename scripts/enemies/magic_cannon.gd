extends RefCounted
## A visible straight-length challenge owns cannon charging, separate from boss break marks.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")

static func is_cannon(enemy: Dictionary) -> bool:
	return enemy.role == Catalog.Role.MAGIC_CANNON

## The cannon charges from turn start; bosses enter charging through their chosen move.
static func prepare_turn(model, index: int) -> void:
	if not model.enemy_cannot_act(index): model.enemies[index].charging = true
