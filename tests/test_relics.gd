extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(430)
	m.begin_round()
	return m

func plague_spread_checks() -> void:
	var m = fresh()
	m.enemies = [Rules.make_enemy(0),Rules.make_enemy(1),Rules.make_enemy(2),Rules.make_enemy(0)]
	for enemy in m.enemies: enemy.hp = 500; enemy.max_hp = 500
	m.apply_enemy_status(0,Status.PLAGUE,1)
	m.apply_enemy_status(1,Status.PLAGUE,1)
	m._tick_enemy_statuses()
	check(m.enemies.map(func(e): return e.statuses[Status.PLAGUE].count) == [2,2,1,1],"Two infected enemies each spread to a different uninfected ally; fresh infections do not grow or spread")
	var state: int = m.rng.state
	m._tick_enemy_statuses()
	check(m.enemies.map(func(e): return e.statuses[Status.PLAGUE].count) == [3,3,2,2],"When everyone is infected, plague only gains its own one stack")
	check(m.rng.state == state,"No spread target means no extra random roll")
	m = fresh()
	m.enemies = [Rules.make_enemy(0),Rules.make_enemy(1),Rules.make_enemy(2)]
	for enemy in m.enemies: enemy.hp = 500; enemy.max_hp = 500
	m.apply_enemy_status(0,Status.PLAGUE,1)
	m._tick_enemy_statuses()
	check(m.living().filter(func(i): return m.enemy_status_count(i,Status.PLAGUE) > 0).size() == 2,"A new infection cannot cascade during the same turn")
	m = fresh()
	m.enemies = [Rules.make_enemy(0),Rules.make_enemy(1),Rules.make_enemy(2)]
	m.apply_enemy_status(0,Status.PLAGUE,1)
	m.enemies[1].hp = 0
	m.enemies[2].hp = 1
	m.apply_enemy_status(2,Status.BURNING,1)
	state = m.rng.state
	m._tick_enemy_statuses()
	check(m.enemy_status_count(1,Status.PLAGUE) == 0 and m.enemy_status_count(2,Status.PLAGUE) == 0,"Plague excludes dead allies, including one killed by this turn's burning")
	check(m.enemy_status_count(0,Status.PLAGUE) == 2 and m.rng.state == state,"A lone survivor grows its own plague without spreading it to itself")

