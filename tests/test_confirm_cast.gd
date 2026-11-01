extends SceneTree
## Real pointer flow: selection stays editable, Confirm casts once, and previews never spend RNG.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)

## Observe coroutines with a deadline so a missing confirmation cannot hang the test.
func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+8000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

## Capture the live selection without advancing a cast or changing its gameplay data.
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/confirm-cast-"+label+".png")

## Both layouts retain drag chains, show floating dice, and consume only confirmed dice.
func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 4; g.set_process_input(false)
	g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1),g.model.make_enemy(2)]
	for e in g.model.enemies: e.hp = 10000; e.max_hp = 10000; e.shield = 0
	g.model.roll_pool(false,[1,2,3,4,5,6]); g._show_pending_skill(false)
	for i in range(6): g.dice[i].face = i+1
	var pool = g.model.dice_turn
	var ui = g.dice_selection
	var rng_state: int = g.model.rng.state
	var rolls: int = pool.rolls_left
	g._handle_click(g.DICE_POSITIONS[0])
	g._handle_motion(g.DICE_POSITIONS[1]); g._handle_motion(g.DICE_POSITIONS[2])
	check(ui.dragging and ui.preview.dice.size() == 3,"A dragged straight previews before release")
	g._handle_release(g.DICE_POSITIONS[2])
	check(pool.selected == [0,1,2] and g.model.pending.is_empty() and g.view_phase == "ready","Release retains selection without forming a skill")
	check(pool.locked.is_empty() and pool.rolls_left == rolls and g.model.rng.state == rng_state,"Selection spends no dice, throws or target randomness")
	ui._process(0.2)
	check(g.dice[0].selection_offset().y < -20 and g.dice[0].connection_glow,"Selected dice float above their resting positions and stay lit")
	check(ui.die_rect(0).has_point(g.DICE_POSITIONS[0]) and ui.die_rect(0).has_point(ui.die_center(0)),"Raised and original die positions both remain tappable")
	check(g.dice[5].selection_offset() == Vector2.ZERO,"Unselected dice stay grounded")
	# Inspect every tier and evolution in both languages before committing anything.
	for locale in ["zh_CN","en"]:
		GameText.set_language(locale,false)
		for length in [3,4,5,6]:
			pool.selected = range(length)
			g.model.character_level = 5
			ui._selection_changed(); ui._process(0.2)
			check(not ui.damage_text.is_empty() and not "+" in ui.damage_text,"Preview gives total damage without base-plus-modifier formulas")
			check(not "pip sum" in ui.caption.description and not "base damage" in ui.caption.description,"Skill effect description omits damage arithmetic")
			var rect: Rect2 = ui.preview_rect()
			check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(rect),"Preview panel fits the viewport")
			for i in range(6):
				check(not rect.intersects(ui.die_rect(i)),"Preview never covers a die")
				check(not ui.cancel_rect().intersects(ui.die_rect(i)),"Deselect never steals touches from a raised die")
				check(not ui.center_hit(ui.die_center(i)),"Tapping a floating die never confirms the skill")
			var body: Rect2 = ui.description_rect()
			var body_size: int = 22 if phone else 20
			while body_size > 16 and GameText.lines(ui.caption.description,g.description_font,body_size,body.size.x).size()*(body_size+4) > body.size.y: body_size -= 1
			check(GameText.lines(ui.caption.description,g.description_font,body_size,body.size.x).size()*(body_size+4) <= body.size.y,"Full effect description fits its reserved footer or side panel")
			await capture(("portrait" if phone else "landscape")+"-"+locale+"-"+str(length))
	check(g.model.rng.state == rng_state and pool.rolls_left == rolls,"Live preview refreshes never choose a target or consume resources")
	g.model.character_level = 1
	pool.selected = [0,1,2]; ui._selection_changed()
	tap(g,ui.cancel_rect().get_center())
	check(pool.selected.is_empty() and g.model.pending.is_empty(),"Deselect clears the uncommitted straight")
	for i in [0,1,2]: tap(g,g.DICE_POSITIONS[i])
	tap(g,g.DICE_CENTER)
	check(g.view_phase in ["forming","resolving"] and pool.locked == [0,1,2],"Confirm starts the automatic cast and reserves exactly its three dice")
	tap(g,g.DICE_CENTER)
	check(pool.groups.size() == 1,"Double confirmation cannot create a second skill")
	check(await until(func(): return g.model.phase == "executing"),"Fireball starts without any target click")
	var target: int = g.model.pending.target
	check(target in [0,1,2] and g.view_phase == "resolving","Automatic Fireball chooses one living foe")
	check(await until(func(): return g.view_phase == "ready"),"Automatic cast returns control to the unused dice")
	check(g.model.enemies[target].hp == 9982 and g.model.enemy_status_count(target,g.Status.BURNING) == 2,"Random foe takes the previewed damage and Burning")
	check(g.model.enemies.filter(func(e): return e.hp < 10000).size() == 1,"Ordinary Fireball damages only one foe")
	check(pool.committed == [0,1,2] and pool.unused() == [3,4,5] and pool.rolls_left == rolls,"Automatic cast commits only the confirmed dice and preserves rerolls")
	g._restart(); g.queue_free(); await process_frame

## Total includes every use and pulse; previews keep modifiers intact and obey taunt ranges.
func totals() -> void:
	GameText.set_language("en",false)
	var m = Run.new(667)
	m.begin_round(); m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for e in m.enemies: e.hp = 10000; e.max_hp = 10000; e.shield = 0
	var fireball: MultiHitSkill = m.make_straight_skill([1,2,3])
	check(m.damage_caption(fireball) == "18 damage","Single hit omits its redundant hit count")
	var storm: MultiHitSkill = m.make_straight_skill([1,2,3,4,5])
	check(m.damage_caption(storm) == "35 damage (5 hits)","Storm shows all five rounded pulses")
	m.apply_enemy_status(1,m.Status.BURNING,2)
	check(m.damage_caption(storm) == "35–75 damage (5 hits)","Different target conditions show a total range")
	m.acquire_relic("split_arrow"); m.set_skill_use_multiplier("test",2)
	var before: int = m.rng.state
	check(m.damage_caption(fireball) == "36 damage (4 hits)","Split and extra uses are included once in the whole-skill total")
	check(m.rng.state == before and not fireball.amplifier_locked,"Preview consumes no target RNG or next-skill charge")
	check(m.damage_caption(storm) == "110–150 damage (10 hits)","A second Storm use includes Burning from the completed first use")
	m.pending = storm; m.phase = "player"
	m.apply_player(0)
	check(m.enemies[0].hp == 9890 and m.enemies[1].hp == 9850,"Two actual Storm uses match their direct-damage preview")
	var seen: Dictionary = {}
	for seed_value in range(40):
		m = Run.new(seed_value); m.begin_round()
		m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
		m.pending = m.make_straight_skill([1,2,3]); m.phase = "player"
		check(m.begin_player_cast(),"A target-free Fireball can begin")
		seen[m.pending.target] = true
	check(seen.size() == 3,"Random selection reaches every living foe across seeds")
	m = Run.new(44); m.begin_round()
	m.enemies = [m.make_enemy(0),m.make_enemy(m.EnemyCatalog.Role.PALADIN)]
	m.pending = m.make_straight_skill([1,2,3]); m.phase = "player"
	check(m.begin_player_cast() and m.pending.target == 1,"Random Fireball respects a living Paladin's taunt")

func run() -> void:
	totals(); await scene(false); await scene(true)
	print("Confirm cast: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
