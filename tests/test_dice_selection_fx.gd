extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame; await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/dice-style-"+name+".png")

func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	await process_frame
	g.model.roll_pool(false,[1,2,3,4,5,6])
	for i in range(6): g.dice[i].face = i+1
	var select = g.dice_selection
	select.set_process(false)
	var label: String = "portrait" if portrait else "landscape"
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_release(g.DICE_POSITIONS[0])
	select._process(0.1)
	check(g.dice[0].connection_glow and g.dice[0].connection_fire == 0,"Single selected die glows without a completed pattern")
	select.cancel_gesture()
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_motion(g.DICE_POSITIONS[1]); g._handle_motion(g.DICE_POSITIONS[0])
	check(g.model.dice_turn.selected.is_empty(),"Backtracking a pair clears its last die")
	g._handle_release(g.DICE_POSITIONS[0])
	check(g.model.pending.is_empty() and g.model.dice_turn.rolls_left == 2,"Cancelled drag neither summons nor spends rolls")
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_motion(g.DICE_POSITIONS[1])
	g._handle_motion(g.DICE_POSITIONS[1]+Vector2(100,0)); g._handle_motion(g.DICE_POSITIONS[1])
	check(g.model.dice_turn.selected.is_empty(),"Re-entering the endpoint also clears a lone remaining die")
	g._handle_release(g.DICE_POSITIONS[1])
	var previous_particles: int = 0
	for count in range(3,7):
		select.cancel_gesture()
		g.model.dice_turn.selected = range(count)
		select._selection_changed()
		for frame in range(20): select._process(0.04)
		check(select.particles.size() > previous_particles,"Higher straight tiers emit more particles")
		previous_particles = select.particles.size()
		check(g.dice[0].connection_fire == count-2,"Flame intensity follows straight tier")
		check(select.skill_color() == preload("res://scripts/effects/flame_spell.gd").COLORS[count-2],"Straight tier uses its fire color")
		await capture(label+"-tier-"+str(count))
	select.cancel_gesture()
	g.model.dice_turn.locked = [0,1,2,3]
	g.model.dice_turn.committed = [0,1,2,3]
	select._process(0.25)
	check(select.end_turn_prompt_age == 0,"Remaining rerolls suppress the End Turn prompt")
	check(select.should_prompt_roll() and select.roll_prompt_age > 0,"No straight with rerolls available bounces Reroll")
	await capture(label+"-reroll-pulse")
	g.model.dice_turn.rolls_left = 0
	select._process(0.25)
	check(select.end_turn_prompt_age > 0,"End Turn pulses only with no combinations and no rerolls")
	check(not select.should_prompt_roll() and select.roll_prompt_age == 0,"Exhausted rerolls stop the Reroll prompt")
	await capture(label+"-end-turn-pulse")
	g.model.dice_turn.locked = [0,1,2]; g.model.dice_turn.committed = [0,1,2]
	select._process(0.1)
	check(select.end_turn_prompt_age == 0,"An available straight stops the End Turn prompt")
	g.model.dice_turn.locked.clear(); g.model.dice_turn.committed.clear()
	g.model.dice_turn.rolls_left = 2
	g.model.dice_turn.values = [1,2,3,4,5,6]
	select._process(0.1)
	check(not select.should_prompt_roll() and select.roll_prompt_age == 0,"An available straight suppresses the Reroll prompt")
	g.menu_open = true; select._process(0.1)
	check(not select.should_prompt_roll(),"Menus cannot trigger the Reroll prompt")
	g.menu_open = false
	var banner = g.bonus_turn_banner
	banner.set_process(false); banner.play(); banner._process(banner.ENTER)
	g._handle_click(g.DICE_POSITIONS[0]); g._handle_release(g.DICE_POSITIONS[0])
	check(g.model.dice_turn.selected == [0] and g.view_phase == "ready","Banner leaves dice controls responsive")
	select.cancel_gesture()
	banner._process(0.4)
	await capture(label+"-bonus-middle")
	banner._process(0.59)
	check(banner.age > 0 and banner.age < banner.ENTER+banner.HOLD,"Banner remains centered for the full one second")
	g.menu_open = true; var before: float = banner.age; banner._process(0.5)
	check(not banner.visible and banner.age == before,"Menus hide and pause the banner")
	g.menu_open = false; banner._process(0.01+banner.EXIT+0.01)
	check(banner.age == -1,"Banner exits and cleans itself up")
	g.reduced = true
	g.model.dice_turn.values = [1,2,3,4,5,6]; g.model.dice_turn.selected = range(6)
	select._selection_changed(); select._process(0.1)
	check(select.particles.size() <= 6,"Reduced effects keep a restrained particle budget")
	g._restart()
	check(banner.age == -1 and g.dice.all(func(d): return d.connection_fire == 0 and not d.connection_glow),"Restart clears banner and dice effects")
	g.queue_free(); await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	await layout(false); await layout(true)
	print("Dice selection FX: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
