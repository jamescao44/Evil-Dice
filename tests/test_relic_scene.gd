extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
var game

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func until_phase(phase: String) -> void:
	var end: int = Time.get_ticks_msec()+6000
	while game.view_phase != phase and Time.get_ticks_msec() < end: await process_frame
	check(game.view_phase == phase,"Reached phase " + phase)

func until_pickup_finished() -> void:
	var end: int = Time.get_ticks_msec()+2000
	while game.relic_ui.pickup.active and Time.get_ticks_msec() < end: await process_frame
	check(not game.relic_ui.pickup.active,"Relic pickup completes before another reward can be chosen")

func capture(name: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-output")
	root.get_texture().get_image().save_png("res://test-output/relic-%s-%s.png" % ["portrait" if game is Portrait else "landscape",name])

func open_test_chest(ids: Array) -> void:
	game.model._roll_chest(0)
	# A deterministic award fixture, supplied before the view snapshots prizes.
	game.model.open_rewards.clear()
	game.model.chest_relics.clear()
	game.model.chest_tarots.clear()
	for i in range(ids.size()):
		game.model.open_rewards.append(game.Rewards.Category.RELIC)
		game.model.chest_relics[i] = ids[i]
	game._show_chest(game.model.open_rewards.duplicate())
	var deadline: int = Time.get_ticks_msec()+3000
	while not game.chest.visible and Time.get_ticks_msec() < deadline: await process_frame
	game.chest.open_chest()
	game.chest.skip_animation()
	game.chest.skip_animation()
	while game.chest.active and Time.get_ticks_msec() < deadline+5000: await process_frame

func pickup_destination_checks() -> void:
	var pages: Array = []
	pages.resize(9)
	pages.fill("codex_page")
	var cases: Array = [
		{"owned":["heart","codex_page"],"pick":"codex_page","result":"codex_page"},
		{"owned":["heart"]+pages,"pick":"codex_page","result":"ancient_codex"},
		{"owned":["heart"]+game.relic_ui.Catalog.STONES.slice(0,5),"pick":game.relic_ui.Catalog.STONES[5],"result":"prismatic_stone"}
	]
	for case in cases:
		game._restart()
		for id in case.owned: game.model.acquire_relic(id)
		await open_test_chest([case.pick])
		game._handle_click(game.chest.reel_rect(0).get_center())
		check(game.relic_ui.pickup.active and game.relic_ui.pickup.slot == 1 and game.model.relics.items[1].id == case.result,"Pickup lands on the acquired stack or fused relic: "+case.result)
		if case.result == "ancient_codex":
			game.reduced = true
			game.relic_ui.pickup.advance(game.relic_ui.Pickup.LAND_TIME)
			check(game.relic_ui.pickup.inventory_scale(1,true) == Vector2.ONE,"Reduced effects omit the impact squash")
		if case.result == "prismatic_stone":
			game._restart()
			check(not game.relic_ui.pickup.active and game.model.relics.items.is_empty(),"Restart cancels the pending flight and its wave transition")
			continue
		await until_phase("ready")
		game.reduced = false
	game._restart()

func charged_item_checks() -> void:
	game._restart()
	for id in ["codex_page","heart","magic_shield","magic_sword","reaper_scythe","cursed_bow","orange_stone"]: game.model.acquire_relic(id)
	game.model.acquire_relic("codex_page")
	game.model.acquire_relic("codex_page")
	var catalog = game.relic_ui.Catalog
	var items: Array = game.model.relics.items
	items[2].charges = 2
	items[3].charges = 1
	items[4].kills = 12
	items[5].waves = 4
	for i in range(items.size()):
		check(catalog.counter_value(items[i]) == [3,0,2,1,12,4,0][i],"Badges show only an item's stack, charge, or accumulated effect count")
	var ui = game.relic_ui
	ui.set_process(false)
	ui.ready_clock = PI/(2*4.5)
	var bright: float = ui.ready_glow(items[2])
	ui.queue_redraw()
	await capture("charged-bright")
	ui.ready_clock = 3*PI/(2*4.5)
	check(bright > ui.ready_glow(items[2]) and ui.ready_glow(items[2]) > 0,"Stored charges repeat a glow without going completely dark")
	check(ui.ready_glow(items[0]) == 0 and ui.ready_glow(items[1]) == 0,"Uncharged stacks and passive relics do not pretend to be charged")
	ui.queue_redraw()
	await capture("charged-dim")
	game.reduced = true
	var still: float = ui.ready_glow(items[2])
	ui.ready_clock += 1
	check(ui.ready_glow(items[2]) == still,"Reduced effects retain a steady ready glow")
	game.reduced = false
	game.menu_open = true
	var paused: float = ui.ready_clock
	ui._process(1)
	check(ui.ready_clock == paused,"Menus pause the ready pulse")
	game.menu_open = false
	game._handle_click(ui.slot_rect(2).get_center())
	game._handle_motion(ui.slot_rect(6).get_center()-Vector2(0,100))
	ui.queue_redraw()
	await capture("charged-drag")
	game._handle_release(ui.slot_rect(6).get_center())
	var shield: Dictionary = game.model.relics.items[game.model.relics.index_of("magic_shield")]
	check(catalog.counter_value(shield) == 2 and catalog.charged(shield),"Charge count and ready state follow the item when reordered")
	game.model.receive_damage(5)
	check(shield.charges == 1 and ui.ready_glow(shield) > 0,"A remaining stored charge keeps the glow active")
	game.model.receive_damage(5)
	check(shield.charges == 0 and ui.ready_glow(shield) == 0,"Spending the last shield charge stops its repeating glow")
	game.model.set_test_roll([1,1,2])
	game.model.begin_player_cast()
	var sword: Dictionary = game.model.relics.items[game.model.relics.index_of("magic_sword")]
	check(game.model.pending.critical and sword.charges == 0 and ui.ready_glow(sword) == 0,"Casting consumes the sword charge and clears its ready glow")
	ui.activations.clear()
	ui.queue_redraw()
	await capture("charges-spent")
	ui.set_process(true)
	game._restart()

func run() -> void:
	game = Portrait.new() if "--portrait" in OS.get_cmdline_user_args() else Battle.new()
	root.add_child(game)
	game.muted = true; game.speed = 20
	await open_test_chest(["armor"])
	var offers: Array = ["armor"]
	await capture("choices")
	game._handle_click(game.chest.reel_rect(0).get_center())
	var ui = game.relic_ui
	check(ui.pickup.active and game.model.claimed_slots == [0] and game.model.stage == 0,"Choice commits once while the wave waits for its inventory landing")
	game._handle_click(game.chest.reel_rect(0).get_center())
	check(game.model.relics.items.size() == 1 and game.model.relics.has(offers[0]),"Tapping again during pickup cannot grant another relic")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	check(ui.pickup.active,"Focus changes cancel held input without dropping an acquired relic's animation")
	ui.set_process(false)
	game.menu_open = true
	ui._process(1)
	check(ui.pickup.age == 0,"Menus pause the pickup animation")
	game.menu_open = false
	ui.pickup.advance(0.26)
	ui.queue_redraw()
	await capture("pickup-flight")
	ui.pickup.advance(ui.Pickup.LAND_TIME-ui.pickup.age+0.025)
	check(ui.pickup.landed and game.view_phase == "reward","The impact is shown before leaving the reward screen")
	ui.queue_redraw()
	await capture("pickup-impact")
	ui.set_process(true)
	await until_phase("ready")
	check(game.model.stage == 0 and game.model.relics.has(offers[0]),"Selecting a relic returns to the prior battle")
	await pickup_destination_checks()
	await charged_item_checks()
	game._restart()
	for id in ["heart","armor","coin"]: game.model.acquire_relic(id)
	check(game.relic_ui.inventory_rect().position.y > game.ARENA.end.y,"Inventory sits outside the battlefield")
	var hold: Vector2 = game.relic_ui.slot_rect(0).get_center()
	game._handle_click(hold)
	check(game.relic_ui.pressed == 0 and not game.relic_ui.dragging,"Holding an item selects its description immediately")
	game._handle_motion(hold-Vector2(0,180))
	check(not game.relic_ui.dragging and game.relic_ui.held_position() == hold,"Vertical movement keeps the held item stationary")
	await capture("holding")
	game._handle_release(hold)
	check(game.relic_ui.pressed == -1,"Releasing dismisses the held description")
	var empty_end: Vector2 = game.relic_ui.slot_rect(9).get_center()
	game._handle_click(game.relic_ui.slot_rect(0).get_center())
	game._handle_motion(empty_end-Vector2(0,180))
	check(is_equal_approx(game.relic_ui.held_position().y,hold.y),"Horizontal dragging stays on the inventory rail")
	check(game.relic_ui.drop_index(empty_end) == 2,"Dragging into unused bar space indicates insertion at the end")
	game._handle_release(empty_end-Vector2(0,180))
	check(game.model.relics.items.map(func(item): return item.id) == ["armor","coin","heart"],"Dropping in unused space appends without creating empty slots")
	game._restart(5)
	var locale: String = GameText.language
	for language in GameText.LANGUAGES:
		GameText.set_language(language,false)
		for id in game.relic_ui.Catalog.ITEMS:
			game.model.relics.items = [{"id":id}]
			var tooltip: Rect2 = game.relic_ui.tooltip_rect(0)
			check(tooltip.position.y >= 20 and tooltip.end.y < game.relic_ui.inventory_rect().position.y,"Held description fits above inventory: "+language+" "+id)
		game.model.relics.items = [{"id":"magic_sword","turns":5,"charges":1}]
		game._handle_click(game.relic_ui.slot_rect(0).get_center())
		await capture("description-"+language)
		game._handle_release(game.relic_ui.slot_rect(0).get_center())
	game.model.relics.items.clear()
	GameText.set_language(locale,false)
	for id in ["codex_page","heart","bracelet","armor","coin","magic_shield","magic_sword","twin_scythes","orange_stone","blue_stone"]:
		game.model.acquire_relic(id)
	var before: Array = game.model.relics.items.map(func(item): return item.id)
	var from: Vector2 = game.relic_ui.slot_rect(0).get_center()
	var to: Vector2 = game.relic_ui.slot_rect(9).get_center()
	game._handle_click(from); game._handle_motion(to)
	check(game.relic_ui.dragging and game.relic_ui.drop_index(to) == 9,"Drag indicator identifies the final inventory position")
	await capture("dragging")
	game._handle_release(to)
	check(game.model.relics.items[9].id == before[0] and game.model.relics.items[0].id == before[1],"Dragging moves a relic and shifts intervening slots")
	check(game.view_phase == "ready" and not game.skill_pressed,"Relic dragging cannot throw dice or select skills")
	var ordered: Array = game.model.relics.items.map(func(item): return item.id)
	game._handle_click(to); game._handle_motion(Vector2.ZERO); game._handle_release(Vector2.ZERO)
	check(game.model.relics.items.map(func(item): return item.id) == ordered,"Dropping outside the bar cancels the reorder")
	check(game.relic_ui.drop_index(Vector2.ZERO) == -1,"No placement indicator outside the bar")
	game.model.apply_enemy_status(0,game.Status.BURNING,3)
	game.model.apply_enemy_status(0,game.Status.FROZEN,1)
	game.model.apply_enemy_status(0,game.Status.DARKNESS,3)
	game.model.apply_enemy_status(0,game.Status.CORROSION,3)
	game.model.apply_enemy_status(0,game.Status.PLAGUE,1)
	await capture("inventory")
	await open_test_chest(["contract"])
	game._handle_click(game.chest.reel_rect(0).get_center())
	check(game.relic_ui.chest_slot == 0 and game.model.relics.items.size() == 10,"Full inventory prompts for replacement")
	await capture("replacement")
	game._handle_click(game.relic_ui.slot_rect(2).get_center())
	await until_phase("ready")
	check(game.model.relics.items[2].id == "contract" and game.model.relics.items.size() == 10,"Replacement preserves position and slot limit")
	var rubies: int = game.model.blood_gems
	await open_test_chest(["bloodstone"])
	game._handle_click(game.chest.skip_rect().get_center())
	await until_phase("ready")
	check(game.model.blood_gems == rubies+30,"Skipping gifts retains the normal chest crystal payout")
	game.model.reroll_progress = 15
	game.model.reward_weights = [0,1,0,0,0,0,0]
	game._reward_sequence()
	var deadline: int = Time.get_ticks_msec()+4000
	while not game.chest.visible and Time.get_ticks_msec() < deadline: await process_frame
	check(game.chest.visible and game.model.chest_relics.size() == 5 and game.model.chest_tarots.is_empty(),"Forced relic category locks five real relics")
	game.chest.open_chest()
	game.chest.set_process(false)
	game.chest.elapsed = 3.8
	game.chest.queue_redraw()
	await capture("chest-spinning")
	game.chest.set_process(true)
	game.chest.playback_speed = 100
	while game.chest.active and Time.get_ticks_msec() < deadline: await process_frame
	check(not game.chest.active,"Relic reels finish normally")
	game.model.claim_reward(0,-1,true)
	game.chest.collected.append(0)
	for slot in range(1,5):
		var prize: String = game.model.chest_relics[slot]
		check(game.chest.symbols[game.chest.rewards[slot]].relic_id == prize,"Reel lands on the exact locked relic")
		game._handle_click(game.chest.reel_rect(slot).get_center())
		if slot in game.chest.collected:
			check(prize == "codex_page","Pages stack directly even when inventory is full")
			await until_pickup_finished()
			continue
		check(game.relic_ui.chest_slot == slot,"A full inventory prompts before claiming a chest relic")
		if slot == 0: await capture("chest-replacement")
		if slot == 4: game._handle_click(game.relic_ui.skip_rect().get_center())
		else: game._handle_click(game.relic_ui.slot_rect(slot).get_center())
		check(slot in game.chest.collected and (not game.model.relics.has(prize) if slot == 4 else game.model.relics.has(prize)),"Replacement or leaving a chest relic resolves exactly one gift")
		if slot != 4:
			check(game.relic_ui.pickup.active and game.relic_ui.pickup.slot == slot,"Chest replacements fly to the chosen inventory position")
			if slot == 0: await capture("chest-pickup")
		await until_pickup_finished()
	await until_phase("ready")
	game._restart()
	game.model.acquire_relic("magic_sword")
	game.model.relics.items[0].turns = 5
	game.model.enemies[0].hp = 5
	game.model.enemies[0].acted = true
	game.model.apply_enemy_status(0,game.Status.BURNING,1)
	game.model.apply_affliction(game.Status.BURNING,3)
	game.model.phase = "enemy"; game.view_phase = "resolving"
	await game._resolve_turn_end(game.run_id)
	while game.view_phase == "collecting": await process_frame
	check(game.view_phase == "reward" and game.model.wave_chest_stage == game.model.stage and game.model.hp == 85 and game.model.status_count(game.Status.BURNING) == 2,"Enemy burn victory waits for every player burn tick before the wave chest")
	check(game.model.relics.items[0].charges == 1,"A status-effect victory completes the sixth relic turn")
	game._restart(Waves.COUNT)
	game.model.city_hp = 0; game.model.reroll_progress = 15
	game.model.wave_chest_stage = game.model.stage
	game.model.wave_reward_resolved = true
	game._check_over()
	await until_phase("over")
	check(game.model.open_rewards.size() == 5 and game.auto_claim_tier == 3,"Victory preserves banked Ultra chest")
	game._restart()
	check(game.model.relics.items.is_empty() and game.model.open_rewards.is_empty(),"Restart clears inventory and pending choices")
	game.queue_free(); await process_frame
	print("Relic UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
