extends RefCounted
## Conditional relic rules share the normal combat hooks, independent of presentation.
const Sequence = preload("res://scripts/relics/relic_sequence.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const VULNERABILITIES := {"hellfire":Status.BURNING,"nightmare_totem":Status.DARKNESS,"corrupt_crystal":Status.CORROSION}
const RANDOM_STATUSES := [Status.BURNING,Status.FROZEN,Status.DARKNESS,Status.CORROSION,Status.PLAGUE]

## Gate conditional loot consistently in chests, shops, tarot grants and reel strips.
static func loot_allowed(inventory, id: String) -> bool:
	if Catalog.ITEMS.get(id,{}).get("requires_unlock",false) and not inventory.unlocks.has(id): return false
	var exclusion: String = Catalog.ITEMS.get(id,{}).get("excluded_after_unlock","")
	if not exclusion.is_empty() and inventory.unlocks.has(exclusion): return false
	if not Catalog.ITEMS.get(id,{}).get("requires_set_parts",false): return true
	var recipe: Dictionary = Catalog.Sets.recipe_for(id)
	return not recipe.is_empty() and recipe.ingredients.all(func(part): return part == id or inventory.has(part))

## The eye grows once per actual tarot use; copying repeats its benefit, not its counter.
static func tarot_used(model) -> void:
	for item in model.relics.items:
		if item.id == "precognition_eye":
			item["damage_growth"] = item.get("damage_growth",0.0)+0.05
			model.relic_activated.emit(item.id)

## Add conditional multipliers at this relic's position in the ordered inventory.
static func damage_modifier(item: Dictionary, value: float, skill: MultiHitSkill) -> float:
	for part in Catalog.Sets.stateful_parts(item): value += part.get("damage_growth",0.0)
	if item.id == "red_chip" and item.get("no_straight",false): value += 10.0
	if item.id == "holy_grail" and not skill.is_empty():
		if skill.cast_source in ["relic","chip"]: value *= 2.0
		elif skill.pattern != "match_auto" and skill.pattern != "cleanup": value *= 0.5
	return value

## Auras scale incoming enemy damage independently; previews do not activate visuals.
static func target_factor(model, target: int, activate: bool = false) -> float:
	var factor := 1.0
	for entry in Sequence.entries(model.relics.items):
		if VULNERABILITIES.has(entry.item.id) and model.enemy_status_count(target,VULNERABILITIES[entry.item.id]) > 0:
			factor *= 1.3
			if activate: Sequence.activate(model,entry)
	return factor

## Any new roll expires the previous Red Chip bonus without activating it again.
static func clear_roll_bonuses(model) -> void:
	for item in model.relics.items:
		if item.id == "red_chip": item.no_straight = false

## Opening throws set Red Chip's condition and snapshot free chip casts.
static func rolled(model) -> Array:
	var values: Array = model.dice_turn.unused().map(func(i): return model.dice_turn.values[i])
	var no_straight: bool = not model.Patterns.has_combination(values)
	for item in model.relics.items:
		if item.id == "red_chip": item.no_straight = no_straight
	var casts: Array = []
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id == "red_chip" and no_straight: Sequence.activate(model,entry)
		if entry.item.id not in ["black_chip","blue_chip"] or no_straight: continue
		var faces: Array = straight(values,entry.item.id == "black_chip")
		var skill: MultiHitSkill = model.make_straight_skill(faces)
		skill.cast_source = "chip"
		skill.effect_multiplier = 0.3
		skill.amplifier_locked = true
		skill.relic_cast_locked = true
		casts.append({"skill":skill,"activation":entry})
	return casts

## Prefer the highest pip sum among equally long available straights.
static func straight(values: Array, longest: bool) -> Array:
	for length in (range(6,2,-1) if longest else [3]):
		for first in range(7-length,0,-1):
			var candidate: Array = range(first,first+length)
			if candidate.all(func(face): return face in values): return candidate
	return []

## Ticket capacity refreshes only on a full turn; bonus pools retain any unspent ticket.
static func begin_turn(model) -> void:
	model.dice_turn.ticket_rolls_left = 0
	for entry in Sequence.entries(model.relics.items):
		var extra: int = Catalog.ITEMS[entry.item.id].get("extra_rolls",0)
		if extra <= 0: continue
		model.dice_turn.ticket_rolls_left += extra
		Sequence.activate(model,entry)

## Apply catalog-defined opening afflictions once per full turn and copied source.
static func turn_started(model, entry: Dictionary) -> Array:
	var rule: Dictionary = Catalog.ITEMS[entry.item.id].get("turn_start_status",{})
	if rule.is_empty() or model.is_city() or model.hp <= 0: return []
	var targets: Array = model.living().filter(func(i): return not model.enemies[i].get("phase_transition_pending",false))
	if targets.is_empty(): return []
	Sequence.activate(model,entry)
	if model.hp <= 0: return []
	var target: int = targets[model.rng.randi_range(0,targets.size()-1)]
	return model.apply_enemy_status(target,rule.status,rule.stacks)

## Random potion effects exclude enemy stun and action-lock bookkeeping.
static func after_hit(model, target: int, entry: Dictionary) -> Array:
	var id: String = entry.item.id
	if not model.is_enemy_alive(target) or id in model.active_relic_procs: return []
	var rule: Dictionary = Catalog.ITEMS[id].get("hit_status",{})
	if id == "mystery_potion": rule = {"chance":0.1,"stacks":1}
	if rule.is_empty() or model.rng.randf() >= rule.chance: return []
	var status: int = {"plague":Status.PLAGUE,"burning":Status.BURNING,"frozen":Status.FROZEN}.get(rule.get("status",""),-1)
	if status < 0: status = RANDOM_STATUSES[model.rng.randi_range(0,RANDOM_STATUSES.size()-1)]
	model.active_relic_procs.append(id)
	var events: Array = model.apply_enemy_status(target,status,rule.stacks)
	model.active_relic_procs.pop_back()
	# The owner handles activation once, after a successful status application.
	return events

## Trigger once per target or boss phase, preserving the plague stacks.
static func plague_applied(model, target: int) -> Array:
	if model.enemy_status_count(target,Status.PLAGUE) < 10: return []
	var enemy: Dictionary = model.enemies[target]
	var phase: int = enemy.get("boss_phase",0)
	if enemy.get("potion_x_phase",-1) == phase: return []
	var sources: Array = model.RelicEffects.repeat_sources(model.relics.items,"potion_x")
	if sources.is_empty(): return []
	enemy.potion_x_phase = phase
	Sequence.activate(model,sources[0])
	var boss: bool = enemy.get("boss",false)
	var amount: int = maxi(1,floori(enemy.hp*0.3)) if boss else enemy.hp
	var shield_before: int = enemy.shield
	var loss: int = model.direct_enemy_hp_damage(target,amount)
	enemy.shield = shield_before
	return [model.damage_event(target,loss,amount,"damage",not boss)]

## Expiring consumable relics roll once per owned item, never once per copied trigger.
static func turn_finished(model) -> Array:
	var events: Array = []
	for i in range(model.relics.items.size()-1,-1,-1):
		var item: Dictionary = model.relics.items[i]
		if item.id == "red_chip": item.no_straight = false
		var chance: float = Catalog.ITEMS[item.id].get("vanish_chance",0.0)
		if chance > 0 and model.rng.randf() < chance:
			model.relic_activated.emit(item.id)
			var unlock: String = Catalog.ITEMS[item.id].get("vanish_unlock","")
			if not unlock.is_empty(): model.relics.unlocks.unlock(unlock)
			model.relics.remove(i)
			events.append(model.event(-1,0,"relic","RELIC VANISHED"))
	return events
