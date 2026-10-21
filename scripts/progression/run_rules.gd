extends "res://scripts/combat/battle_rules.gd"
## Run progression and real-time siege. No presentation state or wall-clock calls.
const Chests = preload("res://scripts/rewards/chest_rules.gd")
const ChestPity = preload("res://scripts/rewards/chest_pity.gd")
var chest_pity = ChestPity.new() # Meta progression: deliberately survives reset_run().
const Rewards = preload("res://scripts/rewards/reward_catalog.gd")
const Tarot = preload("res://scripts/tarot/tarot_catalog.gd")
const TarotInventory = preload("res://scripts/tarot/tarot_inventory.gd")
signal tarot_granted(item: Dictionary)
signal character_leveled(level: int)
## Already credited; the view animates a receipt, never owns the reward transaction.
## Nonnegative targets are enemies; -3-index identifies a defeated city troop.
signal enemy_crystals_dropped(target: int, amount: int)
var tarots = TarotInventory.new()
var wave_tarots: Array = []
var chest_tarots: Dictionary = {}
var tarot_choices: Array = []
var tarot_source: String = ""
var tarot_slot: int = -1
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const WAVE_NAMES := ["OUTSKIRTS","OLD ROAD","THE CHAMPION","CROSSROADS","WATCH POST","WAR CAMP","CITY ROAD","ELITE GUARD","LAST STAND","THE PALADIN","HOLY ESCORT","ELITE COMPANY","THE HIGH PRIEST","SACRED ALLIANCE","GOLDEN GUARD","RITUAL PROCESSION","TWIN SENTINELS","CATHEDRAL GUARD","THE INNER SANCTUM","THE CITY"]
static var WAVE_COUNTS: Array = Waves.counts()
const WAVE_BOOSTS := [1.0,1.0,1.5,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25,2.25]
const CITY_FEVER_ENABLED := false
const LAST_PLAYABLE_STAGE := Waves.CITY_STAGE - 1
const PLAYABLE_WAVES := Waves.COUNT if CITY_FEVER_ENABLED else LAST_PLAYABLE_STAGE + 1
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
var reroll_progress: int = 0
var treasure_settled_turn: int = -1
var perfect_total: int = 0
const CHEST_THRESHOLDS := Chests.THRESHOLDS
const CHEST_COUNTS := Chests.COUNTS
var opened_chest_tier: int = -1
var chest_crystals_claimed: bool = false
var chest_crystals: int = 0
var chest_crystal_base_paid: int = 0
var guaranteed_slot: int = -1
var wave_chest_stage: int = -1
var wave_chest_tier: int = -1
var wave_chest_opened: bool = false
var wave_tarot_bought: bool = false
var claimed_slots: Array = []
var reward_weights: Array = Rewards.DEFAULT_WEIGHTS.duplicate()
var open_rewards: Array = []
var chest_relics: Dictionary = {}
var reward_history: Array = []
var blood_gems: int = 0
var souls: int = 0
const WaveRewards = preload("res://scripts/progression/wave_rewards.gd")
const LEVEL_COSTS := [30,50]
const MAX_CHARACTER_LEVEL := 3
const LEVEL_DAMAGE_FACTOR := 1.5
var character_level: int = 1
var wave_kind: String = WaveRewards.RELIC
var wave_amount: int = 0
var route_choices: Array = []
var route_history: Array = [WaveRewards.RELIC]
var next_route: String = ""
var battles_since_shop: int = 0
var first_shop_offered: bool = false
var blood_gem_remainder: float = 0.0
var summon_shards: int = 0
var reward_rng := RandomNumberGenerator.new()
var wave_reward_resolved: bool = true
var relic_reward_stage: int = -1
const ShopStock = preload("res://scripts/rewards/shop_stock.gd")
var shop = ShopStock.new()

func blood_gem_gain_preview(amount: int) -> int:
	return floori(amount*RelicEffects.currency_factor(relics.items)+blood_gem_remainder+0.000001)

## Grant currency with Soul Vessel bonuses and fractional carry.
func gain_blood_gems(amount: int) -> int:
	if amount <= 0: return 0
	var total: float = RelicEffects.currency_bonus(self,amount)+blood_gem_remainder
	var gained: int = floori(total+0.000001)
	blood_gem_remainder = maxf(0,total-gained)
	blood_gems += gained
	return gained

