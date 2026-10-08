extends "res://scripts/battle_rules.gd"
## Run progression and real-time siege. No presentation state or wall-clock calls.
const WAVE_NAMES := ["OUTSKIRTS", "OLD ROAD", "CITY GATES", "LAST COMPANY", "THE CITY"]
const WAVE_ROLES := [[0], [0, 1, 2], [0, 1, 0, 2, 1], [0, 1, 2, 1, 0, 2, 0, 1]]
const WAVE_BOOSTS := [1.0, 1.0, 1.5, 2.25, 2.25]
const CITY_MAX_HP := 2400
const CITY_ULTIMATE_DAMAGE := CITY_MAX_HP / 3
var stage: int = 0
var city_hp: int = CITY_MAX_HP
var troops: int = 0
var spawn_clock: float = 2.5
var volley_clock: float = 4.0
var troop_clock: float = 1.5
var volley_warned: bool = false

func _init(seed_value: int = -1) -> void:
	super(seed_value)
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
	_load_wave()

func is_city() -> bool:
	return stage == WAVE_ROLES.size()

func roll(throw_power: float = 0.0, perfect: bool = false, _fever: bool = false) -> Dictionary:
	return super.roll(throw_power, perfect, is_city())

func damage_cap(kind: int, target: int) -> int:
	var numerator: float = 2.0 if kind == Kind.SPECIAL else 1.0
	return floori(enemies[target].max_hp * numerator * WAVE_BOOSTS[stage] / 3.0)

func _load_wave() -> void:
	enemies.clear()
	if not is_city():
		for role in WAVE_ROLES[stage]:
			var enemy: Dictionary = make_enemy(role, 1.0 + stage * 0.35)
			# At this scale individual adventurers are weaker, but all eight act.
			if stage == 3: enemy.damage = [1,2,1][role]
			enemies.append(enemy)
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
		buffs[2] -= 1
		events.append(event(-1, heal(5), "heal", "REGROWTH"))
	phase = "roll"
	return events

func siege_damage(result: Dictionary) -> int:
	if not is_attack(result): return 0
	if result.kind == Kind.ULTIMATE: return mini(city_hp, CITY_ULTIMATE_DAMAGE)
	# A city is not a humanoid: triple 1 deals five regular attacks instead.
	var base: float = REGULAR_ATTACK_POWER * 5 if result.kind == Kind.SPECIAL and result.face == 1 else attack_base(result)
	return mini(city_hp, floori(base * DAMAGE_MULTIPLIER * power * attack_multiplier() * 2.0))

func player_target() -> int:
	if not is_city(): return super.player_target()
	return -2 if phase in ["player", "executing"] and is_attack(pending) and outcome().is_empty() else -1

func _finish_player_action(result: Dictionary) -> void:
	super._finish_player_action(result)
	if is_city(): phase = "round_end" if outcome().is_empty() else "finished"

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