func _initialize() -> void:
	plague_spread_checks()
	var m = fresh()
	var counts := [0,0,0,0,0]
	for n in range(12000):
		var offers: Array = m.relics.offers(m.reward_rng)
		check(offers.size() == 3 and offers[0] != offers[1] and offers[1] != offers[2] and offers[0] != offers[2],"Three distinct choices")
		counts[Catalog.ITEMS[offers[0]].rarity] += 1
		for id in offers: check(not Catalog.ITEMS[id].get("fusion",false),"Fusion relics never drop directly")
	for tier in range(5): check(absf(counts[tier]/120.0-Catalog.RARITY_WEIGHTS[tier]) < 1.5,"Drop rarity matches specified probability")
	check(Catalog.ITEMS.size() == 53,"All 53 relic definitions exist")
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","codex_page"]:
		check(m.acquire_relic(id),"Acquire " + id)
	check(not m.acquire_relic("heart"),"Relics are unique")
	check(not m.acquire_relic("contract"),"Full inventory requires replacement")
	check(m.acquire_relic("contract",1) and not m.relics.has("bracelet") and m.relics.items.size() == 10,"Replacement keeps ten slots")
	for i in range(9): check(m.acquire_relic("codex_page"),"Pages stack in a full inventory")
	check(m.relics.has("ancient_codex") and not m.relics.has("codex_page") and m.relics.items.size() == 10,"Ten pages fuse in place")
	m = fresh()
	m.acquire_relic("coin")
	for id in Catalog.STONES: m.acquire_relic(id)
	check(m.relics.items.size() == 2 and m.relics.items[1].id == "prismatic_stone","Six stones fuse at their earliest inventory position")
	for id in [Status.FROZEN,Status.BURNING,Status.STUNNED,Status.DARKNESS,Status.CORROSION]: check(m.apply_affliction(id,3).is_empty(),"Combined immunities")
	m.record_perfect(true)
	check(m.perfect_combo == 2,"Prismatic retains double combo gains")
	m.enemies[0].hp = 1000; m.enemies[0].max_hp = 1000
	m.pending = Rules.classify([2,2,3])
	check(not m.resolve_perfect_relic().is_empty() and m.enemies[0].hp <= 880,"Perfect grants a 100-base prismatic hit")
	check(m.resolve_perfect_relic().is_empty(),"Prismatic strike is once per Perfect")
	check(m.enemy_status_count(0,Status.BURNING) == 1 and m.enemy_status_count(0,Status.PLAGUE) == 1,"Prismatic attack applies combined stone effects")
	m = fresh()
	m.acquire_relic("codex_page"); m.acquire_relic("cursed_skull")
	var roll = Rules.classify([1,2,6])
	check(is_equal_approx(m.damage_multiplier(roll),2.4),"Page before skull: (1 + .2) x 2")
	m.relics.move(0,1)
	check(is_equal_approx(m.damage_multiplier(roll),2.2),"Skull before page: (1 x 2) + .2")
	m = fresh()
	m.acquire_relic("cursed_bow")
	check(is_equal_approx(m.damage_multiplier(Rules.classify([1,1,2])),1.0),"New Bow has no penalty before a wave is cleared")
	m.relics.items[0].waves = 2
	m.acquire_relic("twin_scythes")
	roll = Rules.classify([5,5,5])
	check(m.skill_use_count(roll) == 16,"Bow before scythes: (6 + 2) x 2")
	m.relics.move(0,1)
	check(m.skill_use_count(roll) == 14,"Scythes before bow: 6 x 2 + 2")
	check(m.skill_use_count(Rules.classify([1,2,3])) == 1,"Combo relics do not multiply ordinary attacks")
	check(is_equal_approx(m.damage_multiplier(roll),pow(0.95,2)) and is_equal_approx(m.damage_multiplier(Rules.classify([4,4,4])),1.0),"Bow compounds its penalty per cleared wave for single-target and combo hits, leaving area attacks unchanged")
	m = fresh()
	m.acquire_relic("runestone"); m.acquire_relic("orange_stone")
	m.enemies[0].hp = 1000; m.enemies[0].max_hp = 1000
	m._attack_relic_effects(0,10,roll)
	check(m.enemy_status_count(0,Status.BURNING) == 2,"Runestone before stone boosts stacks")
	m.relics.move(0,1); m.enemies[0].statuses[Status.BURNING].count = 0
	m._attack_relic_effects(0,10,roll)
	check(m.enemy_status_count(0,Status.BURNING) == 1,"Runestone after stone waits until subsequent relic effects")
	m = fresh()
	m.acquire_relic("heart"); m.acquire_relic("bracelet"); m.acquire_relic("mithril_blade")
	check(m.max_hp == 110 and m.hp == 110,"Heart increases capacity and fills new capacity")
	check(m.attack_base(Rules.classify([1,2,3])) == 119,"Flat base damage bonuses apply before multiplier")
	m.acquire_relic("reaper_scythe")
	check(m.max_hp == 55 and m.hp == 55,"Reaper halves max health")
	m.hit_enemy(0,1000,true)
	check(is_equal_approx(m.damage_multiplier(),1.1),"Kills grow Reaper independently")
	m = fresh(); m.acquire_relic("armor")
	m.receive_damage(10)
	check(m.hp == 91,"Armor reduces incoming damage")
	m.acquire_relic("contract"); m.receive_damage(1000)
	check(m.hp == 60 and not m.relics.has("contract"),"Contract prevents lethal damage once")
	m = fresh(); m.acquire_relic("magic_shield"); m.acquire_relic("magic_sword")
	for i in range(6): m.relic_turn_closed = false; m._complete_relic_turn()
	check(m.relics.items[0].charges == 1 and m.relics.items[1].charges == 1,"Six completed turns grant charges")
	m.receive_damage(80)
	check(m.hp == 100 and m.relics.items[0].charges == 0,"Magic shield consumes one whole-hit block")
	m.set_test_roll([5,5,5]); m.begin_player_cast()
	check(m.pending.critical and m.relics.items[1].charges == 0 and m.attack_damage(m.pending) == 45,"Critical covers the whole attack skill")
	m = fresh(); m.acquire_relic("bloodstone"); m.hp = 1
	m._attack_relic_effects(-2,1000,Rules.classify([5,5,5]))
	check(m.hp == 6,"Combo lifesteal has a 5% max HP per-hit cap")
	m.lifesteal_used = 0
	m._attack_relic_effects(-2,1000,Rules.classify([4,4,4])); m._attack_relic_effects(-2,1000,Rules.classify([4,4,4]))
	check(m.hp == 16,"Area attack lifesteal shares a 10% cap across targets")
	m.apply_affliction(Status.DARKNESS,3)
	check(m.heal(100) == 0 and m.damage_multiplier() == 0.5,"Darkness halves damage and stops healing")
	m.statuses[Status.IMMUNITY].count = 3
	m.statuses[Status.CORROSION].count = 3; m.shield = 100
	m.receive_damage(10)
	check(m.hp == 1 and m.shield == 100,"Corrosion bypasses shield and invincibility and multiplies damage")
	m = fresh(); m.apply_affliction(Status.BURNING,20)
	check(m.status_count(Status.BURNING) == 10,"Burning remains capped at ten")
	m.phase = "enemy"; m.enemies[0].acted = true
	m.end_round()
	check(m.hp == 50 and m.status_count(Status.BURNING) == 9,"Ten burn stacks deal 50 then lose one stack")
	m = fresh(); m.apply_enemy_status(0,Status.FROZEN,1)
	m.phase = "enemy"
	check(m.enemy_act(0)[0].type == "skip" and m.enemy_status_count(0,Status.FROZEN) == 0,"Enemy freeze skips one action")
	check(m.apply_enemy_status(0,Status.STUNNED,1).is_empty(),"Enemies do not receive stun")
	m.enemies.append(Rules.make_enemy(1)); m.apply_enemy_status(0,Status.PLAGUE,100)
	check(m.enemies[0].max_hp == 1,"Enemy plague max health has a floor of one")
	m._tick_enemy_statuses()
	check(m.enemy_status_count(0,Status.PLAGUE) == 101 and m.enemy_status_count(1,Status.PLAGUE) == 1,"Plague grows and spreads once, without recursive spread")
	m = fresh()
	var plague_hp: int = m.hp
	check(m.apply_affliction(Status.PLAGUE,100).is_empty() and m.status_count(Status.PLAGUE) == 0 and m.hp == plague_hp and m.max_hp == plague_hp,"The player is immune to plague without relics or protection")
	m.apply_affliction(Status.CORROSION,3)
	check(m.apply_affliction(Status.PLAGUE,1).is_empty(),"Corrosion cannot bypass innate plague immunity")
	m.set_status_counts({Status.PLAGUE:10})
	check(m.status_count(Status.PLAGUE) == 0 and m.max_hp == plague_hp,"Restoring player statuses cannot reintroduce plague")
	m = fresh(); m.acquire_relic("cursed_watch"); m.acquire_relic("cursed_die")
	for i in range(300):
		m.phase = "roll"
		roll = m.roll(0,false)
		check(roll.perfect and 6 in roll.dice and roll.kind != Rules.Kind.ULTIMATE,"Stopwatch + cursed die always Perfect, includes six, never 666")
	check(m.reroll_progress == 0 and m.perfect_combo == 300,"Stopwatch preserves combo but blocks treasure progress")
	m = fresh(); m.acquire_relic("cursed_die")
	for i in range(300):
		m.phase = "roll"; roll = m.roll(0.8,false)
		check(6 not in roll.dice,"Cursed die excludes six on misses")
	m = fresh(); m.acquire_relic("coin"); m.acquire_relic("cursed_bow")
	m.enemies[0].hp = 0
	m.begin_wave_reward()
	var first: Array = m.open_rewards.duplicate()
	check(m.rubies == 10 and m.relics.items[1].waves == 1,"Wave relics trigger before new relic is chosen")
	check(m.begin_wave_reward() and m.open_rewards == first and m.rubies == 10,"Offers and wave rewards cannot reroll or duplicate")
	check(not m.advance_wave(),"Wave waits for relic decision")
	m.open_wave_chest()
	var payout: int = m.Chests.CRYSTALS[m.wave_chest_tier]
	m.discard_unclaimed_rewards(); m.close_chest()
	check(m.finish_wave_reward() and m.rubies == 10+payout and not m.finish_wave_reward(),"Chest pays crystals once even when all items are skipped")
	check(m.advance_wave() and m.power == 1 and m.max_hp == 130,"Wave grows health without free damage multiplier")
	for wave in range(1,Run.Waves.COUNT+1):
		m.load_debug_wave(wave)
		check(m.damage_baseline() == 1,"Every wave including city starts at base x1")
	m.begin_round(); m.acquire_relic("prismatic_stone"); m.set_test_roll([2,2,2],true)
	var hp: int = m.city_hp
	m.resolve_perfect_relic()
	check(m.city_hp == hp-120 and m.apply_enemy_status(-2,Status.BURNING,3).is_empty(),"City receives prismatic damage but is immune to statuses")
	chest_checks()
	lucky_die_checks()
	print("Relics and expanded statuses: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func chest_checks() -> void:
	for legacy_curse_weight in [false,true]:
		var m = fresh()
		m.acquire_relic("heart")
		m.reroll_progress = 9
		m.reward_weights = [0,0 if legacy_curse_weight else 1,1 if legacy_curse_weight else 0,0,0,0,0]
		var rewards: Array = m.open_chest()
		var locked: Dictionary = m.chest_relics.duplicate()
		check(m.open_chest() == rewards and m.chest_relics == locked,"Opening a chest again preserves its locked prizes")
		var seen: Array = []
		for slot in range(rewards.size()):
			if m.open_rewards[slot] == Run.Rewards.Category.TAROT:
				m.begin_tarot_reward("chest",slot)
				check(not m.choose_tarot(0).is_empty(),"The substituted tarot slot grants one card")
				continue
			var gift: Dictionary = m.reward_item(slot)
			check(gift.has("relic_id"),"Both relic weight entries use the complete rarity table")
			var id: String = gift.relic_id
			check(id not in seen and not m.relics.has(id),"Chest excludes owned and already reserved unique relics")
			check((Catalog.ITEMS[id].rarity == Catalog.Rarity.CURSED) == (gift.id == "curse") and not Catalog.ITEMS[id].get("fusion",false),"Cursed presentation follows the locked rarity; fusions never drop")
			seen.append(id)
			check(not m.claim_reward(slot).is_empty() and m.relics.has(id),"Collecting a relic grants its real inventory effect")
			check(m.claim_reward(slot).is_empty(),"A chest prize cannot be collected twice")
		check(m.close_chest() and m.chest_relics.is_empty(),"Closing clears all chest relic reservations")
	var m = fresh()
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","codex_page"]: m.acquire_relic(id)
	m.open_rewards = [1,2]
	m.chest_relics = {0:"contract",1:"cursed_bow"}
	check(m.claim_reward(0).is_empty() and m.claimed_slots.is_empty(),"Full inventory leaves a relic unclaimed until a replacement is selected")
	check(not m.claim_reward(0,2).is_empty() and m.relics.items[2].id == "contract","Chest replacement preserves the chosen slot")
	check(m.claim_reward(1,-1,true).id == "discard" and not m.relics.has("cursed_bow") and m.rubies == 0,"Leaving a chest relic resolves it without awarding skip rubies")
	check(m.close_chest(),"Replacement and leaving a relic both allow the chest to close")
	for n in range(8): m.acquire_relic("codex_page")
	m.open_rewards = [1]; m.chest_relics = {0:"codex_page"}
	check(not m.claim_reward(0).is_empty() and m.relics.has("ancient_codex") and m.relics.items.size() == 10,"A chest page can complete fusion while the inventory is full")

func lucky_die_checks() -> void:
	for perfect in [false,true]:
		var baseline = Run.new(828)
		var lucky = Run.new(951)
		lucky.acquire_relic("lucky_die")
		var baseline_sixes: int = 0
		var lucky_sixes: int = 0
		for n in range(20000):
			baseline.phase = "roll"; lucky.phase = "roll"
			if 6 in baseline.roll(0.8,perfect).dice: baseline_sixes += 1
			if 6 in lucky.roll(0.8,perfect).dice: lucky_sixes += 1
		check(absf((lucky_sixes-baseline_sixes)/200.0-5.0) < 1.5,"Lucky Die adds five percentage points to throws containing six")