## Keep run-leveling souls separate from shop currency and currency-boosting relics.
func gain_souls(amount: int) -> int:
	var gained := maxi(0,amount)
	souls += gained
	while level_cost() > 0 and souls >= level_cost():
		if not level_up(): break
	return gained

## Award enemy-drop crystals exactly once when a hit causes a death.
func hit_enemy(index: int, damage: int, ignore: bool = false) -> int:
	var alive_before: bool = is_enemy_alive(index)
	var loss: int = super.hit_enemy(index,damage,ignore)
	if alive_before and not is_enemy_alive(index):
		var amount: int = gain_blood_gems(EnemyCatalog.crystal_reward(enemies[index]))
		enemy_crystals_dropped.emit(index,amount)
	return loss

func _crush_troops(count: int) -> Dictionary:
	var crushed: int = clampi(count,0,troops)
	troops -= crushed
	for i in range(troops,troops+crushed):
		enemy_crystals_dropped.emit(-3-i,gain_blood_gems(EnemyCatalog.crystal_reward({"role":i%3,"elite":false})))
	var sweep: Dictionary = event(-2,crushed,"sweep","TROOPS CRUSHED")
	sweep["first"] = troops
	return sweep

## Draw eligible tarot rewards with reward RNG and announce each granted card.
func grant_random_tarots(count: int) -> Array:
	var granted: Array = []
	for i in range(count):
		var id: String = Tarot.draw_one(reward_rng,tarot_effects.banned)
		if id.is_empty(): break
		granted.append(grant_tarot(id))
	return granted

## Add one tarot instance and emit its inventory-pickup notification.
func grant_tarot(id: String) -> Dictionary:
	var item: Dictionary = tarots.add(id)
	if not item.is_empty(): tarot_granted.emit(item.duplicate())
	return item

func _init(seed_value: int = -1) -> void:
	super(seed_value)
	if seed_value < 0: reward_rng.randomize()
	else: reward_rng.seed = seed_value + 7919
	reset_run()

## Start a fresh run while retaining persistent chest pity.
func reset_run() -> void:
	super.reset()
	shop.reset()
	stage = 0
	city_hp = CITY_MAX_HP
	troops = 0
	spawn_clock = 2.5
	volley_clock = 4.0
	troop_clock = 1.5
	volley_warned = false
	city_immunity_clock = 0.0
	reroll_progress = 0
	treasure_settled_turn = -1
	perfect_total = 0
	opened_chest_tier = -1
	chest_crystals_claimed = false
	chest_crystals = 0
	chest_crystal_base_paid = 0
	guaranteed_slot = -1
	wave_chest_stage = -1
	wave_chest_tier = -1
	wave_chest_opened = false
	wave_tarot_bought = false
	claimed_slots.clear()
	reward_weights = Rewards.DEFAULT_WEIGHTS.duplicate()
	open_rewards.clear()
	chest_relics.clear()
	reward_history.clear()
	blood_gems = 0
	souls = 0
	character_level = 1
	wave_kind = WaveRewards.BATTLE_TYPES[reward_rng.randi_range(0,WaveRewards.BATTLE_TYPES.size()-1)]
	wave_amount = 0
	route_choices.clear()
	route_history = [wave_kind]
	next_route = ""
	battles_since_shop = 0
	first_shop_offered = false
	blood_gem_remainder = 0.0
	summon_shards = 0
	wave_reward_resolved = true
	relic_reward_stage = -1
	tarots.clear()
	wave_tarots.clear()
	chest_tarots.clear()
	_clear_tarot_draw()
	_load_wave()

## Keep Perfect statistics and combat bonuses independent of treasure earnings.
func record_perfect(perfect: bool) -> void:
	super.record_perfect(perfect)
	if perfect: perfect_total += 1

## Bank unused throws once per completed turn; untouched or frozen turns earn none.
func _bank_unused_rolls() -> void:
	if treasure_settled_turn == dice_turn.turn_id or dice_turn.rolls_left >= DiceTurn.ROLLS: return
	treasure_settled_turn = dice_turn.turn_id
	if hp <= 0 or RelicEffects.has_flag(relics.items,"no_treasure"): return
	reroll_progress = mini(CHEST_THRESHOLDS[-1],reroll_progress + maxi(0,dice_turn.rolls_left))

## Bank this completed pool before a bonus turn restores its three throws.
func _grant_dice_bonus_turn() -> void:
	_bank_unused_rolls()
	super._grant_dice_bonus_turn()

