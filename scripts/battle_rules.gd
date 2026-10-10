extends RefCounted
## Deterministic battle model. Rendering and cosmetic randomness never alter it.
const Weighted = preload("res://scripts/weighted_choice.gd")

const Skill = preload("res://scripts/multi_hit_skill.gd")
const Status = preload("res://scripts/status_effect.gd")
const ELITE_CONTROL_CHANCE := 0.5
const Kind = Skill.Kind
const NORMAL_NAME = "Tentacle Swipe"
const PAIR_NAMES = ["Rending Blow", "Unnatural Regrowth", "Eldritch Might", "Sweeping Ruin", "Tentacle Flurry", "Beyond Harm"]
const PAIR_TEXT = ["1.5x regular attack + spare die.", "Heal 5 at the next spare-die turn starts.", "1.5x attack power for the next spare-die turns.", "Hit all: 2/3 regular attack + spare die each.", "3 automatic random hits, each regular attack + spare die.", "Invincible for spare-die enemy phases / roll intervals."]
const SPECIAL_NAMES = ["Death Sentence", "Abyssal Renewal", "Eldritch Ascension", "Worldbreaker", "Sixfold Ruin", "Annihilation"]
const SPECIAL_TEXT = ["Instantly kill your chosen foe, ignoring shield.", "Restore all missing health. No attack.", "3x attack power for the next 3 turns.", "Hit every foe for 2x regular attack power.", "6 automatic random hits, each regular attack power.", "Destroy the squad. Heal 12 HP."]
const CITY_SPECIAL_TEXT = ["Hit the city for 5x regular attack power.", "Restore all missing health. No attack.", "3x attack power for the next 3 rolls.", "2x city attack; clear all troops.", "6 automatic city hits; each clears one troop.", "800 damage x Perfect combo bonus; clear troops; heal 12."]
const REGULAR_ATTACK_POWER = 10.0
const MAX_HP = 100
const SHIELD_CAP = 20
const DAMAGE_MULTIPLIER = 1.5
const NON_PERFECT_TRIPLE_CAP = 0.25
const NON_PERFECT_PAIR_CAP = 0.70

var rng = RandomNumberGenerator.new()
var hp: int = MAX_HP
var max_hp: int = MAX_HP
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
	if hp <= 0 or status_count(Status.IMMUNITY) > 0: return []
	if id not in [Status.FROZEN, Status.BURNING, Status.STUNNED]: return []
	var before: int = status_count(id)
	statuses[id].apply(amount)
	if id == Status.BURNING:
		amount = status_count(id) - before
		if amount <= 0: return []
	var applied := event(-1, amount, "status", {Status.FROZEN:"FROZEN", Status.BURNING:"BURN +%d" % amount, Status.STUNNED:"STUNNED"}[id])
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
	pending = classify(values)
	record_perfect(perfect)
	statuses[Status.STUNNED].consume()
	phase = "player"
	return pending.duplicate(true)

func set_test_roll(dice: Array, perfect: bool = false) -> MultiHitSkill:
	# Only called by tests or the visual debug picker; overrides power odds.
	if phase != "roll":
		return Skill.new()
	var result := classify(dice)
	if result.is_empty():
		return Skill.new()
	pending = result
	record_perfect(perfect)
	statuses[Status.STUNNED].consume()
	phase = "player"
	return pending.duplicate(true)

func record_perfect(perfect: bool) -> void:
	# Only accepted throws change the streak; skips and bonus casts preserve it.
	perfect_combo = perfect_combo + 1 if perfect else 0

func combo_multiplier() -> float:
	return 1.0 + perfect_combo * 0.1

func living() -> Array:
	var result: Array = []
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			result.append(i)
	return result

func outcome() -> String:
	if hp <= 0:
		return "defeat"
	if living().is_empty():
		return "victory"
	return ""

func begin_round() -> Array:
	if not outcome().is_empty() or phase not in ["new", "round_end"]:
		return []
	round_number += 1
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
	return floori(float(max_hp) * (2.0 / 3.0 if kind == Kind.SPECIAL else 1.0 / 3.0))

static func is_attack(result: MultiHitSkill) -> bool:
	if result.is_empty(): return false
	if result.kind == Kind.PAIR: return result.face in [1, 4, 5]
	if result.kind == Kind.SPECIAL: return result.face in [1, 4, 5]
	return true

