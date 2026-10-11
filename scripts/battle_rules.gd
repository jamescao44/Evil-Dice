extends RefCounted
## Deterministic battle model. Rendering and cosmetic randomness never alter it.
signal relic_activated(id: String)
const Weighted = preload("res://scripts/weighted_choice.gd")

const Skill = preload("res://scripts/multi_hit_skill.gd")
const Status = preload("res://scripts/status_effect.gd")
const Relics = preload("res://scripts/relic_inventory.gd")
const RelicEffects = preload("res://scripts/relic_effects.gd")
const DiceOdds = preload("res://scripts/dice_odds.gd")
const ELITE_CONTROL_CHANCE := 0.5
const Kind = Skill.Kind
const NORMAL_NAME = "Tentacle Swipe"
const PAIR_NAMES = ["Rending Blow", "Unnatural Regrowth", "Eldritch Might", "Sweeping Ruin", "Tentacle Flurry", "Beyond Harm"]
const PAIR_TEXT = ["1.5x regular attack + 1.5x spare die.", "Heal 5 at the next spare-die turn starts.", "+0.5 damage multiplier for the next spare-die turns.", "Hit all: 2/3 regular attack + 1.5x spare die each.", "3 automatic random hits, each regular attack + 1.5x spare die.", "Invincible for spare-die enemy phases / roll intervals."]
const SPECIAL_NAMES = ["Death Sentence", "Abyssal Renewal", "Eldritch Ascension", "Worldbreaker", "Sixfold Ruin", "Annihilation"]
const SPECIAL_TEXT = ["Instantly kill your chosen foe, ignoring shield.", "Restore all missing health. No attack.", "+2.0 damage multiplier for the next 3 turns.", "Hit every foe for 2x regular attack power.", "6 automatic random hits, each regular attack power.", "Destroy the squad. Heal 12 HP."]
const CITY_SPECIAL_TEXT = ["Hit the city for 5x regular attack power.", "Restore all missing health. No attack.", "+2.0 damage multiplier for the next 3 rolls.", "2x city attack; clear all troops.", "6 automatic city hits; each clears one troop.", "2000 base damage x DMG multiplier; clear troops; heal 12."]
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
		return maxi(1, floori(value + 0.000001) - status_count(Status.PLAGUE) * 10)
	set(value): base_max_hp = value
var relics = Relics.new()
var perfect_relic_ready: bool = false
var relic_turn_closed: bool = false
var turn_end_events: Array = []
var lifesteal_used: int = 0
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
	relics.clear()
	perfect_relic_ready = false
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
	# Keep exact half-HP thresholds stable despite decimal scale rounding.
	var health: int = roundi(([150, 100, 75] if elite else [75, 50, 35])[role] * health_scale + 0.0001)
	return {"name": ("Elite " if elite else "") + ["Vanguard", "Elf Archer", "Mage"][role], "role": role, "elite": elite, "attribute": [Status.Attribute.SHOCK, Status.Attribute.ICE, Status.Attribute.FIRE][role] if elite else Status.Attribute.NONE, "hp": health, "max_hp": health, "shield": 10 if elite else 0, "damage": ([10.0, 10.0, 15.0] if elite else [5.0, 7.5, 10.0])[role], "attack_boost": false, "weight": [70, 70, 65][role], "heals": 0, "intent": {}, "canceled": false, "acted": false}

func set_status_counts(counts: Dictionary) -> void:
	statuses.clear()
	for id in Status.IDS:
		statuses[id] = Status.new(id)
		statuses[id].count = int(counts.get(id, 0))

