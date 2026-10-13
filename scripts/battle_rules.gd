extends RefCounted
## Deterministic battle model. Rendering and cosmetic randomness never alter it.
signal relic_activated(id: String)
const Weighted = preload("res://scripts/weighted_choice.gd")

const Skill = preload("res://scripts/multi_hit_skill.gd")
const Status = preload("res://scripts/status_effect.gd")
const Relics = preload("res://scripts/relic_inventory.gd")
const RelicEffects = preload("res://scripts/relic_effects.gd")
const AreaAttack = preload("res://scripts/area_attack.gd")
const TarotEffects = preload("res://scripts/tarot_effects.gd")
var tarot_effects = TarotEffects.new()
const DiceOdds = preload("res://scripts/dice_odds.gd")
const EnemyCatalog = preload("res://scripts/enemy_catalog.gd")
const EnemyActions = preload("res://scripts/enemy_actions.gd")
const Kind = Skill.Kind
const NORMAL_NAME = "Tentacle Swipe"
const PAIR_NAMES = ["Rending Blow", "Abyssal Frost", "Eldritch Might", "Sweeping Ruin", "Tentacle Flurry", "Beyond Harm"]
const PAIR_TEXT = ["1.5x regular attack + 1.5x spare die.", "Apply 1 Frozen stack to every enemy. No attack.", "+0.5 damage multiplier for the next spare-die attacks.", "Hit all: 2/3 regular attack + 1.5x spare die each.", "3 automatic random hits, each regular attack + 1.5x spare die.", "Invincible for spare-die enemy phases / roll intervals."]
const SPECIAL_NAMES = ["Death Sentence", "Abyssal Renewal", "Eldritch Ascension", "Worldbreaker", "Sixfold Ruin", "Annihilation"]
const SPECIAL_TEXT = ["Instantly kill your chosen foe, ignoring shield.", "Restore all missing health. No attack.", "+2.0 damage multiplier for the next 3 attacks.", "Hit every foe for 2x regular attack power.", "6 automatic random hits, each regular attack power.", "Destroy the squad. Heal 12 HP."]
const CITY_SPECIAL_TEXT = ["Hit the city for 5x regular attack power.", "Restore all missing health. No attack.", "+2.0 damage multiplier for the next 3 attacks.", "2x city attack; clear all troops.", "6 automatic city hits; each clears one troop.", "2000 base damage x DMG multiplier; clear troops; heal 12."]
const REGULAR_ATTACK_POWER = 15.0
const DAMAGE_PER_PIP = 1.5
const MAX_HP = 100
const SHIELD_CAP = 20
const DAMAGE_MULTIPLIER = 1.0
const NON_PERFECT_TRIPLE_CAP = 0.25
const NON_PERFECT_PAIR_CAP = 0.70

var rng = RandomNumberGenerator.new()
var dice_odds = DiceOdds.new()
var hp: int = MAX_HP
var base_max_hp: int = MAX_HP
var max_hp: int:
	get:
		var value: float = RelicEffects.max_health(relics.items,base_max_hp)
		return maxi(1, floori(value + 0.000001))
	set(value): base_max_hp = value
var relics = Relics.new()
var perfect_relic_ready: bool = false
var roll_relic_actions: Array = []
var active_relic_procs: Array = []
var relic_activation_speed: float = 1.0
var relic_turn_closed: bool = false
var turn_end_events: Array = []
var lifesteal_budgets: Dictionary = {}
var lifesteal_used: int = 0:
	set(value):
		lifesteal_used = value
		if value == 0: lifesteal_budgets.clear()
var power: float = 1.0
var reward_base_damage: float = 0.0
var reward_damage_multiplier: float = 0.0
var perfect_combo: int = 0
var shield: int = 0
var statuses: Dictionary = {}
var burn_ticks_remaining: int = 0
var ice_hits_remaining: int = 0
var enemies: Array = []
var round_number: int = 0
var pending: MultiHitSkill = Skill.new()
var saved_skill: MultiHitSkill = Skill.new()
var bonus_resume: Dictionary = {}
var buff_ticks: Dictionary = {}
# Future buffs/relics can add or remove named use multipliers without changing skills.
var skill_use_modifiers: Dictionary = {}
var phase: String = "new"
var category_weights: Array = [1.0, 1.0, 1.0] # normal, pair, triple; relic hooks
var pair_weights: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var triple_weights: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 0.7]
var face_weights: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	reset()

func reset() -> void:
	tarot_effects = TarotEffects.new()
	relics.clear()
	perfect_relic_ready = false
	roll_relic_actions.clear()
	active_relic_procs.clear()
	relic_activation_speed = 1.0
	relic_turn_closed = false
	turn_end_events.clear()
	hp = MAX_HP
	max_hp = MAX_HP
	power = 1.0
	reward_base_damage = 0
	reward_damage_multiplier = 0
	perfect_combo = 0
	shield = 0
	set_status_counts({2: 0, 3: 0, 6: 0, 33: 0})
	burn_ticks_remaining = 0
	ice_hits_remaining = 0
	enemies = [make_enemy(0), make_enemy(1), make_enemy(2)]
	for e in enemies:
		e["intent"] = {}
		e["canceled"] = false
		e["acted"] = false
	round_number = 0
	pending = Skill.new()
	saved_skill = Skill.new()
	bonus_resume = {}
	buff_ticks.clear()
	skill_use_modifiers.clear()
	phase = "new"
	category_weights = [1.0, 1.0, 1.0]
	pair_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	triple_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 0.7]
	face_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

