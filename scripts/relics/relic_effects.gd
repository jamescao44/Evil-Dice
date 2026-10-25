extends RefCounted
## Relic behavior lives here; inventory owns order/ownership and battle owns HP/turns.
## Passive variants need only a STATS entry. New triggers belong in the matching
## lifecycle hook, never in UI code. All hooks traverse inventory left to right.
const Status = preload("res://scripts/status/status_effect.gd")
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Sequence = preload("res://scripts/relics/relic_sequence.gd")
const Attack = preload("res://scripts/relics/relic_attack.gd")
const Conditions = preload("res://scripts/relics/relic_conditions.gd")
const EMPTY := {}
const Sets = preload("res://scripts/relics/relic_sets.gd")
const STATS := {
	"banana":{"damage_add":0.5},
	"magic_banana":{"damage_factor":1.5},
	"broken_blade":{"damage_add":0.3},
	"steel_sword": {"damage_add":3.0},
	"book_of_dead": {"max_hp_factor":3.0},
	"glass_marble": {"three_straight_bonus":0.1},
	"steel_marble": {"three_straight_bonus":0.2},
	"gold_marble": {"three_straight_bonus":0.3},
	"codex_page": {"damage_add":0.2},
	"fries": {"damage_add":0.3},
	"lemon_soda": {"auto_damage":5.0},
	"oreo_sundae": {"base_damage":10.0},
	"fried_chicken": {"damage_factor":1.1},
	"hamburger": {"damage_add":0.6},
	"worn_dagger": {"combo_uses_add":1,"base_damage":2.0},
	"royal_dagger": {"combo_uses_add":3,"base_damage":10.0},
	"magic_sword": {"base_damage":10.0},
	"magic_slingshot": {"base_damage":5.0},
	"contract": {"base_factor":1.2},
	"runestone": {"base_damage":5.0},
	"orange_stone": {"base_damage":5.0},
	"blue_stone": {"base_damage":5.0},
	"purple_stone": {"base_damage":5.0},
	"yellow_stone": {"base_damage":5.0},
	"green_stone": {"base_damage":5.0},
	"black_stone": {"base_damage":5.0},
	"prismatic_stone": {}, # Retain six five-point stones: 30 total, no extra flat bonus.
	"heart": {"max_hp_factor":1.1},
	"bracelet": {"base_damage":5.0},
	"mithril_blade": {"damage_factor":2.0},
	"armor": {"incoming_factor":0.9},
	"ancient_codex": {"damage_factor":2.0},
	"reaper_scythe": {"max_hp_factor":0.5,"damage_per_kill":0.05,"kill_damage_cap":2.0},
	"twin_scythes": {"combo_uses_factor":2},
	"cursed_bow": {"combo_uses_per_wave":1,"single_target_factor_per_wave":0.95},
	"coin": {"wave_rubies":10},
	"ancient_prophecy": {"tarot_repeat":true},
	"cursed_watch": {"always_perfect":true,"no_ultimate":true,"no_treasure":true},
}
const STONES := {
	"orange_stone": {"immune":Status.BURNING,"status":Status.BURNING,"stacks":1,"chance":1.0},
	"blue_stone": {"immune":Status.FROZEN,"status":Status.FROZEN,"stacks":1,"chance":0.3},
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
const TAROT_GENERATORS := {"fortune_cookie":5,"magician_hat":4}

## Run a relic’s immediate acquisition effect after inventory insertion.
static func acquired(model, id: String, batch: bool = false) -> void:
	var acquired_slot: int = model.relics.index_of(id)
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id in TAROT_GENERATORS and (entry.origin == acquired_slot or (not batch and entry.slot == acquired_slot)):
			if _grant_generator_tarot(model,entry.item.id): Sequence.activate(model,entry)
	if id == "pet_slime":
		for target in model.living():
			if model.enemy_status_count(target,Status.CORROSION) > 0: model.enemies[target].statuses[Status.CORROSION].permanent = true

static func repeat_sources(items: Array, id: String) -> Array:
	return Sequence.entries(items).filter(func(entry): return entry.item.id == id)

static func currency_factor(_items: Array) -> float:
	return 1.0

static func currency_bonus(_model, amount: int) -> float:
	return amount

## Savings are additional value, never a deduction from the enemy pickup.
static func enemy_gems_dropped(model, amount: int) -> void:
	for entry in repeat_sources(model.relics.items,"piggy_bank"):
		entry.item["savings"] = entry.item.get("savings",0.0)+amount*0.2
		Sequence.activate(model,entry)

## Fractional soul bonuses carry forward; chest and shop souls bypass this hook.
static func enemy_soul_bonus(model, amount: int) -> int:
	var total: float = amount+model.enemy_soul_remainder
	for entry in repeat_sources(model.relics.items,"soul_vessel"):
		total += amount*0.15
		Sequence.activate(model,entry)
	var gained := floori(total+0.000001)
	model.enemy_soul_remainder = maxf(0,total-gained)
	return gained

static func tarot_drop_chance(items: Array) -> float:
	return minf(1.0,0.125+0.05*repeat_sources(items,"cross").size())

## Apply recovery bonuses once before the missing-health and lifesteal caps.
static func healing_amount(items: Array, amount: float) -> int:
	return roundi(amount*(1.0+0.1*repeat_sources(items,"blood_bag").size()))

static func _grant_generator_tarot(model, id: String) -> bool:
	if id == "magician_hat": return not model.grant_tarot("magician").is_empty()
	return not model.grant_random_tarots(1).is_empty()

## Tarot activation grants shields only on a committed card effect.
static func tarot_used(model, grow_eye: bool = true) -> Array:
	if grow_eye: Conditions.tarot_used(model)
	var events: Array = []
	for entry in repeat_sources(model.relics.items,"bookmark"):
		model.shield += 10
		Sequence.activate(model,entry)
		events.append(model.event(-1,10,"buff","SHIELD +10"))
	return events

## Track real Perfect attempts, with one banked protection regardless of combo bonuses.
static func protect_perfect(model, perfect: bool, preserve_combo: bool) -> bool:
	var protected: bool = preserve_combo
	for item in model.relics.items:
		if item.id != "perfectionist": continue
		if perfect:
			item["perfects"] = mini(3,item.get("perfects",0)+1)
			if item.perfects == 3 and item.charges == 0:
				item.charges = 1
				model.relic_activated.emit(item.id)
		elif not preserve_combo:
			item["perfects"] = 0
			if item.charges > 0:
				item.charges = 0
				protected = true
				model.relic_activated.emit(item.id)
	return protected

static func has_flag(items: Array, flag: String) -> bool:
	for item in items:
		if item.id not in Catalog.DISABLED and Sets.stats(item,STATS).get(flag,false): return true
	return false

static func max_health(items: Array, base: int) -> float:
	var value: float = base
	for entry in Sequence.entries(items): value *= Sets.stats(entry.item,STATS).get("max_hp_factor",1.0)
	return value

static func base_damage(items: Array, starting_base: float = 0.0) -> float:
	var value: float = starting_base
	for entry in Sequence.entries(items):
		for part in Sets.modifiers(entry.item,STATS):
			value = (value+part.get("base_damage",0.0))*part.get("base_factor",1.0)
	return value-starting_base

## Soda adds to automatic attack base before its pip coefficient and ordered multiplier.
static func auto_damage(items: Array, skill: MultiHitSkill) -> float:
	if skill.pattern != "match_auto": return 0.0
	var amount := 0.0
	for entry in Sequence.entries(items): amount += Sets.stats(entry.item,STATS).get("auto_damage",0.0)
	return amount

static func damage_multiplier(items: Array, value: float, skill: MultiHitSkill, model = null) -> float:
	for entry in Sequence.entries(items):
		var item: Dictionary = entry.item
		value = apply_damage_modifier(item,value,skill,model)
	value *= marble_factor(items,skill)
	return value

## Apply one relic’s damage rule in inventory order.
static func apply_damage_modifier(item: Dictionary, value: float, skill: MultiHitSkill, model = null) -> float:
	var stats: Dictionary = Sets.stats(item,STATS)
	for part in Sets.modifiers(item,STATS):
		value += part.get("damage_add",0.0)*item.count
		value *= part.get("damage_factor",1.0)
	value = Conditions.damage_modifier(item,value,skill)
	if item.id == "magic_sword" and skill.critical: value *= CRITICAL_FACTOR
	if stats.has("damage_per_kill"): value *= 1.0+minf(stats.kill_damage_cap,stats.damage_per_kill*item.kills)
	if not skill.is_empty():
		if item.id == "cursed_skull": value *= 2.0 if 6 in (skill.source_dice if not skill.source_dice.is_empty() else skill.dice) else 0.5
		if model != null and skill.is_attack():
			if item.id == "light_sword" and model.living().size() == 1: value += 2.0
			if item.id == "alternating_gears" and model.relic_skills.alternates(skill): value *= 1.5
		if skill.is_attack() and not skill.hits_all():
			value *= pow(stats.get("single_target_factor_per_wave",1.0),item.get("waves",0))
	return value

## Same-family skill bonuses add, then multiply independently of general damage.
static func marble_factor(items: Array, skill: MultiHitSkill) -> float:
	var factor := 1.0
	if skill.pattern != "straight" or skill.dice.size() != 3: return factor
	for entry in Sequence.entries(items): factor += Sets.stats(entry.item,STATS).get("three_straight_bonus",0.0)
	return factor

## Describe ordered relic damage activations without consuming their effects.
static func attack_steps(items: Array, value: float, skill: MultiHitSkill, model = null) -> Array:
	var steps: Array = []

	for entry in Sequence.entries(items):
		var item: Dictionary = entry.item
		var slot: int = entry.slot
		var before: float = value
		value = apply_damage_modifier(item,value,skill,model)
		var stats: Dictionary = Sets.stats(item,STATS)
		var extra: String = ""
		var extra_values: Array = []
		if stats.get("base_factor",1.0) != 1.0: extra = "BASE DAMAGE"
		if stats.get("base_damage",0) != 0 or (skill.pattern == "match_auto" and stats.get("auto_damage",0) != 0):
			extra = "+%d BASE"
			extra_values = [stats.get("base_damage",0)+ (stats.get("auto_damage",0) if skill.pattern == "match_auto" else 0)]
		if skill.is_combo_attack() and (stats.has("combo_uses_factor") or stats.has("combo_uses_add") or stats.get("combo_uses_per_wave",0)*item.waves > 0):
			extra = "EXTRA HITS"
			extra_values.clear()
		if not is_equal_approx(before,value) or not extra.is_empty():
			steps.append({"source":"relic","id":entry.source,"slot":slot,"activators":entry.activators,"speed":Sequence.animation_speed(entry),"before":before,"after":value,"note":extra,"note_values":extra_values,"base_bonus":float(stats.get("base_damage",0.0)),"base_factor":float(stats.get("base_factor",1.0)),"auto_bonus":float(stats.get("auto_damage",0.0)) if skill.pattern == "match_auto" else 0.0})
	var marble: float = 1.0
	if skill.pattern == "straight" and skill.dice.size() == 3:
		for entry in Sequence.entries(items):
			var bonus: float = Sets.stats(entry.item,STATS).get("three_straight_bonus",0.0)
			if bonus <= 0: continue
			var before: float = value
			value *= (marble+bonus)/marble
			marble += bonus
			steps.append({"source":"relic","id":entry.source,"slot":entry.slot,"activators":entry.activators,"speed":Sequence.animation_speed(entry),"before":before,"after":value,"note":""})
	return steps

## Auto and relic attacks bypass the damage-build UI but still show contributing relics.
static func activate_damage_modifiers(model, skill: MultiHitSkill) -> void:
	var start: float = model.damage_baseline()+model.reward_damage_multiplier+(model.attack_multiplier()-1.0)
	for step in attack_steps(model.relics.items,start,skill,model):
		Sequence.activate_ids(model,step.activators,step.speed)

## Combine relic extra-hit rules with the skill’s existing use modifiers.
static func use_modifiers(items: Array, skill: MultiHitSkill, modifiers: Dictionary) -> Dictionary:
	var result: Dictionary = modifiers.duplicate()
	if not skill.is_combo_attack(): return result
	for entry in Sequence.entries(items):
		var item: Dictionary = entry.item
		var stats: Dictionary = Sets.stats(item,STATS)
		if stats.has("combo_uses_factor"): result[str(result.size())+":"+item.id] = stats.combo_uses_factor
		elif stats.has("combo_uses_add"): result[str(result.size())+":"+item.id] = {"add":stats.combo_uses_add}
		elif stats.has("combo_uses_per_wave"): result[str(result.size())+":"+item.id] = {"add":item.waves*stats.combo_uses_per_wave}
	return result

static func has_critical(items: Array) -> bool:
	return items.any(func(item): return item.id == "magic_sword" and item.charges > 0)

## Consume stored critical charges for one whole attack cast.
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

## Resolve ordered on-hit relic effects using actual damage dealt.
static func after_hit(model, target: int, damage: int, skill: MultiHitSkill) -> Array:
	var events: Array = []
	var extra_stacks: int = 0
	var runestones: Array = []
	var extra_burning: int = 0
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if item.id == "runestone": extra_stacks += 1; runestones.append(entry)
		if item.id == "pet_lizard": extra_burning += 4 if Sets.collection_complete(model.relics.items,"pets") else 2; runestones.append(entry)
		if item.id == "bloodstone":
			var cap: int = floori(model.max_hp*(0.05 if skill.is_combo_attack() or skill.pattern == "cleanup" else 0.1))
			var budget: String = str(entry.activators)
			var attempted: int = mini(maxi(0,cap-model.lifesteal_budgets.get(budget,0)),model.modified_healing(damage*0.2))
			var restored: int = model.heal(attempted,false)
			# Overhealing spends the same capped recovery budget as restored HP.
			model.lifesteal_budgets[budget] = model.lifesteal_budgets.get(budget,0)+(attempted if model.status_count(Status.DARKNESS) == 0 else 0)
			if restored > 0:
				model.lifesteal_used += restored
				events.append(model.event(-1,restored,"heal","LIFESTEAL"))
				Sequence.activate(model,entry)
		if not model.is_enemy_alive(target): continue
		var applied: Array = Conditions.after_hit(model,target,entry)
		if item.id == "pet_slime" and skill.pattern == "straight" and Sets.collection_complete(model.relics.items,"pets"):
			applied.append_array(model.apply_enemy_status(target,Status.CORROSION,1))
		if item.id == "prismatic_stone":
			for stone in Catalog.STONES: applied.append_array(_apply_stone(model,target,STONES[stone],extra_stacks,extra_burning))
		elif STONES.has(item.id): applied.append_array(_apply_stone(model,target,STONES[item.id],extra_stacks,extra_burning))
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

## Calculate relic protection and consumed charges for one incoming hit.
static func incoming(items: Array, amount: float, corroded: bool, burning: bool) -> Dictionary:
	var activated: Array = []
	if not corroded:
		for entry in Sequence.entries(items):
			var item: Dictionary = entry.item
			var before: float = amount
			amount *= Sets.stats(item,STATS).get("incoming_factor",1.0)
			if not is_equal_approx(amount,before): activated.append_array(entry.activators)
			if item.id == "magic_shield" and item.charges > 0 and not burning:
				item.charges -= 1
				activated.append_array(entry.activators)
				return {"amount":0.0,"blocked":true,"activated":activated}
	return {"amount":amount,"blocked":false,"activated":activated}

## Consume a qualifying survival relic when the player would die.
static func prevent_death(model) -> Array:
	var index: int = model.relics.index_of("contract")
	if index < 0: return []
	model.relic_activated.emit("contract")
	model.relics.remove(index)
	model.hp = maxi(1,roundi(model.max_hp*0.6))
	return [model.event(-1,model.hp,"relic","CONTRACT: REVIVED")]

## Generate turn-only tarot in inventory order, including explicit copy effects.
static func turn_started(model) -> Array:
	var events: Array = []
	for entry in repeat_sources(model.relics.items,"crystal_ball"):
		var cards: Array = model.grant_random_tarots(1,true)
		if not cards.is_empty():
			Sequence.activate(model,entry)
			events.append(model.event(-1,1,"relic","PROJECTION +1"))
	model.relic_skills.turn_started(model)
	return events

## Advance periodic relic counters and repeat their eligible payouts.
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
			if _grant_generator_tarot(model,item.id):
				Sequence.activate(model,entry)
				events.append(model.event(-1,1,"relic","TAROT +1"))
		elif TURN_CHARGES.has(item.id):
			item.charges += 1
			Sequence.activate(model,entry)
			events.append(model.event(-1,1,"relic",TURN_CHARGES[item.id].message))
	events.append_array(model.relic_recovery.full_turn_finished(model))
	events.append_array(Conditions.turn_finished(model))
	return events

static func enemy_killed(model) -> void:
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if Sets.stats(item,STATS).has("damage_per_kill"):
			if entry.origin == entry.slot: item.kills += 1
			Sequence.activate(model,entry)

## Apply wave-based relic growth and currency rewards.
static func wave_cleared(model) -> int:
	var rubies: int = 0
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		var stats: Dictionary = Sets.stats(item,STATS)
		rubies += stats.get("wave_rubies",0)
		if stats.has("combo_uses_per_wave") and entry.origin == entry.slot: item.waves += 1
		if stats.has("wave_rubies") or stats.has("combo_uses_per_wave"): Sequence.activate(model,entry)
	return rubies

## Apply ordered relic face changes while respecting Perfect and roll categories.
static func modify_dice(model, values: Array, perfect: bool, rates: Dictionary) -> Array:
	var six_chance: float = model._six_probability(rates)
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		var before: Array = values.duplicate()
		if item.id == "lucky_die":
			if 6 not in values and model.rng.randf() < minf(1,0.05/maxf(0.0001,1-six_chance)): values = _include_face(model,values,6)
			six_chance = minf(1.0,six_chance+0.05)
		elif Catalog.CURSED_DICE.has(item.id) and item.id != "cursed_die":
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
		var restored: int = model.heal(roundi(model.max_hp*(0.02 if Sets.collection_complete(model.relics.items,"pets") else 0.01)))
		if restored > 0:
			Sequence.activate(model,entry)
			events.append(model.event(-1,restored,"heal","HEALING"))
	return events

static func status_bonus(model, status: int) -> int:
	if status == Status.IMMOBILIZED: return 0
	var extra: int = 0
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		if item.id == "runestone" or (item.id == "pet_lizard" and status == Status.BURNING):
			extra += (4 if Sets.collection_complete(model.relics.items,"pets") else 2) if item.id == "pet_lizard" else 1
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
	if status == Status.BURNING: events.append_array(model.RelicCombat.burning_applied(model,target))
	if status == Status.PLAGUE: events.append_array(Conditions.plague_applied(model,target))
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
		var amount: float = Conditions.ROLL_DAMAGE.get(item.id,0)
		var fixed: bool = false
		var area: bool = false
		var count: int = 1
		match item.id:
			"worn_bow": amount = 5
			"tissue_pack":
				if not model.Patterns.has_combination(model.dice_turn.unused().map(func(i): return model.dice_turn.values[i])): amount = 10
			"magic_slingshot", "enchanted_missile":
				amount = model.dice_turn.unused().reduce(func(total,i): return total+model.dice_turn.values[i],0)*0.5
			"pet_ghost": amount = 20; fixed = true; area = true
			"pet_dragon": amount = 15; count = 3 if Sets.collection_complete(model.relics.items,"pets") else 2
			"spiked_helmet":
				if perfect: amount = 10
			"prismatic_stone":
				if perfect: amount = PERFECT_STRIKE_BASE
		if amount > 0:
			for i in range(count): actions.append({"id":item.id,"activation":entry,"amount":amount,"fixed":fixed,"area":area})
	return actions

## Roll-trigger relics no longer trigger a second time when a skill is formed.
static func formation_actions(_model, _skill: MultiHitSkill) -> Array:
	return []
