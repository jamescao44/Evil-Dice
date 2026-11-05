extends SceneTree
## Debug batch corrections share budgets and modifiers while leaving single-tap rerolls intact.
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
	m.roll_pool(true,[1,2,3,4,5,6])
	return m

func snapshot(m) -> Array:
	return [m.rng.state,m.dice_turn.values.duplicate(),m.dice_turn.rolls_left,m.dice_turn.rolls_made,m.same_pip_rerolls,m.perfect_combo]

func rules() -> void:
	var m = fresh()
	var before: Array = snapshot(m)
	for indices in [[],[0,0],[-1,2],[0,6],[0,1.0],["1"],[0,1,2,3,4,5,6]]:
		check(m.reroll_dice(indices).is_empty() and snapshot(m) == before,"Invalid batch changes no dice, budget, combo or RNG")
	check(m.reroll_dice([0,2],[5]).is_empty() and snapshot(m) == before,"Bad forced-face count is atomic")
	check(m.reroll_dice([0,2],[5,7]).is_empty() and snapshot(m) == before,"Invalid forced face is atomic")
	check(m.reroll_dice([0,2,5],[5,1,3]) == [0,2,5],"Batch returns its exact physical dice")
	check(m.dice_turn.values == [5,2,1,4,5,3],"Only selected dice change")
	check(m.dice_turn.rolls_left == 3 and m.dice_turn.rolls_made == 2,"Any batch spends one roll, not one per die")
	check(m.perfect_combo == 1 and m.roll_attacks.is_empty() and m.phase == "roll","Batch preserves combo and does not attack")
	m = fresh(); m.dice_turn.locked = [1]; m.dice_turn.committed = [1]
	before = snapshot(m)
	check(m.reroll_dice([0,1]).is_empty() and snapshot(m) == before,"One used die rejects the entire batch")
	m = fresh(); m.dice_turn.reset()
	before = snapshot(m)
	check(m.reroll_dice([0,1]).is_empty() and snapshot(m) == before,"Batch cannot replace the timed opening throw")
	m = fresh(); m.dice_turn.selected = [0,1,2]; m.form_selected_skill()
	before = snapshot(m)
	check(m.reroll_dice([3,4]).is_empty() and snapshot(m) == before,"Pending skill locks batch corrections")
	m = fresh(); m.reroll_dice([0,1,2,3],[1,2,3,4])
	check(m.same_pip_rerolls == 4 and m.dice_turn.values[0] == 1 and m.dice_turn.values[1] != 2 and m.dice_turn.values[2] == 3 and m.dice_turn.values[3] != 4,"Same-pip protection advances across every die in a batch")
	m = fresh(); m.tarot_effects.dice_boost = 1; m.tarot_effects.star_throws = 3
	m.reroll_dice([0,2],[5,5])
	check(m.dice_turn.values == [6,2,6,4,5,6] and m.tarot_effects.star_throws == 3,"Face boosts affect selected dice, without spending Star")
	m = fresh(); m.tarot_effects.lovers = true
	m.reroll_dice([0,1,2],[5,5,5])
	check(m.tarot_effects.lovers,"Four-die guarantee waits for a large enough batch")
	m.reroll_dice([0,1,2,3],[1,2,3,4])
	var faces: Array = m.dice_turn.values.slice(0,4); faces.sort()
	check(not m.tarot_effects.lovers and faces[3]-faces[0] == 3 and faces[0]+1 == faces[1] and faces[1]+1 == faces[2],"Lovers applies once to a qualifying batch")
	check(m.roll_attacks.is_empty(),"Guaranteed results still do not queue automatic attacks")
	m = fresh(); m.tarot_effects.devil = 3
	m.reroll_dice([0,1,2],[2,3,4])
	check(m.dice_turn.values == [6,6,6,4,5,6] and m.tarot_effects.devil == 0 and m.roll_attacks.is_empty(),"Devil uses only selected dice without firing matching attacks")
	m = fresh(); m.dice_turn.ticket_rolls_left = 1; m.dice_turn.rolls_left = 2
	m.reroll_dice(range(6),[2,3,4,5,6,1])
	check(m.dice_turn.rolls_left == 1 and m.dice_turn.ticket_rolls_left == 1 and m.dice_turn.rewardable_rolls() == 0,"Batch spends ordinary roll before Ticket and treasure excludes Ticket")
	m.reroll_dice(range(6),[3,4,5,6,1,2])
	check(m.dice_turn.rolls_left == 0 and m.dice_turn.ticket_rolls_left == 0,"Ticket pays for a full batch")
	before = snapshot(m)
	check(m.reroll_dice([0,1]).is_empty() and snapshot(m) == before,"No batch can reroll on an exhausted budget")
	# Compare the legacy wrapper against the shared one-die path with identical random streams.
	for seed_value in range(12):
		var single = fresh(); var batch = fresh()
		single.rng.seed = seed_value; batch.rng.seed = seed_value
		for index in [0,3,5,1]:
			check(single.reroll_die(index) == batch.reroll_dice([index]) and snapshot(single) == snapshot(batch),"Default single-die results and RNG order stay identical")