static func make_enemy(role: int, health_scale: float = 1.0, elite: bool = false) -> Dictionary:
	return EnemyCatalog.make(role,health_scale,elite)

func set_status_counts(counts: Dictionary) -> void:
	statuses.clear()
	for id in Status.IDS:
		statuses[id] = Status.new(id)
		statuses[id].count = 0 if id == Status.PLAGUE else int(counts.get(id, 0))

func status_count(id: int) -> int:
	return statuses[id].count if statuses.has(id) else 0

func is_city() -> bool:
	return false

func relic_drop_weights() -> Array:
	return Relics.Drops.weights_for_wave(1)

func status_counts(ids: Array = Status.IDS) -> Dictionary:
	var counts: Dictionary = {}
	for id in ids: counts[id] = status_count(id)
	return counts

func is_frozen() -> bool:
	return status_count(Status.FROZEN) > 0

func is_stunned() -> bool:
	return status_count(Status.STUNNED) > 0

func apply_affliction(id: int, amount: int) -> Array:
	if hp <= 0 or (status_count(Status.IMMUNITY) > 0 and status_count(Status.CORROSION) == 0): return []
	if id not in Status.PLAYER_HARMFUL: return []
	var protector: String = RelicEffects.immunity_source(relics.items,id)
	if not protector.is_empty():
		relic_activated.emit(protector)
		return []
	var before: int = status_count(id)
	statuses[id].apply(amount)
	if id == Status.BURNING:
		amount = status_count(id) - before
		if amount <= 0: return []
	var applied := event(-1, amount, "status", status_label(id, amount))
	applied.status = id
	return [applied]

static func classify(dice: Array) -> MultiHitSkill:
	if dice.size() != 3: return Skill.new()
	var counts: Dictionary = {}
	for value in dice:
		if not value is int or value < 1 or value > 6: return Skill.new()
		counts[value] = counts.get(value, 0) + 1
	for face in counts:
		if counts[face] == 3:
			return Skill.new(Kind.ULTIMATE if face == 6 else Kind.SPECIAL, face, dice, 6 if face == 5 else 1)
	for face in counts:
		if counts[face] == 2:
			return Skill.new(Kind.PAIR, face, dice, 3 if face == 5 else 1)
	return Skill.new(Kind.NORMAL, 0, dice)

static func throw_rates(throw_power: float, perfect: bool = false, fever: bool = false) -> Dictionary:
	if perfect:
		if fever: return {"normal": 0.0, "pair": 0.0, "triple": 1.0}
		return {"normal": 0.0, "pair": 0.5, "triple": 0.5}
	var weight: float = pow(clampf(throw_power, 0, 1), 2)
	var triple: float = minf(NON_PERFECT_TRIPLE_CAP, lerpf(1.0 / 36.0, 0.5, weight))
	var match_rate: float = lerpf(4.0 / 9.0, 1.0, weight)
	var pair: float = match_rate - triple
	if fever:
		pair *= 1.5
		triple *= 1.5
		var total: float = pair + triple
		# Preserve the boosted category ratio when their combined chance exceeds 100%.
		if total > 1.0:
			pair /= total
			triple /= total
	# Apply the pair ceiling after fever normalization; overflow becomes singles.
	pair = minf(pair, NON_PERFECT_PAIR_CAP)
	return {"normal": maxf(0, 1.0 - pair - triple), "pair": pair, "triple": triple}

func roll_rates(throw_power: float, perfect: bool = false, fever: bool = false) -> Dictionary:
	var base: Dictionary = throw_rates(throw_power, perfect, fever)
	var values: Array = [base.normal, base.pair, base.triple]
	var total: float = 0
	for i in range(3):
		values[i] *= maxf(0, category_weights[i])
		total += values[i]
	if total <= 0: return RelicEffects.category_rates(relics.items,base,perfect and fever)
	var triple: float = values[2] / total
	if perfect:
		triple = minf(triple, 1.0 if fever else 0.5)
		return RelicEffects.category_rates(relics.items,{"normal":0.0, "pair":1.0-triple, "triple":triple},fever)
	triple = minf(triple, NON_PERFECT_TRIPLE_CAP * (1.5 if fever else 1.0))
	var pair: float = minf(values[1] / total, NON_PERFECT_PAIR_CAP)
	return RelicEffects.category_rates(relics.items,{"normal":maxf(0, 1.0-pair-triple), "pair":pair, "triple":triple})

func _weighted_face(weights: Array) -> int:
	var index: int = Weighted.pick(rng, weights)
	return index + 1 if index >= 0 else rng.randi_range(1, 6)

func _match_values(triple: bool) -> Array:
	var face: int = _weighted_face(triple_weights if triple else pair_weights)
	var values: Array = [face, face, face]
	if not triple:
		var spare_weights: Array = face_weights.duplicate()
		spare_weights[face-1] = 0.0
		var other: int = Weighted.pick(rng, spare_weights)
		if other < 0: other = (face % 6)
		values[rng.randi_range(0, 2)] = other + 1
	return values

