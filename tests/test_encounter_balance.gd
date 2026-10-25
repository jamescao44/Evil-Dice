extends SceneTree
## Guard pacing, independent spawn scales, capped snowballing and repeatable reward changes.
const Run = preload("res://scripts/progression/run_rules.gd")
const Balance = preload("res://scripts/progression/encounter_balance.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	var m = Run.new(81)
	m.load_debug_wave(10)
	check(m.enemies[0].level == 5 and m.enemies[0].hp == 2142 and m.enemies[0].damage == 23,"Commander uses its individual level")
	m.hit_enemy(0,99999,true)
	check(m.enemies[0].hp == 3142 and m.enemies[0].damage == 23,"Second phase scales from base exactly once")
	check(m.enemies.slice(1).all(func(e): return e.level == 2 and e.hp == 520 and e.damage == 19),"Guards have a lower authored level than their commander")
	m.load_debug_wave(20)
	check(m.enemies[0].level == 11 and m.enemies[0].hp == 13786 and m.enemies[0].damage == 30,"Spellsword uses level eleven")
	m.hit_enemy(0,99999,true)
	check(m.enemies[0].hp == 16543,"Spellsword second bar scales independently")
	for stage in range(Run.PLAYABLE_WAVES):
		for enemy in m.Waves.create(stage,RandomNumberGenerator.new()):
			check(enemy.hp > 0 and enemy.damage > 0 and m.EnemyCatalog.soul_reward(enemy) > 0,"Every roster has positive stats and rewards")
	var early := RandomNumberGenerator.new(); early.seed = 917
	var late := RandomNumberGenerator.new(); late.seed = 917
	for i in range(200):
		var initial: int = m.WaveRewards.amount(early,"souls",0)
		var scaled: int = m.WaveRewards.amount(late,"souls",19)
		check(scaled == roundi(initial*2.52),"Soul scaling preserves each locked rarity-band roll")
	check(m.WaveRewards.amount_scale("souls",25,19) == 1.0 and m.WaveRewards.amount_scale("souls",101,19) == 2.0,"Late soul receipts retain the requested size endpoints")
	check(m.WaveRewards.amount_scale("blood_gems",333,19) == 1.0 and m.WaveRewards.amount_scale("blood_gems",666,19) == 2.0,"Blood gem amounts and visuals stay unchanged")
	m = Run.new(10); m.acquire_relic("reaper_scythe")
	for kills in [0,1,10,40,400]:
		m.relics.items[0].kills = kills
		var expected: float = {0:1.0,1:1.05,10:1.5,40:3.0,400:3.0}[kills]
		check(is_equal_approx(m.damage_multiplier(),expected),"Reaper grows additively and stops at triple damage")
	m.acquire_relic("disguise_mask"); m.acquire_relic("ancient_tentacle")
	check(is_equal_approx(m.damage_multiplier(),81.0),"Copy relics retain ordered retriggers of the bounded source")
	check(m.max_hp == 6,"Reaper copies also repeat its health penalty")
	m = Run.new(10); m.acquire_relic("mithril_blade")
	check(m.relic_base_damage() == 0 and m.standing_damage_values() == Vector2(5,2),"Mithril doubles the multiplier without adding flat base")
	var fireball = m.Patterns.classify([1,2,3])
	check(m.attack_damage(fireball) == 36,"Level-one Fireball benefits from Mithril's percentage")
	m.character_level = 11
	check(is_equal_approx(m.raw_attack_damage(fireball),5*pow(1.1,10)*3.6*2),"Mithril scales with later character levels")
	m.acquire_relic("fries")
	check(is_equal_approx(m.damage_multiplier(),2.3),"Fries after Mithril adds to the doubled multiplier")
	m.move_relic(1,0)
	check(is_equal_approx(m.damage_multiplier(),2.6),"Mithril after Fries doubles the earlier bonus")
	var trace: Array = m.attack_damage_steps(fireball).filter(func(s): return s.id == "mithril_blade")
	check(trace.size() == 1 and trace[0].base_bonus == 0 and is_equal_approx(trace[0].before,1.3) and is_equal_approx(trace[0].after,2.6),"Mithril feedback matches ordered damage calculation")
	m = Run.new(10); m.acquire_relic("mithril_blade"); m.acquire_relic("disguise_mask"); m.acquire_relic("ancient_tentacle")
	check(is_equal_approx(m.damage_multiplier(),16.0),"Explicit copy relics retrigger Mithril four times")
	for id in ["pet_ghost","pet_dragon"]:
		m = Run.new(10); m.acquire_relic(id); m.begin_round(); m.dice_turn.values = [1,2,3,4,5,6]
		var actions: Array = m.RelicEffects.roll_actions(m,false)
		check(actions.size() == (2 if id == "pet_dragon" else 1) and actions.all(func(a): return a.amount == (15 if id == "pet_dragon" else 20)),"Pets preserve trigger counts with revised amounts")
	var session = Session.new(42)
	session.model.reroll_progress = 10
	session.model.chest_pity.misses = [0,3,3]
	var claimed: Dictionary = session.command({"action":"treasure"})
	check(claimed.ok and claimed.state.chest_tier == 3 and claimed.state.rewards.size() == 5,"CLI uses the shared reroll chest upgrade chain")
	print("Encounter balance: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
