extends RefCounted
## Apply straight guarantees only to newly rolled dice, before tarot overrides.
const Sequence = preload("res://scripts/relics/relic_sequence.gd")

static func apply(model, indices: Array) -> void:
	var length := 0
	var activated: Array = []
	var lucky_spent: Array = []
	var lucky_items: Array = model.relics.items.filter(func(item): return item.id == "lucky_die")
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		var desired := 0
		if item.id == "lucky_die" and item.get("throws",0) >= 10 and indices.size() >= 4:
			desired = 4
			if item not in lucky_spent: lucky_spent.append(item)
		elif item.id == "four_leaf_clover" and indices.size() >= 4 and model.rng.randf() < 0.10: desired = 4
		elif item.id == "five_leaf_clover" and indices.size() >= 5 and model.rng.randf() < 0.05: desired = 5
		if desired > 0:
			length = maxi(length,desired)
			activated.append(entry)
	for item in lucky_items: item.throws = 0 if item in lucky_spent else mini(10,item.get("throws",0)+1)
	if length == 0: return
	var first: int = model.rng.randi_range(1,7-length)
	var slots: Array = indices.duplicate()
	for face in range(first,first+length):
		model.dice_turn.values[slots.pop_at(model.rng.randi_range(0,slots.size()-1))] = face
	for entry in activated: Sequence.activate(model,entry)
