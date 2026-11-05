extends SceneTree
## Exclusive operation versions share selection and combat rules, with a centered first throw.
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(917)
	m.begin_round()
	m.enemies = [m.make_enemy(0)]
	m.enemies[0].hp = 100000; m.enemies[0].max_hp = 100000
	m.enemies[0].intent = {"skill":"rest","type":"rest","target":0,"amount":0,"name":"Rest"}
	return m

func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)

func until(predicate: Callable, seconds: float = 6.0) -> bool:
	var deadline: int = Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/split-controls-"+label+".png")

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	if DisplayServer.get_name() != "headless":
		root.grab_focus(); await create_timer(0.5).timeout
	g.model = fresh(); g._show_pending_skill(false)
	var ui = g.dice_selection
	var controls = g.dice_action_controls
	check(not g.debug_split_controls and not controls.actions_shown(),"Split layout defaults off")
	g._open_debug(); g.debug_page.page = g.debug_page.Page.DICE
	for version in g.ControlVersion.values():
		g._handle_menu_page_click(g.debug_page.control_rect(version).get_center())
		check(g.debug_control_version == version and g.debug_batch_reroll == (version == g.ControlVersion.V2) and g.debug_split_controls == (version == g.ControlVersion.V3),"Exactly one checkbox version controls the layout")
	await capture("debug-"+str(phone))
	g._handle_menu_page_click(g.debug_page.control_rect(g.ControlVersion.V3).get_center())
	g._close_debug(false)
	check(ui.center_label() == "ROLL" and not controls.enabled(false) and not controls.enabled(true),"Opening Roll stays centered; both side controls start disabled")
	await capture("opening-"+str(phone))
	tap(g,controls.action_center(false))
	check(g.view_phase == "ready" and g.model.dice_turn.rolls_left == 5,"Disabled left End Turn cannot start a throw or pass")
	tap(g,g.DICE_CENTER)
	check(g.view_phase == "charging" and ui.center_label() == "STOP!","Center Roll starts the normal Perfect meter")
	g._cancel_charge()
	g.model.roll_pool(true,[1,2,3,4,5,6]); g._show_pending_skill(false)
	for i in range(6): g.dice[i].face = i+1
	check(controls.left_label() == "END TURN" and controls.enabled(false) and not controls.enabled(true),"Empty selection offers End Turn on the left, disabled OK on the right")
	check(controls.action_color("END TURN") == controls.END_TURN_COLOR and controls.action_color("REROLL") == controls.REROLL_COLOR,"Passing is red and rerolling is blue")
	var rounds: int = g.model.round_number
	tap(g,controls.action_center(true))
	check(g.model.round_number == rounds and g.model.dice_turn.rolls_left == 4 and g.view_phase == "ready","Empty OK cannot accidentally end the turn")
	for side in [false,true]:
		var at: Vector2 = controls.action_center(side)
		check(is_equal_approx(at.y,g.DICE_POSITIONS[0].y),"Side controls align with the upper die")
		check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(Rect2(at-Vector2.ONE*(controls.radius()+10),Vector2.ONE*(controls.radius()+10)*2)),"Side touch targets remain onscreen")
		for index in range(6): check(not ui.die_rect(index).grow(controls.radius()+10).has_point(at),"Side buttons do not overlap die touch targets")
	check(g.ARENA.encloses(controls.combo_bounds()) and controls.combo_bounds().end.y < g.player_health_rect().position.y,"Combo and flame halo fit above HP inside the arena")
	check(g._perfect_combo_center() == controls.combo_center(),"Combo-to-damage animation uses the relocated badge")
	g.model.perfect_combo = 0; check(not controls.combo_shown(),"Inactive combo leaves the battlefield clear")
	g.model.perfect_combo = 7; check(controls.combo_shown(),"Active combo is visible")
	await capture("idle-"+str(phone))
	await check_connecting_reroll(g,false,phone)
	await check_match_centering(g,phone)
	# Invalid patterns can still be selected for a reroll; they never enable skill casting.
	g.model.dice_turn.values = [1,1,3,4,5,6]
	for i in range(6): g.dice[i].face = g.model.dice_turn.values[i]
	for i in [0,1]: tap(g,g.DICE_POSITIONS[i])
	check(g.model.dice_turn.selected == [0,1] and controls.enabled(false) and not controls.enabled(true),"Duplicate faces are selectable for rerolls, not skills")
	check(controls.left_label() == "REROLL" and ui.center_label() == "CANCEL","Selected dice switch the left button to Reroll")
	tap(g,controls.action_center(true))
	check(g.view_phase == "ready" and g.model.dice_turn.selected == [0,1],"Invalid OK preserves selection without spending")
	tap(g,g.DICE_CENTER)
	check(g.model.dice_turn.selected.is_empty() and g.model.dice_turn.rolls_left == 4,"Center Cancel clears all with no cost")
	for i in [0,2,5]: tap(g,g.DICE_POSITIONS[i])
	tap(g,controls.action_center(false))
	check(g.view_phase == "rolling" and g.dice.filter(func(d): return d.rolling).size() == 3 and g.model.dice_turn.rolls_left == 3,"Left rerolls all selected dice for one roll")
	check(await until(func(): return g.view_phase == "ready"),"Selected reroll completes")
	check(g.model.dice_turn.selected.is_empty() and not ui.reroll_mode and g.model.perfect_combo == 7 and controls.left_label() == "END TURN","Landing clears selection and returns left End Turn without resetting combo")
	g.model.dice_turn.values = [1,2,3,4,5,6]
	for i in range(6): g.dice[i].face = i+1
	# Drag release previews the skill; only the right-hand OK commits it.
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_motion(g.DICE_POSITIONS[1]); g._handle_motion(g.DICE_POSITIONS[2]); g._handle_release(g.DICE_POSITIONS[2])
	check(g.model.dice_turn.selected == [0,1,2] and g.model.pending.is_empty() and controls.enabled(true),"Drag selects a valid straight and enables OK without casting on release")
	check(controls.enabled(false),"A valid skill selection can still be rerolled instead")
	await create_timer(0.15).timeout
	await capture("skill-"+str(phone))
	g.menu_open = true
	var before: Array = g.model.dice_turn.selected.duplicate()
	tap(g,controls.action_center(false))
	check(g.model.dice_turn.selected == before and g.model.dice_turn.rolls_left == 3,"Menu blocks side actions")
	g.menu_open = false
	g.speed = 30; rounds = g.model.round_number
	tap(g,controls.action_center(true))
	check(g.view_phase != "ready" and g.model.dice_turn.locked.size() >= 3,"Right OK casts the selected skill")
	check(await until(func(): return g.view_phase == "ready" and g.model.round_number > rounds,15),"Cast finishes and returns to the next real turn")
	# Empty left End Turn remains available even when rerolls remain.
	g.model.roll_pool(false,[1,2,3,4,5,6]); g._show_pending_skill(false)
	var progress: int = g.model.reroll_progress
	rounds = g.model.round_number
	tap(g,controls.action_center(false))
	check(g.model.reroll_progress == progress+4,"Empty left End Turn settles all unused rolls immediately")
	check(g.treasure_pickup.orbs.all(func(orb): return orb.origin == controls.action_center(false)),"Treasure orbs originate from the new End Turn button")
	check(await until(func(): return g.view_phase == "ready" and g.model.round_number > rounds,15),"Passing completes the enemy turn")
	g.model.roll_pool(false,[1,2,3,4,5,6]); g._show_pending_skill(false)
	g.model.dice_turn.rolls_left = 0
	tap(g,g.DICE_POSITIONS[0])
	check(controls.left_label() == "REROLL" and not controls.enabled(false) and not controls.enabled(true),"Exhausted selected reroll is disabled without ending the turn")
	tap(g,g.DICE_CENTER)
	check(controls.left_label() == "END TURN" and controls.enabled(false),"Cancel makes passing available after exhaustion")
	# Checkbox changes select one version and clear stale selection; reselecting is harmless.
	g.model.dice_turn.rolls_left = 3
	tap(g,g.DICE_POSITIONS[0])
	g._open_debug(); g._handle_menu_page_click(g.debug_page.control_rect(g.ControlVersion.V3).get_center()); g._close_debug(false)
	check(g.model.dice_turn.selected == [0] and g.debug_control_version == g.ControlVersion.V3,"Clicking the checked version keeps its selection and remains enabled")
	g._open_debug(); g._handle_menu_page_click(g.debug_page.control_rect(g.ControlVersion.V2).get_center()); g._close_debug(false)
	check(not g.debug_split_controls and g.debug_batch_reroll and g.model.dice_turn.selected.is_empty(),"Selecting V2 replaces V3 and clears pending dice")
	tap(g,g.DICE_CENTER); tap(g,g.DICE_POSITIONS[0])
	check(ui.reroll_mode and ui.reroll_selected == [0] and ui.center_label() == "OK","Original batch-confirm center returns")
	g._open_debug(); g._handle_menu_page_click(g.debug_page.control_rect(g.ControlVersion.V1).get_center()); g._close_debug(false)
	tap(g,g.DICE_CENTER); tap(g,g.DICE_POSITIONS[0])
	check(g.view_phase == "rolling" and g.dice[0].rolling,"V1 restores immediate single-die corrections")
	check(await until(func(): return g.view_phase == "ready"),"Original single-die correction completes")
	# Render the new locations with a fully populated tarot quick-access area.
	ui.set_control_version(g.ControlVersion.V3); ui.cancel_gesture()
	for id in g.model.tarots.Catalog.ITEMS: g.model.tarots.add(id)
	g.model.perfect_combo = 7
	await create_timer(0.6).timeout
	await capture("tarots-"+str(phone))
	var language: String = GameText.language
	GameText.set_language("en",false)
	ui.cancel_gesture()
	for i in [0,1]: tap(g,g.DICE_POSITIONS[i])
	await capture("english-"+str(phone))
	GameText.set_language(language,false)
	await check_v4(g,phone)
	g._restart(); g.queue_free(); await process_frame