func roll(throw_power: float = 0.0, perfect: bool = false, fever: bool = false) -> MultiHitSkill:
	if phase != "roll": return Skill.new()
	perfect = perfect or forces_perfect()
	var rates: Dictionary = roll_rates(throw_power, perfect, fever)
	var category: int = Weighted.pick(rng, [rates.normal, rates.pair, rates.triple])
	var values: Array = []
	if category > 0:
		values = _match_values(category == 2)
	else:
		var weights: Array = face_weights.duplicate()
		for i in range(3):
			var index: int = Weighted.pick(rng, weights)
			if index < 0:
				for j in range(6): weights[j] = 0.0 if j+1 in values else 1.0
				index = Weighted.pick(rng, weights)
			values.append(index+1)
			weights[index] = 0.0
	pending = classify(tarot_effects.modify_dice(self,RelicEffects.modify_dice(self,values,perfect,rates)))
	pending.perfect = perfect
	record_perfect(perfect)
	statuses[Status.STUNNED].consume()
	phase = "player"
	return pending.duplicate(true)

func set_test_roll(dice: Array, perfect: bool = false) -> MultiHitSkill:
	# Only called by tests or the visual debug picker; overrides power odds.
	if phase != "roll" or classify(dice).is_empty():
		return Skill.new()
	perfect = perfect or forces_perfect()
	var result := classify(tarot_effects.modify_dice(self,RelicEffects.modify_dice(self,dice.duplicate(),perfect,throw_rates(0,perfect))))
	if result.is_empty():
		return Skill.new()
	pending = result
	pending.perfect = perfect
	record_perfect(perfect)
	statuses[Status.STUNNED].consume()
	phase = "player"
	return pending.duplicate(true)

func record_perfect(perfect: bool) -> void:
	# Only accepted throws change the streak; skips and bonus casts preserve it.
	perfect_combo = perfect_combo + RelicEffects.perfect_combo_gain(relics.items) if perfect else 0
	roll_relic_actions = RelicEffects.roll_actions(self,perfect)
	perfect_relic_ready = not roll_relic_actions.is_empty()
	if perfect:
		for item in relics.items:
			if RelicEffects.STATS.get(item.id,{}).get("always_perfect",false) or RelicEffects.STONES.get(item.id,{}).get("combo_gain",0) > 0:
				relic_activated.emit(item.id)

func forces_perfect() -> bool:
	return tarot_effects.star_throws > 0 or RelicEffects.has_flag(relics.items,"always_perfect")

func combo_multiplier() -> float:
	return 1.0 + perfect_combo * 0.1

func is_enemy_alive(index: int) -> bool:
	return index >= 0 and index < enemies.size() and enemies[index].hp > 0

func has_living_enemies() -> bool:
	for enemy in enemies:
		if enemy.hp > 0: return true
	return false

func living() -> Array:
	var result: Array = []
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			result.append(i)
	return result

func has_pending_attack_hits() -> bool:
	return phase == "executing" and pending.is_attack() and pending.uses_left() > 0

func taunting_enemies() -> Array:
	var targets: Array = living()
	return targets.filter(func(i): return EnemyCatalog.taunts(enemies[i])) if targets.size() > 1 else []

func attack_targets() -> Array:
	var guards: Array = taunting_enemies()
	return guards if not guards.is_empty() else living()

func area_damage_factor(target: int, guards: Array) -> float:
	return 0.5 if not guards.is_empty() and target not in guards else 1.0

func player_attack_targets() -> Array:
	var targets: Array = attack_targets()
	# Only an already-started cast can follow through on the defeated squad.
	if targets.is_empty() and has_pending_attack_hits(): return range(enemies.size())
	return targets

func outcome() -> String:
	if hp <= 0:
		return "defeat"
	if not has_living_enemies() and not has_pending_attack_hits():
		return "victory"
	return ""

func begin_round() -> Array:
	if not outcome().is_empty() or phase not in ["new", "round_end"]:
		return []
	tarot_effects.begin_round()
	round_number += 1
	relic_turn_closed = false
	var events: Array = []
	if statuses[2].count > 0:
		var healed := heal(roundi(5*statuses[2].potency))
		buff_ticks[2] = true
		events.append(event(-1, healed, "heal", "Regrowth +%d" % healed))
	for i in living():
		enemies[i].canceled = false
		enemies[i].acted = false
		enemies[i].action_hit = 0
		enemies[i].intent = choose_intent(i)
	_prepare_player_turn()
	return events

func _prepare_player_turn() -> void:
	if is_frozen(): tarot_effects.extra_rolls = 0
	phase = "frozen" if is_frozen() else "roll"
	ice_hits_remaining = 3 if is_frozen() else 0

func break_ice() -> Array:
	if phase != "frozen" or not is_frozen() or not outcome().is_empty() or ice_hits_remaining <= 0: return []
	ice_hits_remaining -= 1
	if ice_hits_remaining == 0: return skip_frozen_turn()
	return [event(-1, ice_hits_remaining, "ice_crack", "CRACK")]

func skip_frozen_turn() -> Array:
	if phase != "frozen" or not is_frozen() or not outcome().is_empty() or ice_hits_remaining > 0: return []
	statuses[Status.FROZEN].consume()
	_finish_player_action(Skill.new(Kind.NORMAL))
	return [event(-1, 0, "skip", "TURN SKIPPED")]

func choose_intent(index: int) -> Dictionary:
	return EnemyActions.choose(self,index)

