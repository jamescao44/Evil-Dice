extends SceneTree
const Rules = preload("res://scripts/battle_rules.gd")
const Run = preload("res://scripts/run_rules.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
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
		m.stage = 9
		m._load_wave()
		m.city_hp = 10000
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
			var expected: int = 1 if not city and values == [6,6,6] else budget
			check(actions == expected and m.pending.is_empty(),"All modified uses resolve, with immediate stop on a squad wipe")
			check(m.round_number == 1 and m.apply_player_step().is_empty(),"Multiple uses never create extra turns or permit an extra activation")
			if values == [5,5,5]:
				check(events.filter(func(e): return e.type == "damage").size() == 12,"Doubled Sixfold Ruin deals exactly twelve hits")
			if values == [4,4,4] and not city:
				check(m.enemies.all(func(e): return e.hp == 2910),"Doubled AoE strikes every living foe twice")
			if values == [2,2,4]: check(m.statuses[2].count == 4,"Repeating a regeneration cast preserves its refresh rules instead of stacking durations")
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
	check(m.living().size() == 1 and m.enemies[1].hp == 0,"Repeated execution selects a new living foe after the chosen target dies")
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
	check(m.save_pending_skill(),"A modified skill can be saved")
	m.begin_round()
	m.set_test_roll([2,2,4])
	var waiting: MultiHitSkill = m.pending.duplicate()
	m.begin_saved_cast()
	var events: Array = m.apply_player()
	check(events.filter(func(e):return e.type == "damage").size() == 12 and m.pending.same_as(waiting) and m.phase == "player","Saved twelve-hit casts restore the waiting skill exactly once")
	m.reset_run()
	check(m.skill_use_modifiers.is_empty() and m.pending.is_empty() and m.saved_skill.is_empty(),"Restart clears all skill instances and run modifiers")

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
	check(g.view_phase == "skill" and g.skill_bubble.orb_count() == 12 and g.model.round_number == turn,"Saved modified chain restores the waiting preview without spending its turn")
	g.queue_free()
	await process_frame

func run() -> void:
	object_checks()
	model_checks()
	await scene_checks(Battle.new())
	await scene_checks(Portrait.new())
	print("Multi-hit skills: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