func status_count(id: int) -> int:
	return statuses[id].count if statuses.has(id) else 0

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
	if id not in Status.HARMFUL: return []
	var protector: String = RelicEffects.immunity_source(relics.items,id)
	if not protector.is_empty():
		relic_activated.emit(protector)
		return []
	var before: int = status_count(id)
	statuses[id].apply(amount)
	if id == Status.BURNING:
		amount = status_count(id) - before
		if amount <= 0: return []
	if id == Status.PLAGUE: hp = mini(hp, max_hp)
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
	if total <= 0: return base
	var triple: float = values[2] / total
	if perfect:
		triple = minf(triple, 1.0 if fever else 0.5)
		return {"normal":0.0, "pair":1.0-triple, "triple":triple}
	triple = minf(triple, NON_PERFECT_TRIPLE_CAP * (1.5 if fever else 1.0))
	var pair: float = minf(values[1] / total, NON_PERFECT_PAIR_CAP)
	return {"normal":maxf(0, 1.0-pair-triple), "pair":pair, "triple":triple}

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
	pending = classify(RelicEffects.modify_dice(self,values,perfect,rates))
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
	var result := classify(RelicEffects.modify_dice(self,dice.duplicate(),perfect,throw_rates(0,perfect)))
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
	perfect_relic_ready = perfect and relics.has("prismatic_stone")
	if perfect:
		for item in relics.items:
			if RelicEffects.STATS.get(item.id,{}).get("always_perfect",false) or RelicEffects.STONES.get(item.id,{}).get("combo_gain",0) > 0:
				relic_activated.emit(item.id)

func forces_perfect() -> bool:
	return RelicEffects.has_flag(relics.items,"always_perfect")

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

func outcome() -> String:
	if hp <= 0:
		return "defeat"
	if not has_living_enemies():
		return "victory"
	return ""

func begin_round() -> Array:
	if not outcome().is_empty() or phase not in ["new", "round_end"]:
		return []
	round_number += 1
	relic_turn_closed = false
	var events: Array = []
	if statuses[2].count > 0:
		var healed := heal(5)
		buff_ticks[2] = true
		events.append(event(-1, healed, "heal", "Regrowth +%d" % healed))
	for i in living():
		enemies[i].canceled = false
		enemies[i].acted = false
		enemies[i].intent = choose_intent(i)
	_prepare_player_turn()
	return events

func _prepare_player_turn() -> void:
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
	var e: Dictionary = enemies[index]
	var role: int = e.role
	var support: Array = []
	if role == 0 and e.shield < SHIELD_CAP:
		support.append({"type": "shield", "target": index, "amount": 6, "name": "Raise Shield"})
	if role == 2 and e.hp < e.max_hp:
		support.append({"type": "heal", "target": index, "amount": roundi(e.max_hp * 0.3), "name": "Self Mend"})
	if role == 1 and e.elite and living().any(func(i): return enemies[i].hp < enemies[i].max_hp):
		support.append({"type": "team_heal", "target": index, "amount": 0, "name": "Renewing Volley"})
	if role == 2 and e.elite:
		var allies: Array = living().filter(func(i): return i != index and not enemies[i].attack_boost)
		if not allies.is_empty():
			support.append({"type": "empower", "target": allies[rng.randi_range(0, allies.size() - 1)], "amount": 0, "name": "Arcane Empowerment"})
	if not support.is_empty() and rng.randi_range(1, 100) > e.weight:
		return support[rng.randi_range(0, support.size() - 1)]
	var intent := {"type": "attack", "target": -1, "amount": e.damage, "name": ["Sword Slash", "Arrow Shot", "Arcane Bolt"][role], "attribute": Status.Attribute.NONE}
	# Decide once when the turn starts, so the displayed move is the actual move.
	# These intents execute after the current player turn. If it is frozen,
	# archers must leave the following player turn available after the ice breaks.
	if e.elite and not (role == 1 and is_frozen()) and (role == 2 or rng.randf() < ELITE_CONTROL_CHANCE):
		intent.attribute = e.attribute
		intent.name = ["Stunning Blow", "Ice Arrow", "Burning Bolt"][role]
	return intent

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
	return RelicEffects.use_modifiers(relics.items,skill,skill_use_modifiers)

func begin_player_cast() -> bool:
	if phase != "player" or pending.is_empty() or not outcome().is_empty(): return false
	pending.begin_cast(skill_modifiers_for(pending))
	if is_attack(pending) and RelicEffects.begin_attack(relics.items): pending.critical = true
	phase = "executing"
	return true

