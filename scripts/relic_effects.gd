extends RefCounted
## Relic behavior lives here; inventory owns order/ownership and battle owns HP/turns.
## Passive variants need only a STATS entry. New triggers belong in the matching
## lifecycle hook, never in UI code. All hooks traverse inventory left to right.
const Status = preload("res://scripts/status_effect.gd")
const Skill = preload("res://scripts/multi_hit_skill.gd")
const Catalog = preload("res://scripts/relic_catalog.gd")
const Sequence = preload("res://scripts/relic_sequence.gd")
const Attack = preload("res://scripts/relic_attack.gd")
const EMPTY := {}
const STATS := {
	"codex_page": {"damage_add":0.2},
	"fries": {"damage_add":0.5},
	"hamburger": {"damage_add":1.0},
	"worn_dagger": {"combo_uses_add":1},
	"royal_dagger": {"combo_uses_add":3},
	"heart": {"max_hp_factor":1.1},
	"bracelet": {"base_damage":10.0},
	"mithril_blade": {"base_damage":100.0},
	"armor": {"incoming_factor":0.9},
	"ancient_codex": {"damage_factor":2.0},
	"reaper_scythe": {"max_hp_factor":0.5,"damage_per_kill":1.1},
	"twin_scythes": {"combo_uses_factor":2},
	"cursed_bow": {"combo_uses_per_wave":1,"single_target_factor_per_wave":0.95},
	"coin": {"wave_rubies":10},
	"ancient_prophecy": {"tarot_repeat":true},
	"cursed_watch": {"always_perfect":true,"no_ultimate":true,"no_treasure":true},
}
const STONES := {
	"orange_stone": {"immune":Status.FROZEN,"status":Status.BURNING,"stacks":1,"chance":1.0},
	"blue_stone": {"immune":Status.BURNING,"status":Status.FROZEN,"stacks":1,"chance":0.3},
	"purple_stone": {"immune":Status.DARKNESS,"status":Status.DARKNESS,"stacks":1,"chance":0.3},
	"yellow_stone": {"immune":Status.STUNNED,"combo_gain":1},
	"green_stone": {"immune":Status.CORROSION,"status":Status.CORROSION,"stacks":1,"chance":0.5},
	"black_stone": {"status":Status.PLAGUE,"stacks":1,"chance":1.0},
}
const TURN_CHARGES := {
	"magic_shield": {"period":6,"message":"SHIELD READY"},
	"magic_sword": {"period":6,"message":"CRITICAL READY"},
}
const CRITICAL_FACTOR := 3.0
const PERFECT_STRIKE_BASE := 100.0
const TAROT_GENERATORS := {"fortune_cookie":3,"crystal_ball":1}

static func acquired(model, id: String, batch: bool = false) -> void:
	var acquired_slot: int = model.relics.index_of(id)
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id == "fortune_cookie" and (entry.origin == acquired_slot or (not batch and entry.slot == acquired_slot)):
			if not model.grant_random_tarots(1).is_empty(): Sequence.activate(model,entry)
	if id == "pet_slime":
		for target in model.living():
			if model.enemy_status_count(target,Status.CORROSION) > 0: model.enemies[target].statuses[Status.CORROSION].permanent = true

static func repeat_sources(items: Array, id: String) -> Array:
	return Sequence.entries(items).filter(func(entry): return entry.item.id == id)

static func currency_factor(items: Array) -> float:
	return 1.0+0.15*repeat_sources(items,"soul_vessel").size()

static func currency_bonus(model, amount: int) -> float:
	var factor: float = 1.0
	for entry in repeat_sources(model.relics.items,"soul_vessel"):
		factor += 0.15
		Sequence.activate(model,entry)
	return amount*factor

static func has_flag(items: Array, flag: String) -> bool:
	for item in items:
		if STATS.get(item.id,EMPTY).get(flag,false): return true
	return false

static func max_health(items: Array, base: int) -> float:
	var value: float = base
	for entry in Sequence.entries(items): value *= STATS.get(entry.item.id,EMPTY).get("max_hp_factor",1.0)
	return value

