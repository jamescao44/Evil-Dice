extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Driver = preload("res://tests/scene_driver.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func fresh(city: bool = false):
	var m = Run.new(441) if city else Rules.new(441)
	if city:
		m.stage = Waves.CITY_STAGE
		m._load_wave()
		m.city_hp = 100000 # Leave room for both modified Annihilation uses.
	m.begin_round()
	for enemy in m.enemies:
		enemy.hp = 3000
		enemy.max_hp = 3000
	m.hp = 50
	return m

func object_checks() -> void:
	for a in range(1,7):
		for b in range(1,7):
			for c in range(1,7):
				var skill := Rules.classify([a,b,c])
				var expected: int = 6 if [a,b,c] == [5,5,5] else 3 if [a,b,c].count(5) == 2 else 1
				check(skill is MultiHitSkill and skill.use_count() == expected,"Every dice outcome is a skill object with its default use count")
				check(skill.has_use_orbs() == (expected > 1),"Only multiple uses show orbs")
				skill.set_use_multiplier("echo",2)
				check(skill.use_count() == expected*2,"Use modifiers apply to every kind of skill")
	var sixfold := Rules.classify([5,5,5])
	sixfold.set_use_multiplier("echo",2)
	sixfold.set_use_multiplier("echo",2)
	check(sixfold.use_count() == 12,"Refreshing x2 does not compound to x4")
	var copy := sixfold.duplicate()
	copy.set_use_multiplier("relic",3)
	check(copy.use_count() == 36 and sixfold.use_count() == 12,"Independent modifier sources multiply and copies do not share their maps")
	copy.dice[0] = 1
	check(sixfold.dice == [5,5,5],"Copies do not share dice arrays")
	sixfold.begin_cast()
	sixfold.set_use_multiplier("echo",1)
	check(sixfold.use_count() == 12,"A cast keeps its locked use budget if a modifier expires")
	for i in range(12): check(sixfold.consume_use(),"Every advertised use is consumed exactly once")
	check(sixfold.uses_left() == 0 and not sixfold.consume_use(),"No thirteenth use is possible")
	var single := Rules.classify([2,2,4])
	check(single.uses_left() == 1 and not single.has_use_orbs(),"Single-use support still has one use and zero orbs")

func model_checks() -> void:
	var examples := [[1,2,3],[1,1,4],[2,2,4],[3,3,4],[4,4,1],[5,5,1],[6,6,4],[1,1,1],[2,2,2],[3,3,3],[4,4,4],[5,5,5],[6,6,6]]
	for city in [false,true]:
		for values in examples:
			var m = fresh(city)
			m.statuses[3].count = 3
			m.set_skill_use_multiplier("echo_buff",2)
			m.set_test_roll(values)
			var budget: int = m.skill_use_count(m.pending)
			var rng: int = m.rng.state
			var description: String = m.damage_caption(m.pending,0)
			if Rules.is_attack(m.pending) and not m.is_instant_kill(m.pending):
				check(description.ends_with("(x%d)" % budget),"Damage preview uses the modified count")
			check(m.rng.state == rng,"Calculating a modified preview does not consume combat RNG")
			var actions: int = 0
			var events: Array = []
			while m.phase in ["player","executing"]:
				var step: Array = m.apply_player_step()
				check(not step.is_empty(),"Each attack or support use produces its effect")
				events.append_array(step)
				actions += 1
				if m.phase == "executing":
					check(m.pending.uses_left() == budget-actions and m.statuses[3].count >= 3,"Remaining uses decrease without ending the turn or expiring buffs")
				if actions > budget: break
			check(actions == budget and m.pending.is_empty(),"All modified uses resolve, including after a squad wipe")
			check(m.round_number == 1 and m.apply_player_step().is_empty(),"Multiple uses never create extra turns or permit an extra activation")
			if values == [5,5,5]:
				check(events.filter(func(e): return e.type == "damage").size() == 12,"Doubled Sixfold Ruin deals exactly twelve hits")
			if values == [4,4,4] and not city:
				check(m.enemies.all(func(e): return e.hp == 2910),"Doubled AoE strikes every living foe twice")
			if values == [2,2,4]: check(m.statuses[2].count == 0 and (city or m.enemy_status_count(0,m.Status.FROZEN) == budget),"Repeated freeze adds one stack per use; city stays immune")
			if values == [2,2,2]: check(m.hp == m.max_hp,"Repeated full heals never overheal")
			if values == [6,6,6] and city: check(m.hp == 74,"Each completed ultimate use applies its healing as well as damage")
	var m = fresh()
	m.set_skill_use_multiplier("echo",2)
	m.set_test_roll([1,1,2])
	var initial_hp: int = m.enemies[1].hp
	m.apply_player(1)
	check(m.enemies[1].hp == initial_hp-50 and m.enemies[0].hp == 3000 and m.enemies[2].hp == 3000,"A modified aimed attack keeps its selected living foe")
	m = fresh()
	m.set_skill_use_multiplier("echo",2)
	m.set_test_roll([1,1,1])
	m.apply_player(1)
	check(m.living().size() == 2 and m.enemies[1].hp == 0,"Repeated execution stays on its selected foe after death")
	m = fresh()
	m.set_skill_use_multiplier("echo",2)
	m.set_test_roll([5,5,5])
	m.apply_player_step()
	m.set_skill_use_multiplier("echo",1)
	var remaining: Array = m.apply_player().filter(func(e): return e.type == "damage")
	check(remaining.size() == 11,"Expiring a modifier during execution cannot truncate the locked twelve-use chain")
	m = fresh(true)
	m.set_test_roll([5,5,5])
	m.pending.set_use_multiplier("skill_relic",2)
	var waiting: MultiHitSkill = m.pending.duplicate()
	check(not m.save_pending_skill() and not m.begin_saved_cast() and m.pending.same_as(waiting),"Saving is suspended and cannot consume a modified skill")
	m.reset_run()
	check(m.skill_use_modifiers.is_empty() and m.pending.is_empty() and m.saved_skill.is_empty(),"Restart clears all skill instances and run modifiers")

func corpse_checks() -> void:
	for mode in ["battle","wave","city"]:
		for values in [[1,2,3],[1,1,2],[1,1,1],[4,4,4],[5,5,1],[5,5,5],[6,6,6]]:
			var m = Run.new(992) if mode != "battle" else Rules.new(992)
			if mode == "city": m.load_debug_wave(Waves.COUNT); m.city_hp = 1
			m.begin_round()
			for enemy in m.enemies: enemy.hp = 1; enemy.shield = 0
			for id in ["reaper_scythe","bloodstone","magic_shield"]: m.acquire_relic(id)
			m.hp = 10
			m.set_skill_use_multiplier("echo",4)
			m.set_test_roll(values)
			var cast: MultiHitSkill = m.pending
			var count: int = m.skill_use_count(cast)
			var corpses: int = 0
			for use in range(count):
				var defeated: bool = m.city_hp == 0 if mode == "city" else (not m.is_enemy_alive(cast.target) if cast.keeps_selected_target() and cast.target >= 0 else m.living().is_empty())
				var before_hp: int = m.hp
				var kills: int = m.relics.items[m.relics.index_of("reaper_scythe")].kills
				var target: int = m.player_target()
				var state: int = m.rng.state
				check(m.player_target() == target and m.rng.state == state,"Living and corpse targets lock once per impact")
				var events: Array = m.apply_player_step(target)
				var hits: Array = events.filter(func(e): return e.type == "damage")
				check(not hits.is_empty() and cast.uses_spent == use+1,"Every remaining use makes an impact and spends exactly one use")
				if defeated:
					corpses += 1
					check(hits.all(func(e): return e.get("corpse_hit",false) and e.amount == 0),"Corpse impacts never remove additional HP")
					check(m.relics.items[m.relics.index_of("reaper_scythe")].kills == kills,"Corpse hits never award duplicate kills")
					if values != [6,6,6]: check(m.hp == before_hp,"Corpse hits do not grant lifesteal")
				else: check(hits.all(func(e): return not e.get("corpse_hit",false)),"Random and area attacks prefer living targets")
				if use < count-1:
					check(m.phase == "executing" and m.outcome().is_empty(),"Victory waits for the complete locked hit budget")
					if mode != "battle": check(not m.begin_wave_reward(),"Rewards stay unavailable between remaining hits")
				if mode == "city" and m.city_hp == 0:
					check(m.tick_city(0.25).is_empty(),"A destroyed city cannot attack during follow-through")
			var expected_outcome: String = "" if mode != "city" and not m.living().is_empty() else "wave_clear" if mode == "wave" else "victory"
			check(corpses > 0 and m.pending.is_empty() and m.outcome() == expected_outcome,"The last corpse hit ends the cast; victory requires every enemy defeated")
			check(m.relics.items[m.relics.index_of("magic_shield")].turns == (0 if expected_outcome.is_empty() else 1),"Relic turn advances once on victory, otherwise waits for the enemy phase")
			check(m.apply_player_step().is_empty(),"A finished battle cannot start another corpse hit")
	var saved = Run.new(994)
	saved.begin_round()
	saved.enemies[0].hp = 1
	saved.saved_skill = Rules.classify([5,5,5])
	var waiting: MultiHitSkill = saved.set_test_roll([3,3,4]).duplicate()
	check(not saved.begin_saved_cast() and saved.pending.same_as(waiting),"Legacy saved attacks remain unavailable during the dice redesign")
	var defeated = fresh()
	defeated.set_test_roll([5,5,5]); defeated.begin_player_cast()
	for enemy in defeated.enemies: enemy.hp = 0
	defeated.hp = 0
	check(defeated.outcome() == "defeat" and defeated.apply_player_step().is_empty(),"Player defeat still stops an unfinished chain immediately")

func prepare(g, values: Array) -> void:
	g._restart()
	g.model.stage = 1
	g.model._load_wave()
	g._start_round()
	for enemy in g.model.enemies:
		enemy.hp = 3000
		enemy.max_hp = 3000
	g.result = g.model.set_test_roll(values)
	g.skill_bubble.begin(g.result)
	g.skill_bubble.age = g.skill_bubble.formation
	g.view_phase = "skill"

func capture_corpses(g) -> void:
	# Rendering can pause when a native window is occluded; never block the driver.
	await RenderingServer.frame_post_draw
	if not is_instance_valid(g) or not g.is_inside_tree(): return
	DirAccess.make_dir_recursive_absolute("res://test-output")
	root.get_texture().get_image().save_png("res://test-output/multi-hit-corpses-%s.png" % ("portrait" if g is Portrait else "landscape"))

func scene_checks(g) -> void:
	root.add_child(g)
	g.muted = true
	g.speed = 20
	for values in [[1,1,2],[2,2,4],[4,4,4],[5,5,5]]:
		prepare(g,values)
		var turn: int = g.model.round_number
		check(g.skill_bubble.orb_count() == (6 if values == [5,5,5] else 0),"Unmodified single-use skills show no use orbs")
		g.model.set_skill_use_multiplier("echo",2)
		var count: int = 12 if values == [5,5,5] else 2
		check(g.skill_bubble.orb_count() == count and g.skill_bubble.uses_left() == count,"Held skill orbs follow the same live use count as combat")
		check(g._skill_needs_target() == (values == [1,1,2]),"Uses do not change a skill's targeting mode")
		Driver.cast_pending(g)
		check(g.skill_bubble.used == 1 and not g._can_claim_chest(),"First orb pops when casting starts and treasure stays locked")
		var max_used: int = g.skill_bubble.used
		var deadline: int = Time.get_ticks_msec()+8000
		while g.view_phase == "resolving" and Time.get_ticks_msec()<deadline:
			max_used = maxi(max_used,g.skill_bubble.used)
			await process_frame
		check(Time.get_ticks_msec()<deadline and max_used == count,"Visual orbs pop once for every completed attack or support use")
		check(g.view_phase == "ready" and g.model.round_number == turn+1,"Modified visual chain still advances exactly one full turn")
	prepare(g,[5,5,5])
	var turn: int = g.model.round_number
	g.model.saved_skill = Rules.classify([5,5,5])
	g._sync_saved_bubble()
	g.model.set_skill_use_multiplier("echo",2)
	check(g.saved_bubble.orb_count() == 12,"An idle stored Sixfold skill also displays twelve orbs")
	g._handle_click(g._saved_slot_center())
	g._handle_motion(g.ARENA.get_center())
	g._handle_release(g.ARENA.get_center())
	var deadline: int = Time.get_ticks_msec()+8000
	while g.view_phase == "resolving" and Time.get_ticks_msec()<deadline: await process_frame
	check(g.view_phase == "skill" and g.skill_bubble.orb_count() == 12 and g.model.round_number == turn,"Hidden saved slot cannot spend or replace the waiting skill")
	prepare(g,[5,5,5])
	for enemy in g.model.enemies: enemy.hp = 1; enemy.shield = 0
	g.speed = 1
	g.model.set_skill_use_multiplier("echo",5)
	var cast: MultiHitSkill = g.model.pending
	var impact_times: Array = []
	Driver.cast_pending(g)
	var max_used: int = g.skill_bubble.used
	var continued: bool = false
	var rewards_locked: bool = true
	var captured: bool = false
	deadline = Time.get_ticks_msec()+12000
	while g.view_phase == "resolving" and Time.get_ticks_msec()<deadline:
		if cast.uses_spent > impact_times.size(): impact_times.append(Time.get_ticks_msec())
		max_used = maxi(max_used,g.skill_bubble.used)
		if g.model.living().is_empty() and cast.uses_left() > 0:
			continued = true
			rewards_locked = rewards_locked and g.model.outcome().is_empty() and not g._can_claim_chest()
			if not captured and cast.uses_spent >= 4 and "--visual" in OS.get_cmdline_user_args():
				captured = true
				capture_corpses(g)
		await process_frame
	check(Time.get_ticks_msec()<deadline and continued and max_used == 30 and cast.uses_spent == 30,"Scene consumes all thirty accelerating hits after killing the last creature")
	if impact_times.size() == 30:
		var early: float = (impact_times[6]-impact_times[1])/5.0
		var late: float = (impact_times[29]-impact_times[24])/5.0
		check(late < early*0.7 and late > 35,"Long combos speed up gradually while retaining separate readable impacts")
		print("30-hit timing: %.0f ms early, %.0f ms late; %.2f s from first to last hit" % [early,late,(impact_times[29]-impact_times[0])/1000.0])
	else: check(false,"Every accelerated impact remains observable")
	check(rewards_locked,"Scene keeps rewards locked while hitting bodies")
	while g.view_phase == "collecting" and Time.get_ticks_msec()<deadline: await process_frame
	check(g.view_phase == "wave_reward" and g.wave_chest.phase == "closed" and g.model.wave_chest_stage == g.model.stage,"Closed wave chest appears only after the complete chain")
	g.fallen[0] = 1.0
	check(g._enemy_impact_point(0).is_equal_approx(g._enemy_feet(0)-Vector2(0,g._enemy_side()*0.08)),"Follow-through aims at the body on the floor")
	g.queue_free()
	await process_frame

func run() -> void:
	object_checks()
	model_checks()
	corpse_checks()
	await scene_checks(Battle.new())
	await scene_checks(Portrait.new())
	print("Multi-hit skills: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