func damage_cap(kind: int, target: int) -> int:
	var max_hp: int = enemies[target].max_hp
	return maxi(1, floori(float(max_hp) * (2.0 / 3.0 if kind == Kind.SPECIAL else 1.0 / 3.0)))

static func is_attack(result: MultiHitSkill) -> bool:
	return result.is_attack()

func set_skill_use_multiplier(source: String, multiplier: int) -> void:
	if multiplier <= 1: skill_use_modifiers.erase(source)
	else: skill_use_modifiers[source] = multiplier

func skill_use_count(skill: MultiHitSkill) -> int:
	return skill.use_count(skill_modifiers_for(skill))

func skill_modifiers_for(skill: MultiHitSkill) -> Dictionary:
	var modifiers: Dictionary = RelicEffects.use_modifiers(relics.items,skill,skill_use_modifiers)
	if skill.is_attack() and not is_instant_kill(skill) and tarot_effects.extra_uses > 0: modifiers["high_priestess"] = {"add":tarot_effects.extra_uses}
	return modifiers

func begin_player_cast() -> bool:
	if phase != "player" or pending.is_empty() or not outcome().is_empty(): return false
	pending.begin_cast(skill_modifiers_for(pending))
	if pending.is_attack() and not is_instant_kill(pending): tarot_effects.extra_uses = 0
	tarot_effects.begin_skill(pending)
	if pending.is_attack(): statuses[Status.HIDDEN].count = 0
	if is_attack(pending) and RelicEffects.begin_attack(relics.items): pending.critical = true
	phase = "executing"
	return true

static func hits_all(result: MultiHitSkill) -> bool:
	return result.hits_all()

func attack_multiplier() -> float:
	return 1.0 + (0.5*statuses[3].potency if statuses[3].count > 0 else 0.0) + (2.0*statuses[33].potency if statuses[33].count > 0 else 0.0)

func boon_turns(face: int) -> int:
	return (statuses[33].count if statuses[33].count > 0 else statuses[3].count) if face == 3 else int(status_count(face))

func attack_base(result: MultiHitSkill) -> float:
	return attack_base_with_bonus(result,relic_base_damage())*tarot_effects.skill_factor(result)

func regular_base_damage() -> float:
	return REGULAR_ATTACK_POWER + reward_base_damage * DAMAGE_PER_PIP

func attack_base_with_bonus(result: MultiHitSkill, bonus: float) -> float:
	if result.kind == Kind.NORMAL: return (result.sum + reward_base_damage) * DAMAGE_PER_PIP + bonus
	var amount: float = regular_base_damage() + bonus
	if result.kind == Kind.PAIR:
		if result.face == 1: amount *= 1.5
		elif result.face == 4: amount *= 2.0 / 3.0
		amount += result.spare * DAMAGE_PER_PIP
	elif result.kind == Kind.SPECIAL and result.face == 4:
		amount *= 2.0
	return amount

func regular_attack_power() -> float:
	return regular_base_damage() + relic_base_damage()

func relic_base_damage() -> float:
	return RelicEffects.base_damage(relics.items)

func damage_baseline() -> float:
	return DAMAGE_MULTIPLIER * power

func damage_multiplier(result: MultiHitSkill = null) -> float:
	# One multiplier: additive rewards, both active boons, and the Perfect streak.
	var value: float = damage_baseline() + reward_damage_multiplier + (attack_multiplier() - 1.0) + perfect_combo * 0.1
	var skill: MultiHitSkill = pending if result == null else result
	value = RelicEffects.damage_multiplier(relics.items,value,skill)
	if status_count(Status.DARKNESS) > 0: value *= 0.5
	return value

func attack_damage_steps(result: MultiHitSkill) -> Array:
	# Read-only trace of the same formula used by hits. Never consumes charges/RNG.
	if not is_attack(result) or is_instant_kill(result): return []
	var base: float = attack_base_with_bonus(result,0)
	var steps: Array = [{"source":"skill","id":"","slot":-1,"before":1.0,"after":1.0,"base_before":regular_base_damage(),"base_after":base,"note":""}]
	var value: float = 1.0
	var bonuses: Array = [
		{"source":"baseline","amount":damage_baseline()-1.0},
		{"source":"treasure","amount":reward_damage_multiplier},
		{"source":"boon","amount":attack_multiplier()-1.0},
		{"source":"combo","amount":perfect_combo*0.1},
	]
	for bonus in bonuses:
		if is_zero_approx(bonus.amount): continue
		steps.append({"source":bonus.source,"id":"","slot":-1,"before":value,"after":value+bonus.amount,"note":""})
		value += bonus.amount
	var relic_steps: Array = RelicEffects.attack_steps(relics.items,value,result)
	steps.append_array(relic_steps)
	if not relic_steps.is_empty(): value = relic_steps.back().after
	if status_count(Status.DARKNESS) > 0:
		steps.append({"source":"darkness","id":"","slot":-1,"before":value,"after":value*0.5,"note":""})
	if status_count(Status.DARKNESS) > 0: value *= 0.5
	var strength_factor: float = tarot_effects.skill_factor(result)
	var base_bonus: float = 0
	for step in steps:
		if step.source == "skill": continue
		step.base_before = base
		base_bonus += step.get("base_bonus",0.0)
		base = attack_base_with_bonus(result,base_bonus)
		step.base_after = base
		if not is_equal_approx(step.base_before,base):
			step.note = "+%s BASE"
			step.note_values = [str(snappedf(base-step.base_before,0.01))]
	var strength_base: float = base
	for i in range(roundi(strength_factor)-1):
		steps.append({"source":"tarot","id":"","slot":-1,"before":value,"after":value,"base_before":base,"base_after":base+strength_base,"note":"STRENGTH"})
		base += strength_base
	return steps

