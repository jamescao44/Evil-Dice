extends "res://scripts/battle_rules.gd"
## Run progression and real-time siege. No presentation state or wall-clock calls.
const Rewards = preload("res://scripts/reward_catalog.gd")
const WAVE_NAMES := ["OUTSKIRTS", "OLD ROAD", "THE CHAMPION", "CROSSROADS", "WATCH POST", "WAR CAMP", "CITY ROAD", "ELITE GUARD", "LAST STAND", "THE CITY"]
# Normal / elite counts. Roles are independently randomized and then shuffled.
const WAVE_COUNTS := [[1,0], [3,0], [0,1], [5,0], [2,1], [3,2], [5,2], [0,4], [5,5]]
const WAVE_BOOSTS := [1.0, 1.0, 1.5, 2.25, 2.25, 2.25, 2.25, 2.25, 2.25, 2.25]
const CITY_MAX_HP := 2400
const CITY_ULTIMATE_DAMAGE := CITY_MAX_HP / 3
var stage: int = 0
var city_hp: int = CITY_MAX_HP
var troops: int = 0
var spawn_clock: float = 2.5
var volley_clock: float = 4.0
var troop_clock: float = 1.5
var volley_warned: bool = false
var perfect_progress: int = 0
var perfect_total: int = 0
const CHEST_THRESHOLDS := [0, 3, 6, 9]
const CHEST_COUNTS := [0, 1, 3, 5]
var claimed_slots: Array = []
var reward_weights: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var open_rewards: Array = []
var reward_history: Array = []
var rubies: int = 0
var summon_shards: int = 0
var reward_rng := RandomNumberGenerator.new()

func _init(seed_value: int = -1) -> void:
	super(seed_value)
	if seed_value < 0: reward_rng.randomize()
	else: reward_rng.seed = seed_value + 7919
	reset_run()

func reset_run() -> void:
	super.reset()
	stage = 0
	city_hp = CITY_MAX_HP
	troops = 0
	spawn_clock = 2.5
	volley_clock = 4.0
	troop_clock = 1.5
	volley_warned = false
	perfect_progress = 0
	perfect_total = 0
	claimed_slots.clear()
	reward_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	open_rewards.clear()
	reward_history.clear()
	rubies = 0
	summon_shards = 0
	_load_wave()

func record_perfect(perfect: bool) -> void:
	# Accepted throws only. Misses/waves preserve progress; a full bank holds nine.
	if not perfect: return
	perfect_total += 1
	perfect_progress = mini(9, perfect_progress + 1)

func chest_tier() -> int:
	return clampi(perfect_progress / 3, 0, 3)

func open_chest(requested_tier: int = 0) -> Array:
	if not open_rewards.is_empty(): return open_rewards.duplicate()
	var tier: int = chest_tier() if requested_tier == 0 else requested_tier
	if tier < 1 or tier > 3 or tier > chest_tier(): return []
	# Any claimed milestone empties the bank, including extra unspent diamonds.
	perfect_progress = 0
	claimed_slots.clear()
	for i in range(CHEST_COUNTS[tier]):
		var index: int = Weighted.pick(reward_rng, reward_weights)
		open_rewards.append(index if index >= 0 else reward_rng.randi_range(0, Rewards.ITEMS.size()-1))
	return open_rewards.duplicate()

func claim_reward(slot: int) -> Dictionary:
	if slot < 0 or slot >= open_rewards.size() or slot in claimed_slots: return {}
	var index: int = open_rewards[slot]
	var item: Dictionary = Rewards.ITEMS[index]
	claimed_slots.append(slot)
	match item.id:
		"ruby": rubies += 100
		"shard": summon_shards += 1
		"damage": reward_base_damage += 5
		"multiplier": reward_damage_multiplier += 0.5
	reward_history.append(index)
	return item.duplicate()

func rewards_collected() -> bool:
	return not open_rewards.is_empty() and claimed_slots.size() == open_rewards.size()

func close_chest() -> bool:
	if not rewards_collected(): return false
	open_rewards.clear()
	claimed_slots.clear()
	return true

func auto_claim_victory_chest() -> int:
	if outcome() != "victory" or not open_rewards.is_empty(): return 0
	var tier: int = chest_tier()
	if tier == 0: return 0
	var outcomes: Array = open_chest(tier)
	for slot in range(outcomes.size()): claim_reward(slot)
	close_chest()
	return tier

func is_city() -> bool:
	return stage == WAVE_COUNTS.size()

func roll(throw_power: float = 0.0, perfect: bool = false, _fever: bool = false) -> Dictionary:
	return super.roll(throw_power, perfect, is_city())

func damage_cap(kind: int, target: int) -> int:
	var numerator: float = 2.0 if kind == Kind.SPECIAL else 1.0
	return floori(enemies[target].max_hp * numerator * WAVE_BOOSTS[stage] / 3.0)

func _load_wave() -> void:
	enemies.clear()
	if not is_city():
		for tier in range(2):
			for i in range(WAVE_COUNTS[stage][tier]):
				enemies.append(make_enemy(rng.randi_range(0, 2), 1.0, tier == 1))
		for i in range(enemies.size() - 1, 0, -1):
			var other: int = rng.randi_range(0, i)
			var temp: Dictionary = enemies[i]
			enemies[i] = enemies[other]
			enemies[other] = temp
	pending = {}
	phase = "new"

func outcome() -> String:
	if hp <= 0:
		return "defeat"
	if is_city():
		return "victory" if city_hp <= 0 else ""
	return "wave_clear" if living().is_empty() else ""

