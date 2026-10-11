extends SceneTree
const Driver = preload("res://tests/scene_driver.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func test_layout(game) -> void:
	root.add_child(game)
	game.muted = true
	game.speed = 30
	check(game._active_statuses().is_empty(), "Unactivated statuses have no indicator")
	game.model.set_status_counts({2:4,3:2,33:3,6:1})
	var items: Array = game._active_statuses()
	check(items.size() == 4, "Both attack boons own separate indicators and durations")
	for item in items:
		var at: Vector2 = game._status_center(item.id)
		if game is Portrait:
			var rect: Rect2 = game._status_rect(item.id)
			check(game.ARENA.encloses(rect), "Portrait status fits the battlefield")
			for enemy in range(game.model.enemies.size()):
				check(not rect.intersects(game._target_rect(enemy)) and not rect.intersects(game._enemy_health_rect(enemy)) and not rect.intersects(game._enemy_intent_rect(enemy)), "Portrait status avoids enemy controls")
		else:
			check(at.y < game._player_feet().y-game.monster_side, "Status follows above Horror")
		check(game._status_rect(item.id).has_point(at), "Each status owns a hit area")
	game.model.statuses[6].count = 0
	game.model.statuses[3].count = 0
	items = game._active_statuses()
	check(items.map(func(item): return item.id) == [2,33] and items[0].turns == 4 and items[1].turns == 3, "Expired indicators disappear without removing other statuses")
	game._restart()
	check(game._active_statuses().is_empty(), "Restart clears every indicator")

	game.debug_perfect = true
	game._start_charge()
	game._cancel_charge()
	check(game.debug_perfect and game.model.perfect_total == 0, "Canceled charging preserves queued Perfect")
	game.debug_repeat = true
	game.debug_choice = 2
	await game._roll()
	var expected_turns: int = game.result.spare
	await Driver.resolve_held(game)
	check(game.debug_perfect and game.model.perfect_total == 1 and game.model.statuses[2].count == expected_turns, "Repeat retains Perfect and the chosen combination")
	game._restart()
	check(game.debug_perfect, "Perfect toggle stays enabled across restart until switched off")
	for i in range(2):
		game.debug_choice = 2
		await game._roll()
		check(game.throw_perfect and game.debug_perfect and game.debug_choice == -1,"Perfect stays on across throws without Repeat while the forced dice choice clears")
		await Driver.resolve_held(game)
	if not game.menu_open: game._handle_click(game.MENU_RECT.get_center())
	game._handle_click(game.DEBUG_RECT.get_center())
	game._handle_click(game.DEBUG_PERFECT.get_center())
	game._handle_click(game.DEBUG_CLOSE.get_center())
	if game.menu_open: game._handle_click(game.MENU_RESUME.get_center())
	check(not game.debug_perfect,"Debug button switches the persistent Perfect toggle off")
	game.debug_choice = 2
	await game._roll()
	check(not game.throw_perfect,"Turning the toggle off restores natural throw power")
	await Driver.resolve_held(game)
	game._restart()
	game.model.stage = 9
	game.model._load_wave()
	game.model.begin_round()
	game.debug_perfect = true
	game._roll()
	check(game.throw_perfect and game.result.kind in [game.Rules.Kind.SPECIAL,game.Rules.Kind.ULTIMATE], "Natural city debug Perfect guarantees a triple")
	game._restart()
	await create_timer(0.05).timeout

	var chest = game.chest
	chest.set_process(false)
	chest.start([0,1,2],game.fx.canvas_size,game.pixel_font)
	var signals: Array = []
	chest.opened.connect(func(): signals.append("open"))
	chest.landed.connect(func(i): signals.append(i))
	chest.completed.connect(func(): signals.append("complete"))
	check(chest.stop_time(0) > 6 and chest.stop_time(2) > chest.stop_time(0), "Long reels stop in succession")
	check(chest.prize_origin(0).distance_to(chest.chest_point()) < 50 and chest.emergence(0) == 0, "Prizes start inside the chest")
	chest._process(1)
	check(signals == ["open"] and chest.emergence(0) > 0 and chest.emergence(0) < 1, "Box opens before prizes rise into reels")
	chest._process(1)
	check(chest.prize_origin(2).is_equal_approx(chest.reel_rect(2).get_center()), "Every prize reaches its own reel")
	for i in range(3):
		check(Rect2(Vector2.ZERO,game.fx.canvas_size).encloses(chest.reel_rect(i)), "Three reels fit each layout")
		chest._process(chest.stop_time(i)-chest.elapsed+0.001)
		check(chest.announced == i+1 and signals.back() == i and is_equal_approx(chest.travel(i),chest.REEL_STEPS), "Each locked result lands once")
	check(chest.celebrations.is_empty(), "Category effects wait for pickup")
	for i in range(3): chest.celebrate(i)
	check(chest.celebrations.map(func(event): return event.id) == ["ruby","relic","curse"], "Picked prizes get category celebrations")
	chest._process(0.7)
	check(not chest.active and signals.back() == "complete", "Completion follows the last landing")
	chest._process(0.1)
	check(signals.count("complete") == 1, "Completion cannot duplicate a claim")
	for id in [0,6]:
		chest.start([id],game.fx.canvas_size,game.pixel_font,true)
		chest.celebrate(0)
		check(chest.reduced and chest.celebrations[0].id == game.Rewards.ITEMS[id].id, "Currency FX preserve reward category in reduced mode")
	chest.cancel()
	check(not chest.visible and not chest.active and chest.celebrations.is_empty(), "Cancel clears all celebration particles")
	game.queue_free()
	await process_frame

func run() -> void:
	await test_layout(Battle.new())
	await test_layout(Portrait.new())
	print("Reward presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