static func hits_all(result: MultiHitSkill) -> bool:
	return result.hits_all()

func attack_multiplier() -> float:
	return 1.0 + (0.5 if statuses[3].count > 0 else 0.0) + (2.0 if statuses[33].count > 0 else 0.0)

func boon_turns(face: int) -> int:
	return (statuses[33].count if statuses[33].count > 0 else statuses[3].count) if face == 3 else int(status_count(face))

func attack_base(result: MultiHitSkill) -> float:
	if result.kind == Kind.NORMAL: return (result.sum + reward_base_damage) * DAMAGE_PER_PIP + relic_base_damage()
	var amount: float = regular_attack_power()
	if result.kind == Kind.PAIR:
		if result.face == 1: amount *= 1.5
		elif result.face == 4: amount *= 2.0 / 3.0
		amount += result.spare * DAMAGE_PER_PIP
	elif result.kind == Kind.SPECIAL and result.face == 4:
		amount *= 2.0
	return amount

func regular_attack_power() -> float:
	return REGULAR_ATTACK_POWER + reward_base_damage * DAMAGE_PER_PIP + relic_base_damage()

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

func attack_multiplier_steps(result: MultiHitSkill) -> Array:
	# Read-only trace of the same formula used by hits. Never consumes charges/RNG.
	var steps: Array = []
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
	var targets: Array = [primary] if is_enemy_alive(primary) else living()
	if targets.is_empty(): return ""
	var low: int = _target_damage(result,damage,targets[0])-base
	var high: int = low
	for target in targets:
		var modifier: int = _target_damage(result,damage,target)-base
		low = mini(low,modifier)
		high = maxi(high,modifier)
	var modifier: String = str(low) if low == high else "%d to %d" % [low,high]
	if low < 0 or low != high: modifier = "("+modifier+")"
	return "%d + %s (x%d)" % [base,modifier,skill_use_count(result)]

func player_target() -> int:
	if phase not in ["player", "executing"] or not is_attack(pending) or not outcome().is_empty(): return -1
	if not is_enemy_alive(pending.target):
		var candidates: Array = living()
		if candidates.is_empty(): return -1
		pending.target = candidates[rng.randi_range(0, candidates.size() - 1)]
	return pending.target

func preview(result: MultiHitSkill, primary: int) -> Array:
	# Preview one impact, without drawing RNG or consuming resources.
	var hits: Array = []
	if not is_attack(result) or not is_enemy_alive(primary): return hits
	var targets: Array = living() if hits_all(result) else [primary]
	for i in targets:
		var execute: bool = is_instant_kill(result)
		var damage: int = enemies[i].hp if execute else attack_damage(result, i)
		var hp_loss: int = 0 if enemies[i].shield > 0 and not execute and enemy_status_count(i, Status.CORROSION) == 0 else mini(enemies[i].hp, damage)
		hits.append({"target": i, "damage": damage, "ignore": execute, "hp_loss": hp_loss})
	return hits

func _apply_support(result: MultiHitSkill) -> Array:
	if result.kind == Kind.PAIR:
		statuses[result.face].apply(result.spare)
		buff_ticks.erase(result.face)
		return [event(-1, 0, "buff", PAIR_NAMES[result.face - 1])]
	if result.face == 2:
		return [event(-1, heal(max_hp), "heal", "FULL HEAL")]
	statuses[33].apply(3)
	return [event(-1, 0, "buff", SPECIAL_NAMES[2])]

func _finish_player_action(result: MultiHitSkill) -> void:
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
	# Keep counters and effects active until every enemy has finished acting.
	for face in [3, 33]:
		var refreshed: bool = (result.kind == Kind.PAIR and result.face == face) or (result.kind == Kind.SPECIAL and result.face == 3 and face == 33)
		if not refreshed: buff_ticks[face] = true
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
		if not is_enemy_alive(primary): return []
		pending.target = primary
	if phase == "player": begin_player_cast()
	var result: MultiHitSkill = pending.duplicate()
	var events: Array = []
	if not is_attack(result): events = _apply_support(result)
	else:
		lifesteal_used = 0
		for hit in preview(result, primary):
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
	_complete_skill_use(result, events)
	return events