static func base_damage(items: Array) -> float:
	var value: float = 0
	for entry in Sequence.entries(items): value += STATS.get(entry.item.id,EMPTY).get("base_damage",0.0)
	return value

static func damage_multiplier(items: Array, value: float, skill: MultiHitSkill) -> float:
	for entry in Sequence.entries(items):
		var item: Dictionary = entry.item
		value = apply_damage_modifier(item,value,skill)
	return value

static func apply_damage_modifier(item: Dictionary, value: float, skill: MultiHitSkill) -> float:
	var stats: Dictionary = STATS.get(item.id,EMPTY)
	value += stats.get("damage_add",0.0)*item.count
	value *= stats.get("damage_factor",1.0)
	if stats.has("damage_per_kill"): value *= pow(stats.damage_per_kill,item.kills)
	if not skill.is_empty():
		if item.id == "cursed_skull": value *= 2.0 if 6 in skill.dice else 0.5
		if skill.is_attack() and not skill.hits_all():
			value *= pow(stats.get("single_target_factor_per_wave",1.0),item.get("waves",0))
	return value

static func attack_steps(items: Array, value: float, skill: MultiHitSkill) -> Array:
	var steps: Array = []
	var critical: float = 1.0
	for entry in Sequence.entries(items):
		var item: Dictionary = entry.item
		var slot: int = entry.slot
		var before: float = value*critical
		value = apply_damage_modifier(item,value,skill)
		if item.id == "magic_sword" and skill.critical: critical = CRITICAL_FACTOR
		var stats: Dictionary = STATS.get(item.id,EMPTY)
		var extra: String = ""
		var extra_values: Array = []
		if stats.get("base_damage",0) != 0:
			extra = "+%d BASE"
			extra_values = [stats.base_damage]
		if skill.random_target_per_use() and (stats.has("combo_uses_factor") or stats.has("combo_uses_add") or stats.get("combo_uses_per_wave",0)*item.waves > 0):
			extra = "EXTRA HITS"
			extra_values.clear()
		if not is_equal_approx(before,value*critical) or not extra.is_empty():
			steps.append({"source":"relic","id":entry.source,"slot":slot,"activators":entry.activators,"speed":Sequence.animation_speed(entry),"before":before,"after":value*critical,"note":extra,"note_values":extra_values,"base_bonus":float(stats.get("base_damage",0.0))})
	if skill.critical and critical == 1.0:
		steps.append({"source":"critical","id":"","slot":-1,"before":value,"after":value*CRITICAL_FACTOR,"note":""})
	return steps

static func use_modifiers(items: Array, skill: MultiHitSkill, modifiers: Dictionary) -> Dictionary:
	var result: Dictionary = modifiers.duplicate()
	if not skill.random_target_per_use(): return result
	for entry in Sequence.entries(items):
		var item: Dictionary = entry.item
		var stats: Dictionary = STATS.get(item.id,EMPTY)
		if stats.has("combo_uses_factor"): result[str(result.size())+":"+item.id] = stats.combo_uses_factor
		elif stats.has("combo_uses_add"): result[str(result.size())+":"+item.id] = {"add":stats.combo_uses_add}
		elif stats.has("combo_uses_per_wave"): result[str(result.size())+":"+item.id] = {"add":item.waves*stats.combo_uses_per_wave}
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
	for entry in Sequence.entries(items):
		var item: Dictionary = entry.item
		if item.id == "prismatic_stone":
			for stone in Catalog.STONES: amount += STONES[stone].get("combo_gain",0)
		else: amount += STONES.get(item.id,EMPTY).get("combo_gain",0)
	return amount

