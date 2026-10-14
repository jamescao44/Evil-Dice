extends RefCounted
## Run-local consumables. Separate instances allow duplicates and future single-use effects.
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
var items: Array = []
var next_instance: int = 1

func clear() -> void:
	items.clear()
	next_instance = 1

func add(id: String) -> Dictionary:
	if not Catalog.ITEMS.has(id): return {}
	var item := {"id":id, "instance_id":next_instance}
	next_instance += 1
	items.append(item)
	return item.duplicate()

func find_instance(instance_id: int) -> int:
	return items.find_custom(func(item): return item.instance_id == instance_id)

func remove_instance(instance_id: int) -> Dictionary:
	var index: int = find_instance(instance_id)
	return {} if index < 0 else items.pop_at(index)