func _complete_skill_use(result: MultiHitSkill, events: Array) -> void:
	if result.kind == Kind.ULTIMATE: events.append(event(-1, heal(12), "heal", "+12 HP"))
	pending.consume_use()
	if pending.random_target_per_use(): pending.target = -1
	if pending.uses_left() == 0 or not outcome().is_empty():
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

func enemy_act(index: int) -> Array:
	if phase != "enemy" or not outcome().is_empty():
		return []
	var e: Dictionary = enemies[index]
	if e.hp <= 0 or e.acted:
		return []
	e.acted = true
	if enemy_status_count(index, Status.FROZEN) > 0:
		e.statuses[Status.FROZEN].consume()
		return [event(index, 0, "skip", "FROZEN")]
	if e.canceled:
		return [event(index, 0, "cancel", "Lost in thought.")]
	var intent: Dictionary = e.intent
	if intent.is_empty():
		return []
	var events: Array = []
	if intent.type == "attack":
		# Keep 7.5 archer damage exact until impact, then round once for integer HP.
		var amount: int = roundi(intent.amount * (1.5 if e.attack_boost else 1.0) * (0.5 if enemy_status_count(index, Status.DARKNESS) > 0 else 1.0))
		e.attack_boost = false
		events.append_array(receive_damage(amount))
		if events.any(func(hit): return hit.type == "damage" and hit.amount > 0):
			match intent.get("attribute", Status.Attribute.NONE):
				Status.Attribute.ICE: events.append_array(apply_affliction(Status.FROZEN, 1))
				Status.Attribute.FIRE: events.append_array(apply_affliction(Status.BURNING, 2))
				Status.Attribute.SHOCK: events.append_array(apply_affliction(Status.STUNNED, 1))
	elif intent.type == "team_heal":
		for target_index in living():
			var target: Dictionary = enemies[target_index]
			var actual: int = 0 if enemy_status_count(target_index, Status.DARKNESS) > 0 else mini(roundi(target.max_hp * 0.2), target.max_hp - target.hp)
			target.hp += actual
			events.append(event(target_index, actual, "heal", "TEAM MEND"))
	elif intent.type == "empower":
		var allies: Array = living().filter(func(i): return i != index and not enemies[i].attack_boost)
		if not allies.is_empty():
			var target: int = intent.target if intent.target in allies else allies[rng.randi_range(0, allies.size() - 1)]
			enemies[target].attack_boost = true
			events.append(event(target, 0, "buff", "ATTACK x1.5"))
	elif intent.target >= 0 and intent.target < enemies.size() and enemies[intent.target].hp > 0:
		var target: Dictionary = enemies[intent.target]
		if intent.type == "heal":
			var actual: int = 0 if enemy_status_count(intent.target, Status.DARKNESS) > 0 else mini(intent.amount, target.max_hp - target.hp)
			target.hp += actual
			if actual > 0:
				e.heals += 1
			events.append(event(intent.target, actual, "heal", "+%d HP" % actual))
		else:
			var actual: int = 0 if enemy_status_count(intent.target, Status.CORROSION) > 0 else mini(intent.amount, SHIELD_CAP - target.shield)
			target.shield += actual
			events.append(event(intent.target, actual, "buff", "+%d SHIELD" % actual))
	if not outcome().is_empty():
		phase = "finished"
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
	if status_count(Status.PLAGUE) > 0:
		statuses[Status.PLAGUE].apply(1)
		hp = mini(hp, max_hp)
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
	for status in Status.HARMFUL:
		if relic_immune(status): statuses[status].count = 0
	hp = clampi(hp + maxi(0, max_hp - old_max), 0, max_hp)
	return true

