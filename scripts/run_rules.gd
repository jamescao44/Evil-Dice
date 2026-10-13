extends "res://scripts/battle_rules.gd"
## Run progression and real-time siege. No presentation state or wall-clock calls.
const Rewards = preload("res://scripts/reward_catalog.gd")
const Tarot = preload("res://scripts/tarot_catalog.gd")
const TarotInventory = preload("res://scripts/tarot_inventory.gd")
signal tarot_granted(item: Dictionary)
var tarots = TarotInventory.new()
var wave_tarots: Array = []
var chest_tarots: Dictionary = {}
var tarot_choices: Array = []
var tarot_source: String = ""
var tarot_slot: int = -1
const Waves = preload("res://scripts/wave_catalog.gd")
const WAVE_NAMES := ["OUTSKIRTS","OLD ROAD","THE CHAMPION","CROSSROADS","WATCH POST","WAR CAMP","CITY ROAD","ELITE GUARD","LAST STAND","THE PALADIN","HOLY ESCORT","ELITE COMPANY","THE HIGH PRIEST","SACRED ALLIANCE","GOLDEN GUARD","RITUAL PROCESSION","TWIN SENTINELS","CATHEDRAL GUARD","THE INNER SANCTUM","THE CITY"]
static var WAVE_COUNTS: Array = Waves.counts()
const WAVE_BOOSTS := [1.0,1.0,1.5,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25]
const CITY_MAX_HP := Waves.CITY_HP
const CITY_ULTIMATE_DAMAGE := 2000
const CITY_IMMUNITY_SECONDS_PER_STACK := 2.0
var city_immunity_clock: float = 0.0
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
var reward_weights: Array = Rewards.DEFAULT_WEIGHTS.duplicate()
var open_rewards: Array = []
var chest_relics: Dictionary = {}
var reward_history: Array = []
var rubies: int = 0 # Stable internal currency key; displayed as Soul Crystals.
var soul_crystal_remainder: float = 0.0
var summon_shards: int = 0
var reward_rng := RandomNumberGenerator.new()
var relic_choices: Array = []
var relic_offer_resolved: bool = true
var relic_reward_stage: int = -1

func soul_crystal_gain_preview(amount: int) -> int:
	return floori(amount*RelicEffects.currency_factor(relics.items)+soul_crystal_remainder+0.000001)

func gain_soul_crystals(amount: int) -> int:
	if amount <= 0: return 0
	var total: float = RelicEffects.currency_bonus(self,amount)+soul_crystal_remainder
	var gained: int = floori(total+0.000001)
	soul_crystal_remainder = maxf(0,total-gained)
	rubies += gained
	return gained

func grant_random_tarots(count: int) -> Array:
	var granted: Array = []
	for i in range(count):
		var id: String = Tarot.draw_one(reward_rng,tarot_effects.banned)
		if id.is_empty(): break
		granted.append(grant_tarot(id))
	return granted

func grant_tarot(id: String) -> Dictionary:
	var item: Dictionary = tarots.add(id)
	if not item.is_empty(): tarot_granted.emit(item.duplicate())
	return item

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
	city_immunity_clock = 0.0
	perfect_progress = 0
	perfect_total = 0
	claimed_slots.clear()
	reward_weights = Rewards.DEFAULT_WEIGHTS.duplicate()
	open_rewards.clear()
	chest_relics.clear()
	reward_history.clear()
	rubies = 0
	soul_crystal_remainder = 0.0
	summon_shards = 0
	relic_choices.clear()
	relic_offer_resolved = true
	relic_reward_stage = -1
	tarots.clear()
	wave_tarots.clear()
	chest_tarots.clear()
	_clear_tarot_draw()
	_load_wave()

func record_perfect(perfect: bool) -> void:
	super.record_perfect(perfect)
	# Accepted throws only. Misses/waves preserve progress; a full bank holds nine.
	if not perfect or RelicEffects.has_flag(relics.items,"no_treasure"): return
	perfect_total += 1
	perfect_progress = mini(9, perfect_progress + 1)

func load_debug_wave(wave_number: int) -> bool:
	if wave_number < 1 or wave_number > WAVE_NAMES.size(): return false
	reset_run()
	stage = wave_number - 1
	max_hp = MAX_HP + stage * 30
	hp = max_hp
	power = 1.0
	if stage > 0: _load_wave()
	return true

func chest_tier() -> int:
	return clampi(perfect_progress / 3, 0, 3)

func open_chest(requested_tier: int = 0) -> Array:
	if not open_rewards.is_empty(): return open_rewards.duplicate()
	var tier: int = chest_tier() if requested_tier == 0 else requested_tier
	if tier < 1 or tier > 3 or tier > chest_tier(): return []
	# Any claimed milestone empties the bank, including extra unspent diamonds.
	perfect_progress = 0
	return _roll_chest(tier)

