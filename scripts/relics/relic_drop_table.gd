extends RefCounted
## Roll rarity before the item; optional per-item steering never changes rarity weights.
## Callers supply eligibility and RNG; this table never changes inventory.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Weighted = preload("res://scripts/shared/weighted_choice.gd")

static func weights_for_wave(wave_number: int) -> Array:
	# Move 10% of the remaining distance toward an even split each wave.
	# Keep the curve independent of the route length so future waves extend it.
	var remaining: float = pow(0.9,maxi(0,wave_number-1))
	var equal_share: float = 100.0/Catalog.RARITY_WEIGHTS.size()
	return Catalog.RARITY_WEIGHTS.map(func(weight): return equal_share+(weight-equal_share)*remaining)

static func draw(rng: RandomNumberGenerator, eligible: Array, rarity_weights: Array = Catalog.RARITY_WEIGHTS, minimum_rarity: int = 0, item_weights: Dictionary = {}) -> String:
	var pools: Array = Catalog.RARITY_WEIGHTS.map(func(_weight): return [])
	for id in eligible:
		var item: Dictionary = Catalog.ITEMS[id]
		if id not in Catalog.DISABLED and not item.get("fusion",false): pools[item.rarity].append(id)
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
	# Optional shop steering affects only the item draw, never the rarity roll.
	if not item_weights.is_empty():
		var index: int = Weighted.pick(rng,pools[rarity].map(func(id): return item_weights.get(id,1.0)))
		return pools[rarity][index] if index >= 0 else ""
	return pools[rarity][rng.randi_range(0,pools[rarity].size()-1)]