func receive_damage(amount: int, burning: bool = false) -> Array:
	var corroded: bool = status_count(Status.CORROSION) > 0
	if status_count(Status.IMMUNITY) > 0 and not corroded: return [event(-1,0,"immune","INVINCIBLE")]
	var incoming: float = maxf(0, amount) * (1.5 if corroded else 1.0)
	var defense: Dictionary = RelicEffects.incoming(relics.items,incoming,corroded,burning)
	for id in defense.activated: relic_activated.emit(id)
	if defense.blocked: return [event(-1,0,"relic","SHIELD BLOCK")]
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
	return events

func _complete_relic_turn() -> Array:
	if relic_turn_closed: return []
	relic_turn_closed = true
	return RelicEffects.turn_finished(self)

static func status_label(id: int, amount: int) -> String:
	return "%s +%d" % [{Status.FROZEN:"FROZEN",Status.BURNING:"BURN",Status.STUNNED:"STUN",Status.DARKNESS:"DARKNESS",Status.CORROSION:"CORROSION",Status.PLAGUE:"PLAGUE"}.get(id,"STATUS"), amount]

func enemy_status_count(index: int, id: int) -> int:
	if index < 0 or index >= enemies.size(): return 0
	var effects: Dictionary = enemies[index].get("statuses", {})
	return effects[id].count if effects.has(id) else 0

func apply_enemy_status(index: int, id: int, amount: int) -> Array:
	if not is_enemy_alive(index) or id == Status.STUNNED or id not in Status.HARMFUL: return []
	var enemy: Dictionary = enemies[index]
	if not enemy.has("statuses"): enemy.statuses = {}
	if not enemy.statuses.has(id): enemy.statuses[id] = Status.new(id)
	var before: int = enemy.statuses[id].count
	enemy.statuses[id].apply(amount)
	var added: int = enemy.statuses[id].count - before
	if added <= 0: return []
	if id == Status.PLAGUE:
		if not enemy.has("healthy_max_hp"): enemy.healthy_max_hp = enemy.max_hp
		enemy.max_hp = maxi(1, enemy.healthy_max_hp - enemy.statuses[id].count * 10)
		enemy.hp = mini(enemy.hp, enemy.max_hp)
	var effect: Dictionary = event(index, added, "status", status_label(id, added))
	effect.status = id
	return [effect]

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
		events.append_array(apply_enemy_status(i,Status.PLAGUE,1))
		var allies: Array = living().filter(func(ally): return ally != i)
		if not allies.is_empty(): events.append_array(apply_enemy_status(allies[rng.randi_range(0,allies.size()-1)],Status.PLAGUE,1))
	return events

func resolve_perfect_relic() -> Array:
	if not perfect_relic_ready or not outcome().is_empty(): return []
	relic_activated.emit("prismatic_stone")
	perfect_relic_ready = false
	lifesteal_used = 0
	var candidates: Array = living()
	var target: int = candidates[rng.randi_range(0,candidates.size()-1)]
	var amount: int = floori((RelicEffects.PERFECT_STRIKE_BASE + relic_base_damage()) * damage_multiplier(pending))
	if enemy_status_count(target,Status.CORROSION) > 0: amount = floori(amount * 1.5)
	var previous_shield: int = enemies[target].shield
	var loss: int = hit_enemy(target,amount)
	var events: Array = [damage_event(target,loss,amount)]
	if loss == 0 and previous_shield > 0:
		var blocked: Dictionary = damage_event(target,previous_shield-enemies[target].shield,amount,"shield_hit")
		blocked.text = "SHIELD BREAK" if enemies[target].shield == 0 else "BLOCKED"
		events = [blocked]
	if loss > 0: events.append_array(_attack_relic_effects(target,loss,Skill.new(Kind.NORMAL)))
	if not outcome().is_empty():
		if saved_skill.is_empty(): saved_skill = pending.duplicate()
		pending = Skill.new()
		phase = "finished"
		events.append_array(_complete_relic_turn())
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
