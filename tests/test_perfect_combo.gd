extends SceneTree
const Waves = preload("res://scripts/wave_catalog.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const Run = preload("res://scripts/run_rules.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Status = preload("res://scripts/status_effect.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func fresh(city: bool = false):
	var m = Run.new(732)
	if city:
		m.stage = Waves.CITY_STAGE
		m._load_wave()
	else:
		m.enemies = [Rules.make_enemy(0,20)]
	m.begin_round()
	return m

func streak_checks() -> void:
	var m = fresh()
	check(m.perfect_combo == 0 and m.combo_multiplier() == 1,"A new run has no bonus")
	for n in range(1,4):
		m.phase = "roll"
		m.roll(1,true)
		check(m.perfect_combo == n and is_equal_approx(m.combo_multiplier(),1+n*0.1),"Accepted Perfects add one combo each")
	check(m.perfect_total == 3 and m.perfect_progress == 3,"Accepted rolls count treasure once")
	check(m.roll(1,true).is_empty() and m.perfect_combo == 3,"Rejected roll cannot increment combo")
	m.phase = "roll"
	check(m.set_test_roll([0,1,2],false).is_empty() and m.perfect_combo == 3,"Invalid forced roll cannot reset combo")
	m.open_chest()
	check(m.perfect_combo == 3 and m.perfect_progress == 0,"Claiming treasure preserves the streak")
	for slot in range(m.open_rewards.size()): m.claim_reward(slot)
	m.close_chest()
	m.enemies[0].hp = 0
	check(m.advance_wave() and m.perfect_combo == 3,"Wave transition preserves the streak")
	m.begin_round()
	m.roll(1,false)
	check(m.perfect_combo == 0 and m.combo_multiplier() == 1 and m.perfect_total == 3,"A non-Perfect at full power resets combo without erasing treasure")
	m.phase = "roll"
	m.set_test_roll([2,2,4],true)
	check(m.perfect_combo == 1 and m.perfect_total == 4,"Debug dice use the same accepted Perfect bookkeeping")
	m.reset_run()
	check(m.perfect_combo == 0 and m.perfect_total == 0,"Restart clears combo and treasure")

func damage_checks() -> void:
	for city in [false,true]:
		var m = fresh(city)
		m.set_test_roll([5,5,5],true)
		check(m.attack_damage(m.pending,0) == 16,"First Perfect boosts the skill it just rolled")
		m.phase = "roll"
		m.set_test_roll([5,5,5],true)
		check(m.damage_caption(m.pending,0) == "15 + 3 (x6)","Preview includes the current combo on each hit")
		m.set_skill_use_multiplier("echo",2)
		var events: Array = m.apply_player(0)
		var hits: Array = events.filter(func(e): return e.type == "damage")
		check(hits.size() == 12 and hits.all(func(e): return e.amount == 18),"Every one of twelve hits receives the combo bonus")
		check(m.perfect_combo == 2,"Individual hits never add to the throw streak")
		m = fresh(city)
		m.reward_base_damage = 5
		m.reward_damage_multiplier = 0.5
		m.power = 2
		m.statuses[3].count = 3
		m.set_test_roll([4,4,4],true)
		check(m.attack_damage(m.pending,0) == 139,"Combo adds to rewards and attack boons above the growth baseline")
		m = fresh(city)
		m.hp = 40
		m.set_test_roll([2,2,2],true)
		var healed: Array = m.apply_player()
		check(m.hp == 100 and healed[0].amount == 60,"Perfect healing increases combo without amplifying regeneration")
	var m = fresh()
	m.set_test_roll([4,5,6],true)
	m.enemies[0].max_hp = 30
	check(m.attack_damage(m.pending,0) == 10,"Normal damage caps still apply after combo")
	m = fresh()
	m.set_test_roll([1,1,1],true)
	check(m.damage_caption(m.pending,0).is_empty(),"Instant kills still have no numeric caption")
	m.apply_player(0)
	check(m.enemies[0].hp == 0,"Perfect instant kills still execute")
	m = fresh(true)
	m.city_hp = 100000 # Keep this fixture alive to measure uncapped combo damage.
	m.set_test_roll([6,6,6],true)
	check(m.damage_caption(m.pending) == "2000 + 200 (x1)","City Annihilation includes combo in its numeric preview")
	m.apply_player()
	check(m.city_hp == 100000-2200,"City Annihilation receives the Perfect damage bonus")
	m.city_hp = 20
	check(m.siege_damage(Rules.classify([6,6,6])) == 20,"Combo damage clamps to remaining city health")

func additive_checks() -> void:
	var m = fresh()
	m.reward_damage_multiplier = 0.5
	m.statuses[3].count = 2
	m.statuses[33].count = 1
	m.perfect_combo = 5
	check(m.damage_multiplier() == 4.5, "Baseline 1.0 + treasure 0.5 + both buffs 0.5/2.0 + combo 0.5 = 4.5")
	var skill = Rules.classify([5,5,5])
	check(m.attack_damage(skill,0) == 67, "Fifteen base damage times 4.5 rounds down to 67")
	m.statuses[33].consume()
	check(m.damage_multiplier() == 2.5 and m.attack_damage(skill,0) == 37, "Expiring one buff removes only its own contribution")
	m.phase = "roll"
	m.set_test_roll([5,5,5],false)
	check(m.damage_multiplier() == 2.0, "Missing Perfect removes only combo; treasure and remaining buff persist")
	m.power = 2
	check(m.damage_multiplier() == 3.0, "Growth changes baseline without multiplying reward or buff bonuses")
	m.stage = Waves.CITY_STAGE
	check(m.damage_multiplier() == 3.0, "City preserves the same baseline and additive bonuses")
	m.city_hp = 100000
	check(m.siege_damage(Rules.classify([6,6,6])) == 6000, "Annihilation uses the same multiplier as every other numeric city attack")

func preserved_turn_checks() -> void:
	var m = fresh()
	m.set_test_roll([1,1,4],true)
	check(m.save_pending_skill() and m.perfect_combo == 1,"Banking a Perfect skill keeps combo")
	m.phase = "roll"
	m.set_test_roll([2,2,2],true)
	check(m.begin_saved_cast(),"Saved attack starts as a bonus cast")
	var events: Array = m.apply_player(0)
	check(events[0].amount == 34 and m.perfect_combo == 2,"Saved damage uses the current two-Perfect combo without incrementing it")
	check(m.phase == "player" and m.pending.face == 2,"Saved bonus resumes the waiting skill")
	m.statuses[Status.FROZEN].count = 1
	m.phase = "round_end"
	m.begin_round()
	for i in range(3): m.break_ice()
	check(m.perfect_combo == 2 and m.phase == "enemy","Three ice taps skip a turn without breaking the throw streak")

func scene_checks(portrait: bool) -> void:
	if not portrait:
		root.content_scale_size = Vector2i(1280,800)
		root.size = Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	check(g._damage_multiplier_label().is_empty() and not g.damage_feedback.active, "Multiplier stays hidden before an attack")
	var at: Vector2 = g._perfect_combo_center()
	var saved: Vector2 = g._saved_slot_center()
	check(is_equal_approx(at.x+saved.x,2*g.DICE_CENTER.x) and at.y == saved.y,"Combo mirrors the saved slot in each layout")
	g.model.perfect_combo = 3
	check(g._damage_multiplier_label().is_empty() and g.model.damage_multiplier() == 1.3, "Idle combo changes do not reveal the cast-only multiplier")
	g._start_charge()
	g._cancel_charge()
	check(g.model.perfect_combo == 3,"Canceled charging preserves combo")
	g._roll(1,true)
	check(g.model.perfect_combo == 4 and g.model.perfect_total == 1,"Scene counts a natural Perfect exactly once")
	g._roll(1,true)
	check(g.model.perfect_combo == 4,"Extra input during an accepted throw cannot add combo")
	g._restart()
	check(g.model.perfect_combo == 0 and g.combo_flash_until == 0,"Scene restart clears combo and its flash")
	g.debug_choice = 5
	g.debug_perfect = true
	g._roll()
	check(g.model.perfect_combo == 1 and g.model.perfect_total == 1,"Debug Perfect follows the same combo path")
	g._restart()
	g.debug_perfect = false
	if "--capture" in OS.get_cmdline_user_args():
		g.reduced = true
		g.model.perfect_combo = 12
		g._start_charge()
		g.set_process(false)
		g.throw_meter.elapsed = g.ThrowMeter.PERIOD/4-0.035
		g.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/perfect-combo-"+("portrait" if portrait else "landscape")+".png")
		g._restart(Waves.COUNT)
		for status in Status.IDS: g.model.statuses[status].count = 3
		g.model.perfect_combo = 5
		g.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/additive-city-"+("portrait" if portrait else "landscape")+".png")
	g.queue_free()
	await process_frame

func run() -> void:
	streak_checks()
	damage_checks()
	additive_checks()
	preserved_turn_checks()
	await scene_checks(false)
	await scene_checks(true)
	print("Perfect combo: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