func open_bonus_chest() -> Array:
	if not open_rewards.is_empty() or tarot_effects.bonus_chests.is_empty(): return []
	return _roll_chest(tarot_effects.bonus_chests.pop_front())

func _roll_chest(tier: int) -> Array:
	claimed_slots.clear()
	# Resolve every category, rarity and concrete relic before presentation starts.
	for i in range(CHEST_COUNTS[tier]):
		var index: int = Rewards.draw_category(reward_rng,reward_weights)
		if index == Rewards.Category.RELIC:
			# Replace one relic slot per treasure. Currency rolls are unchanged.
			if chest_tarots.is_empty():
				index = Rewards.Category.TAROT
				chest_tarots[i] = Tarot.draw_choices(reward_rng,tarot_effects.banned)
			else:
				var id: String = relics.draw_one(reward_rng,chest_relics.values(),relic_drop_weights())
				if id.is_empty(): index = Rewards.Category.RUBY
				else:
					chest_relics[i] = id
					if Relics.Catalog.ITEMS[id].rarity == Relics.Catalog.Rarity.CURSED: index = Rewards.Category.CURSE
		open_rewards.append(index)
	return open_rewards.duplicate()

func reward_item(slot: int) -> Dictionary:
	if slot < 0 or slot >= open_rewards.size(): return {}
	var item: Dictionary = Rewards.ITEMS[open_rewards[slot]].duplicate()
	if chest_relics.has(slot):
		var id: String = chest_relics[slot]
		item.name = Relics.Catalog.ITEMS[id].name
		item.text = Relics.Catalog.ITEMS[id].text
		item.color = Relics.Catalog.rarity_color(id)
		item.relic_id = id
	return item

func claim_reward(slot: int, replace_index: int = -1, discard: bool = false) -> Dictionary:
	if not tarot_source.is_empty(): return {}
	if slot < 0 or slot >= open_rewards.size() or slot in claimed_slots: return {}
	var index: int = open_rewards[slot]
	if index in Rewards.RETIRED_CATEGORIES and not discard: return {}
	if index == Rewards.Category.TAROT and not discard: return {} # Resolved by choose_tarot.
	var item: Dictionary = reward_item(slot)
	if item.has("relic_id") and not discard and not acquire_relic(item.relic_id, replace_index): return {}
	claimed_slots.append(slot)
	if discard:
		item.id = "discard"
		item.name = "LEFT BEHIND"
		item.text = "Relic discarded."
		return item
	match item.id:
		"ruby":
			item.text = "+%d soul crystals"
			item.text_values = [gain_soul_crystals(100)]
		"shard": summon_shards += 1
	reward_history.append(index)
	return item.duplicate()

func discard_unclaimed_rewards() -> int:
	if not tarot_source.is_empty(): return 0
	# Resolve remaining slots without applying rewards, history entries or RNG.
	var discarded: int = 0
	for slot in range(open_rewards.size()):
		if slot not in claimed_slots:
			claim_reward(slot,-1,true)
			discarded += 1
	return discarded

func rewards_collected() -> bool:
	return not open_rewards.is_empty() and claimed_slots.size() == open_rewards.size()

func close_chest() -> bool:
	if not rewards_collected(): return false
	open_rewards.clear()
	chest_relics.clear()
	chest_tarots.clear()
	claimed_slots.clear()
	return true

func auto_claim_victory_chest() -> int:
	if outcome() != "victory" or not open_rewards.is_empty(): return 0
	var tier: int = chest_tier()
	if tier == 0: return 0
	# Claim the chest automatically, but leave its locked gifts for the reels
	# and individual player pickups, just like a manually opened chest.
	open_chest(tier)
	return tier

func is_city() -> bool:
	return stage == Waves.CITY_STAGE

func relic_drop_weights() -> Array:
	return Relics.Drops.weights_for_wave(stage+1)

func roll(throw_power: float = 0.0, perfect: bool = false, _fever: bool = false) -> MultiHitSkill:
	return super.roll(throw_power, perfect, is_city())

func damage_cap(kind: int, target: int) -> int:
	var numerator: float = 2.0 if kind == Kind.SPECIAL else 1.0
	return maxi(1, floori(enemies[target].max_hp * numerator * WAVE_BOOSTS[stage] / 3.0))

func _load_wave() -> void:
	city_immunity_clock = 0.0
	enemies = Waves.create(stage,rng)
	pending = Skill.new()
	phase = "new"

func outcome() -> String:
	if hp <= 0:
		return "defeat"
	if has_pending_attack_hits(): return ""
	if is_city():
		return "victory" if city_hp <= 0 else ""
	return "wave_clear" if not has_living_enemies() else ""

