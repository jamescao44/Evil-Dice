extends RefCounted
## Run-local consumables. Separate instances allow duplicates and future single-use effects.
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
var items: Array = []
var next_instance: int = 1

func clear() -> void:
	items.clear()
	next_instance = 1

func add(id: String, projection: bool = false) -> Dictionary:
	if not Catalog.ITEMS.has(id): return {}
	var item := {"id":id, "instance_id":next_instance}
	if projection: item.projection = true
	next_instance += 1
	items.append(item)
	return item.duplicate()

## Expire temporary instances without removing permanent copies of the same tarot.
func expire_projections() -> Array:
	var expired: Array = items.filter(func(item): return item.get("projection",false)).map(func(item): return item.instance_id)
	items = items.filter(func(item): return not item.get("projection",false))
	return expired

func find_instance(instance_id: int) -> int:
	return items.find_custom(func(item): return item.instance_id == instance_id)

func remove_instance(instance_id: int) -> Dictionary:
	var index: int = find_instance(instance_id)
	return {} if index < 0 else items.pop_at(index)
