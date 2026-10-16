extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func until(predicate: Callable, seconds: float = 15) -> bool:
	var deadline: int = Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame; await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/patterns-"+name+".png")
func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)
func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.reduced = true; g.set_process_input(false)
	g.model.enemies[0].hp = 100000; g.model.enemies[0].max_hp = 100000
	var label: String = "portrait" if portrait else "landscape"
	await create_timer(0.2).timeout
	check(not g._can_end_turn() and not g._can_use_saved(),label+": no skip before throw or saved slot")
	g.debug_choice = 0
	tap(g,g.DICE_CENTER); tap(g,g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "ready"),label+": six dice roll")
	check(g.model.dice_turn.values == [1,2,3,4,5,6],label+": debug straight fits six dice")
	tap(g,g.DICE_POSITIONS[0])
	check(g.model.dice_turn.selected == [0] and g.model.pending.is_empty(),label+": tap selection persists without summoning")
	tap(g,g.DICE_CENTER)
	check(g.model.pending.is_empty() and g.model.dice_turn.rolls_left == 2,label+": incomplete OK cannot roll or summon")
	tap(g,g.dice_selection.cancel_rect().get_center())
	check(g.model.dice_turn.selected.is_empty(),label+": red cancel deselects all")
	# Inspect idle feedback without letting rendering time move its sampled phase.
	g.dice_selection.set_process(false); g.reduced = false
	g.model.dice_turn.values = [6,6,4,4,2,2]
	for i in range(6): g.dice[i].face = g.model.dice_turn.values[i]
	g.dice_selection._process(0.95)
	check(g.dice[0].idle_hint.x > 0 and g.dice[0].idle_hint == g.dice[1].idle_hint and g.dice[2].idle_hint == Vector2.ZERO,label+": highest matching dice hint together first")
	await capture(label+"-idle-high")
	g.dice_selection._process(1.3)
	check(g.dice[2].idle_hint.x > 0 and g.dice[0].idle_hint == Vector2.ZERO,label+": hint continues to next lower matching face")
	await capture(label+"-idle-middle")
	tap(g,g.DICE_POSITIONS[2]); g.dice_selection._process(0)
	check(g.dice.all(func(d): return d.idle_hint == Vector2.ZERO),label+": selecting any die stops idle hints")
	tap(g,g.dice_selection.cancel_rect().get_center())
	g.menu_open = true; g.dice_selection._process(1)
	check(not g.dice_selection.idle_feedback.active and g.dice.all(func(d): return d.idle_hint == Vector2.ZERO),label+": menus suppress idle waves and hints")
	g.menu_open = false; g.reduced = true; g.dice_selection._process(1)
	check(g.dice.all(func(d): return d.idle_hint == Vector2.ZERO),label+": reduced effects suppress rocking")
	g.dice_selection.set_process(true)
	# Test rejected taps on a pair with an incompatible third face.
	g.model.dice_turn.values = [2,2,3,4,5,6]
	for i in range(6): g.dice[i].face = g.model.dice_turn.values[i]
	tap(g,g.DICE_POSITIONS[0]); tap(g,g.DICE_POSITIONS[1]); tap(g,g.DICE_POSITIONS[2])
	check(g.model.dice_turn.selected == [0,1] and g.dice[2].rejection_age > 0,label+": invalid tap shakes only rejected die")
	await capture(label+"-tap-preview")
	tap(g,g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "skill"),label+": OK forms pair")
	check(g.model.pending.dice.size() == 2 and not g._can_end_turn(),label+": pair uses two dice and blocks End Turn")
	await capture(label+"-pair")
	tap(g,g._skill_center())
	check(g._current_skill_selected() and not g._save_slot_accepts(),label+": selected skill offers cancel without save")
	g._handle_click(g._skill_center()); g._handle_motion(g.DICE_CENTER); g._handle_release(g.DICE_CENTER)
	check(g.view_phase == "ready" and g.model.dice_turn.locked.is_empty(),label+": skill cancellation refunds pair")
	# Drag a pair and cast through the existing targeted interaction.
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_motion(g.DICE_POSITIONS[1]); g._handle_release(g.DICE_POSITIONS[1])
	check(await until(func(): return g.view_phase == "skill"),label+": drag release forms pair")
	var round_before: int = g.model.round_number
	tap(g,g._skill_center()); tap(g,g._enemy_point(0))
	check(await until(func(): return g.view_phase == "ready"),label+": attack returns to remaining dice")
	check(g.model.round_number == round_before and g.model.dice_turn.locked.size() == 2,label+": no early enemy phase")
	await capture(label+"-remaining")
	g.menu_open = true; check(not g._can_end_turn(),label+": menu blocks End Turn"); g.menu_open = false
	tap(g,g._saved_slot_center()); tap(g,g._saved_slot_center())
	check(await until(func(): return not g.leftover_volley.flight.is_empty()),label+": End Turn fires directly from dice")
	check(g.skill_bubble.roll.is_empty() and g.result.is_empty() and g.fx.dice_power.is_empty(),label+": leftovers never combine into a skill bubble")
	var flight_origin: Vector2 = g.leftover_volley.flight.from
	check(flight_origin.distance_to(g.DICE_POSITIONS[2]) < 50,label+": first orb starts at a printed pip on the first unused die")
	await capture(label+"-leftover-orb")
	g.menu_open = true
	var flight_age: float = g.leftover_volley.flight.age
	await process_frame; await process_frame
	check(g.leftover_volley.flight.age == flight_age and not g.leftover_volley.visible,label+": menu pauses and hides direct orbs")
	g.menu_open = false
	check(await until(func(): return g.model.round_number == round_before+1 and g.view_phase == "ready"),label+": End Turn completes volley and one enemy phase")
	check(g.model.reroll_progress == 2,label+": auto volley banks unused rolls once")
	# Six connected dice must not snap at the old three-die boundary.
	g.debug_choice = 0; tap(g,g.DICE_CENTER); tap(g,g.DICE_CENTER)
	await until(func(): return g.view_phase == "ready")
	g._handle_click(g.DICE_POSITIONS[0])
	for i in range(1,6): g._handle_motion(g.DICE_POSITIONS[i])
	check(g.model.dice_turn.selected.size() == 6 and g.dice_selection.preview.pattern == "straight",label+": dragging grows through all six")
	await capture(label+"-straight-preview")
	g._handle_release(g.DICE_POSITIONS[5]); await until(func(): return g.view_phase == "skill")
	g._handle_click(g._skill_center()); g._handle_motion(g._player_point()); g._handle_release(g._player_point())
	check(await until(func(): return g.model.round_number == round_before+2 and g.view_phase == "ready"),label+": six-straight casts without targeting")
	check(g.model.shield > 0,label+": shield is visible after enemy phase")
	g.guide = true
	for page in [0,1]:
		if portrait: g.guide_page = page
		g.queue_redraw(); await capture(label+"-help-"+str(page))
	GameText.set_language("en",false)
	g.queue_redraw(); await capture(label+"-help-en")
	GameText.set_language("zh_CN",false)
	# Restart midway through direct fire must discard the old asynchronous volley.
	g._restart(); g.model.roll_pool(false,[6,6,6,6,6,6])
	for die in g.dice: die.face = 6
	g._end_dice_turn()
	check(await until(func(): return not g.leftover_volley.flight.is_empty()),label+": direct volley starts without selection")
	g._restart()
	var fresh_hp: int = g.model.enemies[0].hp
	await create_timer(0.3).timeout
	check(g.leftover_volley.flight.is_empty() and g.model.enemies[0].hp == fresh_hp and g.model.pending.is_empty(),label+": restart cancels the old orb and prevents stale damage")
	g.queue_free(); await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	await layout(false); await layout(true)
	print("Dice pattern scene: %d passed, %d failed" % [checks-failures,failures])
	quit(1 if failures else 0)