static func after_hit(model, target: int, damage: int, skill: MultiHitSkill) -> Array:
	var events: Array = []
	var extra_stacks: int = 0
	var runestones: Array = []
	var extra_burning: int = 0
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if item.id == "runestone": extra_stacks += 1; runestones.append(entry)
		if item.id == "pet_lizard": extra_burning += 1; runestones.append(entry)
		if item.id == "bloodstone":
			var cap: int = floori(model.max_hp*(0.05 if skill.random_target_per_use() else 0.1))
			var budget: String = str(entry.activators)
			var restored: int = model.heal(mini(maxi(0,cap-model.lifesteal_budgets.get(budget,0)),floori(damage*0.2)))
			model.lifesteal_budgets[budget] = model.lifesteal_budgets.get(budget,0)+restored
			model.lifesteal_used += restored
			if restored > 0:
				events.append(model.event(-1,restored,"heal","LIFESTEAL"))
				Sequence.activate(model,entry)
		if not model.is_enemy_alive(target): continue
		var applied: Array = []
		if item.id == "prismatic_stone":
			for stone in Catalog.STONES: applied.append_array(_apply_stone(model,target,STONES[stone],extra_stacks,extra_burning))
		elif STONES.has(item.id): applied = _apply_stone(model,target,STONES[item.id],extra_stacks,extra_burning)
		if not applied.is_empty():
			for source in runestones: Sequence.activate(model,source)
			Sequence.activate(model,entry)
			events.append_array(applied)
	return events

static func _apply_stone(model, target: int, effect: Dictionary, extra: int, burning: int) -> Array:
	if not effect.has("status"): return []
	# Guaranteed effects deliberately consume no RNG; previews never call this hook.
	if effect.chance < 1.0 and model.rng.randf() >= effect.chance: return []
	return model.apply_enemy_status(target,effect.status,effect.stacks+extra+(burning if effect.status == Status.BURNING else 0),false)

static func incoming(items: Array, amount: float, corroded: bool, burning: bool) -> Dictionary:
	var activated: Array = []
	if not corroded:
		for entry in Sequence.entries(items):
			var item: Dictionary = entry.item
			var before: float = amount
			amount *= STATS.get(item.id,EMPTY).get("incoming_factor",1.0)
			if not is_equal_approx(amount,before): activated.append_array(entry.activators)
			if item.id == "magic_shield" and item.charges > 0 and not burning:
				item.charges -= 1
				activated.append_array(entry.activators)
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
	var due: Array = []
	for item in model.relics.items:
		var period: int = TAROT_GENERATORS.get(item.id,TURN_CHARGES.get(item.id,EMPTY).get("period",0))
		if period == 0: continue
		item.turns += 1
		if item.turns >= period:
			item.turns = 0
			due.append(item.id)
	var events: Array = []
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if item.id not in due: continue
		if TAROT_GENERATORS.has(item.id):
			var cards: Array = model.grant_random_tarots(1)
			if not cards.is_empty():
				Sequence.activate(model,entry)
				events.append(model.event(-1,cards.size(),"relic","TAROT +1"))
		elif TURN_CHARGES.has(item.id):
			item.charges += 1
			Sequence.activate(model,entry)
			events.append(model.event(-1,1,"relic",TURN_CHARGES[item.id].message))
	return events

static func enemy_killed(model) -> void:
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if STATS.get(item.id,EMPTY).has("damage_per_kill"):
			if entry.origin == entry.slot: item.kills += 1
			Sequence.activate(model,entry)

static func wave_cleared(model) -> int:
	var rubies: int = 0
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		var stats: Dictionary = STATS.get(item.id,EMPTY)
		rubies += stats.get("wave_rubies",0)
		if stats.has("combo_uses_per_wave") and entry.origin == entry.slot: item.waves += 1
		if stats.has("wave_rubies") or stats.has("combo_uses_per_wave"): Sequence.activate(model,entry)
	return rubies