## Settle treasure after enemy/status resolution, or when a player action clears the wave.
func _complete_relic_turn() -> Array:
	if not relic_turn_closed: _bank_unused_rolls()
	return super._complete_relic_turn()

## Reset combat and progression to a validated wave number.
func load_debug_wave(wave_number: int) -> bool:
	if wave_number < 1 or wave_number > WAVE_NAMES.size(): return false
	reset_run()
	stage = wave_number - 1
	max_hp = MAX_HP
	battles_since_shop = stage
	hp = max_hp
	power = 1.0
	if stage > 0: _load_wave()
	return true

func chest_tier() -> int:
	return Chests.tier_for_progress(reroll_progress)

func open_chest(requested_tier: int = 0) -> Array:
	if not open_rewards.is_empty(): return open_rewards.duplicate()
	var tier: int = chest_tier() if requested_tier == 0 else requested_tier
	if tier < 1 or tier > 3 or tier > chest_tier(): return []
	# Any claimed milestone empties the bank, including extra unspent diamonds.
	reroll_progress = 0
	return _roll_chest(tier)

func open_bonus_chest() -> Array:
	if not open_rewards.is_empty() or tarot_effects.bonus_chests.is_empty(): return []
	return _roll_chest(tarot_effects.bonus_chests.pop_front())

func open_debug_chest() -> Array:
	if not open_rewards.is_empty() or not tarot_source.is_empty(): return []
	# Same upgrade odds and locked prizes as a wave chest, without clearing a wave.
	return _roll_chest(chest_pity.roll(reward_rng))

## Commit chest categories, guaranteed relics and tarot candidates before animation.
func _roll_chest(tier: int) -> Array:
	if not open_rewards.is_empty(): return open_rewards.duplicate()
	opened_chest_tier = clampi(tier,0,3)
	chest_crystals_claimed = false
	chest_crystals = 0
	chest_crystal_base_paid = 0
	claimed_slots.clear()
	chest_relics.clear()
	chest_tarots.clear()
	var count: int = CHEST_COUNTS[opened_chest_tier]
	guaranteed_slot = reward_rng.randi_range(0,count-1) if opened_chest_tier > 0 else -1
	# Reserve the guarantee first, so other slots cannot exhaust its eligible pool.
	if guaranteed_slot >= 0:
		var guaranteed: String = relics.draw_one(reward_rng,[],Relics.Catalog.RARITY_WEIGHTS,Chests.MIN_RARITY[opened_chest_tier])
		if not guaranteed.is_empty(): chest_relics[guaranteed_slot] = guaranteed
	for i in range(count):
		var index: int = Rewards.Category.RELIC if chest_relics.has(i) else Rewards.draw_category(reward_rng,reward_weights)
		if index == Rewards.Category.RELIC:
			var id: String = chest_relics.get(i,"")
			if id.is_empty(): id = relics.draw_one(reward_rng,chest_relics.values(),Relics.Catalog.RARITY_WEIGHTS)
			if id.is_empty(): index = Rewards.Category.RUBY # An exhausted eligible relic pool converts to currency.
			else:
				chest_relics[i] = id
				if Relics.Catalog.ITEMS[id].rarity == Relics.Catalog.Rarity.CURSED: index = Rewards.Category.CURSE
		open_rewards.append(index)
	return open_rewards.duplicate()

## Pay only the newly revealed chest tier’s outstanding crystal amount.
func release_chest_crystals(revealed_tier: int = -1) -> int:
	# Pay only the publicly revealed tier. Upgrades pay the difference, never
	# leaking the locked final tier through the currency counter or its particles.
	if opened_chest_tier < 0 or chest_crystals_claimed: return 0
	var tier: int = opened_chest_tier if revealed_tier < 0 else clampi(revealed_tier,0,opened_chest_tier)
	var base: int = Chests.CRYSTALS[tier]
	var gained: int = gain_blood_gems(maxi(0,base-chest_crystal_base_paid))
	chest_crystal_base_paid = maxi(chest_crystal_base_paid,base)
	chest_crystals += gained
	chest_crystals_claimed = tier == opened_chest_tier
	return gained

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