func cast_damage_multiplier(result: MultiHitSkill) -> float:
	return damage_multiplier(result)*(RelicEffects.CRITICAL_FACTOR if result.critical else 1.0)

func is_instant_kill(result: MultiHitSkill) -> bool:
	return result.kind == Kind.ULTIMATE or (result.kind == Kind.SPECIAL and result.face == 1)

func unmitigated_damage(result: MultiHitSkill) -> int:
	var critical: bool = result.critical or (phase != "executing" and RelicEffects.has_critical(relics.items))
	return floori(attack_base(result)*damage_multiplier(result)*(RelicEffects.CRITICAL_FACTOR if critical else 1.0)+0.000001)

func _target_damage(result: MultiHitSkill, damage: int, target: int) -> int:
	if result.kind == Kind.NORMAL and is_enemy_alive(target): damage = mini(damage,damage_cap(result.kind,target))
	if enemy_status_count(target,Status.CORROSION) > 0: damage = floori(damage*1.5)
	return damage

func attack_damage(result: MultiHitSkill, target: int = -1) -> int:
	return _target_damage(result,unmitigated_damage(result),target)

func damage_caption(result: MultiHitSkill, primary: int = -1) -> String:
	if not is_attack(result) or is_instant_kill(result): return ""
	var base: int = floori(attack_base(result))
	var damage: int = unmitigated_damage(result)
	var targets: Array = living() if hits_all(result) else [primary] if primary in attack_targets() else attack_targets()
	var guards: Array = taunting_enemies()
	if targets.is_empty(): return ""
	var low: int = floori(_target_damage(result,damage,targets[0])*(area_damage_factor(targets[0],guards) if hits_all(result) else 1.0))-base
	var high: int = low
	for target in targets:
		var modifier: int = floori(_target_damage(result,damage,target)*(area_damage_factor(target,guards) if hits_all(result) else 1.0))-base
		low = mini(low,modifier)
		high = maxi(high,modifier)
	var modifier: String = str(low) if low == high else "%d to %d" % [low,high]
	if low < 0 or low != high: modifier = "("+modifier+")"
	return "%d + %s (x%d)" % [base,modifier,skill_use_count(result)]

func player_target() -> int:
	if phase not in ["player", "executing"] or not is_attack(pending) or not outcome().is_empty(): return -1
	var candidates: Array = player_attack_targets()
	if pending.target not in candidates:
		if candidates.is_empty(): return -1
		pending.target = candidates[rng.randi_range(0, candidates.size() - 1)]
	return pending.target

func preview(result: MultiHitSkill, primary: int) -> Array:
	# Preview one impact, without drawing RNG or consuming resources.
	var hits: Array = []
	var candidates: Array = player_attack_targets()
	if not is_attack(result) or primary not in candidates: return hits
	var targets: Array = (living() if has_living_enemies() else candidates) if hits_all(result) else [primary]
	var guards: Array = taunting_enemies()
	for i in targets:
		var execute: bool = is_instant_kill(result)
		var damage: int = enemies[i].hp if execute else attack_damage(result, i)
		if not execute and hits_all(result): damage = floori(damage*area_damage_factor(i,guards))
		var hp_loss: int = 0 if enemies[i].shield > 0 and not execute and enemy_status_count(i, Status.CORROSION) == 0 else mini(enemies[i].hp, damage)
		hits.append({"target": i, "damage": damage, "ignore": execute, "hp_loss": hp_loss, "corpse_hit": not is_enemy_alive(i)})
	return hits

func _apply_support(result: MultiHitSkill) -> Array:
	var events: Array = []
	if result.is_freeze():
		if is_city(): return [event(-2,0,"immune","IMMUNE")]
		var stacks: int = roundi(tarot_effects.skill_factor(result))
		for target in living():
			events.append_array(apply_enemy_status(target,Status.FROZEN,enemy_status_count(target,Status.FROZEN)+stacks))
		return events
	var id: int = result.face if result.kind == Kind.PAIR else Status.ASCENSION
	if result.kind == Kind.SPECIAL and result.face == 2:
		return [event(-1, heal(max_hp), "heal", "FULL HEAL")]
	if id in Status.ATTACK_BOONS and status_count(id) > 0:
		events.append_array(_boon_shockwave(result,10.0 if id == Status.MIGHT else 50.0))
	if result.kind == Kind.PAIR:
		var duration: int = result.spare + (status_count(id) if id == Status.IMMUNITY else 0)
		statuses[id].apply(duration,tarot_effects.skill_factor(result))
		buff_ticks.erase(result.face)
		events.append(event(-1, 0, "buff", PAIR_NAMES[result.face - 1]))
	else:
		statuses[Status.ASCENSION].apply(3,tarot_effects.skill_factor(result))
		events.append(event(-1, 0, "buff", SPECIAL_NAMES[2]))
	return events

