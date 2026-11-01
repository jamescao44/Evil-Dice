extends RefCounted
## Pure socket math is shared by previews; random effects resolve only on committed actions.
const Catalog = preload("res://scripts/dice/gemstone_catalog.gd")

## Aggregate level contributions only from participating physical dice.
static func level_sum(gems: Array, modifier: String) -> int:
	var total := 0
	for gem in gems:
		if Catalog.valid(gem) and Catalog.ITEMS[gem.id].get("modifier","") == modifier: total += Catalog.potency(gem)
	return total

static func factor(gems: Array, modifier: String) -> float:
	return 1.0+level_sum(gems,modifier)*0.1

## Each socket rolls separately; guaranteed stacks plus a fractional chance support future tiers.
static func status_chance(gem: Dictionary, automatic: bool) -> float:
	if not Catalog.valid(gem): return 0.0
	var data: Dictionary = Catalog.ITEMS[gem.id]
	if ("automatic" if automatic else "skill") not in data.get("attack_hooks",[]): return 0.0
	var chance: float = Catalog.potency(gem)*data.get("auto_chance" if automatic else "skill_chance",0.0)*0.01
	return minf(float(data.chance_cap)*0.01,chance) if data.get("chance_cap",-1) >= 0 else chance

static func roll_stacks(chance: float, rng: RandomNumberGenerator) -> int:
	var whole: int = floori(chance)
	var remainder: float = chance-whole
	return whole+(1 if remainder > 0 and rng.randf() < remainder else 0)

## Return separate applications so stack-boosting relics affect each successful gemstone.
static func roll_statuses(gems: Array, automatic: bool, rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	for gem in gems:
		var chance: float = status_chance(gem,automatic)
		if chance <= 0: continue
		var amount: int = roll_stacks(chance,rng)
		if amount > 0: result.append({"status":Catalog.ITEMS[gem.id].status,"amount":amount})
	return result

## Guaranteed stacks only; chance-based effects must not appear as guaranteed in previews.
static func attack_statuses(gems: Array, automatic: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for gem in gems:
		var count: int = floori(status_chance(gem,automatic))
		if count > 0:
			var id: int = Catalog.ITEMS[gem.id].status
			result[id] = int(result.get(id,0))+count
	return result

## Chance of at least one extra stack, combining independent socket checks without RNG.
static func status_chances(gems: Array, automatic: bool = false) -> Dictionary:
	var misses: Dictionary = {}
	for gem in gems:
		var chance: float = fposmod(status_chance(gem,automatic),1.0)
		if chance <= 0: continue
		var id: int = Catalog.ITEMS[gem.id].status
		misses[id] = float(misses.get(id,1.0))*(1.0-chance)
	for id in misses: misses[id] = 1.0-misses[id]
	return misses

## Matching groups recover once at half potency; skills recover once per use at full potency.
static func recovery(gems: Array, values: Array, maximum_hp: int, type: String, automatic: bool = false) -> int:
	var percent := 0.0
	for i in range(mini(gems.size(),values.size())):
		if not Catalog.valid(gems[i]): continue
		if Catalog.ITEMS[gems[i].id].get("recovery","") != type: continue
		percent += int(values[i])*Catalog.potency(gems[i])*(0.5 if automatic else 1.0)
	return roundi(percent*0.01*maximum_hp)

## One critical check per skill use or automatic hit, shared by its targets and damage ticks.
static func critical_factor(gems: Array, rng: RandomNumberGenerator) -> float:
	var levels: int = level_sum(gems,"critical")
	if levels == 0: return 1.0
	return 1.5+levels*0.1 if levels >= 10 or rng.randf() < levels*0.1 else 1.0
