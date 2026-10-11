extends RefCounted
## One rarity roll, then a uniform item roll. Pool size never adds rarity weight.
## Callers supply eligibility and RNG; this table never changes inventory.
const Catalog = preload("res://scripts/relic_catalog.gd")
const Weighted = preload("res://scripts/weighted_choice.gd")

static func draw(rng: RandomNumberGenerator, eligible: Array, rarity_weights: Array = Catalog.RARITY_WEIGHTS) -> String:
	var pools: Array = [[],[],[],[],[]]
	for id in eligible:
		var item: Dictionary = Catalog.ITEMS[id]
		if not item.get("fusion",false): pools[item.rarity].append(id)
	var weights: Array = rarity_weights.duplicate()
	for rarity in range(pools.size()):
		if pools[rarity].is_empty(): weights[rarity] = 0.0
	# Exhausted rarities redistribute proportionally among the remaining pools.
	var rarity: int = Weighted.pick(rng,weights)
	if rarity < 0: return ""
	return pools[rarity][rng.randi_range(0,pools[rarity].size()-1)]
