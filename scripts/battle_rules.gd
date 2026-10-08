extends RefCounted
## Deterministic battle model. Rendering and cosmetic randomness never alter it.

enum Kind { NORMAL, PAIR, SPECIAL, ULTIMATE }
const NORMAL_NAME = "Tentacle Swipe"
const PAIR_NAMES = ["Rending Blow", "Unnatural Regrowth", "Eldritch Might", "Sweeping Ruin", "Tentacle Flurry", "Beyond Harm"]
const PAIR_TEXT = ["1.5x regular attack + spare die.", "Heal 5 at the next spare-die turn starts.", "1.5x attack power for the next spare-die turns.", "Hit all: 2/3 regular attack + spare die each.", "3 quick hits; regular attack + spare die each.", "Invincible for spare-die enemy phases / roll intervals."]
const SPECIAL_NAMES = ["Death Sentence", "Abyssal Renewal", "Eldritch Ascension", "Worldbreaker", "Sixfold Ruin", "Annihilation"]
const SPECIAL_TEXT = ["Instantly kill one random foe, ignoring shield.", "Restore all missing health. No attack.", "3x attack power for the next 3 turns.", "Hit every foe for 2x regular attack power.", "6 quick hits at regular attack power.", "Destroy the squad. Heal 12 HP."]
const CITY_SPECIAL_TEXT = ["Hit the city for 5x regular attack power.", "Restore all missing health. No attack.", "3x attack power for the next 3 rolls.", "2x city attack; clear all troops.", "6 quick city hits; clear troops.", "800 city damage; clear troops; heal 12."]
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
var shield: int = 0
var buffs: Dictionary = {2: 0, 3: 0, 6: 0, 33: 0}
var enemies: Array = []
var round_number: int = 0
var pending: Dictionary = {}
var phase: String = "new"

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
	shield = 0
	buffs = {2: 0, 3: 0, 6: 0, 33: 0}
	enemies = [make_enemy(0), make_enemy(1), make_enemy(2)]
	for e in enemies:
		e["intent"] = {}
		e["canceled"] = false
		e["acted"] = false
	round_number = 0
	pending = {}
	phase = "new"

static func make_enemy(role: int, health_scale: float = 1.0) -> Dictionary:
	# Keep exact half-HP thresholds stable despite decimal scale rounding.
	var health: int = roundi([30, 36, 30][role] * health_scale + 0.0001)
	return {"name": ["Vanguard", "Elf Archer", "Mage"][role], "role": role, "hp": health, "max_hp": health, "shield": 0, "damage": [3, 4, 2][role], "weight": [65, 70, 60][role], "heals": 0, "intent": {}, "canceled": false, "acted": false}

static func classify(dice: Array) -> Dictionary:
	if dice.size() != 3:
		return {}
	var counts: Dictionary = {}
	var total: int = 0
	for value in dice:
		if not value is int or value < 1 or value > 6:
			return {}
		counts[value] = counts.get(value, 0) + 1
		total += value
	for face in counts:
		if counts[face] == 3:
			return {"kind": Kind.ULTIMATE if face == 6 else Kind.SPECIAL, "face": face, "sum": total, "dice": dice.duplicate()}
	for face in counts:
		if counts[face] == 2:
			return {"kind": Kind.PAIR, "face": face, "spare": total - face * 2, "sum": total, "dice": dice.duplicate()}
	return {"kind": Kind.NORMAL, "face": 0, "sum": total, "dice": dice.duplicate()}

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

func _match_values(triple: bool) -> Array:
	var face: int = rng.randi_range(1, 6)
	var values: Array = [face, face, face]
	if not triple:
		var other: int = rng.randi_range(1, 5)
		if other >= face: other += 1
		values[rng.randi_range(0, 2)] = other
	return values

