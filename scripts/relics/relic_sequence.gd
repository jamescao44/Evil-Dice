extends RefCounted
## Expand ordered activations without duplicating inventory or mutable counters.
## A -> Mask -> Tentacle resolves A, A, A, A. Mask cannot copy Tentacle.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const MASK := "disguise_mask"
const TENTACLE := "ancient_tentacle"
const RETRIGGER_SPEED := 1.5

static func entries(items: Array) -> Array:
	var result: Array = []
	for slot in range(items.size()):
		var id: String = items[slot].id
		if id == TENTACLE:
			for left in range(slot): result.append_array(_copy(items,left,slot,[id]))
		else: result.append_array(_copy(items,slot,slot,[]))
	return result

static func _copy(items: Array, index: int, slot: int, chain: Array) -> Array:
	if index < 0: return []
	var item: Dictionary = items[index]
	if item.id == TENTACLE or item.id in Catalog.DISABLED: return []
	var activators: Array = chain + [item.id]
	if item.id == MASK: return _copy(items,index-1,slot,activators)
	return [{"item":item,"origin":index,"slot":slot,"source":items[slot].id,"activators":activators}]

static func activate(model, entry: Dictionary) -> void:
	var previous: float = model.relic_activation_speed
	model.relic_activation_speed = animation_speed(entry)
	for id in entry.activators: model.relic_activated.emit(id)
	model.relic_activation_speed = previous

static func animation_speed(entry: Dictionary) -> float:
	return RETRIGGER_SPEED if entry.origin != entry.slot else 1.0
