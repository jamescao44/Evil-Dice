extends RefCounted
## Shared cast lifecycle: tier upgrades, alternating skills and non-recursive echoes.
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Sequence = preload("res://scripts/relics/relic_sequence.gd")
var first_manual_used: bool = false
var previous_skill: String = ""
var queued: Array = []
var resume_phase: String = ""

## Skill identity follows the effect tier, not the particular pips selected.
static func identity(skill: MultiHitSkill) -> String:
	return "%s:%d" % [skill.pattern,skill.dice.size()] if not skill.pattern.is_empty() else "%d:%d" % [skill.kind,skill.face]

func counts_as_cast(skill: MultiHitSkill) -> bool:
	return skill.cast_source in ["manual","missile"] and skill.pattern not in ["cleanup","match_auto"]

## Read-only previews use the last committed skill; a running cast keeps its result.
func alternates(skill: MultiHitSkill) -> bool:
	if skill.relic_cast_locked: return skill.alternating_bonus
	return counts_as_cast(skill) and not previous_skill.is_empty() and identity(skill) != previous_skill

## Upgrade only the effect, retaining original dice for costs and pip-dependent curses.
func preview_upgrade(model, skill: MultiHitSkill) -> MultiHitSkill:
	if first_manual_used or skill.cast_source != "manual" or skill.pattern != "straight": return skill
	var upgraded: MultiHitSkill = skill.duplicate()
	upgraded.source_dice = skill.dice.duplicate()
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id != "royal_seal" or upgraded.dice.size() >= 6: continue
		var values: Array = upgraded.dice.duplicate()
		values.sort()
		if values.back() < 6: values.append(values.back()+1)
		else: values.push_front(values.front()-1)
		var next: MultiHitSkill = model.make_straight_skill(values)
		next.source_dice = skill.dice.duplicate()
		next.perfect = skill.perfect
		next.royal_activations = upgraded.royal_activations+[entry]
		upgraded = next
	return upgraded

## Split each eligible skill once; repeats retain the already configured hit budget.
func configure_split(model, skill: MultiHitSkill) -> void:
	if skill.split_attack or skill.cast_source in ["echo","relic"] or skill.pattern in ["cleanup","match_auto"]: return
	if not skill.is_attack() or skill.hits_all() or model.is_instant_kill(skill): return
	if not model.relics.has("split_arrow"): return
	skill.split_attack = true
	skill.base_uses *= 2

## Refresh the first-manual-skill upgrade only when entering a new wave.
func wave_started() -> void:
	first_manual_used = false

## New complete turns queue automatic relic skills without refreshing the seal.
func turn_started(model) -> void:
	queued.clear()
	resume_phase = ""
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id != "enchanted_missile": continue
		var skill: MultiHitSkill = model.make_straight_skill([3,4,5])
		skill.cast_source = "missile"
		queued.append({"skill":skill,"activation":entry})
	if not queued.is_empty():
		resume_phase = model.phase
		start_next(model)

## Commit counters once per manual or missile cast, regardless of damage pulses.
func cast_started(model, skill: MultiHitSkill) -> void:
	if skill.split_attack:
		for entry in Sequence.entries(model.relics.items):
			if entry.item.id == "split_arrow": Sequence.activate(model,entry)
	if not counts_as_cast(skill): return
	skill.alternating_bonus = alternates(skill)
	skill.relic_cast_locked = true
	previous_skill = identity(skill)
	if skill.cast_source == "manual":
		first_manual_used = true
		for entry in skill.royal_activations: Sequence.activate(model,entry)
	var due: Array = []
	for item in model.relics.items:
		if item.id != "echo_bell": continue
		item["casts"] = item.get("casts",0)+1
		if item.casts >= 3: item.casts = 0; due.append(item.id)
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id not in due: continue
		var echo: MultiHitSkill = Skill.new(skill.kind,skill.face,skill.dice,skill.use_count())
		echo.pattern = skill.pattern
		echo.split_attack = skill.split_attack
		echo.damage_ticks = skill.damage_ticks
		echo.target = skill.target
		echo.cast_source = "echo"
		echo.source_dice = skill.source_dice.duplicate()
		echo.effect_multiplier = skill.effect_multiplier*0.5
		echo.critical = skill.critical
		echo.amplifier_locked = true
		echo.relic_effect_scale = 0.5
		echo.relic_cast_locked = true
		echo.alternating_bonus = skill.alternating_bonus
		queued.append({"skill":echo,"activation":entry})

## Queue two independent Fireballs ahead of relic echoes, reusing the triggering skill's final whole-use damage.
func queue_character_fireballs(source: MultiHitSkill) -> void:
	for i in range(2):
		var fireball: MultiHitSkill = Patterns.classify([3,4,5])
		fireball.cast_source = "character_bonus"
		fireball.inherited_damage = source.calculated_damage_total*(2 if source.split_attack else 1)
		fireball.effect_multiplier = source.effect_multiplier
		fireball.critical = source.critical
		fireball.perfect = source.perfect
		fireball.amplifier_locked = true
		fireball.relic_cast_locked = true
		queued.push_front({"skill":fireball})

## Generated casts use normal model/presentation steps and never reserve extra dice.
func start_next(model) -> bool:
	if not model.outcome().is_empty():
		queued.clear(); resume_phase = ""
		return false
	if not queued.is_empty():
		var next: Dictionary = queued.pop_front()
		model.pending = next.skill
		model.phase = "player"
		if next.has("activation"): Sequence.activate(model,next.activation)
		return true
	if not resume_phase.is_empty():
		model.pending = Skill.new()
		model.phase = resume_phase
		resume_phase = ""
		return true
	return false