func roll(throw_power: float = 0.0, perfect: bool = false, fever: bool = false) -> Dictionary:
	if phase != "roll":
		return {}
	var values: Array = []
	if not perfect and not fever and throw_power <= 0:
		# Zero power is natural 3D6, with no history-dependent guarantees.
		values = [rng.randi_range(1, 6), rng.randi_range(1, 6), rng.randi_range(1, 6)]
	else:
		var rates: Dictionary = throw_rates(throw_power, perfect, fever)
		var chance: float = rng.randf()
		if chance < rates.triple:
			values = _match_values(true)
		elif chance < rates.triple + rates.pair:
			values = _match_values(false)
		else:
			var faces: Array = [1, 2, 3, 4, 5, 6]
			for i in range(3): values.append(faces.pop_at(rng.randi_range(0, faces.size() - 1)))
	pending = classify(values)
	phase = "player"
	return pending.duplicate(true)

func set_test_roll(dice: Array) -> Dictionary:
	# Only called by tests or the visual debug picker; overrides power odds.
	if phase != "roll":
		return {}
	var result := classify(dice)
	if result.is_empty():
		return {}
	pending = result
	phase = "player"
	return pending.duplicate(true)

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
	if buffs[2] > 0:
		var healed := heal(5)
		buffs[2] -= 1
		events.append(event(-1, healed, "heal", "Regrowth +%d" % healed))
	for i in living():
		enemies[i].canceled = false
		enemies[i].acted = false
		enemies[i].intent = choose_intent(i)
	phase = "roll"
	return events

func choose_intent(index: int) -> Dictionary:
	var e: Dictionary = enemies[index]
	var role: int = e.role
	var target: int = -1
	if role == 0 and e.shield < SHIELD_CAP:
		target = index
	elif role == 1:
		for i in living():
			if enemies[i].shield < SHIELD_CAP and (target == -1 or enemies[i].hp < enemies[target].hp):
				target = i
	elif role == 2 and e.heals < 2:
		for i in living():
			var missing: int = enemies[i].max_hp - enemies[i].hp
			if missing > 0 and (target == -1 or missing > enemies[target].max_hp - enemies[target].hp):
				target = i
	if target == -1 or rng.randi_range(1, 100) <= e.weight:
		return {"type": "attack", "target": -1, "amount": e.damage, "name": ["Sword Slash", "Arrow Shot", "Arcane Bolt"][role]}
	if role == 2:
		return {"type": "heal", "target": target, "amount": 6, "name": "Mend"}
	return {"type": "shield", "target": target, "amount": 6 if role == 0 else 4, "name": "Raise Shield" if role == 0 else "Covering Fire"}

func damage_cap(kind: int, target: int) -> int:
	var max_hp: int = enemies[target].max_hp
	return floori(float(max_hp) * (2.0 / 3.0 if kind == Kind.SPECIAL else 1.0 / 3.0))

static func is_attack(result: Dictionary) -> bool:
	if result.is_empty(): return false
	if result.kind == Kind.PAIR: return result.face in [1, 4, 5]
	if result.kind == Kind.SPECIAL: return result.face in [1, 4, 5]
	return true

static func hit_count(result: Dictionary) -> int:
	if not is_attack(result): return 0
	if result.face == 5 and result.kind in [Kind.PAIR, Kind.SPECIAL]:
		return 3 if result.kind == Kind.PAIR else 6
	return 1

static func hits_all(result: Dictionary) -> bool:
	return result.kind == Kind.ULTIMATE or (result.kind in [Kind.PAIR, Kind.SPECIAL] and result.face == 4)

func attack_multiplier() -> float:
	return 3.0 if buffs[33] > 0 else 1.5 if buffs[3] > 0 else 1.0

func boon_turns(face: int) -> int:
	return (buffs[33] if buffs[33] > 0 else buffs[3]) if face == 3 else int(buffs.get(face, 0))

func attack_base(result: Dictionary) -> float:
	if result.kind == Kind.NORMAL: return result.sum
	var amount: float = REGULAR_ATTACK_POWER
	if result.kind == Kind.PAIR:
		if result.face == 1: amount *= 1.5
		elif result.face == 4: amount *= 2.0 / 3.0
		amount += result.spare
	elif result.kind == Kind.SPECIAL and result.face == 4:
		amount *= 2.0
	return amount

func player_target() -> int:
	if phase not in ["player", "executing"] or not is_attack(pending) or not outcome().is_empty(): return -1
	if not pending.has("target") or pending.target not in living():
		var candidates: Array = living()
		if candidates.is_empty(): return -1
		pending["target"] = candidates[rng.randi_range(0, candidates.size() - 1)]
	return pending.target

