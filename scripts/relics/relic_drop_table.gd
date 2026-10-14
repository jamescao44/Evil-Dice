extends RefCounted
## One rarity roll, then a uniform item roll. Pool size never adds rarity weight.
## Callers supply eligibility and RNG; this table never changes inventory.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Weighted = preload("res://scripts/shared/weighted_choice.gd")

static func weights_for_wave(wave_number: int) -> Array:
	# Move 10% of the remaining distance toward an even split each wave.
	# Keep the curve independent of the route length so future waves extend it.
	var remaining: float = pow(0.9,maxi(0,wave_number-1))
	return Catalog.RARITY_WEIGHTS.map(func(weight): return 20.0+(weight-20.0)*remaining)

static func draw(rng: RandomNumberGenerator, eligible: Array, rarity_weights: Array = Catalog.RARITY_WEIGHTS, minimum_rarity: int = 0) -> String:
	var pools: Array = [[],[],[],[],[]]
	for id in eligible:
		var item: Dictionary = Catalog.ITEMS[id]
		if not item.get("fusion",false): pools[item.rarity].append(id)
	var weights: Array = rarity_weights.duplicate()
	# A guarantee promotes low rolls to its floor, without inflating top rarities.
	for rarity in range(minimum_rarity):
		weights[minimum_rarity] += weights[rarity]
		weights[rarity] = 0.0
	for rarity in range(pools.size()):
		if pools[rarity].is_empty(): weights[rarity] = 0.0
	# Exhausted rarities redistribute proportionally among the remaining pools.
	var rarity: int = Weighted.pick(rng,weights)
	if rarity < 0: return ""
	return pools[rarity][rng.randi_range(0,pools[rarity].size()-1)]