## Apply one locked reward, respecting replacement and duplicate-claim guards.
func claim_reward(slot: int, replace_index: int = -1, discard: bool = false) -> Dictionary:
	if not tarot_source.is_empty(): return {}
	if slot < 0 or slot >= open_rewards.size() or slot in claimed_slots: return {}
	var index: int = open_rewards[slot]
	if index in Rewards.RETIRED_CATEGORIES and index != Rewards.Category.RUBY and not discard: return {}
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
			item.text = "+%d blood gems"
			item.text_values = [gain_blood_gems(100)]
		"shard": summon_shards += 1
	reward_history.append(index)
	return item.duplicate()

## Skip remaining prizes while preserving already collected rewards.
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
	release_chest_crystals()
	open_rewards.clear()
	chest_relics.clear()
	chest_tarots.clear()
	claimed_slots.clear()
	opened_chest_tier = -1
	guaranteed_slot = -1
	return true

func auto_claim_victory_chest() -> int:
	if outcome() != "victory" or not open_rewards.is_empty(): return 0
	_bank_unused_rolls()
	var tier: int = chest_tier()
	if tier == 0: return 0
	# Claim the chest automatically, but leave its locked gifts for the reels
	# and individual player pickups, just like a manually opened chest.
	open_chest(tier)
	return tier

func is_city() -> bool:
	return stage == Waves.CITY_STAGE

func relic_drop_weights() -> Array:
	return Relics.Catalog.RARITY_WEIGHTS.duplicate()

func roll(throw_power: float = 0.0, perfect: bool = false, _fever: bool = false) -> MultiHitSkill:
	return super.roll(throw_power, perfect, is_city())

func damage_cap(kind: int, target: int) -> int:
	var numerator: float = 2.0 if kind == Kind.SPECIAL else 1.0
	return maxi(1, floori(enemies[target].max_hp * numerator * WAVE_BOOSTS[stage] / 3.0))

func _load_wave() -> void:
	shield = 0 # Straight shields last within this wave only.
	city_immunity_clock = 0.0
	enemies = [] if wave_kind == WaveRewards.SHOP else Waves.create(stage,rng)
	pending = Skill.new()
	phase = "new"

func outcome() -> String:
	if hp <= 0:
		return "defeat"
	if wave_kind == WaveRewards.SHOP and (shop.wave != stage+1 or shop.active): return ""
	if has_pending_attack_hits(): return ""
	if is_city():
		return "victory" if city_hp <= 0 else ""
	if not has_living_enemies():
		return "victory" if not CITY_FEVER_ENABLED and stage >= LAST_PLAYABLE_STAGE else "wave_clear"
	return ""

## Lock two distinct, uniformly sampled eligible destinations once per cleared wave.
func offer_routes() -> Array:
	if outcome() != "wave_clear" or not wave_reward_resolved: return []
	if not route_choices.is_empty(): return route_choices.duplicate()
	var eligible: Array = WaveRewards.TYPES.duplicate()
	if stage < 2 or battles_since_shop < 2: eligible.erase(WaveRewards.SHOP)
	if route_history.size() >= 2 and route_history[-1] == route_history[-2]: eligible.erase(route_history[-1])
	if stage == 2 and not first_shop_offered:
		route_choices.append(WaveRewards.SHOP)
		eligible.erase(WaveRewards.SHOP)
		first_shop_offered = true
	while route_choices.size() < 2 and not eligible.is_empty():
		var index: int = reward_rng.randi_range(0,eligible.size()-1)
		route_choices.append(eligible.pop_at(index))
	if reward_rng.randf() < 0.5: route_choices.reverse()
	return route_choices.duplicate()

## Commit a displayed route once; repeated taps cannot change the destination.
func choose_route(index: int) -> bool:
	if not next_route.is_empty() or index < 0 or index >= route_choices.size(): return false
	next_route = route_choices[index]
	return true

## Enter a chosen battle or a battle-free shop wave without automatic health growth.
func advance_wave() -> bool:
	if outcome() != "wave_clear" or not wave_reward_resolved or shop.active or next_route.is_empty(): return false
	if wave_kind != WaveRewards.SHOP:
		_end_buff_turn()
		heal(25)
	stage += 1
	wave_kind = next_route
	route_history.append(wave_kind)
	next_route = ""
	route_choices.clear()
	if wave_kind == WaveRewards.SHOP: battles_since_shop = 0
	power = 1.0
	_load_wave()
	return true

## Soul levels multiply character base damage before flat relic additions.
func character_damage_factor() -> float:
	return pow(LEVEL_DAMAGE_FACTOR,character_level-1)

func level_cost() -> int:
	return LEVEL_COSTS[character_level-1] if character_level <= LEVEL_COSTS.size() else 0