func preview(result: Dictionary, primary: int) -> Array:
	# Preview one impact, without drawing RNG or consuming resources.
	var hits: Array = []
	if not is_attack(result) or primary not in living(): return hits
	var targets: Array = living() if hits_all(result) else [primary]
	for i in targets:
		var execute: bool = result.kind == Kind.ULTIMATE or (result.kind == Kind.SPECIAL and result.face == 1)
		var damage: int = enemies[i].hp if execute else floori(attack_base(result) * DAMAGE_MULTIPLIER * power * attack_multiplier())
		if result.kind == Kind.NORMAL: damage = mini(damage, damage_cap(result.kind, i))
		var hp_loss: int = mini(enemies[i].hp, maxi(0, damage - (0 if execute else enemies[i].shield)))
		hits.append({"target": i, "damage": damage, "ignore": execute, "hp_loss": hp_loss})
	return hits

func _apply_support(result: Dictionary) -> Array:
	if result.kind == Kind.PAIR:
		buffs[result.face] = result.spare
		return [event(-1, 0, "buff", PAIR_NAMES[result.face - 1])]
	if result.face == 2:
		return [event(-1, heal(max_hp), "heal", "FULL HEAL")]
	buffs[33] = 3
	return [event(-1, 0, "buff", SPECIAL_NAMES[2])]

func _finish_player_action(result: Dictionary) -> void:
	# Attack boosts count complete subsequent actions, not individual impacts.
	# Immunity protects the granting enemy phase / city interval, then expires
	# after the specified number of subsequent completed actions.
	for face in [3, 6, 33]:
		var refreshed: bool = (result.kind == Kind.PAIR and result.face == face) or (result.kind == Kind.SPECIAL and result.face == 3 and face == 33)
		if not refreshed: buffs[face] = maxi(0, buffs[face] - 1)
	pending = {}
	phase = "enemy" if outcome().is_empty() else "finished"

func apply_player_step(primary: int = -1) -> Array:
	if phase not in ["player", "executing"] or pending.is_empty() or not outcome().is_empty(): return []
	var result: Dictionary = pending.duplicate(true)
	if not is_attack(result):
		var support: Array = _apply_support(result)
		_finish_player_action(result)
		return support
	if primary < 0: primary = player_target()
	if primary not in living(): return []
	if phase == "player": pending["hits_left"] = hit_count(result)
	phase = "executing"
	var events: Array = []
	for hit in preview(result, primary):
		var loss: int = hit_enemy(hit.target, hit.damage, hit.ignore)
		events.append(event(hit.target, loss, "damage", "-%d" % loss))
	pending.hits_left -= 1
	pending.erase("target")
	if pending.hits_left <= 0 or not outcome().is_empty():
		if result.kind == Kind.ULTIMATE: events.append(event(-1, heal(12), "heal", "+12 HP"))
		_finish_player_action(result)
	return events

func apply_player(primary: int = -1) -> Array:
	var events: Array = []
	while phase in ["player", "executing"] and not pending.is_empty() and outcome().is_empty():
		var step: Array = apply_player_step(primary)
		if step.is_empty(): break
		events.append_array(step)
		primary = -1
	return events

func hit_enemy(index: int, damage: int, ignore: bool = false) -> int:
	var e: Dictionary = enemies[index]
	if not ignore:
		var blocked: int = mini(e.shield, damage)
		e.shield -= blocked
		damage -= blocked
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
		if buffs[6] > 0:
			events.append(event(-1, 0, "immune", "INVINCIBLE"))
		else:
			var blocked: int = mini(shield, intent.amount)
			shield -= blocked
			var loss: int = mini(hp, intent.amount - blocked)
			hp -= loss
			events.append(event(-1, loss, "damage", "-%d HP" % loss if loss else "BLOCKED"))
	elif enemies[intent.target].hp > 0:
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

func end_round() -> void:
	if phase != "enemy":
		return
	for i in living():
		if not enemies[i].acted:
			return
	phase = "round_end"

static func event(target: int, amount: int, type: String, text: String) -> Dictionary:
	return {"target": target, "amount": amount, "type": type, "text": text}
