extends SceneTree
const Driver = preload("res://tests/scene_driver.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Battle = preload("res://scripts/battle.gd")
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func touch(point: Vector2, pressed: bool, finger: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = game.get_global_transform_with_canvas() * point
	event.pressed = pressed
	game._input(event)

func tap(point: Vector2) -> void:
	touch(point, true)
	touch(point, false)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while game.view_phase not in ["ready", "over"] and Time.get_ticks_msec() < deadline:
		Driver.cast_pending(game)
		await process_frame
	check(Time.get_ticks_msec() < deadline, "Roll settles")

func run() -> void:
	game = Portrait.new()
	root.add_child(game)
	game.muted = true
	game.speed = 20
	game.reduced = true
	var safe := Rect2(24, 124, 756, 1560)
	var controls: Array = [game.DEBUG_RECT, game.SPEED_RECT, game.AUDIO_RECT, game.FX_RECT, game.GUIDE_RECT, game.GUIDE_CLOSE, game.DEBUG_CLOSE, game.DEBUG_REPEAT, game.REPLAY_RECT, game.GUIDE_PAIRS, game.GUIDE_TRIPLES, game._chest_milestone_rect(1), game._chest_milestone_rect(2), game._chest_milestone_rect(3)]
	for i in range(-1, 13): controls.append(game._debug_option_rect(i))
	controls.append(game.DEBUG_PERFECT)
	for id in [2,3,33,6]: game.model.buffs[id] = 2
	for item in game._active_statuses(): controls.append(game._status_rect(item.id))
	for id in game.model.buffs: game.model.buffs[id] = 0
	for rect in controls:
		check(safe.encloses(rect), "Portrait control stays inside safe area: %s" % rect)
		check(rect.size.x >= 88 and rect.size.y >= 88, "Touch target is at least 44 points: %s" % rect)
	check(safe.encloses(Rect2(game.DICE_CENTER - Vector2.ONE * game.DICE_RADIUS, Vector2.ONE * game.DICE_RADIUS * 2)), "Full dice circle fits safe area")
	check(root.content_scale_size == Vector2i(804, 1748), "Canvas matches iPhone 16 Pro aspect ratio")
	for i in range(3):
		check(game.DICE_POSITIONS[i].distance_to(game.DICE_CENTER) + 77 * game.dice[i].base_scale < game.DICE_RADIUS, "Enlarged dice remain inside the roll circle")
	var landscape := Battle.new()
	check(landscape.DICE_CENTER == Vector2(639, 640) and landscape.DICE_RADIUS == 144 and landscape.ARENA == Rect2(24, 80, 1232, 409), "Portrait geometry does not mutate restored landscape layout")
	landscape.free()
	tap(game.GUIDE_RECT.get_center())
	tap(game.GUIDE_TRIPLES.get_center())
	check(game.guide and game.guide_page == 1, "Grimoire tabs work by touch")
	tap(game.DICE_CENTER)
	check(game.view_phase == "ready" and game.guide, "Modal consumes underlying dice touch")
	tap(game.GUIDE_CLOSE.get_center())
	tap(game.DEBUG_RECT.get_center())
	tap(game.DEBUG_REPEAT.get_center())
	tap(game._debug_option_rect(2).get_center())
	check(game.debug_repeat and game.debug_choice == 2 and not game.debug_open, "Debug touch queues repeating pair")
	game.model.buffs[2] = 2
	tap(game._status_rect(2).get_center())
	check(game.selected_status == 2, "Active status descriptions available without hover")
	game.model.buffs[2] = 0
	touch(game.DICE_CENTER, true)
	var pending: Dictionary = game.model.pending.duplicate(true)
	touch(game.AUDIO_RECT.get_center(), true, 1)
	check(game.muted and game.active_touch == 0, "Second finger cannot steal the active touch")
	var mouse := InputEventMouseButton.new()
	mouse.device = -1
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = game.AUDIO_RECT.get_center()
	game._input(mouse)
	check(game.muted and game.model.pending == pending, "Synthetic mouse does not double-fire touch")
	touch(game.DICE_CENTER, false)
	tap(game.DICE_CENTER)
	var regeneration_turns: int = game.result.spare
	await settle()
	check(game.model.round_number == 2 and game.model.buffs[2] == regeneration_turns-1, "Touch applies pair regeneration and consumes its first turn")
	for stage in range(9):
		game.debug_choice = 12
		await game._roll()
		await Driver.resolve_held(game)
		await settle()
		check(game.model.stage == stage + 1, "Portrait advances to stage %d" % (stage + 2))
	tap(game.DEBUG_RECT.get_center())
	var siege_clock: float = game.model.volley_clock
	await create_timer(0.15).timeout
	check(game.model.volley_clock == siege_clock, "Touch debug pauses fever")
	tap(game._debug_option_rect(1).get_center())
	touch(game.DICE_CENTER, true)
	await create_timer(0.15).timeout
	check(game._roll_speed() == 2.0 and game.view_phase == "charging", "Holding touch keeps fixed city speed and does not throw")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = game.get_global_transform_with_canvas() * Vector2(10, 10)
	game._input(drag)
	await create_timer(0.15).timeout
	check(game._roll_speed() == 2.0 and game.view_phase == "charging", "Dragging outside does not change speed or release dice")
	touch(Vector2(10, 10), false)
	check(game.active_touch == -1, "Touch release clears hold even outside circle")
	check(game.view_phase == "charging", "Holding does not automatically throw")
	tap(game.DICE_CENTER)
	await settle()
	touch(game.DICE_CENTER, true)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.active_touch == -1, "App suspension cancels held input")
	await settle()
	for i in range(3):
		game.debug_choice = 12
		await game._roll()
		await Driver.resolve_held(game)
	check(game.model.outcome() == "victory", "Portrait city retains three-ultimate health balance")
	tap(game.REPLAY_RECT.get_center())
	check(game.model.stage == 0 and game.model.hp == 100 and game.view_phase == "ready", "Touch restart resets the whole run")
	print("Portrait: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