static func modify_dice(model, values: Array, perfect: bool, rates: Dictionary) -> Array:
	var six_chance: float = model._six_probability(rates)
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		var before: Array = values.duplicate()
		if item.id == "lucky_die":
			if 6 not in values and model.rng.randf() < minf(1,0.05/maxf(0.0001,1-six_chance)): values = _include_face(model,values,6)
			six_chance = minf(1.0,six_chance+0.05)
		elif Catalog.CURSED_DICE.has(item.id):
			var face: int = Catalog.CURSED_DICE[item.id]
			if perfect and face not in values: values = _include_face(model,values,face)
			elif not perfect and face in values:
				var alternatives: Array = [1,2,3,4,5,6].filter(func(value): return value not in values)
				var replacement: int = alternatives[model.rng.randi_range(0,alternatives.size()-1)]
				for i in range(3):
					if values[i] == face: values[i] = replacement
		if before != values: Sequence.activate(model,entry)
	if has_flag(model.relics.items,"no_ultimate") and values == [6,6,6]:
		if model.relics.has("cursed_die"): values[model.rng.randi_range(0,2)] = model.rng.randi_range(1,5)
		else: values.fill(model.rng.randi_range(1,5))
	return values

static func category_rates(items: Array, base: Dictionary, perfect_city: bool = false) -> Dictionary:
	var rates: Dictionary = base.duplicate()
	if perfect_city: return rates # City Perfects retain their guaranteed triple.
	for entry in Sequence.entries(items):
		var item: Dictionary = entry.item
		var key: String = "pair" if item.id == "four_leaf_clover" else "triple" if item.id == "five_leaf_clover" else ""
		if key.is_empty(): continue
		var bonus: float = minf(0.10 if key == "pair" else 0.05,1.0-rates[key])
		var normal: float = minf(bonus,rates.normal)
		rates.normal -= normal
		var other: String = "triple" if key == "pair" else "pair"
		rates[other] -= bonus-normal
		rates[key] += bonus
	return rates

static func _include_face(model, values: Array, face: int) -> Array:
	var skill: MultiHitSkill = model.classify(values)
	if skill.kind >= Skill.Kind.SPECIAL: return [face,face,face]
	if skill.kind == Skill.Kind.PAIR:
		for i in range(3):
			if values[i] == skill.spare: values[i] = face
	else: values[model.rng.randi_range(0,2)] = face
	return values

# Independent triggers return regular combat events, so the UI can animate them
# with the same impact and healing feedback as skill attacks.
static func attack_used(model) -> Array:
	var events: Array = []
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if item.id != "pet_bat": continue
		var restored: int = model.heal(5)
		if restored > 0:
			Sequence.activate(model,entry)
			events.append(model.event(-1,restored,"heal","+5 HP"))
	return events

static func status_bonus(model, status: int) -> int:
	if status == Status.IMMOBILIZED: return 0
	var extra: int = 0
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if item.id == "runestone" or (item.id == "pet_lizard" and status == Status.BURNING):
			extra += 1
			Sequence.activate(model,entry)
	return extra

static func status_applied(model, target: int, status: int) -> Array:
	var events: Array = []
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if item.id == "pet_slime" and status == Status.CORROSION:
			model.enemies[target].statuses[status].permanent = true
			Sequence.activate(model,entry)
		if item.id == "ice_rose" and status == Status.FROZEN and item.id not in model.active_relic_procs:
			Sequence.activate(model,entry)
			events.append_array(Attack.apply(model,item.id,10,false,false,target))
	return events

static func retaliation(model, target: int) -> Array:
	var events: Array = []
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if item.id != "spiked_helmet": continue
		Sequence.activate(model,entry)
		events.append_array(Attack.apply(model,item.id,10,true,false,target))
	return events

static func roll_actions(model, perfect: bool) -> Array:
	var actions: Array = []
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		var amount: float = 0
		var fixed: bool = false
		var area: bool = false
		var count: int = 1
		match item.id:
			"worn_bow": amount = 5; fixed = true
			"tissue_pack":
				if model.pending.kind == Skill.Kind.NORMAL: amount = 10
			"magic_slingshot":
				if model.pending.kind == Skill.Kind.PAIR: amount = model.pending.spare
			"pet_ghost": amount = 50; fixed = true; area = true
			"pet_dragon": amount = 50; count = 2
			"spiked_helmet":
				if perfect: amount = 10
			"prismatic_stone":
				if perfect: amount = PERFECT_STRIKE_BASE
		if amount > 0:
			for i in range(count): actions.append({"id":item.id,"activation":entry,"amount":amount,"fixed":fixed,"area":area})
	return actions
