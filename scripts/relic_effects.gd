extends RefCounted
## Relic behavior lives here; inventory owns order/ownership and battle owns HP/turns.
## Passive variants need only a STATS entry. New triggers belong in the matching
## lifecycle hook, never in UI code. All hooks traverse inventory left to right.
const Status = preload("res://scripts/status_effect.gd")
const Skill = preload("res://scripts/multi_hit_skill.gd")
const Catalog = preload("res://scripts/relic_catalog.gd")
const EMPTY := {}
const STATS := {
	"codex_page": {"damage_add":0.2},
	"heart": {"max_hp_factor":1.1},
	"bracelet": {"base_damage":10.0},
	"mithril_blade": {"base_damage":100.0},
	"armor": {"incoming_factor":0.9},
	"ancient_codex": {"damage_factor":2.0},
	"reaper_scythe": {"max_hp_factor":0.5,"damage_per_kill":1.1},
	"twin_scythes": {"combo_uses_factor":2},
	"cursed_bow": {"combo_uses_per_wave":1,"single_target_factor":0.95},
	"coin": {"wave_rubies":10},
	"ancient_prophecy": {"tarot_repeat":true},
	"cursed_watch": {"always_perfect":true,"no_ultimate":true,"no_treasure":true},
}
const STONES := {
	"orange_stone": {"immune":Status.FROZEN,"status":Status.BURNING,"stacks":1,"chance":1.0},
	"blue_stone": {"immune":Status.BURNING,"status":Status.FROZEN,"stacks":1,"chance":0.3},
	"purple_stone": {"immune":Status.DARKNESS,"status":Status.DARKNESS,"stacks":3,"chance":0.3},
	"yellow_stone": {"immune":Status.STUNNED,"combo_gain":1},
	"green_stone": {"immune":Status.CORROSION,"status":Status.CORROSION,"stacks":3,"chance":0.5},
	"black_stone": {"status":Status.PLAGUE,"stacks":1,"chance":1.0},
}
const TURN_CHARGES := {
	"magic_shield": {"period":6,"message":"SHIELD READY"},
	"magic_sword": {"period":6,"message":"CRITICAL READY"},
}
const CRITICAL_FACTOR := 3.0
const PERFECT_STRIKE_BASE := 100.0
const TAROT_GENERATORS := {"fortune_cookie":3,"crystal_ball":1}

static func acquired(model, id: String) -> void:
	if id == "fortune_cookie" and not model.grant_random_tarots(1).is_empty():
		model.relic_activated.emit(id)

static func has_flag(items: Array, flag: String) -> bool:
	for item in items:
		if STATS.get(item.id,EMPTY).get(flag,false): return true
	return false

static func max_health(items: Array, base: int) -> float:
	var value: float = base
	for item in items: value *= STATS.get(item.id,EMPTY).get("max_hp_factor",1.0)
	return value

static func base_damage(items: Array) -> float:
	var value: float = 0
	for item in items: value += STATS.get(item.id,EMPTY).get("base_damage",0.0)
	return value

static func damage_multiplier(items: Array, value: float, skill: MultiHitSkill) -> float:
	for item in items:
		value = apply_damage_modifier(item,value,skill)
	return value

static func apply_damage_modifier(item: Dictionary, value: float, skill: MultiHitSkill) -> float:
	var stats: Dictionary = STATS.get(item.id,EMPTY)
	value += stats.get("damage_add",0.0)*item.count
	value *= stats.get("damage_factor",1.0)
	if stats.has("damage_per_kill"): value *= pow(stats.damage_per_kill,item.kills)
	if not skill.is_empty():
		if item.id == "cursed_skull": value *= 2.0 if 6 in skill.dice else 0.5
		if skill.is_attack() and not skill.hits_all(): value *= stats.get("single_target_factor",1.0)
	return value