func set_skill_use_multiplier(source: String, multiplier: int) -> void:
	if multiplier <= 1: skill_use_modifiers.erase(source)
	else: skill_use_modifiers[source] = multiplier

func skill_use_count(skill: MultiHitSkill) -> int:
	return skill.use_count(skill_use_modifiers)

func begin_player_cast() -> bool:
	if phase != "player" or pending.is_empty() or not outcome().is_empty(): return false
	pending.begin_cast(skill_use_modifiers)
	phase = "executing"
	return true

static func hits_all(result: MultiHitSkill) -> bool:
	return result.kind == Kind.ULTIMATE or (result.kind in [Kind.PAIR, Kind.SPECIAL] and result.face == 4)

func attack_multiplier() -> float:
	return 3.0 if statuses[33].count > 0 else 1.5 if statuses[3].count > 0 else 1.0

func boon_turns(face: int) -> int:
	return (statuses[33].count if statuses[33].count > 0 else statuses[3].count) if face == 3 else int(status_count(face))

func attack_base(result: MultiHitSkill) -> float:
	if result.kind == Kind.NORMAL: return result.sum + reward_base_damage
	var amount: float = regular_attack_power()
	if result.kind == Kind.PAIR:
		if result.face == 1: amount *= 1.5
		elif result.face == 4: amount *= 2.0 / 3.0
		amount += result.spare
	elif result.kind == Kind.SPECIAL and result.face == 4:
		amount *= 2.0
	return amount

func regular_attack_power() -> float:
	return REGULAR_ATTACK_POWER + reward_base_damage

func damage_multiplier() -> float:
	return DAMAGE_MULTIPLIER + reward_damage_multiplier

func is_instant_kill(result: MultiHitSkill) -> bool:
	return result.kind == Kind.ULTIMATE or (result.kind == Kind.SPECIAL and result.face == 1)

func attack_damage(result: MultiHitSkill, target: int = -1) -> int:
	var damage: int = floori(attack_base(result) * damage_multiplier() * power * attack_multiplier() * combo_multiplier())
	if result.kind == Kind.NORMAL and target in living(): damage = mini(damage, damage_cap(result.kind, target))
	return damage

func damage_caption(result: MultiHitSkill, primary: int = -1) -> String:
	if not is_attack(result) or is_instant_kill(result): return ""
	var base: int = floori(attack_base(result))
	var targets: Array = [primary] if primary in living() else living()
	if targets.is_empty(): return ""
	var modifiers: Array = targets.map(func(i): return attack_damage(result, i) - base)
	var low: int = modifiers.min()
	var high: int = modifiers.max()
	var modifier: String = str(low) if low == high else "%d to %d" % [low, high]
	if low < 0 or low != high: modifier = "("+modifier+")"
	return "%d + %s (x%d)" % [base, modifier, skill_use_count(result)]

func player_target() -> int:
	if phase not in ["player", "executing"] or not is_attack(pending) or not outcome().is_empty(): return -1
	if pending.target not in living():
		var candidates: Array = living()
		if candidates.is_empty(): return -1
		pending.target = candidates[rng.randi_range(0, candidates.size() - 1)]
	return pending.target

func preview(result: MultiHitSkill, primary: int) -> Array:
	# Preview one impact, without drawing RNG or consuming resources.
	var hits: Array = []
	if not is_attack(result) or primary not in living(): return hits
	var targets: Array = living() if hits_all(result) else [primary]
	for i in targets:
		var execute: bool = is_instant_kill(result)
		var damage: int = enemies[i].hp if execute else attack_damage(result, i)
		var hp_loss: int = 0 if enemies[i].shield > 0 and not execute else mini(enemies[i].hp, damage)
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
		if primary not in living(): return []
		pending.target = primary
	if phase == "player": begin_player_cast()
	var result: MultiHitSkill = pending.duplicate()
	var events: Array = []
	if not is_attack(result): events = _apply_support(result)
	else:
		for hit in preview(result, primary):
			var previous_shield: int = enemies[hit.target].shield
			var loss: int = hit_enemy(hit.target, hit.damage, hit.ignore)
			if previous_shield > 0 and not hit.ignore:
				events.append(event(hit.target, previous_shield-enemies[hit.target].shield, "shield_hit", "SHIELD BREAK" if enemies[hit.target].shield == 0 else "BLOCKED"))
			else:
				events.append(event(hit.target, loss, "damage", "-%d" % loss))
	_complete_skill_use(result, events)
	return events