## V4 preserves the original combo/End Turn slots while sharing V3's batch selection.
func check_v4(g, phone: bool) -> void:
	var ui = g.dice_selection
	var controls = g.dice_action_controls
	g.model = fresh(); g._show_pending_skill(false)
	g._open_debug(); g._handle_menu_page_click(g.debug_page.control_rect(g.ControlVersion.V4).get_center()); g._close_debug(false)
	var right: Vector2 = g._saved_slot_center()
	var left: Vector2 = Vector2(2*g.DICE_CENTER.x-right.x,right.y)
	check(g.debug_control_version == g.ControlVersion.V4 and controls.shared_selection(),"V4 checkbox enables shared selection")
	check(g._perfect_combo_center() == left and not controls.combo_shown(),"V4 keeps the original left Perfect combo")
	check(controls.action_center(true) == right and controls.action_at(left) == -1 and not controls.enabled(false),"V4 uses only the original right action slot")
	check(ui.center_label() == "ROLL" and ui.center_enabled() and not controls.enabled(true),"V4 opening Roll stays in the center")
	tap(g,g.DICE_CENTER)
	check(g.view_phase == "charging","V4 center starts the timed opening throw")
	g._cancel_charge()
	g.model.roll_pool(true,[1,2,3,4,5,6]); g._show_pending_skill(false)
	await check_connecting_reroll(g,true,phone)
	g.model.dice_turn.values = [1,1,3,4,5,6]
	g.model.perfect_combo = 7
	for i in range(6): g.dice[i].face = g.model.dice_turn.values[i]
	check(ui.center_label() == "OK" and not ui.center_enabled() and controls.enabled(true),"V4 empty selection disables center OK and enables right End Turn")
	tap(g,g.DICE_CENTER)
	check(not ui.reroll_mode and g.view_phase == "ready" and g.model.dice_turn.rolls_left == 4,"Empty V4 OK cannot enter reroll mode or spend a roll")
	await capture("v4-idle-"+str(phone))
	for i in [0,1]: tap(g,g.DICE_POSITIONS[i])
	check(g.model.dice_turn.selected == [0,1] and not ui.center_enabled() and controls.enabled(true),"V4 duplicate faces select for batch rerolls without enabling OK")
	check(controls.left_label() == "REROLL","V4 selection switches right End Turn to Reroll")
	tap(g,ui.confirm_center())
	check(g.model.dice_turn.selected == [0,1] and g.model.dice_turn.rolls_left == 4,"V4 invalid center OK leaves selection intact")
	g.model.dice_turn.rolls_left = 0
	tap(g,right)
	check(g.view_phase == "ready" and g.model.dice_turn.selected == [0,1],"V4 exhausted Reroll cannot fall through to End Turn")
	tap(g,ui.cancel_rect().get_center())
	check(g.model.dice_turn.selected.is_empty() and controls.enabled(true),"V4 Deselect restores End Turn even when rolls are exhausted")
	g.model.dice_turn.rolls_left = 4
	for i in [0,2,5]: tap(g,g.DICE_POSITIONS[i])
	g.menu_open = true; tap(g,right); g.menu_open = false
	check(g.model.dice_turn.selected == [0,2,5] and g.model.dice_turn.rolls_left == 4,"Menus block V4 right rerolls")
	tap(g,right)
	check(g.view_phase == "rolling" and g.dice.filter(func(d): return d.rolling).size() == 3 and g.model.dice_turn.rolls_left == 3,"V4 right rerolls the whole selected batch for one roll")
	check(await until(func(): return g.view_phase == "ready"),"V4 batch reroll completes")
	check(g.model.dice_turn.selected.is_empty() and g.model.perfect_combo == 7 and controls.left_label() == "END TURN","V4 landing clears selection and preserves Perfect combo")
	g.model.dice_turn.values = [1,2,3,4,5,6]
	for i in range(6): g.dice[i].face = i+1
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_motion(g.DICE_POSITIONS[1]); g._handle_motion(g.DICE_POSITIONS[2]); g._handle_release(g.DICE_POSITIONS[2])
	check(g.model.dice_turn.selected == [0,1,2] and ui.center_enabled() and controls.enabled(true) and g.model.pending.is_empty(),"V4 drag release previews a straight; center OK casts or right Reroll corrects it")
	await create_timer(0.15).timeout
	await capture("v4-skill-"+str(phone))
	var language: String = GameText.language
	GameText.set_language("en",false); await capture("v4-english-"+str(phone)); GameText.set_language(language,false)
	var rounds: int = g.model.round_number
	tap(g,ui.confirm_center())
	check(g.view_phase != "ready" and g.model.dice_turn.locked.size() >= 3,"V4 center OK commits the selected straight")
	check(await until(func(): return g.view_phase == "ready" and g.model.round_number > rounds,15),"V4 cast completes the real turn")
	g.model.roll_pool(false,[1,2,3,4,5,6]); g._show_pending_skill(false)
	var progress: int = g.model.reroll_progress
	rounds = g.model.round_number
	tap(g,right)
	check(g.model.reroll_progress == progress+4,"V4 empty right End Turn settles remaining rolls")
	check(g._turn_end_center() == right and g.treasure_pickup.orbs.all(func(orb): return orb.origin == right),"V4 treasure receipts originate from the original right button")
	check(await until(func(): return g.view_phase == "ready" and g.model.round_number > rounds,15),"V4 End Turn completes the enemy phase")

