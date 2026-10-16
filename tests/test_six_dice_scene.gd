extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func until(predicate: Callable, seconds: float = 12) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func capture(name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/six-dice-"+name+".png")

func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.speed = 2 if portrait else 1
	g.reduced = true
	g.set_process_input(false)
	g.model.enemies[0].hp = 100000
	g.model.enemies[0].max_hp = 100000
	var name: String = "portrait" if portrait else "landscape"
	var landing_order: Array = []
	for index in range(g.dice.size()):
		g.dice[index].landed.connect(func(): landing_order.append(index))
	await create_timer(0.2).timeout
	check(g.dice.size() == 6, name+": six visible dice")
	for index in range(6):
		var expected: Vector2 = g.DICE_CENTER+Vector2.from_angle(-PI/2+index*TAU/6)*106*g.DICE_RADIUS/144.0
		check(g.DICE_POSITIONS[index].distance_to(expected) < 0.01, name+": die sits on a hexagram vertex")
	await capture(name+"-ready")
	check(g.model.dice_turn.rolls_left == 3, name+": three throws initially")
	g.debug_choice = 2
	g._handle_click(g.DICE_CENTER)
	check(g.view_phase == "charging", name+": Roll starts timer")
	g._handle_click(g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "ready"), name+": throw returns to selection")
	check(g.model.pending.is_empty() and g.model.dice_turn.rolls_left == 2, name+": roll waits for player's trio")
	check(landing_order == [0,5,4,3,2,1], name+": all six land counterclockwise from the top")
	await capture(name+"-thrown")
	g._handle_click(g.DICE_POSITIONS[0])
	g._handle_motion(Vector2(g.DICE_POSITIONS[1].x,g.DICE_POSITIONS[0].y))
	g._handle_motion(g.DICE_POSITIONS[2])
	check(g.model.dice_turn.selected == [0,1,2], name+": dragging snaps through physical indices")
	check(g.model.pending.is_empty() and not g.dice_selection.preview.is_empty(), name+": preview waits for release")
	g._handle_motion(g.DICE_POSITIONS[3])
	check(g.model.dice_turn.selected == [0,1,3], name+": snapping while over another die connects the replacement immediately")
	g.dice_selection.cancel_gesture()
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_motion(g.DICE_POSITIONS[1]); g._handle_motion(g.DICE_POSITIONS[2])
	g._handle_motion(g.DICE_POSITIONS[1])
	check(g.model.dice_turn.selected == [0,1], name+": returning to the previous die removes the third")
	g._handle_motion(g.DICE_POSITIONS[1]+Vector2(90,0))
	g._handle_motion(g.DICE_POSITIONS[1])
	check(g.model.dice_turn.selected == [0], name+": leaving and returning to the second die disconnects it")
	g._handle_motion(g.DICE_POSITIONS[5]); g._handle_motion(g.DICE_POSITIONS[4])
	check(g.model.dice_turn.selected == [0,5,4], name+": another pair of dice replaces the old selection")
	g._handle_motion(g.DICE_POSITIONS[4]-Vector2(g.dice_selection.break_distance()+35,0))
	check(g.model.dice_turn.selected == [0,5] and g.dice_selection.preview.is_empty(), name+": pulling too far snaps the third connection and clears its preview")
	g.dice_selection.cancel_gesture()
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_motion(g.DICE_POSITIONS[1]); g._handle_motion(g.DICE_POSITIONS[2])
	await create_timer(0.12).timeout
	check(g.dice[0].selection_emphasis > 0 and g.dice[0].connection_glow and not g.dice_selection.particles.is_empty(), name+": held trio enlarges, glows and emits sparks")
	await capture(name+"-selected")
	g._handle_release(g.DICE_POSITIONS[g.model.dice_turn.selected[-1]])
	check(await until(func(): return g.view_phase == "skill"), name+": Form creates a usable skill")
	await create_timer(1.0).timeout
	g._handle_click(g._skill_center())
	check(g._current_skill_selected() and g._save_slot_accepts() and not g.skill_dragging, name+": save and cancel hints appear on press")
	g._handle_release(g._skill_center())
	check(g._current_skill_selected() and g._save_slot_accepts(), name+": support tap keeps both hints visible")
	await capture(name+"-selected-skill")
	g._handle_click(g._skill_center())
	g._handle_motion(g.DICE_CENTER)
	await capture(name+"-cancel")
	g._handle_release(g.DICE_CENTER)
	check(g.view_phase == "ready" and g.model.dice_turn.locked.is_empty() and g.model.dice_turn.rolls_left == 2, name+": center cancellation unlocks without spending a roll")
	g._handle_click(g.DICE_POSITIONS[0])
	g._handle_motion(g.DICE_POSITIONS[1])
	g._handle_release(g.DICE_POSITIONS[1])
	check(g.model.pending.is_empty() and g.model.dice_turn.selected.is_empty(), name+": incomplete gesture spends nothing")
	g._handle_click(g.DICE_POSITIONS[0])
	g._handle_motion(g.DICE_POSITIONS[1])
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	g._handle_release(g.DICE_POSITIONS[2])
	check(g.model.pending.is_empty() and not g.dice_selection.dragging, name+": focus loss cannot summon from a stale drag")
	g._handle_click(g.DICE_POSITIONS[0])
	g._handle_motion(g.DICE_POSITIONS[1])
	g._handle_motion(g.DICE_POSITIONS[2])
	g._handle_release(g.DICE_POSITIONS[2])
	check(await until(func(): return g.view_phase == "skill"), name+": cancelled dice can form again")
	var round_before: int = g.model.round_number
	g._handle_click(g.DICE_CENTER)
	g._handle_click(g.DICE_POSITIONS[3])
	g._handle_motion(g.DICE_POSITIONS[4]); g._handle_release(g.DICE_POSITIONS[5])
	check(g.view_phase == "skill" and g.model.dice_turn.rolls_left == 2 and g.model.dice_turn.selected.is_empty(), name+": pending skill blocks reroll and remaining dice")
	await process_frame
	check(g.dice[3].self_modulate.r < 0.6, name+": unused dice also dim while a skill waits")
	check(g._skill_radius() == (96 if portrait else 78), name+": summoned skill uses its larger radius")
	g._handle_click(g._skill_center()); g._handle_motion(g._player_point()); g._handle_release(g._player_point())
	check(await until(func(): return g.view_phase == "ready"), name+": first cast returns control to remaining dice")
	check(g.model.round_number == round_before and not g.model.enemies[0].acted, name+": no early enemy phase")
	await capture(name+"-remaining")
	landing_order.clear()
	g.debug_choice = 3
	g._handle_click(g.DICE_CENTER)
	check(g.view_phase == "charging", name+": unused dice can reroll after first cast")
	check(not g.dice[0].charging and g.dice[3].charging, name+": spent dice remain still")
	g._handle_click(g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "ready"), name+": reroll returns to remaining selection")
	check(landing_order == [5,4,3], name+": reroll lands only unspent dice in counterclockwise order")
	g._handle_click(g.DICE_POSITIONS[3]); g._handle_motion(g.DICE_POSITIONS[4]); g._handle_release(g.DICE_POSITIONS[5])
	check(await until(func(): return g.view_phase == "skill"), name+": second trio summons after the first is used")
	g._handle_click(g._skill_center()); g._handle_motion(g._player_point()); g._handle_release(g._player_point())
	check(await until(func(): return g.model.round_number > round_before and g.view_phase == "ready"), name+": using all six advances exactly one round")
	check(g.model.dice_turn.rolls_left == 3 and g.model.dice_turn.locked.is_empty(), name+": fresh turn resets budget and locks")
	g.model.roll_pool(false,[1,2,3,4,5,6])
	for index in range(6): g.dice[index].face = g.model.dice_turn.values[index]
	g._handle_click(g.DICE_POSITIONS[0])
	g._handle_motion(g.DICE_POSITIONS[1])
	g._handle_motion(g.DICE_POSITIONS[2])
	await capture(name+"-normal-preview")
	g._handle_click(g.MENU_RECT.get_center())
	check(g.menu_open and not g.dice_selection.dragging and g.model.pending.is_empty(), name+": menu cancels an unfinished connection")
	g.menu_open = false
	g.tarot_ui.opened = true
	g.tarot_ui.expansion = 1
	check(await until(func(): return not g.dice_selection.visible,0.5), name+": dice controls hide in tarot inventory")
	g.tarot_ui.opened = false
	g.tarot_ui.expansion = 0
	g.debug_open = true
	await process_frame
	check(not g.dice_selection.visible, name+": debug covers dice controls")
	g.debug_open = false
	g.guide = true
	for locale in ["zh_CN","en"]:
		GameText.set_language(locale,false)
		await capture(name+"-help-"+locale)
	GameText.set_language("zh_CN",false)
	g.queue_free()
	await process_frame

func run() -> void:
	await layout(false)
	await layout(true)
	print("Six-dice scene checks: %d passed, %d failed" % [checks-failures,failures])
	quit(1 if failures else 0)
