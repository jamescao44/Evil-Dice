extends RefCounted
## A visible straight-length challenge owns cannon charging, separate from boss break marks.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")

static func is_cannon(enemy: Dictionary) -> bool:
	return enemy.role == Catalog.Role.MAGIC_CANNON

## Forecast its first charge without exposing a challenge before the action happens.
static func prepare_turn(model, index: int) -> void:
	var enemy: Dictionary = model.enemies[index]
	if enemy.get("charge",0) == 0: enemy.forced_charge = true
