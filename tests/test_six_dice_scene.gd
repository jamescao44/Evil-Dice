extends SceneTree
## Pointer-level selection, cancellation and modal checks for the straight-only pool.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+10000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()
func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)
func layout(portrait: bool) -> void:
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 4; g.set_process_input(false)
	g.model.enemies[0].hp = 100000; g.model.enemies[0].max_hp = 100000
	check(not g._can_end_turn() and not g._can_use_saved(),"No skip before throw or saved slot")
	g.debug_choice = 0
	tap(g,g.DICE_CENTER); tap(g,g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "ready"),"Six dice roll through the real center control")
	tap(g,g.DICE_POSITIONS[0]); tap(g,g.DICE_CENTER)
	check(g.model.pending.is_empty() and g.model.dice_turn.rolls_left == 2,"Incomplete OK cannot roll or summon")
	tap(g,g.dice_selection.cancel_rect().get_center())
	check(g.model.dice_turn.selected.is_empty(),"Red cancel deselects all")
	g.model.dice_turn.values = [1,2,3,3,5,6]
	for i in range(6): g.dice[i].face = g.model.dice_turn.values[i]
	tap(g,g.DICE_POSITIONS[0]); tap(g,g.DICE_POSITIONS[1]); tap(g,g.DICE_POSITIONS[5])
	check(g.model.dice_turn.selected == [0,1] and g.dice[5].rejection_age > 0,"Impossible straight shakes only rejected die")
	tap(g,g.DICE_POSITIONS[2]); tap(g,g.DICE_POSITIONS[3])
	check(g.model.dice_turn.selected == [0,1,2] and g.dice[3].rejection_age > 0,"Repeated pip is invalid even when another physical die exists")
	tap(g,g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "skill"),"OK forms Fireball")
	check(g.model.pending.dice == [1,2,3] and not g._can_end_turn(),"Pending skill locks its three dice and disables End Turn")
	g._handle_click(g._skill_center()); g._handle_motion(g.DICE_CENTER); g._handle_release(g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "ready"),"Dragging a skill back cancels it")
	check(g.model.dice_turn.locked.is_empty() and g.model.dice_turn.rolls_left == 2,"Cancellation unlocks without refund or automatic-hit replay")
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_motion(g.DICE_POSITIONS[1]); g._handle_motion(g.DICE_POSITIONS[0]); g._handle_release(g.DICE_POSITIONS[0])
	check(g.model.dice_turn.selected.is_empty() and g.model.pending.is_empty(),"Backtracking deselects the final lone die")
	g.dice_selection.set_process(false); g.reduced = false
	g.dice_selection.idle_feedback.signature.clear(); g.dice_selection._process(0.95)
	check(g.dice[0].idle_hint.x > 0 and g.dice[1].idle_hint.x > 0 and g.dice[2].idle_hint.x > 0,"Idle hints highlight a usable straight")
	g.menu_open = true; g.dice_selection._process(0.1)
	check(not g.dice_selection.idle_feedback.active,"Menus suppress idle hints")
	g.menu_open = false; g.reduced = true; g.dice_selection._process(0.1)
	check(g.dice.all(func(d): return d.idle_hint == Vector2.ZERO),"Reduced effects suppress rocking")
	g.queue_free(); await process_frame
func run() -> void:
	await layout(false); await layout(true)
	print("Six-dice interactions: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