## Buy one level, restoring only the newly added health capacity.
func level_up() -> bool:
	var cost: int = level_cost()
	if cost <= 0 or souls < cost or hp <= 0: return false
	souls -= cost
	var previous: int = max_hp
	character_level += 1
	base_max_hp = roundi(MAX_HP*pow(1.5,character_level-1))
	hp = mini(max_hp,hp+maxi(0,max_hp-previous))
	character_leveled.emit(character_level)
	return true

func _record_relic_wave_clear() -> void:
	_bank_unused_rolls() # Tarot and other immediate kills may bypass the normal turn-end path.
	if relic_reward_stage == stage: return
	relic_reward_stage = stage
	battles_since_shop += 1
	gain_blood_gems(RelicEffects.wave_cleared(self))

## Commit the wave chest and its upgrade chain once per completed wave.
func begin_wave_reward() -> bool:
	if wave_kind == WaveRewards.SHOP: return false
	if wave_chest_stage == stage: return not wave_reward_resolved
	if outcome() not in ["wave_clear","victory"] or not open_rewards.is_empty(): return false
	_record_relic_wave_clear()
	wave_chest_stage = stage
	wave_chest_tier = chest_pity.roll(reward_rng) if wave_kind == WaveRewards.RELIC else -1
	wave_amount = WaveRewards.amount(reward_rng,wave_kind)
	wave_chest_opened = false
	wave_tarot_bought = false
	wave_reward_resolved = false
	if wave_kind == WaveRewards.RELIC: _roll_chest(wave_chest_tier)
	wave_tarots.clear()
	return true

func open_wave_chest() -> Array:
	if wave_chest_stage != stage or wave_reward_resolved or wave_chest_opened: return []
	wave_chest_opened = true
	return open_rewards.duplicate()

## Opening a resource chest credits its pre-rolled amount exactly once.
func claim_wave_resource() -> int:
	if wave_kind not in [WaveRewards.BLOOD_GEMS,WaveRewards.SOULS] or wave_chest_stage != stage or wave_chest_opened: return 0
	wave_chest_opened = true
	return gain_souls(wave_amount) if wave_kind == WaveRewards.SOULS else gain_blood_gems(wave_amount)

func can_buy_wave_tarot() -> bool:
	return false # Tarot is now acquired from shops and relic effects.

func finish_wave_reward() -> bool:
	if wave_chest_stage != stage or wave_reward_resolved or not wave_chest_opened or not open_rewards.is_empty() or not tarot_source.is_empty(): return false
	wave_reward_resolved = true
	wave_tarots.clear()
	return true

## Reserve the three tarot candidates for a chest or paid wave draw.
func begin_tarot_reward(source: String, slot: int = -1) -> Array:
	# A transaction stays pending until a revealed card is chosen. All candidates
	# were locked when the parent reward opened; taps never consume reward RNG.
	if not tarot_source.is_empty(): return []
	if source == "wave":
		if not can_buy_wave_tarot(): return []
		blood_gems -= Chests.TAROT_PRICE
		wave_tarot_bought = true
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

## Keep one reserved tarot candidate and finish its reward transaction.
func choose_tarot(index: int) -> Dictionary:
	if tarot_source.is_empty() or index < 0 or index >= tarot_choices.size(): return {}
	var item: Dictionary = tarots.add(tarot_choices[index])
	if item.is_empty(): return {}
	if tarot_source == "wave":
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
	if not is_city() or not result.pattern.is_empty(): return super.attack_base_with_bonus(result,bonus)
	if result.kind == Kind.ULTIMATE: return CITY_ULTIMATE_DAMAGE*character_damage_factor() + bonus
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
		events.append(_crush_troops(troops))
	return events

func _end_buff_turn() -> void:
	# City immunity expires on elapsed time, including between throws.
	if is_city(): buff_ticks.erase(Status.IMMUNITY)
	super._end_buff_turn()

func city_immunity_seconds() -> float:
	return maxf(0.0, status_count(Status.IMMUNITY)*CITY_IMMUNITY_SECONDS_PER_STACK-city_immunity_clock)

## Consume invulnerability in real seconds during City Fever.
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
			events.append(_crush_troops(crushed))
	if result.is_attack(): events.append_array(RelicEffects.attack_used(self))
	_complete_skill_use(result, events)
	return events

## Advance city attacks, reinforcements and player immunity independently of turns.
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