func advance_wave() -> bool:
	if outcome() != "wave_clear":
		return false
	_end_buff_turn()
	stage += 1
	max_hp += 30
	heal(55) # Increased capacity plus a modest recovery from feeding.
	power = (1.0 + stage * 0.5) * WAVE_BOOSTS[stage]
	_load_wave()
	return true

func begin_round() -> Array:
	if not is_city():
		return super.begin_round()
	if not outcome().is_empty() or phase not in ["new", "round_end"]:
		return []
	round_number += 1
	var events: Array = []
	if buffs[2] > 0:
		buff_ticks[2] = true
		events.append(event(-1, heal(5), "heal", "REGROWTH"))
	phase = "roll"
	return events

func is_instant_kill(result: Dictionary) -> bool:
	return not is_city() and super.is_instant_kill(result)

func attack_base(result: Dictionary) -> float:
	if not is_city(): return super.attack_base(result)
	if result.kind == Kind.ULTIMATE: return CITY_ULTIMATE_DAMAGE
	# A city is not a humanoid: triple 1 deals five regular attacks instead.
	return regular_attack_power() * 5 if result.kind == Kind.SPECIAL and result.face == 1 else super.attack_base(result)

func attack_damage(result: Dictionary, target: int = -1) -> int:
	if not is_city(): return super.attack_damage(result, target)
	if not is_attack(result): return 0
	if result.kind == Kind.ULTIMATE: return mini(city_hp, CITY_ULTIMATE_DAMAGE)
	return mini(city_hp, floori(attack_base(result) * damage_multiplier() * power * attack_multiplier() * 2.0))

func siege_damage(result: Dictionary) -> int:
	return attack_damage(result, -2)

func damage_caption(result: Dictionary, primary: int = -1) -> String:
	if not is_city(): return super.damage_caption(result, primary)
	if not is_attack(result): return ""
	var base: int = floori(attack_base(result))
	var modifier: int = siege_damage(result)-base
	return "%d + %s (x%d)" % [base, "(%d)" % modifier if modifier < 0 else str(modifier), hit_count(result)]

func player_target() -> int:
	if not is_city(): return super.player_target()
	return -2 if phase in ["player", "executing"] and is_attack(pending) and outcome().is_empty() else -1

func _finish_player_action(result: Dictionary) -> void:
	var bonus: bool = not bonus_resume.is_empty()
	super._finish_player_action(result)
	if bonus: return
	if is_city():
		# Siege has no discrete enemy phase: preserve its complete roll intervals.
		if result.kind == Kind.PAIR and result.face == 6: buff_ticks.erase(6)
		_end_buff_turn()
		phase = "round_end" if outcome().is_empty() else "finished"

func apply_player_step(primary: int = -1) -> Array:
	if not is_city(): return super.apply_player_step(primary)
	if phase not in ["player", "executing"] or pending.is_empty() or not outcome().is_empty(): return []
	var result: Dictionary = pending.duplicate(true)
	if not is_attack(result):
		var support: Array = _apply_support(result)
		_finish_player_action(result)
		return support
	if phase == "player": pending["hits_left"] = hit_count(result)
	phase = "executing"
	var damage: int = siege_damage(result)
	city_hp -= damage
	var events: Array = [event(-2, damage, "damage", "SIEGE")]
	var crushed: int = 0
	if hits_all(result): crushed = troops
	elif result.kind in [Kind.PAIR, Kind.SPECIAL] and result.face == 5: crushed = mini(troops, 1)
	if crushed > 0:
		troops -= crushed
		var sweep: Dictionary = event(-2, crushed, "sweep", "TROOPS CRUSHED")
		sweep["first"] = troops
		events.append(sweep)
	pending.hits_left -= 1
	if pending.hits_left <= 0 or not outcome().is_empty():
		if result.kind == Kind.ULTIMATE: events.append(event(-1, heal(12), "heal", "+12 HP"))
		_finish_player_action(result)
	return events

func tick_city(delta: float) -> Array:
	var events: Array = []
	if not is_city() or not outcome().is_empty() or delta <= 0:
		return events
	# Bounded fixed steps keep damage independent of frame rate and prevent a
	# window stall from delivering an unbounded batch of invisible attacks.
	var remaining: float = minf(delta, 0.25)
	while remaining > 0 and outcome().is_empty():
		var step: float = minf(remaining, 0.05)
		remaining -= step
		spawn_clock -= step
		volley_clock -= step
		troop_clock -= step
		if spawn_clock <= 0:
			spawn_clock += 2.5
			troops = mini(6, troops + 2)
			events.append(event(-2, troops, "spawn", "REINFORCEMENTS"))
		if volley_clock <= 0.8 and not volley_warned:
			volley_warned = true
			events.append(event(-2, 0, "warning", "VOLLEY"))
		if volley_clock <= 0:
			volley_clock += 4.0
			volley_warned = false
			events.append(event(-2, 0, "volley", "VOLLEY"))
			events.append_array(_city_hit(7))
		if troop_clock <= 0 and outcome().is_empty():
			troop_clock += 1.5
			if troops > 0:
				events.append_array(_city_hit(troops))
	return events

func _city_hit(amount: int) -> Array:
	if buffs[6] > 0: return [event(-1, 0, "immune", "INVINCIBLE")]
	var blocked: int = mini(shield, amount)
	shield -= blocked
	var loss: int = mini(hp, amount - blocked)
	hp -= loss
	if not outcome().is_empty(): phase = "finished"
	return [event(-1, loss, "damage", "CITY ATTACK")]
