extends RefCounted
## Periodic growth belongs to each owned component, surviving fusion and checkpoints.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Sequence = preload("res://scripts/relics/relic_sequence.gd")

## Advance each timer once, then pay due growth in inventory order, including copies.
static func turn_finished(model) -> void:
	var due: Dictionary = {}
	for slot in range(model.relics.items.size()):
		for part in Catalog.Sets.stateful_parts(model.relics.items[slot]):
			var rule: Dictionary = Catalog.ITEMS[part.id].get("turn_growth",{})
			if rule.is_empty(): continue
			part.turns += 1
			if part.turns >= rule.period:
				part.turns = 0
				due[str(slot)+":"+part.id] = rule.amount
	for entry in Sequence.entries(model.relics.items):
		var changed := false
		for part in Catalog.Sets.stateful_parts(entry.item):
			var key: String = str(entry.origin)+":"+part.id
			if not due.has(key) or model.hp <= 0: continue
			part["damage_growth"] = part.get("damage_growth",0.0)+due[key]
			changed = true
		if changed: Sequence.activate(model,entry)
