extends RefCounted
## Read-only balance telemetry; the graphical game never loads this recorder.
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Sets = preload("res://scripts/relics/relic_sets.gd")
const REFERENCE := "3-4-5 Fireball: current player/relic/tarot modifiers, no sockets or target modifiers; per use before shields/overkill. Extra uses and passive/item attacks excluded."
var samples: Array = []
var command_index := 0
var inventory_events: Array = []
var commands: Array = []
var inventory: Array = []
var context: Dictionary = {}
var command_start: Dictionary = {}
var waves: Dictionary = {}

## A wave counts distinct begun combat rounds, including its partial finishing round.
func note_turn(model) -> void:
	if model.at_shop or model.round_number < 1: return
	var wave: int = model.stage+1
	if not waves.has(wave): waves[wave] = {"wave":wave,"boss":model.Waves.is_boss_stage(model.stage),"round_ids":[],"outcome":"in_progress","skills":{},"auto_attacks":{}}
	if waves[wave].outcome != "in_progress": return
	if model.round_number not in waves[wave].round_ids: waves[wave].round_ids.append(model.round_number)

## Count each real skill cast by name/source; extra uses are separate from damage ticks.
func skill_cast(model, skill: MultiHitSkill, uses: int) -> void:
	if skill.pattern != "straight": return
	note_turn(model)
	var wave: Dictionary = waves[model.stage+1]
	var name: String = model.CharacterSkills.caption(skill,model.character_evolution_stage()).name
	if not wave.skills.has(name): wave.skills[name] = {"casts":0,"uses":0,"sources":{}}
	var count: Dictionary = wave.skills[name]
	count.casts += 1
	count.uses += uses
	count.sources[skill.cast_source] = int(count.sources.get(skill.cast_source,0))+1

## A matching group counts once; its individual shots/AOE pulses are recorded separately.
func auto_step(model, skill: MultiHitSkill, first: bool) -> void:
	note_turn(model)
	var wave: Dictionary = waves[model.stage+1]
	var size: String = str(skill.dice.size())
	if not wave.auto_attacks.has(size): wave.auto_attacks[size] = {"groups":0,"pulses":0}
	wave.auto_attacks[size].groups += 1 if first else 0
	wave.auto_attacks[size].pulses += 1

## Defeat retains turns spent without falsely reporting a clear time.
func finish_wave(model) -> void:
	var wave: int = model.stage+1
	if not waves.has(wave): note_turn(model)
	if waves.has(wave): waves[wave].outcome = model.outcome()

## Keep unfinished encounters, shops and failed runs distinguishable in exports.
func wave_report() -> Array:
	var result: Array = []
	for value in waves.values():
		var row: Dictionary = value.duplicate(true)
		row.turns_spent = row.round_ids.size()
		row.cleared = row.outcome in ["wave_clear","victory"]
		row.turns_to_clear = row.turns_spent if row.cleared else null
		result.append(row)
	return result

## Keep visible command/card context so sales, replacements and rerolls are distinguishable.
func begin_command(model, request: Dictionary, choice: Dictionary) -> void:
	command_index += 1
	if model.phase in ["roll","player","frozen","roll_attacks","enemy","executing"]: note_turn(model)
	context = {"action":request.get("action","state"),"request":request.duplicate(true)}
	var candidate: Variant = request.get("instance",choice.get("instance_id",0))
	var instance: int = int(candidate) if candidate is int or candidate is float else 0
	if instance != 0:
		var card: Dictionary = model.tarot_effects._card(model,instance)
		context.card = card.get("id","")
		context.projection = card.get("projection",false)
	if request.get("replace") is int or request.get("replace") is float:
		var slot: int = int(request.replace)-1
		if slot >= 0 and slot < model.relics.items.size(): context.replaced = model.relics.items[slot].id
	command_start = measure(model)

## Retain decisions and model events alongside the trace without affecting the playing policy.
func finish_command(model, error: String, events: Array) -> void:
	commands.append({"command":command_index,"context":context.duplicate(true),"ok":error.is_empty(),
		"before":command_start.duplicate(true),"after":measure(model),"events":events.duplicate(true)})
	context = {}

