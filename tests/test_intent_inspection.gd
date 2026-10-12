extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const Run = preload("res://scripts/run_rules.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func city(stack: int):
	var m = Run.new(82)
	m.stage = 9
	m._load_wave()
	m.begin_round()
	m.set_test_roll([6,6,stack])
	m.apply_player()
	return m

func timer_checks() -> void:
	for stacks in [1,2,5]:
		for dt in [0.025,0.05,0.1,0.25]:
			var m = city(stacks)
			check(is_equal_approx(m.city_immunity_seconds(),stacks*2),"City protection starts with exactly two seconds per stack")
			for step in range(roundi(stacks*2/dt)-1): m.tick_city(dt)
			check(m.status_count(6) == 1 and is_equal_approx(m.city_immunity_seconds(),dt),"Protection survives until the last timed fraction, independent of frame rate")
			m.tick_city(dt)
			check(m.status_count(6) == 0 and m.city_immunity_seconds() == 0,"Protection expires with no additional throw")
	var m = city(2)
	m.tick_city(0,1.5)
	check(is_equal_approx(m.city_immunity_seconds(),2.5),"Casting slow motion cannot extend immunity in real seconds")
	m.begin_round()
	m.set_test_roll([6,6,1])
	m.apply_player()
	check(m.city_immunity_seconds() == 4.5,"Reapplying extends the remaining duration, including its partial old stack")
	m.tick_city(0,4.5)
	check(m._city_hit(7)[0].amount == 7,"City damage resumes after expiry")
	m.reset_run()
	check(m.city_immunity_clock == 0 and m.status_count(6) == 0,"Restart clears the timed state")

func prepare(g, skill: bool = false) -> void:
	g._restart()
	g.model.stage = 1
	g.model.enemies = [Rules.make_enemy(0),Rules.make_enemy(1),Rules.make_enemy(2)]
	for e in g.model.enemies: e.damage = 0
	g.model.phase = "new"
	g.visual_stage = 1
	g.monster_side = g.HORROR_SIZES[1]
	g._start_round()
	if skill:
		g.result = g.model.set_test_roll([1,2,3])
		g.skill_bubble.begin(g.result)
		g.skill_bubble.age = g.skill_bubble.formation
		g.view_phase = "skill"

func tap(g, point: Vector2) -> void:
	g._handle_click(point)
	g._handle_release(point)

func layout_checks(g) -> void:
	root.add_child(g)
	g.muted = true
	g.speed = 20
	prepare(g)
	for type in ["attack","heal","team_heal","shield","empower"]:
		g.model.enemies[0].intent = {"type":type,"target":0,"amount":10}
		var data: Dictionary = g._enemy_intent_data(0)
		var expected: String = "sword" if type == "attack" else "plus" if type in ["heal","team_heal"] else "shield" if type == "shield" else "boost"
		check(data.icon == expected and not data.description.is_empty(),"Every intent uses the appropriate symbol and a short inspection description")
	g.model.enemies[0].shield = 5
	g.model.enemies[0].attack_boost = true
	g.model.hit_enemy(0,5)
	var broken: Dictionary = g._enemy_intent_data(0)
	check(broken.icon == "skip" and broken.name == "Immobilized","Shield break replaces the next-move icon with immobilization")
	var inspection = g.get_children().filter(func(node): return node.get_script() == preload("res://scripts/enemy_inspection.gd"))[0]
	var rows: Array = inspection.status_rows(0)
	check(rows.any(func(item): return item.id is String and item.id == "enemy_empower") and rows.any(func(item): return item.id is int and item.id == StatusEffect.IMMOBILIZED),"Enemy buffs and shield-break status appear together in hold inspection")
	g.model.enemies[0].statuses.clear()
	g.model.enemies[0].attack_boost = false
	var point: Vector2 = g._enemy_point(0)
	var rng: int = g.model.rng.state
	g._handle_click(point)
	await create_timer(0.3).timeout
	check(g.inspecting_enemy == 0 and g._world_time_scale() == 0 and g.model.rng.state == rng,"Holding inspects without advancing combat or rerolling its move")
	g._handle_release(point)
	check(g.inspecting_enemy == -1 and g.view_phase == "ready" and g._world_time_scale() == 1,"Release dismisses the dimmed inspection")
	prepare(g,true)
	tap(g,g._skill_center())
	g._handle_click(point)
	await create_timer(0.3).timeout
	g._handle_release(point)
	check(g.view_phase == "targeting" and g.model.enemies[0].hp == 75 and not g.model.pending.is_empty(),"Holding a targeted enemy never casts or consumes the selected skill")
	tap(g,point)
	check(g.view_phase == "resolving","A quick tap still casts a selected targeted attack")
	var deadline: int = Time.get_ticks_msec()+6000
	while g.view_phase == "resolving" and Time.get_ticks_msec()<deadline: await process_frame
	check(g.model.enemies[0].hp < 75 and g.view_phase == "ready","Quick-tap damage resolves exactly once")
	prepare(g,true)
	g._handle_click(g._skill_center())
	g._handle_motion(point)
	g._update_enemy_hold(1)
	check(g.inspecting_enemy < 0 and g.skill_dragging,"Dragging a skill over a foe cannot open inspection")
	g._handle_release(point)
	check(g.view_phase == "resolving","Skill drag still casts on release")
	prepare(g)
	g._handle_click(point)
	g._update_enemy_hold(0.3)
	g._handle_motion(Vector2.ZERO)
	check(g.inspecting_enemy < 0 and g.pressed_enemy < 0,"Dragging away cancels the hold")
	g._handle_click(point)
	g._update_enemy_hold(0.3)
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(g.inspecting_enemy < 0,"Focus loss clears inspection")
	g._restart()
	g.model.stage = 9
	g.model._load_wave()
	g.model.begin_round()
	g.model.set_test_roll([6,6,2])
	g.model.apply_player()
	g.set_process(false)
	g.guide = true
	g._process(0.5)
	check(g.model.city_immunity_seconds() == 4,"Menus pause the seconds countdown")
	g.guide = false
	g._process(0.5)
	check(is_equal_approx(g.model.city_immunity_seconds(),3.5),"Countdown advances without throwing")
	check("seconds" in g._skill_caption(Rules.classify([6,6,2])).description and "3.5" in g._status_description(6,2),"Skill and status descriptions show timed city immunity")
	g._begin_cast_cinematic(Rules.Kind.ULTIMATE)
	g._process(0.05)
	check(g._world_time_scale() == 0 and is_equal_approx(g.model.city_immunity_seconds(),3.45),"Cast anticipation pauses siege motion without stopping the real seconds countdown")
	check(g.HORROR_SIZES[9] < g.HORROR_SIZES[8] and g.HUMAN_SIZES[2] > 88 and g.HUMAN_SIZES[8] > 24,"Larger later enemies and a smaller city Horror are applied")
	g.queue_free()
	await process_frame

func run() -> void:
	# English wording checks; test_localization covers Chinese and live switching.
	GameText.set_language("en",false)
	timer_checks()
	await layout_checks(Battle.new())
	await layout_checks(Portrait.new())
	print("Intent inspection and timed immunity: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
