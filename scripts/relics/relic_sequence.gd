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
	if Catalog.Sets.is_fused(item.id) and Catalog.Sets.recipe_for(item.id).get("activate_components",false):
		var pets: Array = []
		for id in Catalog.Sets.ingredients(item):
			var component: Dictionary = item.duplicate()
			component.id = id
			pets.append({"item":component,"origin":index,"slot":slot,"source":items[slot].id,"activators":activators})
		return pets
	return [{"item":item,"origin":index,"slot":slot,"source":items[slot].id,"activators":activators}]

static func activate(model, entry: Dictionary) -> void:
	pay_retrigger_cost(model,entry.activators)
	activate_ids(model,entry.activators,animation_speed(entry))
	# The effect's identity survives fusion and copying; companion visuals use this signal.
	model.relic_effect_activated.emit(entry.item.id)

## Only committed Tentacle copies pay HP; previews and cosmetic replays never do.
static func pay_retrigger_cost(model, activators: Array) -> void:
	if TENTACLE not in activators or model.hp <= 0: return
	var loss: int = mini(model.hp,maxi(1,ceili(model.max_hp*0.01)))
	model.lose_hp(loss)
	var events: Array = [model.damage_event(-1,loss,loss)]
	if model.hp <= 0: events.append_array(model.RelicEffects.prevent_death(model))
	events.append_array(model.sins.resolve_retaliations(model))
	model.relic_cost_paid.emit(events)

## Notify presentation without applying effects or advancing counters a second time.
static func activate_ids(model, ids: Array, speed: float = 1.0) -> void:
	var previous: float = model.relic_activation_speed
	model.relic_activation_speed = speed
	for id in ids: model.relic_activated.emit(id)
	model.relic_activation_speed = previous

static func animation_speed(entry: Dictionary) -> float:
	return RETRIGGER_SPEED if entry.origin != entry.slot else 1.0

## Preserve the real weapon slot and faster copy timing for any direct-damage hook.
static func attack_options(entry: Dictionary, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = options.duplicate()
	result.origin = entry.origin
	result.animation_speed = animation_speed(entry)
	return result