## Ignore activation counters but retain counts, order and every fused set component.
static func owned(model) -> Array:
	var result: Array = []
	for item in model.relics.items:
		result.append({"id":item.id,"name":Catalog.ITEMS[item.id].name,"count":item.get("count",1),
			"ingredients":Sets.ingredients(item).duplicate()})
	return result

## Expand fusions for acquisition tracking, so a new ingredient remains identifiable.
static func quantities(items: Array, components: bool = false) -> Dictionary:
	var counts := {}
	for item in items:
		var ids: Array = item.ingredients if components and not item.ingredients.is_empty() else [item.id]
		var amount: int = item.count
		if components and item.id == "prismatic_stone": ids = Catalog.STONES
		if components and item.id == "ancient_codex": ids = ["codex_page"]; amount = 10
		for id in ids: counts[id] = int(counts.get(id,0))+amount
	return counts

## Count duplicates and Codex stacks without mistaking a reorder or counter tick for a new item.
static func additions(before: Dictionary, after: Dictionary) -> Array:
	var changes: Array = []
	for id in after:
		var count: int = after[id]-int(before.get(id,0))
		if count > 0: changes.append({"id":id,"name":Catalog.ITEMS[id].name,"count":count})
	return changes

## Log the complete inventory transition; fusion consumption is never labelled as selling.
func inventory_changed(model, row: Dictionary) -> void:
	var current: Array = owned(model)
	if current == inventory: return
	var before: Dictionary = quantities(inventory)
	var after: Dictionary = quantities(current)
	var parts_before: Dictionary = quantities(inventory,true)
	var parts_after: Dictionary = quantities(current,true)
	var previous: Dictionary = samples.back() if not samples.is_empty() else row
	var removed: Array = additions(after,before)
	var lost: Array = additions(parts_after,parts_before)
	var sold: Array = removed if context.get("action","") == "sell" else []
	var lost_ids: Array = lost.map(func(item): return item.id)
	var replaced: Array = removed.filter(func(item): return item.id == context.get("replaced","") and inventory.any(func(old): return old.id == item.id and (old.id in lost_ids or old.ingredients.any(func(id): return id in lost_ids))))
	inventory_events.append({"sample":row.sample,"command":command_index,"wave":row.wave,"round":row.round,
		"source":context.get("action","setup"),"card":context.get("card",""),
		"gained":additions(parts_before,parts_after),"lost":lost,"added":additions(before,after),"removed":removed,
		"sold":sold,"replaced":replaced,"before":inventory.duplicate(true),"after":current.duplicate(true),
		"damage_before":previous.fireball_per_use,"damage_after":row.fireball_per_use,
		"uses_before":previous.fireball_uses,"uses_after":row.fireball_uses})
	inventory = current

## Use a fresh hypothetical skill so inspection cannot alter the pending cast or RNG.
static func measure(model) -> Dictionary:
	var skill = Patterns.classify([3,4,5])
	var damage: int = model.unmitigated_damage(skill)*skill.damage_ticks
	return {"wave":model.stage+1,"round":model.round_number,"phase":model.phase,
		"player_level":model.character_level,"hp":model.hp,"max_hp":model.max_hp,
		"hp_ratio":float(model.hp)/maxi(1,model.max_hp),"shield":model.shield,
		"base_damage":model.character_base_damage(),"fireball_per_use":damage,
		"fireball_uses":model.skill_use_count(skill),"combo_multiplier":model.combo_multiplier()}

## Sample action boundaries, including each enemy action before later recovery can hide damage.
func capture(model, reason: String) -> void:
	var row := measure(model)
	row.sample = samples.size()
	row.command = command_index
	row.reason = reason
	inventory_changed(model,row)
	samples.append(row)

## Batch tools retain the full trace; JSONL sessions return only new samples per command.
func report() -> Dictionary:
	return {"schema":2,"reference":REFERENCE,"samples":samples.duplicate(true),
		"inventory_events":inventory_events.duplicate(true),"commands":commands.duplicate(true),"wave_turns":wave_report()}