## Held and partial connections keep reroll available without enabling an accidental pass.
func check_connecting_reroll(g, right: bool, phone: bool) -> void:
	var ui = g.dice_selection
	var controls = g.dice_action_controls
	var rolls: int = g.model.dice_turn.rolls_left
	g._handle_click(g.DICE_POSITIONS[0])
	check(ui.dragging and controls.enabled(right),"Reroll stays enabled while the first die is held")
	g._handle_motion(g.DICE_POSITIONS[0].lerp(g.DICE_POSITIONS[1],0.5))
	check(ui.dragging and controls.enabled(right),"Reroll stays enabled between dice connections")
	g._handle_motion(g.DICE_POSITIONS[1])
	check(g.model.dice_turn.selected == [0,1] and controls.enabled(right),"Incomplete straight still allows a batch reroll")
	g._handle_motion(g.DICE_POSITIONS[2])
	check(g.model.dice_turn.selected == [0,1,2] and controls.enabled(right),"A complete connected straight also keeps reroll enabled")
	if not right: check(not controls.enabled(true),"V3 skill confirmation still waits for drag release")
	await capture("connecting-"+str(right)+"-"+str(phone))
	g.model.dice_turn.rolls_left = 0
	check(not controls.enabled(right),"Dragging cannot bypass an exhausted reroll budget")
	g.model.dice_turn.rolls_left = rolls
	g._handle_release(g.DICE_POSITIONS[2])
	check(not ui.dragging and controls.enabled(right) and g.model.dice_turn.rolls_left == rolls,"Releasing the connection leaves reroll available without spending")
	ui.cancel_gesture()

## Alike labels stay centered throughout their rise, hold and falling exit in both layouts.
func check_match_centering(g, phone: bool) -> void:
	var label = g.match_announcement
	for count in range(2,7):
		label.play(count)
		for age in [0.0,label.RISE_TIME*0.5,label.RISE_TIME,label.RISE_TIME+label.PEAK_HOLD+0.1]:
			label.age = age
			check(is_equal_approx(label.anchor(60).x,g.DICE_CENTER.x),"Alike announcement remains centered for every match tier")
		label.age = label.RISE_TIME+0.05
		label.set_process(false)
		label.queue_redraw()
		await capture("match-"+str(count)+"-"+str(phone))
	label.clear(); label.set_process(true)

func run() -> void:
	await scene(false); await scene(true)
	print("Split dice controls: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