func _boon_shockwave(result: MultiHitSkill, base_damage: float) -> Array:
	var wave := Skill.new(Kind.SPECIAL,4,result.dice)
	wave.amplifier_locked = true
	var events: Array = [event(-1,int(base_damage),"boon_wave","")]
	events.append_array(AreaAttack.apply(self,base_damage,wave))
	return events

func _finish_player_action(_result: MultiHitSkill) -> void:
	if not bonus_resume.is_empty():
		# A banked skill is a bonus: preserve the current roll and its turn clocks.
		var resume: Dictionary = bonus_resume
		bonus_resume = {}
		if outcome() == "wave_clear" and not resume.pending.is_empty():
			# Carry the unspent summoned skill into the next wave without casting it.
			saved_skill = resume.pending.duplicate(true)
			saved_skill.target = -1
		pending = resume.pending if outcome().is_empty() else Skill.new()
		phase = resume.phase if outcome().is_empty() else "finished"
		return
	if tarot_effects.extra_rolls > 0 and outcome().is_empty():
		tarot_effects.extra_rolls -= 1
		pending = Skill.new()
		phase = "roll"
		return
	# Invulnerability remains active through every enemy action.
	buff_ticks[6] = true
	pending = Skill.new()
	phase = "enemy" if outcome().is_empty() else "finished"
	if phase == "finished": _end_buff_turn()

func _end_buff_turn() -> void:
	for face in buff_ticks: statuses[face].consume()
	buff_ticks.clear()

func save_pending_skill() -> bool:
	if phase != "player" or pending.is_empty() or not saved_skill.is_empty() or not bonus_resume.is_empty() or not outcome().is_empty(): return false
	saved_skill = pending.duplicate(true)
	saved_skill.target = -1
	# Banking passes the turn; it does not apply or refresh the stored boon.
	_finish_player_action(Skill.new(Kind.NORMAL))
	return true

func begin_saved_cast() -> bool:
	if saved_skill.is_empty() or not bonus_resume.is_empty() or phase not in ["roll", "player", "round_end"] or not outcome().is_empty(): return false
	bonus_resume = {"phase": phase, "pending": pending.duplicate(true)}
	pending = saved_skill.duplicate(true)
	saved_skill = Skill.new()
	phase = "player"
	return true

func apply_player_step(primary: int = -1) -> Array:
	if phase not in ["player", "executing"] or pending.is_empty() or not outcome().is_empty(): return []
	if is_attack(pending):
		if primary < 0: primary = player_target()
		if primary not in player_attack_targets(): return []
		pending.target = primary
	if phase == "player": begin_player_cast()
	var result: MultiHitSkill = pending.duplicate()
	var events: Array = []
	if not is_attack(result): events = _apply_support(result)
	else:
		lifesteal_used = 0
		for hit in preview(result, primary):
			if hit.corpse_hit:
				var follow_through: Dictionary = damage_event(hit.target,0,hit.damage,"damage",hit.ignore)
				follow_through.corpse_hit = true
				events.append(follow_through)
				continue
			var previous_shield: int = enemies[hit.target].shield
			var loss: int = hit_enemy(hit.target, hit.damage, hit.ignore)
			if previous_shield > 0 and not hit.ignore and enemy_status_count(hit.target,Status.CORROSION) == 0:
				var blocked: Dictionary = damage_event(hit.target,previous_shield-enemies[hit.target].shield,hit.damage,"shield_hit")
				blocked.text = "SHIELD BREAK" if enemies[hit.target].shield == 0 else "BLOCKED"
				events.append(blocked)
			else:
				events.append(damage_event(hit.target,loss,hit.damage,"damage",hit.ignore))
			if loss > 0:
				events.append_array(_attack_relic_effects(hit.target, loss, result))
	if result.is_attack(): events.append_array(RelicEffects.attack_used(self))
	_complete_skill_use(result, events)
	return events

func _complete_skill_use(result: MultiHitSkill, events: Array) -> void:
	if result.kind == Kind.ULTIMATE: events.append(event(-1, heal(roundi(12*tarot_effects.skill_factor(result))), "heal", "+12 HP"))
	pending.consume_use()
	if pending.random_target_per_use(): pending.target = -1
	if pending.uses_left() == 0 or not outcome().is_empty():
		# One charge covers the whole cast, including every multi-hit impact.
		# Saving, skipping and immediate item effects never pass through here.
		if result.is_attack():
			for id in Status.ATTACK_BOONS: statuses[id].consume()
		_finish_player_action(result)
		if not outcome().is_empty(): events.append_array(_complete_relic_turn())

func apply_player(primary: int = -1) -> Array:
	var events: Array = []
	var bonus: bool = not bonus_resume.is_empty()
	while phase in ["player", "executing"] and not pending.is_empty() and outcome().is_empty():
		var step: Array = apply_player_step(primary)
		if step.is_empty(): break
		events.append_array(step)
		if bonus and bonus_resume.is_empty(): break
		primary = -1
	return events

func hit_enemy(index: int, damage: int, ignore: bool = false) -> int:
	var e: Dictionary = enemies[index]
	if not ignore and e.shield > 0 and enemy_status_count(index, Status.CORROSION) == 0:
		e.shield = maxi(0, e.shield-maxi(0, damage))
		if e.shield == 0: apply_enemy_status(index,Status.IMMOBILIZED,1)
		return 0 # A single hit can break a shield, but never spill into HP.
	if ignore: e.shield = 0
	var actual: int = mini(e.hp, damage)
	e.hp -= actual
	if actual > 0 and e.hp <= 0: RelicEffects.enemy_killed(self)
	return actual