static func attack_steps(items: Array, value: float, skill: MultiHitSkill) -> Array:
	var steps: Array = []
	var critical: float = 1.0
	for slot in range(items.size()):
		var item: Dictionary = items[slot]
		var before: float = value*critical
		value = apply_damage_modifier(item,value,skill)
		if item.id == "magic_sword" and skill.critical: critical = CRITICAL_FACTOR
		var stats: Dictionary = STATS.get(item.id,EMPTY)
		var extra: String = ""
		var extra_values: Array = []
		if stats.get("base_damage",0) != 0:
			extra = "+%d BASE"
			extra_values = [stats.base_damage]
		if skill.random_target_per_use() and (stats.has("combo_uses_factor") or stats.get("combo_uses_per_wave",0)*item.waves > 0):
			extra = "EXTRA HITS"
			extra_values.clear()
		if not is_equal_approx(before,value*critical) or not extra.is_empty():
			steps.append({"source":"relic","id":item.id,"slot":slot,"before":before,"after":value*critical,"note":extra,"note_values":extra_values,"base_bonus":float(stats.get("base_damage",0.0))})
	if skill.critical and critical == 1.0:
		steps.append({"source":"critical","id":"","slot":-1,"before":value,"after":value*CRITICAL_FACTOR,"note":""})
	return steps

static func use_modifiers(items: Array, skill: MultiHitSkill, modifiers: Dictionary) -> Dictionary:
	var result: Dictionary = modifiers.duplicate()
	if not skill.random_target_per_use(): return result
	for item in items:
		var stats: Dictionary = STATS.get(item.id,EMPTY)
		if stats.has("combo_uses_factor"): result[item.id] = stats.combo_uses_factor
		elif stats.has("combo_uses_per_wave"): result[item.id] = {"add":item.waves*stats.combo_uses_per_wave}
	return result

static func has_critical(items: Array) -> bool:
	return items.any(func(item): return item.id == "magic_sword" and item.charges > 0)

static func begin_attack(items: Array) -> bool:
	for item in items:
		if item.id == "magic_sword" and item.charges > 0:
			item.charges -= 1
			return true
	return false

static func immune(items: Array, id: int) -> bool:
	return not immunity_source(items,id).is_empty()

static func immunity_source(items: Array, id: int) -> String:
	for item in items:
		if item.id == "prismatic_stone":
			for stone in Catalog.STONES:
				if STONES[stone].get("immune",-1) == id: return item.id
		elif STONES.get(item.id,EMPTY).get("immune",-1) == id: return item.id
	return ""

static func perfect_combo_gain(items: Array) -> int:
	var amount: int = 1
	for item in items:
		if item.id == "prismatic_stone":
			for stone in Catalog.STONES: amount += STONES[stone].get("combo_gain",0)
		else: amount += STONES.get(item.id,EMPTY).get("combo_gain",0)
	return amount

static func after_hit(model, target: int, damage: int, skill: MultiHitSkill) -> Array:
	var events: Array = []
	var extra_stacks: int = 0
	var runestones: Array = []
	for item in model.relics.items:
		if item.id == "runestone": extra_stacks += 1; runestones.append(item.id)
		if item.id == "bloodstone":
			var cap: int = floori(model.max_hp*(0.05 if skill.random_target_per_use() else 0.1))
			var restored: int = model.heal(mini(maxi(0,cap-model.lifesteal_used),floori(damage*0.2)))
			model.lifesteal_used += restored
			if restored > 0:
				events.append(model.event(-1,restored,"heal","LIFESTEAL"))
				model.relic_activated.emit(item.id)
		if not model.is_enemy_alive(target): continue
		var applied: Array = []
		if item.id == "prismatic_stone":
			for stone in Catalog.STONES: applied.append_array(_apply_stone(model,target,STONES[stone],extra_stacks))
		elif STONES.has(item.id): applied = _apply_stone(model,target,STONES[item.id],extra_stacks)
		if not applied.is_empty():
			for id in runestones: model.relic_activated.emit(id)
			model.relic_activated.emit(item.id)
			events.append_array(applied)
	return events

