extends SceneTree
## Real turn settlement, cosmetic receipts, and consistent backpack destinations.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")

func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.treasure_pickup.queue_redraw(); g.inventory_page.queue_redraw(); g.relic_ui.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/treasure-fx-%s-%s.png" % ["portrait" if g is Portrait else "landscape",label])

func settle_turn(m) -> void:
	m.end_dice_turn(); m.apply_player()
	for index in m.living():
		m.enemies[index].intent = {"type":"attack","target":-1,"amount":0}
		m.enemy_act(index)
	m.end_round()

func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 1
	g.process_mode = Node.PROCESS_MODE_DISABLED
	var m = g.model
	var receipt = g.treasure_pickup
	m.roll_pool(false,[1,2,3,4,5,6]); settle_turn(m)
	check(m.reroll_progress == 2 and receipt.orbs.size() == 2,"Two unused rolls bank immediately and spawn two receipts")
	check(receipt.displayed_progress() == 0,"Meter waits for the visual receipt without delaying model credit")
	m._bank_unused_rolls()
	check(receipt.orbs.size() == 2,"Duplicate settlement never duplicates receipts")
	var state: int = m.rng.state
	var reward_state: int = m.reward_rng.state
	g.view_phase = "ready"
	receipt.advance(0.33)
	await capture(g,"orbs")
	g.menu_open = true; receipt._process(1)
	check(receipt.displayed_progress() == 0 and not receipt.visible,"Menus pause and cover traveling orbs")
	g.menu_open = false; receipt._process(0)
	receipt.advance(0.25)
	check(receipt.displayed_progress() == 1 and receipt.impacts.size() == 1,"First landing lights exactly one diamond")
	await capture(g,"first-landing")
	receipt.advance(0.13)
	check(receipt.displayed_progress() == 2 and receipt.orbs.is_empty(),"Second arrival completes the receipt")
	check(m.rng.state == state and m.reward_rng.state == reward_state,"Receipt animation never consumes gameplay randomness")
	m.reroll_progress = 9; m.begin_round(); m.roll_pool(false,[1,2,3,4,5,6]); settle_turn(m)
	check(receipt.orbs.size() == 1 and receipt.orbs[0].index == 9,"Cap sends only the one point that fits in the meter")
	m.open_chest()
	check(receipt.orbs.is_empty() and receipt.displayed_progress() == 0,"Claim during flight clears stale receipts without repeating a reward")
	m.discard_unclaimed_rewards(); m.close_chest()
	g.view_phase = "ready"
	var target: Vector2 = g.inventory_page.button_rect().get_center()
	check(target.x > g.DICE_CENTER.x and target.y > g.DICE_CENTER.y,"Backpack sits at bottom-right of the dice area")
	for phase in ["reward","over","ready"]:
		g.view_phase = phase
		check(g.relic_ui.pickup_target() == target,"Battle, chest and victory relics share the same backpack destination")
	check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(g.inventory_page.button_rect()),"Backpack remains inside the canvas")
	g.view_phase = "reward"
	m._roll_chest(1)
	var prizes: Array = []
	for index in range(m.open_rewards.size()): prizes.append(m.reward_item(index))
	g.chest.start(m.open_rewards,g.fx.canvas_size,g.description_font,true,prizes,1)
	g.chest.open_chest(); g.chest.request_stop(); g.chest._finish_reels()
	m.acquire_relic("heart")
	g.relic_ui.collect("heart",g.fx.canvas_size*Vector2(0.5,0.43),48,[])
	g.relic_ui.pickup.advance(0.32)
	await capture(g,"relic-flight")
	g.relic_ui.pickup.advance(0.07)
	check(g.relic_ui.pickup.flight_position(target,false).distance_to(target) < 0.01,"Relic reaches the exact backpack center")
	await capture(g,"backpack-impact")
	g.chest.cancel(); g.queue_free(); await process_frame

func run() -> void:
	await layout(false); await layout(true)
	print("Treasure receipts: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
