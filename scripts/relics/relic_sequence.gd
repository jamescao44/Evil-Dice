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
	if item.id == "pet_orb":
		var pets: Array = []
		for id in Catalog.Sets.ingredients(item):
			var component: Dictionary = item.duplicate()
			component.id = id
			pets.append({"item":component,"origin":index,"slot":slot,"source":items[slot].id,"activators":activators})
		return pets
	return [{"item":item,"origin":index,"slot":slot,"source":items[slot].id,"activators":activators}]

static func activate(model, entry: Dictionary) -> void:
	activate_ids(model,entry.activators,animation_speed(entry))
	# The effect's identity survives fusion and copying; companion visuals use this signal.
	model.relic_effect_activated.emit(entry.item.id)

## Notify presentation without applying effects or advancing counters a second time.
static func activate_ids(model, ids: Array, speed: float = 1.0) -> void:
	var previous: float = model.relic_activation_speed
	model.relic_activation_speed = speed
	for id in ids: model.relic_activated.emit(id)
	model.relic_activation_speed = previous

static func animation_speed(entry: Dictionary) -> float:
	return RETRIGGER_SPEED if entry.origin != entry.slot else 1.0