func _complete_skill_use(result: MultiHitSkill, events: Array) -> void:
	if result.kind == Kind.ULTIMATE: events.append(event(-1, heal(12), "heal", "+12 HP"))
	pending.consume_use()
	if pending.random_target_per_use(): pending.target = -1
	if pending.uses_left() == 0 or not outcome().is_empty(): _finish_player_action(result)

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
	if not ignore and e.shield > 0:
		e.shield = maxi(0, e.shield-maxi(0, damage))
		return 0 # A single hit can break a shield, but never spill into HP.
	if ignore: e.shield = 0
	var actual: int = mini(e.hp, damage)
	e.hp -= actual
	return actual

func heal(amount: int) -> int:
	var actual: int = mini(max_hp - hp, amount)
	hp += actual
	return actual

func enemy_act(index: int) -> Array:
	if phase != "enemy" or not outcome().is_empty():
		return []
	var e: Dictionary = enemies[index]
	if e.hp <= 0 or e.acted:
		return []
	e.acted = true
	if e.canceled:
		return [event(index, 0, "cancel", "Lost in thought.")]
	var intent: Dictionary = e.intent
	if intent.is_empty():
		return []
	var events: Array = []
	if intent.type == "attack":
		# Keep 7.5 archer damage exact until impact, then round once for integer HP.
		var amount: int = roundi(intent.amount * (1.5 if e.attack_boost else 1.0))
		e.attack_boost = false
		if statuses[6].count > 0:
			events.append(event(-1, 0, "immune", "INVINCIBLE"))
		else:
			var blocked: int = mini(shield, amount)
			shield -= blocked
			var loss: int = mini(hp, amount - blocked)
			hp -= loss
			events.append(event(-1, loss, "damage", "-%d HP" % loss if loss else "BLOCKED"))
			if loss > 0:
				match intent.get("attribute", Status.Attribute.NONE):
					Status.Attribute.ICE: events.append_array(apply_affliction(Status.FROZEN, 1))
					Status.Attribute.FIRE: events.append_array(apply_affliction(Status.BURNING, 2))
					Status.Attribute.SHOCK: events.append_array(apply_affliction(Status.STUNNED, 1))
	elif intent.type == "team_heal":
		for target_index in living():
			var target: Dictionary = enemies[target_index]
			var actual: int = mini(roundi(target.max_hp * 0.2), target.max_hp - target.hp)
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
			var actual: int = mini(intent.amount, target.max_hp - target.hp)
			target.hp += actual
			if actual > 0:
				e.heals += 1
			events.append(event(intent.target, actual, "heal", "+%d HP" % actual))
		else:
			var actual: int = mini(intent.amount, SHIELD_CAP - target.shield)
			target.shield += actual
			events.append(event(intent.target, actual, "buff", "+%d SHIELD" % actual))
	if not outcome().is_empty():
		phase = "finished"
	return events

func _begin_turn_end() -> void:
	burn_ticks_remaining = status_count(Status.BURNING)
	phase = "turn_end"
	if burn_ticks_remaining == 0: _finish_turn_end()

func _finish_turn_end() -> void:
	statuses[Status.BURNING].consume()
	_end_buff_turn()
	phase = "round_end" if outcome().is_empty() else "finished"

func end_round_step() -> Array:
	# Presentation calls once per burn tick; headless simulation uses end_round().
	if phase == "enemy":
		if living().any(func(i): return not enemies[i].acted): return []
		_begin_turn_end()
	if phase != "turn_end": return []
	var events: Array = []
	if burn_ticks_remaining > 0:
		burn_ticks_remaining -= 1
		if status_count(Status.IMMUNITY) == 0 and hp > 0:
			hp -= 1
			events.append(event(-1, 1, "burn", "-1"))
	if burn_ticks_remaining == 0 or hp <= 0:
		burn_ticks_remaining = 0
		_finish_turn_end()
	return events

func end_round() -> Array:
	var events: Array = []
	while phase in ["enemy", "turn_end"]:
		if phase == "enemy" and living().any(func(i): return not enemies[i].acted): break
		events.append_array(end_round_step())
	return events

static func event(target: int, amount: int, type: String, text: String) -> Dictionary:
	return {"target": target, "amount": amount, "type": type, "text": text}
