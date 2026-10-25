extends RefCounted
## Conditional relic rules share the normal combat hooks, independent of presentation.
const Sequence = preload("res://scripts/relics/relic_sequence.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const BONES := ["unknown_arm","unknown_pelvis","unknown_leg","unknown_sternum","unknown_skull"]
const ROLL_DAMAGE := {"unknown_arm":5,"unknown_pelvis":5,"unknown_leg":5,"unknown_sternum":10,"unknown_skull":10,"witch_ghost":50}
const VULNERABILITIES := {"hellfire":Status.BURNING,"nightmare_totem":Status.DARKNESS,"corrupt_crystal":Status.CORROSION}
const RANDOM_STATUSES := [Status.BURNING,Status.FROZEN,Status.DARKNESS,Status.CORROSION,Status.PLAGUE]

## Gate conditional loot consistently in chests, shops, tarot grants and reel strips.
static func loot_allowed(inventory, id: String) -> bool:
	return id != "unidentified_ring" or BONES.all(func(bone): return inventory.has(bone))

## The eye grows once per actual tarot use; copying repeats its benefit, not its counter.
static func tarot_used(model) -> void:
	for item in model.relics.items:
		if item.id == "precognition_eye":
			item["damage_growth"] = item.get("damage_growth",0.0)+0.05
			model.relic_activated.emit(item.id)

## Add conditional multipliers at this relic's position in the ordered inventory.
static func damage_modifier(item: Dictionary, value: float, skill: MultiHitSkill) -> float:
	if item.id == "precognition_eye": value += item.get("damage_growth",0.0)
	if item.id == "black_chip" and item.get("no_straight",false): value += 5.0
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

## Every accepted throw replaces Black Chip's condition and snapshots free chip casts.
static func rolled(model) -> Array:
	var values: Array = model.dice_turn.unused().map(func(i): return model.dice_turn.values[i])
	var no_straight: bool = not model.Patterns.has_combination(values)
	for item in model.relics.items:
		if item.id == "black_chip": item.no_straight = no_straight
	var casts: Array = []
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id == "black_chip" and no_straight: Sequence.activate(model,entry)
		if entry.item.id not in ["red_chip","blue_chip"] or no_straight: continue
		var faces: Array = straight(values,entry.item.id == "red_chip")
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
	model.dice_turn.ticket_rolls_left = Sequence.entries(model.relics.items).filter(func(entry): return entry.item.id == "ticket").size()

## Random potion effects exclude enemy stun and action-lock bookkeeping.
static func after_hit(model, target: int, entry: Dictionary) -> Array:
	if entry.item.id != "mystery_potion" or not model.is_enemy_alive(target) or "mystery_potion" in model.active_relic_procs or model.rng.randf() >= 0.1: return []
	Sequence.activate(model,entry)
	model.active_relic_procs.append("mystery_potion")
	var events: Array = model.apply_enemy_status(target,RANDOM_STATUSES[model.rng.randi_range(0,RANDOM_STATUSES.size()-1)],1)
	model.active_relic_procs.pop_back()
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
		if item.id == "black_chip": item.no_straight = false
		var chance: float = 0.2 if item.id == "banana" else 0.01 if item.id == "magic_banana" else 0.0
		if chance > 0 and model.rng.randf() < chance:
			model.relic_activated.emit(item.id)
			model.relics.remove(i)
			events.append(model.event(-1,0,"relic","RELIC VANISHED"))
	return events
