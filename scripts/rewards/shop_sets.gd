extends RefCounted
## Set assistance belongs to shops; ordinary chest and tarot loot retain their own rates.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Sets = preload("res://scripts/relics/relic_sets.gd")
const Drops = preload("res://scripts/relics/relic_drop_table.gd")
const GIFT_CHANCE := 0.2
const OWNED_SET_WEIGHT := 1.2
const SHELF_SET_CHANCE := 0.05

## Boost missing pieces once, regardless of collected count or copied relic effects.
static func item_weights(inventory) -> Dictionary:
	var weights: Dictionary = {}
	for pool in Sets.missing_collections(inventory,Catalog.ITEMS,Catalog.DISABLED).values():
		for id in pool: weights[id] = OWNED_SET_WEIGHT
	return weights

## Each shelf slot gets one extra set-piece check, independent of the number of owned sets.
static func roll_stock_piece(rng: RandomNumberGenerator, missing: Dictionary, excluded: Array, rarity_weights: Array, minimum_rarity: int = 0) -> String:
	if missing.is_empty() or rng.randf() >= SHELF_SET_CHANCE: return ""
	var eligible: Array = missing.keys().filter(func(id):
		return id not in excluded and (id not in Catalog.CURSED_DICE or not excluded.any(func(other): return other in Catalog.CURSED_DICE)))
	return Drops.draw(rng,eligible,rarity_weights,minimum_rarity)

## Check each incomplete owned set once, then select one successful set and one missing piece.
static func roll_gift(inventory, rng: RandomNumberGenerator, rarity_weights: Array) -> Dictionary:
	var collections: Dictionary = Sets.missing_collections(inventory,Catalog.ITEMS,Catalog.DISABLED)
	var winners: Array = []
	for label in collections:
		if rng.randf() < GIFT_CHANCE: winners.append(label)
	if winners.is_empty(): return {}
	var label: String = winners[rng.randi_range(0,winners.size()-1)]
	var id: String = Drops.draw(rng,collections[label],rarity_weights)
	if id.is_empty(): return {}
	return {"kind":"relic","id":id,"price":0,"sold":false,"set":label}
