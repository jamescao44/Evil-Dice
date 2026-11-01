extends RefCounted
## Challenger's Badge owns one enemy mark; rendering only reads it, never rolls targets.
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const ID := "challenger_badge"
const MARK := "relic_focus"

## A mark belongs to the enemy itself, so changed formations cannot reuse a stale index.
static func current(model) -> int:
	if not model.relics.has(ID): return -1
	for index in model.living():
		if model.enemies[index].get(MARK,false) and Enemy.targetable(model.enemies,index): return index
	return -1

## Retain a living mark, or select a fresh foe after acquisition, death or a new wave.
static func sync(model) -> int:
	var selected: int = current(model)
	if selected >= 0: return selected
	for enemy in model.enemies: enemy.erase(MARK)
	if not model.relics.has(ID) or model.is_city(): return -1
	var targets: Array = model.living().filter(func(i): return Enemy.targetable(model.enemies,i))
	if targets.is_empty(): return -1
	selected = targets[model.rng.randi_range(0,targets.size()-1)]
	model.enemies[selected][MARK] = true
	return selected

## Moving the mark costs nothing and bypasses taunt without changing area protection.
static func select(model, index: int) -> bool:
	if not model.relics.has(ID) or model.is_city() or not Enemy.targetable(model.enemies,index): return false
	for enemy in model.enemies: enemy.erase(MARK)
	model.enemies[index][MARK] = true
	return true

## Only automatically chosen attacks use this pool; targeted tarot keeps its own rules.
static func targets(model) -> Array:
	var selected: int = current(model)
	return [selected] if selected >= 0 else model.attack_targets()

## Resolve the focus once at launch, leaving already-launched attacks on their target.
static func choose(model) -> int:
	var selected: int = sync(model)
	if selected >= 0: return selected
	var candidates: Array = model.attack_targets()
	return -1 if candidates.is_empty() else candidates[model.rng.randi_range(0,candidates.size()-1)]