func advance_wave() -> bool:
	if outcome() != "wave_clear" or not relic_offer_resolved:
		return false
	_record_relic_wave_clear()
	_end_buff_turn()
	stage += 1
	base_max_hp += 30
	heal(55) # Increased capacity plus a modest recovery from feeding.
	power = 1.0
	_load_wave()
	return true

func _record_relic_wave_clear() -> void:
	if relic_reward_stage == stage: return
	relic_reward_stage = stage
	gain_soul_crystals(RelicEffects.wave_cleared(self))

func open_relic_offer() -> Array:
	if not relic_offer_resolved: return relic_choices.duplicate()
	if outcome() not in ["wave_clear", "victory"] or relic_reward_stage == stage: return []
	_record_relic_wave_clear()
	relic_choices = relics.offers(reward_rng,2,relic_drop_weights())
	wave_tarots = Tarot.draw_choices(reward_rng,tarot_effects.banned)
	relic_offer_resolved = false
	return relic_choices.duplicate()

func choose_relic(index: int, replace_index: int = -1) -> bool:
	if not tarot_source.is_empty(): return false
	if relic_offer_resolved or index < 0 or index >= relic_choices.size(): return false
	if not acquire_relic(relic_choices[index], replace_index): return false
	relic_offer_resolved = true
	relic_choices.clear()
	wave_tarots.clear()
	return true

func skip_relic() -> bool:
	if not tarot_source.is_empty(): return false
	if relic_offer_resolved: return false
	gain_soul_crystals(10)
	relic_offer_resolved = true
	relic_choices.clear()
	wave_tarots.clear()
	return true

func begin_tarot_reward(source: String, slot: int = -1) -> Array:
	# A transaction stays pending until a revealed card is chosen. All candidates
	# were locked when the parent reward opened; taps never consume reward RNG.
	if not tarot_source.is_empty(): return []
	if source == "wave":
		if relic_offer_resolved or wave_tarots.is_empty(): return []
		tarot_choices = wave_tarots.duplicate()
	elif source == "chest":
		if slot in claimed_slots or not chest_tarots.has(slot): return []
		tarot_choices = chest_tarots[slot].duplicate()
	elif source == "debug":
		tarot_choices = Tarot.draw_choices(reward_rng,tarot_effects.banned)
		if tarot_choices.is_empty(): return []
	else: return []
	tarot_source = source
	tarot_slot = slot
	return tarot_choices.duplicate()

func choose_tarot(index: int) -> Dictionary:
	if tarot_source.is_empty() or index < 0 or index >= tarot_choices.size(): return {}
	var item: Dictionary = tarots.add(tarot_choices[index])
	if item.is_empty(): return {}
	if tarot_source == "wave":
		relic_offer_resolved = true
		relic_choices.clear()
		wave_tarots.clear()
	elif tarot_source == "chest":
		claimed_slots.append(tarot_slot)
		reward_history.append(Rewards.Category.TAROT)
	_clear_tarot_draw()
	return item

func _clear_tarot_draw() -> void:
	tarot_choices.clear()
	tarot_source = ""
	tarot_slot = -1

func begin_round() -> Array:
	if not is_city():
		return super.begin_round()
	if not outcome().is_empty() or phase not in ["new", "round_end"]:
		return []
	tarot_effects.begin_round()
	round_number += 1
	relic_turn_closed = false
	var events: Array = []
	if statuses[2].count > 0:
		buff_ticks[2] = true
		events.append(event(-1, heal(roundi(5*statuses[2].potency)), "heal", "REGROWTH"))
	_prepare_player_turn()
	return events

func is_instant_kill(result: MultiHitSkill) -> bool:
	return not is_city() and super.is_instant_kill(result)

func attack_base_with_bonus(result: MultiHitSkill, bonus: float) -> float:
	if not is_city(): return super.attack_base_with_bonus(result,bonus)
	if result.kind == Kind.ULTIMATE: return CITY_ULTIMATE_DAMAGE + bonus
	# A city is not a humanoid: triple 1 deals five regular attacks instead.
	return (regular_base_damage() + bonus) * 5 if result.kind == Kind.SPECIAL and result.face == 1 else super.attack_base_with_bonus(result,bonus)

func attack_damage(result: MultiHitSkill, target: int = -1) -> int:
	if not is_city(): return super.attack_damage(result, target)
	if not is_attack(result): return 0
	return mini(city_hp,unmitigated_damage(result))

func siege_damage(result: MultiHitSkill) -> int:
	return attack_damage(result, -2)

func damage_caption(result: MultiHitSkill, primary: int = -1) -> String:
	if not is_city(): return super.damage_caption(result, primary)
	if not is_attack(result): return ""
	var base: int = floori(attack_base(result))
	var modifier: int = unmitigated_damage(result)-base
	return "%d + %s (x%d)" % [base, "(%d)" % modifier if modifier < 0 else str(modifier), skill_use_count(result)]