func heal(amount: int) -> int:
	if status_count(Status.DARKNESS) > 0: return 0
	var actual: int = maxi(0, mini(max_hp - hp, amount))
	hp += actual
	return actual

func enemy_act_step(index: int) -> Array:
	if phase != "enemy" or not outcome().is_empty() or not is_enemy_alive(index) or enemies[index].acted: return []
	var events: Array = EnemyActions.step(self,index)
	if not outcome().is_empty(): phase = "finished"
	return events

func enemy_act(index: int) -> Array:
	# Model callers can resolve a whole action; the UI plays individual impacts.
	var events: Array = []
	while phase == "enemy" and outcome().is_empty() and is_enemy_alive(index) and not enemies[index].acted:
		events.append_array(enemy_act_step(index))
	return events

func _begin_turn_end() -> void:
	burn_ticks_remaining = status_count(Status.BURNING)
	turn_end_events = _tick_enemy_statuses()
	phase = "turn_end"
	if burn_ticks_remaining == 0 and turn_end_events.is_empty():
		_finish_turn_end()
		turn_end_events.append_array(_complete_relic_turn())

func _finish_turn_end() -> void:
	statuses[Status.BURNING].consume()
	statuses[Status.DARKNESS].consume()
	statuses[Status.CORROSION].consume()
	_end_buff_turn()
	phase = "round_end" if outcome().is_empty() else "finished"

func end_round_step() -> Array:
	# Presentation calls once per burn tick; headless simulation uses end_round().
	if phase == "enemy":
		if living().any(func(i): return not enemies[i].acted): return []
		_begin_turn_end()
	if phase != "turn_end":
		var completed: Array = turn_end_events.duplicate()
		turn_end_events.clear()
		return completed
	var events: Array = []
	events.append_array(turn_end_events)
	turn_end_events.clear()
	if burn_ticks_remaining > 0:
		burn_ticks_remaining -= 1
		if hp > 0: events.append_array(receive_damage(5, true))
	if burn_ticks_remaining == 0 or hp <= 0:
		burn_ticks_remaining = 0
		_finish_turn_end()
		events.append_array(_complete_relic_turn())
	return events

func relic_immune(id: int) -> bool:
	return RelicEffects.immune(relics.items,id)

func acquire_relic(id: String, replace_index: int = -1) -> bool:
	var old_max: int = max_hp
	if not relics.add(id, replace_index): return false
	refresh_relic_health(old_max)
	RelicEffects.acquired(self,id)
	return true

func move_relic(from: int, to: int) -> bool:
	if not relics.move(from,to): return false
	# Reordering passive health bonuses changes capacity, never grants free healing.
	hp = mini(hp,max_hp)
	return true

func grant_random_tarots(_count: int) -> Array:
	# Standalone battles have no run inventory; RunRules owns consumable rewards.
	return []

func refresh_relic_health(old_max: int) -> void:
	for status in Status.HARMFUL:
		if relic_immune(status): statuses[status].count = 0
	hp = clampi(hp + maxi(0, max_hp - old_max), 0, max_hp)

func receive_damage(amount: int, burning: bool = false, attacker: int = -1) -> Array:
	if not burning and status_count(Status.HIDDEN) > 0: return [event(-1,0,"relic","UNTARGETABLE")]
	var corroded: bool = status_count(Status.CORROSION) > 0
	if status_count(Status.IMMUNITY) > 0 and not corroded: return [event(-1,0,"immune","INVINCIBLE")] + (RelicEffects.retaliation(self,attacker) if not burning else [])
	var incoming: float = maxf(0, amount) * (1.5 if corroded else 1.0)
	var defense: Dictionary = RelicEffects.incoming(relics.items,incoming,corroded,burning)
	for id in defense.activated: relic_activated.emit(id)
	if defense.blocked: return [event(-1,0,"relic","SHIELD BLOCK")] + RelicEffects.retaliation(self,attacker)
	incoming = defense.amount
	var loss: int = roundi(incoming)
	if not corroded and not burning:
		var blocked: int = mini(shield, loss)
		shield -= blocked
		loss -= blocked
	var hit_damage: int = loss
	loss = mini(hp, loss)
	hp -= loss
	var events: Array = [damage_event(-1,loss,hit_damage,"burn" if burning else "damage")]
	if hp <= 0: events.append_array(RelicEffects.prevent_death(self))
	if not burning: events.append_array(RelicEffects.retaliation(self,attacker))
	return events

func _complete_relic_turn() -> Array:
	if relic_turn_closed: return []
	relic_turn_closed = true
	tarot_effects.end_round()
	statuses[Status.HIDDEN].consume()
	return RelicEffects.turn_finished(self)

static func status_label(id: int, amount: int) -> String:
	return "%s +%d" % [{Status.FROZEN:"FROZEN",Status.BURNING:"BURN",Status.STUNNED:"STUN",Status.DARKNESS:"DARKNESS",Status.CORROSION:"CORROSION",Status.PLAGUE:"PLAGUE",Status.IMMOBILIZED:"IMMOBILIZED"}.get(id,"STATUS"), amount]

func enemy_cannot_act(index: int) -> bool:
	return Status.ENEMY_ACTION_LOCKS.any(func(id): return enemy_status_count(index,id) > 0)