static func _apply_stone(model, target: int, effect: Dictionary, extra: int) -> Array:
	if not effect.has("status"): return []
	# Guaranteed effects deliberately consume no RNG; previews never call this hook.
	if effect.chance < 1.0 and model.rng.randf() >= effect.chance: return []
	return model.apply_enemy_status(target,effect.status,effect.stacks+extra)

static func incoming(items: Array, amount: float, corroded: bool, burning: bool) -> Dictionary:
	var activated: Array = []
	if not corroded:
		for item in items:
			var before: float = amount
			amount *= STATS.get(item.id,EMPTY).get("incoming_factor",1.0)
			if not is_equal_approx(amount,before): activated.append(item.id)
			if item.id == "magic_shield" and item.charges > 0 and not burning:
				item.charges -= 1
				activated.append(item.id)
				return {"amount":0.0,"blocked":true,"activated":activated}
	return {"amount":amount,"blocked":false,"activated":activated}

static func prevent_death(model) -> Array:
	var index: int = model.relics.index_of("contract")
	if index < 0: return []
	model.relic_activated.emit("contract")
	model.relics.remove(index)
	model.hp = maxi(1,roundi(model.max_hp*0.6))
	return [model.event(-1,model.hp,"relic","CONTRACT: REVIVED")]

static func turn_finished(model) -> Array:
	var events: Array = []
	for item in model.relics.items:
		if TAROT_GENERATORS.has(item.id):
			item.turns += 1
			if item.turns >= TAROT_GENERATORS[item.id]:
				item.turns = 0
				var cards: Array = model.grant_random_tarots(1)
				if not cards.is_empty():
					model.relic_activated.emit(item.id)
					events.append(model.event(-1,cards.size(),"relic","TAROT +1"))
		if not TURN_CHARGES.has(item.id): continue
		var charge: Dictionary = TURN_CHARGES[item.id]
		item.turns += 1
		if item.turns >= charge.period:
			item.turns = 0
			item.charges += 1
			model.relic_activated.emit(item.id)
			events.append(model.event(-1,1,"relic",charge.message))
	return events

static func enemy_killed(model) -> void:
	for item in model.relics.items:
		if STATS.get(item.id,EMPTY).has("damage_per_kill"):
			item.kills += 1
			model.relic_activated.emit(item.id)

static func wave_cleared(model) -> int:
	var rubies: int = 0
	for item in model.relics.items:
		var stats: Dictionary = STATS.get(item.id,EMPTY)
		rubies += stats.get("wave_rubies",0)
		if stats.has("combo_uses_per_wave"): item.waves += 1
		if stats.has("wave_rubies") or stats.has("combo_uses_per_wave"): model.relic_activated.emit(item.id)
	return rubies

static func modify_dice(model, values: Array, perfect: bool, rates: Dictionary) -> Array:
	for item in model.relics.items:
		var before: Array = values.duplicate()
		if item.id == "lucky_die" and 6 not in values:
			var chance: float = model._six_probability(rates)
			if model.rng.randf() < minf(1,0.05/maxf(0.0001,1-chance)): values = _include_six(model,values)
		elif item.id == "cursed_die":
			if perfect and 6 not in values: values = _include_six(model,values)
			elif not perfect and 6 in values:
				var alternatives: Array = [1,2,3,4,5].filter(func(face): return face not in values)
				var replacement: int = alternatives[model.rng.randi_range(0,alternatives.size()-1)]
				for i in range(3):
					if values[i] == 6: values[i] = replacement
		if before != values: model.relic_activated.emit(item.id)
	if has_flag(model.relics.items,"no_ultimate") and values == [6,6,6]:
		if model.relics.has("cursed_die"): values[model.rng.randi_range(0,2)] = model.rng.randi_range(1,5)
		else: values.fill(model.rng.randi_range(1,5))
	return values

static func _include_six(model, values: Array) -> Array:
	var skill: MultiHitSkill = model.classify(values)
	if skill.kind >= Skill.Kind.SPECIAL: return [6,6,6]
	if skill.kind == Skill.Kind.PAIR:
		for i in range(3):
			if values[i] == skill.spare: values[i] = 6
	else: values[model.rng.randi_range(0,2)] = 6
	return values