func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+6000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/batch-reroll-"+label+".png")

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	# Let native window resizing/focus notifications settle before synthetic touch input.
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await create_timer(0.5).timeout
	g.model = fresh(); g._show_pending_skill(false)
	for i in range(6): g.dice[i].face = i+1
	await process_frame
	var ui = g.dice_selection
	check(not g.debug_batch_reroll,"Experiment defaults off")
	g._open_debug(); g.debug_page.page = g.debug_page.Page.DICE
	g._handle_menu_page_click(g.debug_page.control_rect(g.ControlVersion.V2).get_center())
	check(g.debug_batch_reroll,"Dice debug tab enables batch mode")
	await capture("debug-"+str(phone))
	g._close_debug(false)
	tap(g,g.DICE_CENTER); await process_frame
	check(ui.reroll_mode and ui.center_label() == "DONE","Empty reroll selection offers Done")
	var before: Array = snapshot(g.model)
	for i in [0,2,5]: tap(g,g.DICE_POSITIONS[i])
	await create_timer(0.15).timeout
	check(ui.reroll_selected == [0,2,5] and snapshot(g.model) == before and g.view_phase == "ready","Taps select multiple dice without rolling or spending")
	check(ui.center_label() == "OK" and g.model.dice_turn.selected.is_empty() and ui.preview.is_empty(),"Batch uses OK without constructing a skill preview")
	check([0,2,5].all(func(i): return g.dice[i].connection_glow and g.dice[i].selection_emphasis > 0.9),"Chosen dice lift and glow")
	check([1,3,4].all(func(i): return not g.dice[i].connection_glow),"Unselected dice remain distinct")
	await capture("selected-"+str(phone))
	for i in [0,2,5]: tap(g,g.DICE_POSITIONS[i])
	check(ui.reroll_selected.is_empty() and ui.center_label() == "DONE" and snapshot(g.model) == before,"Tapping selected dice freely deselects; no selection restores Done")
	tap(g,g.DICE_CENTER)
	check(not ui.reroll_mode and snapshot(g.model) == before,"Done exits without spending")
	tap(g,g.DICE_CENTER)
	for i in [0,2,5]: tap(g,g.DICE_POSITIONS[i])
	tap(g,ui.confirm_center())
	check(g.view_phase == "rolling" and g.dice.filter(func(d): return d.rolling).size() == 3,"OK starts only selected dice together")
	check(g.model.dice_turn.rolls_left == 3,"Batch charges one roll")
	check(await until(func(): return g.view_phase == "ready"),"Batch animation returns control")
	await process_frame
	check(ui.reroll_mode and ui.reroll_selected.is_empty() and ui.center_label() == "DONE" and g.model.perfect_combo == 1,"Landing clears selection, preserves mode and Perfect combo")
	# Pending selections never leak into ordinary single-tap behavior when the toggle changes.
	tap(g,g.DICE_POSITIONS[1]); g._open_debug()
	g._handle_menu_page_click(g.debug_page.control_rect(g.ControlVersion.V1).get_center())
	g._close_debug(false)
	check(not g.debug_batch_reroll and ui.reroll_selected.is_empty() and not ui.reroll_mode,"Turning off experiment clears pending batch")
	tap(g,g.DICE_CENTER); tap(g,g.DICE_POSITIONS[4])
	check(g.view_phase == "rolling" and g.dice[4].rolling and g.dice.filter(func(d): return d.rolling).size() == 1,"Default mode still rerolls on the first die tap")
	check(await until(func(): return g.view_phase == "ready"),"Single correction still completes")
	g._open_debug(); g._handle_menu_page_click(g.debug_page.control_rect(g.ControlVersion.V2).get_center()); g._close_debug(false)
	g.model.dice_turn.rolls_left = 1
	tap(g,g.DICE_CENTER)
	for i in range(6): tap(g,g.DICE_POSITIONS[i])
	tap(g,ui.confirm_center())
	check(await until(func(): return g.view_phase == "ready"),"Six-die batch completes")
	await process_frame
	check(not ui.reroll_mode and ui.reroll_selected.is_empty() and g.dice.all(func(d): return not d.reroll_hint),"Last roll exits mode and clears every highlight")
	g.model.dice_turn.reset(); g.model.phase = "roll"; g.model.roll_pool(false,[1,2,3,4,5,6])
	tap(g,g.DICE_CENTER); tap(g,g.DICE_POSITIONS[0])
	g.model.dice_turn.reset(); await process_frame
	check(not ui.reroll_mode and ui.reroll_selected.is_empty(),"New turn clears pending batch")
	g.model.roll_pool(false,[1,2,3,4,5,6])
	tap(g,g.DICE_CENTER); tap(g,g.DICE_POSITIONS[0]); ui.cancel_gesture()
	check(ui.reroll_selected.is_empty() and ui.center_label() == "DONE","Tarot or focus-change cancellation clears reroll selection too")
	g._restart(); g.queue_free(); await process_frame

func run() -> void:
	rules(); await scene(false); await scene(true)
	print("Batch rerolls: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