func enemy_status_count(index: int, id: int) -> int:
	if index < 0 or index >= enemies.size(): return 0
	var effects: Dictionary = enemies[index].get("statuses", {})
	return effects[id].count if effects.has(id) else 0

func apply_enemy_status(index: int, id: int, amount: int, modify_stacks: bool = true) -> Array:
	if not is_enemy_alive(index) or id not in Status.ENEMY_HARMFUL: return []
	if modify_stacks: amount += RelicEffects.status_bonus(self,id)
	var enemy: Dictionary = enemies[index]
	if not enemy.has("statuses"): enemy.statuses = {}
	if not enemy.statuses.has(id): enemy.statuses[id] = Status.new(id)
	var before: int = enemy.statuses[id].count
	enemy.statuses[id].apply(amount)
	if id in Status.ENEMY_ACTION_LOCKS and amount > 0: EnemyActions.interrupt(enemy)
	var added: int = enemy.statuses[id].count - before
	if added <= 0: return RelicEffects.status_applied(self,index,id) if amount > 0 else []
	if id == Status.PLAGUE:
		if not enemy.has("healthy_max_hp"): enemy.healthy_max_hp = enemy.max_hp
		enemy.max_hp = maxi(1, enemy.healthy_max_hp - enemy.statuses[id].count * 10)
		enemy.hp = mini(enemy.hp, enemy.max_hp)
	var effect: Dictionary = event(index, added, "status", status_label(id, added))
	effect.status = id
	return [effect] + RelicEffects.status_applied(self,index,id)

func _attack_relic_effects(target: int, damage: int, skill: MultiHitSkill) -> Array:
	return RelicEffects.after_hit(self,target,damage,skill)

func _tick_enemy_statuses() -> Array:
	var events: Array = []
	# Snapshot infections so a newly infected ally cannot spread again this turn.
	var infected: Array = living().filter(func(i): return enemy_status_count(i,Status.PLAGUE) > 0)
	for i in living():
		var burning: int = enemy_status_count(i,Status.BURNING)
		if burning > 0:
			var amount: int = roundi(burning * 5 * (1.5 if enemy_status_count(i,Status.CORROSION) > 0 else 1.0))
			var shield_before: int = enemies[i].shield
			var loss: int = hit_enemy(i,amount,true)
			enemies[i].shield = shield_before
			events.append(damage_event(i,loss,amount,"burn"))
		for id in [Status.BURNING,Status.DARKNESS,Status.CORROSION]:
			if enemy_status_count(i,id) > 0: enemies[i].statuses[id].consume()
	for i in infected:
		if not is_enemy_alive(i): continue
		events.append_array(apply_enemy_status(i,Status.PLAGUE,1,false))
		var allies: Array = living().filter(func(ally): return ally != i and enemy_status_count(ally,Status.PLAGUE) == 0)
		if not allies.is_empty(): events.append_array(apply_enemy_status(allies[rng.randi_range(0,allies.size()-1)],Status.PLAGUE,1,false))
	return events

func roll_relic_animation_speed() -> float:
	return RelicEffects.Sequence.animation_speed(roll_relic_actions[0].activation) if not roll_relic_actions.is_empty() else 1.0

func resolve_roll_relic_step() -> Array:
	if roll_relic_actions.is_empty():
		perfect_relic_ready = false
		return []
	if not outcome().is_empty():
		roll_relic_actions.clear()
		perfect_relic_ready = false
		return []
	var action: Dictionary = roll_relic_actions.pop_front()
	RelicEffects.Sequence.activate(self,action.activation)
	var events: Array = RelicEffects.Attack.apply(self,action.id,action.amount,action.fixed,action.area)
	perfect_relic_ready = not roll_relic_actions.is_empty()
	if not outcome().is_empty():
		roll_relic_actions.clear()
		perfect_relic_ready = false
		if not is_city() and saved_skill.is_empty(): saved_skill = pending.duplicate()
		pending = Skill.new()
		phase = "finished"
		events.append_array(_complete_relic_turn())
	return events

func resolve_perfect_relic() -> Array:
	# Compatibility for model simulations; presentation resolves one proc at a time.
	if perfect_relic_ready and roll_relic_actions.is_empty(): roll_relic_actions = RelicEffects.roll_actions(self,true)
	var events: Array = []
	while not roll_relic_actions.is_empty(): events.append_array(resolve_roll_relic_step())
	return events

func _six_probability(rates: Dictionary) -> float:
	return dice_odds.six_probability(rates,triple_weights,pair_weights,face_weights)

func end_round() -> Array:
	var events: Array = []
	while phase in ["enemy", "turn_end"]:
		if phase == "enemy" and living().any(func(i): return not enemies[i].acted): break
		events.append_array(end_round_step())
	return events

static func event(target: int, amount: int, type: String, text: String) -> Dictionary:
	return {"target": target, "amount": amount, "type": type, "text": text}

static func damage_event(target: int, actual_loss: int, hit_damage: int, type: String = "damage", instant_kill: bool = false) -> Dictionary:
	# Gameplay consumers retain actual HP/shield loss; presentation shows the hit
	# before remaining-health clamping. An execution has impact FX but no number.
	var result: Dictionary = event(target,actual_loss,type,"" if instant_kill else "-%d" % hit_damage)
	result.display_amount = hit_damage
	result.instant_kill = instant_kill
	return result