func player_target() -> int:
	if not is_city(): return super.player_target()
	return -2 if phase in ["player", "executing"] and is_attack(pending) and outcome().is_empty() else -1

func _finish_player_action(result: MultiHitSkill) -> void:
	var bonus: bool = not bonus_resume.is_empty()
	super._finish_player_action(result)
	if bonus or phase == "roll": return
	if is_city():
		# Siege has no discrete enemy phase: preserve its complete roll intervals.
		if outcome().is_empty(): _begin_turn_end()
		else:
			_end_buff_turn()
			phase = "finished"

func _apply_support(result: MultiHitSkill) -> Array:
	var protected_before: bool = status_count(Status.IMMUNITY) > 0
	var events: Array = super._apply_support(result)
	if is_city() and result.kind == Kind.PAIR and result.face == 6 and not protected_before:
		city_immunity_clock = 0.0
	return events

func _boon_shockwave(result: MultiHitSkill, base_damage: float) -> Array:
	var events: Array = super._boon_shockwave(result,base_damage)
	if is_city() and troops > 0:
		events.append(event(-2,troops,"sweep","TROOPS CRUSHED"))
		troops = 0
	return events

func _end_buff_turn() -> void:
	# City immunity expires on elapsed time, including between throws.
	if is_city(): buff_ticks.erase(Status.IMMUNITY)
	super._end_buff_turn()

func city_immunity_seconds() -> float:
	return maxf(0.0, status_count(Status.IMMUNITY)*CITY_IMMUNITY_SECONDS_PER_STACK-city_immunity_clock)

func _tick_city_immunity(delta: float) -> void:
	if status_count(Status.IMMUNITY) == 0:
		city_immunity_clock = 0.0
		return
	city_immunity_clock += maxf(0,delta)
	while city_immunity_clock >= CITY_IMMUNITY_SECONDS_PER_STACK-0.000001 and status_count(Status.IMMUNITY) > 0:
		city_immunity_clock = maxf(0,city_immunity_clock-CITY_IMMUNITY_SECONDS_PER_STACK)
		statuses[Status.IMMUNITY].consume()
	if status_count(Status.IMMUNITY) == 0: city_immunity_clock = 0.0

func apply_player_step(primary: int = -1) -> Array:
	if not is_city(): return super.apply_player_step(primary)
	if phase not in ["player", "executing"] or pending.is_empty() or not outcome().is_empty(): return []
	if phase == "player": begin_player_cast()
	var result: MultiHitSkill = pending.duplicate()
	var events: Array = []
	if not is_attack(result): events = _apply_support(result)
	else:
		lifesteal_used = 0
		var damage: int = unmitigated_damage(result)
		var loss: int = mini(city_hp,damage)
		var ruined: bool = city_hp <= 0
		city_hp -= loss
		var impact: Dictionary = damage_event(-2,loss,damage)
		impact.corpse_hit = ruined
		events.append(impact)
		if loss > 0: events.append_array(_attack_relic_effects(-2,loss,result))
		var crushed: int = troops if hits_all(result) else mini(troops, 1) if result.random_target_per_use() else 0
		if crushed > 0:
			troops -= crushed
			var sweep: Dictionary = event(-2, crushed, "sweep", "TROOPS CRUSHED")
			sweep["first"] = troops
			events.append(sweep)
	if result.is_attack(): events.append_array(RelicEffects.attack_used(self))
	_complete_skill_use(result, events)
	return events

func tick_city(delta: float, immunity_delta: float = -1.0) -> Array:
	var events: Array = []
	if not is_city() or city_hp <= 0 or not outcome().is_empty():
		return events
	var elapsed: float = maxf(0,delta if immunity_delta < 0 else immunity_delta)
	if delta <= 0:
		_tick_city_immunity(elapsed)
		return events
	# Bounded fixed steps keep damage independent of frame rate and prevent a
	# window stall from delivering an unbounded batch of invisible attacks.
	var remaining: float = minf(delta, 0.25)
	var immunity_rate: float = elapsed/remaining
	while remaining > 0 and outcome().is_empty():
		var step: float = minf(remaining, 0.05)
		remaining -= step
		_tick_city_immunity(step*immunity_rate)
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
			if status_count(Status.HIDDEN) == 0: events.append(event(-2, 0, "volley", "VOLLEY"))
			events.append_array(_city_hit(7))
		if troop_clock <= 0 and outcome().is_empty():
			troop_clock += 1.5
			if troops > 0:
				events.append_array(_city_hit(troops))
	return events

func _city_hit(amount: int) -> Array:
	var events: Array = receive_damage(amount,false,-2)
	if not outcome().is_empty(): phase = "finished"
	return events
