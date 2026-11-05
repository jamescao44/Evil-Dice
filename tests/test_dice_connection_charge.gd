extends SceneTree
## Verify reverse ordering, partial beam fills and live dice feedback without changing combat.
const Charge = preload("res://scripts/dice/dice_connection_charge.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func sequence_rules() -> void:
	var charge = Charge.new()
	var order: Array = [4,1,5,0,2]
	var color := Color("ff7440")
	for count in [3,4]:
		var small: Array = order.slice(0,count)
		charge.sync(small,range(1,count+1),color,true)
		check(small.all(func(i): return charge.flash(i) == 1.0 and charge.die_color(i) == color),"Three- and four-straights flash every die together")
		check(range(count-1).all(func(i): return charge.segment_fill(i) == 1.0),"Lower straight links adopt skill color instantly")
		charge.advance(Charge.FLASH_SECONDS,false)
		check(small.all(func(i): return charge.flash(i) == 0 and charge.die_color(i) == color),"Simultaneous flashes fade without removing the colored outline")
	charge.sync(order,[1,2,3,4,5],color,true)
	check(charge.reached(2) and not charge.reached(0) and charge.flash(2) == 1.0,"Only the last connected die flashes at higher-tier formation")
	charge.advance(Charge.LINK_SECONDS*0.5,false)
	check(is_equal_approx(charge.segment_fill(3),0.5) and charge.segment_fill(2) == 0 and charge.segment_fill(0) == 0,"Color first fills half of the final link from its last endpoint")
	check(charge.die_color(2) == color and charge.die_color(0) == Color.WHITE,"Unreached dice stay white")
	var age: float = charge.age
	charge.sync(order,[1,2,3,4,5],color,true)
	check(charge.age == age,"Repeated preview refreshes never restart the wave")
	charge.advance(Charge.LINK_SECONDS*0.5,false)
	check(charge.segment_fill(3) == 1 and charge.segment_fill(2) == 0 and charge.flash(0) > 0.99,"First arrival flashes the next die before coloring its outgoing link")
	charge.advance(Charge.LINK_SECONDS*0.5,false)
	check(is_equal_approx(charge.segment_fill(2),0.5) and charge.segment_fill(1) == 0,"Color travels backward through one link at a time")
	charge.advance(10,false)
	check(order.all(func(index): return charge.die_color(index) == color and charge.flash(index) == 0),"Completed chain retains skill color after arrival flashes fade")
	charge.sync([4,1,5,0,2,3],[1,2,3,4,5,6],Color.RED,true)
	check(charge.age == 0 and charge.reached(3) and not charge.reached(0),"Extending a skill restarts from the new last die")
	charge.sync([4,1],[1,2],Color.WHITE,false)
	check(charge.order.is_empty() and charge.flash(1) == 0 and charge.segment_fill(0) == 0,"Invalid partial selections clear all propagation")
	charge.sync(order,[1,2,3,4,5],color,true)
	charge.advance(0,true)
	check(order.all(func(index): return charge.reached(index) and charge.flash(index) == 0),"Reduced effects immediately show final colors without flashes")

func capture(label: String, g) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	# Freeze the sampled pose across desktop focus changes; input behavior is tested separately.
	var selection: Array = g.model.dice_turn.selected.duplicate()
	var age: float = g.dice_selection.connection_charge.age
	await process_frame; await process_frame
	g.model.dice_turn.selected = selection
	g.dice_selection._refresh_preview()
	g.dice_selection.connection_charge.age = age
	g.dice_selection._process(0)
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/connection-charge-"+label+".png")

func layout(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	if DisplayServer.get_name() != "headless":
		root.grab_focus(); await create_timer(0.5).timeout
	g.model = Run.new(917); g.model.begin_round()
	g.model.roll_pool(false,[1,2,3,4,5,6]); g._show_pending_skill(false)
	for i in range(6): g.dice[i].face = i+1
	var ui = g.dice_selection
	ui.set_control_version(g.ControlVersion.V4)
	ui.set_process(false)
	var budget: int = g.model.dice_turn.rolls_left
	for count in range(3,7):
		ui.cancel_gesture()
		g._handle_click(g.DICE_POSITIONS[0])
		for i in range(1,count): g._handle_motion(g.DICE_POSITIONS[i])
		g._handle_release(g.DICE_POSITIONS[count-1])
		ui._process(0)
		check(g.model.dice_turn.selected == range(count) and ui.connection_charge.order == range(count),"Drag order drives the charge for each straight tier")
		if count <= 4:
			check(range(count).all(func(i): return g.dice[i].connection_flash > 0.99 and g.dice[i].connection_color == ui.skill_color()),"All lower-tier dice flash and color together in the real scene")
			check(range(count-1).all(func(i): return ui.connection_charge.segment_fill(i) == 1),"Lower-tier beams are fully colored immediately")
			await capture(str(phone)+"-instant-"+str(count),g)
		else:
			check(g.dice[count-1].connection_flash > 0.99 and g.dice[0].connection_flash == 0,"Last die flashes first for higher tiers in the real scene")
			check(g.dice[0].connection_color == Color.WHITE and g.dice[0].connection_fire == 0,"Higher-tier flames and colored glow wait for arrival")
		check(ui.center_enabled() and g.dice_action_controls.enabled(true),"Skill confirmation and reroll remain available during propagation")
		for hop in range(count-1 if count >= 5 else 0):
			ui.connection_charge.age = (hop+0.5)*Charge.LINK_SECONDS
			ui._process(0)
			check(is_equal_approx(ui.connection_charge.segment_fill(count-2-hop),0.5),"Each visible link colors from one end to the other")
			if count == 5: await capture(str(phone)+"-link-"+str(hop),g)
			ui.connection_charge.age = (hop+1)*Charge.LINK_SECONDS
			ui._process(0)
			var reached: int = count-2-hop
			check(g.dice[reached].connection_color == ui.skill_color() and g.dice[reached].connection_flash > 0.99,"Each reached die flashes and adopts the skill color")
		ui._process(1)
		check(range(count).all(func(i): return g.dice[i].connection_color == ui.skill_color() and g.dice[i].connection_flash == 0),"All connected dice hold the completed tier color")
		await capture(str(phone)+"-complete-"+str(count),g)
		g.menu_open = true
		var age: float = ui.connection_charge.age
		ui._process(1); g.menu_open = false
		check(ui.connection_charge.age == age,"Menus pause the connection animation")
	check(g.model.dice_turn.rolls_left == budget and g.model.pending.is_empty(),"Animation does not spend rolls or auto-cast the selected skill")
	ui.cancel_gesture()
	check(ui.connection_charge.order.is_empty() and g.dice.all(func(d): return d.connection_flash == 0 and not d.connection_glow),"Deselect clears beam colors and flashes immediately")
	g._restart(); g.queue_free(); await process_frame

func run() -> void:
	sequence_rules()
	await layout(false); await layout(true)
	print("Dice connection charge: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
