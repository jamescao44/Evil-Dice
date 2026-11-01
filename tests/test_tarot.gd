extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func model_checks() -> void:
	var original_language: String = GameText.language
	for language in ["en","zh_CN"]:
		GameText.set_language(language,false)
		for id in Catalog.ITEMS:
			for geometry in [[30,624,250],[20,704,86]]:
				var lines: PackedStringArray = GameText.lines(Catalog.ITEMS[id].design,GameText.description_font(),geometry[0],geometry[1])
				check(geometry[0]+(lines.size()-1)*geometry[0]*1.3 <= geometry[2],"Every planned effect fits the reveal panel in both languages and layouts")
	GameText.set_language(original_language,false)
	var m = Run.new(901)
	check(Catalog.ITEMS.size() == 22,"All 22 Major Arcana have stable definitions")
	for id in Catalog.ITEMS:
		check(ResourceLoader.exists(Catalog.ITEMS[id].art),"Every card has licensed artwork")
		check(Catalog.ITEMS[id].implemented,"Card effects are active")
	# The keeper replaced the retired paid wave draw; candidates still lock before animation.
	m.stage = 2; m.at_shop = true
	check(m.shop.open(m),"A shop visit opens for the free reading")
	var choices: Array = m.begin_tarot_reward("shop")
	var rng_state: int = m.reward_rng.state
	check(choices.size() == 3 and m.tarots.items.is_empty(),"Keeper locks three cards before granting any")
	check(m.begin_tarot_reward("shop").is_empty() and m.reward_rng.state == rng_state,"Repeated start cannot reroll the reading")
	check(m.choose_tarot(-1).is_empty() and not m.tarot_source.is_empty(),"Invalid picks preserve the pending reading")
	var chosen: Dictionary = m.choose_tarot(1)
	check(chosen.get("id","") == choices[1] and m.tarots.items.size() == 1,"Exactly the chosen tarot enters inventory")
	check(m.choose_tarot(1).is_empty() and m.relics.items.is_empty(),"Double collection grants no extra item")
	check(m.reward_rng.state == rng_state and m.begin_tarot_reward("shop").is_empty(),"Selection uses no RNG and spends this visit's one reading")
	for i in range(40): m.tarots.add(choices[1])
	check(m.tarots.items.size() == 41 and m.tarots.items[0].instance_id != m.tarots.items[1].instance_id,"Duplicates have separate identities and no cap")
	for tier in [0,1,2,3]:
		m.reset_run()
		m.reward_weights = [0,0,0,0,0,0,0,1]
		m._roll_chest(tier)
		check(m.chest_tarots.is_empty() and m.open_rewards.size() == m.CHEST_COUNTS[tier],"Current chests contain relics even with legacy tarot weights")
		check(m.begin_tarot_reward("chest",0).is_empty(),"Relic prizes cannot start a retired chest tarot draw")
		m.discard_unclaimed_rewards(); m.close_chest()
	m.reset_run()
	for e in m.enemies: e.hp = 0
	m.wave_kind = m.WaveRewards.BLOOD_GEMS
	check(m.begin_wave_reward() and m.wave_tarots.is_empty(),"Current wave reward has no paid tarot offer")
	check(m.begin_tarot_reward("wave").is_empty(),"Retired wave draw cannot spend currency")
	var amount: int = m.wave_amount
	check(m.begin_tarot_reward("debug").size() == 3,"Debug opens an independent draw")
	check(not m.choose_tarot(0).is_empty() and m.tarots.items.size() == 1,"Debug grants the chosen card")
	check(not m.wave_reward_resolved and m.wave_amount == amount,"Debug preserves the pending wave reward")

func capture(game, label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.queue_redraw()
	game.tarot_ui.queue_redraw()
	game.tarot_ui.ceremony.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/tarot-%s-%s.png" % ["portrait" if game is Portrait else "landscape",label])

func tap(game, at: Vector2) -> void:
	game._handle_click(at)
	game._handle_release(at)

func scene_checks(game) -> void:
	if not game is Portrait:
		root.content_scale_size = Vector2i(1280,800)
		root.size = Vector2i(1280,800)
	root.add_child(game)
	game.muted = true
	game.set_process(false)
	var ui = game.tarot_ui
	ui.set_process(false)
	var draw = ui.ceremony
	var icon: Vector2 = ui.icon_rect().get_center()
	tap(game,icon)
	ui._process(0.4)
	check(ui.opened and ui.expansion == 1 and game.view_phase == "ready","Card icon expands an empty inventory without throwing")
	check(game.dice_group.transform*game.DICE_CENTER == icon,"Dice area contracts into the icon's position")
	check(game.dice.all(func(d): return d.visible),"Minimizing keeps the dice nodes visible")
	await capture(game,"empty")
	tap(game,icon)
	ui._process(0.4)
	check(not ui.blocks_battle() and game.dice_group.transform.is_equal_approx(Transform2D.IDENTITY),"Die icon restores the dice area")
	game.model.stage = 2; game.model.at_shop = true
	game.model.shop.open(game.model)
	game.view_phase = "shop"
	game.shop_ui.open()
	await capture(game,"offer")
	tap(game,game.shop_ui.keeper_rect().get_center())
	check(draw.active() and game._menus_open(),"Keeper starts a blocking ceremony")
	var combat_rng: int = game.model.rng.state
	var reward_rng: int = game.model.reward_rng.state
	ui._process(0.56)
	await capture(game,"shuffle")
	ui._process(draw.shuffle_duration()+0.01)
	ui._process(0.5)
	ui._process(0.6)
	await capture(game,"fan")
	var mid: Vector2 = draw.fan_pose(0).at
	game._handle_click(mid)
	game._handle_motion(mid+Vector2(140,0))
	game._handle_release(mid+Vector2(140,0))
	check(draw.draws.is_empty() and draw.offset != 0,"Swiping the fan moves backs without selecting")
	for i in range(3):
		mid = draw.fan_pose(0).at
		# Choose the topmost visible card, including when the former center is gone.
		var backs: Array = draw.fan_order().filter(func(index): return index not in draw.removed)
		backs.sort_custom(func(a,b): return absf(draw.fan_pose(a).step) < absf(draw.fan_pose(b).step))
		var at: Vector2 = draw.fan_pose(backs[0]).at
		tap(game,at)
		check(draw.draws.size() == i+1,"Each separate tap draws one new card")
		check(game.model.tarots.items.is_empty(),"Drawing a back grants nothing before the final choice")
		ui._process(0.6)
		if i == 1: await capture(game,"two-drawn")
	check(draw.state == "reveal","Three backs line up before revealing")
	ui._process(0.4)
	await capture(game,"reveal")
	ui._process(0.7)
	tap(game,draw.row_point(1))
	check(draw.state == "choose" and draw.selected == 1,"Revealed cards can be inspected before keeping one")
	await capture(game,"choose")
	var original_id: String = draw.choices[1]
	draw.choices[1] = "tower"
	await capture(game,"long-description")
	draw.choices[1] = original_id
	var chosen: String = draw.choices[1]
	tap(game,draw.keep_rect().get_center())
	check(game.model.tarots.items.size() == 1 and game.model.tarots.items[0].id == chosen and draw.state == "collect","Keep grants exactly the selected card and starts collection")
	tap(game,draw.keep_rect().get_center())
	check(game.model.tarots.items.size() == 1,"Double taps during collection do not duplicate rewards")
	ui._process(0.4)
	await capture(game,"collect")
	ui._process(0.5)
	check(not draw.active() and game.model.shop.divination_used,"Collection finishes before continuing")
	check(game.model.rng.state == combat_rng and game.model.reward_rng.state == reward_rng,"Fan motion, reveal, and selection never change reward or combat RNG")
	game.model.shop.close()
	game.shop_ui.cancel()
	game.view_phase = "ready"
	for id in ["fool","magician","sun","world","death","sun"]: game.model.tarots.add(id)
	tap(game,icon)
	ui._process(0.4)
	await capture(game,"inventory")
	var front: int = ui.front_index()
	var front_at: Vector2 = ui.carousel_pose(front).at
	tap(game,game.MENU_RECT.get_center())
	check(game.menu_open and ui.opened,"Settings remain accessible from the tarot inventory")
	game._handle_click(game.MENU_RESUME.get_center())
	check(not game.menu_open and ui.opened,"Closing settings returns to the same inventory")
	check(ui.carousel_order()[-1] == front and ui.card_at(front_at) == front,"The closest upright card draws last and wins hit testing")
	game._handle_click(front_at)
	game._handle_motion(front_at-Vector2(105,0))
	game._handle_release(front_at-Vector2(105,0))
	ui._process(1)
	check(ui.front_index() != front and ui.inspected == -1,"Carousel swipe changes the closest card without opening a description")
	tap(game,ui.carousel_pose(ui.front_index()).at)
	check(ui.inspected >= 0,"Tapping the front card opens its planned description")
	await capture(game,"inspect")
	var other: int = -1
	for i in range(game.model.tarots.items.size()):
		if i != ui.front_index() and ui.card_at(ui.carousel_pose(i).at) == i:
			other = i
			break
	check(other >= 0,"Another card remains selectable while inspecting")
	if other >= 0:
		tap(game,ui.carousel_pose(other).at)
		check(ui.inspected == -1,"Selecting another card dismisses the previous description immediately")
		for i in range(40): ui._process(0.02)
		check(ui.front_index() == other and ui.inspected == -1,"Carousel settles on the selected card without stale inspection")
		tap(game,ui.carousel_pose(other).at)
		check(ui.inspected == other,"The newly selected card opens its own description")
	tap(game,Vector2(10,10))
	check(ui.inspected == -1 and game.view_phase == "ready","Closing inspection cannot send a battle action")
	game.model.acquire_relic("heart")
	game.model.acquire_relic("codex_page")
	var inventory = game.inventory_page
	var source: int = game.model.relics.index_of("heart")
	var destination: int = game.model.relics.index_of("codex_page")
	game.relic_ui.pickup.clear()
	tap(game,ui.carousel_pose(ui.front_index()).at)
	tap(game,inventory.button_rect().get_center())
	check(inventory.opened and ui.inspected == -1 and not ui.held,"Backpack opens above tarot view and dismisses the card description")
	tap(game,inventory.slot_rect(source).get_center())
	check(inventory.selected == source,"Tapping a backpack relic opens its own details")
	await capture(game,"relic-inspect")
	tap(game,inventory.back_rect().get_center())
	var tarot_count: int = game.model.tarots.items.size()
	var carousel_scroll: float = ui.scroll
	game._handle_click(inventory.slot_rect(source).get_center())
	game._handle_motion(inventory.slot_rect(destination).get_center())
	check(inventory.dragging,"Backpack captures the item drag above tarot view")
	game._handle_release(inventory.slot_rect(destination).get_center())
	check(game.model.relics.items[destination].id == "heart" and inventory.pressed == -1,"Backpack drag reorders and releases once")
	tap(game,inventory.close_rect().get_center())
	check(ui.opened and ui.scroll == carousel_scroll and game.model.tarots.items.size() == tarot_count,"Backpack use neither scrolls nor casts tarot cards")
	game._process(0.02)
	check(not game._menus_open() and game.fx.time_factor > 0,"Browsing tarots does not pause battlefield effects")
	game._restart()
	check(not ui.blocks_battle() and game.model.tarots.items.is_empty(),"Restart clears draw, carousel, and cards")
	ui.begin_reward("debug")
	game._restart()
	check(not draw.active() and game.model.tarot_source.is_empty(),"Restart also cancels a pending draw")
	game.queue_free()
	await process_frame

## Exercise the live shop coroutine, modal isolation and return with the collected card.
func integration_checks() -> void:
	var game = Portrait.new()
	root.add_child(game)
	game.muted = true; game.set_process_input(false)
	game.tarot_ui.set_process(false)
	game._open_debug()
	game._handle_click(game.DEBUG_SHOP.get_center())
	check(game.view_phase == "shop" and game.shop_ui.visible,"Real debug-shop entry opens the current shop")
	tap(game,game.shop_ui.keeper_rect().get_center())
	var choices: Array = game.tarot_ui.ceremony.choices.duplicate()
	var rng_state: int = game.model.reward_rng.state
	tap(game,game.shop_ui.leave_rect().get_center())
	check(game.model.shop.active and game.tarot_ui.ceremony.active(),"Ceremony consumes leave-button taps without leaving the shop")
	# The first tap skipped preparation; draw from the resulting fan.
	var draw = game.tarot_ui.ceremony
	for i in range(3):
		var backs: Array = draw.fan_order().filter(func(index): return index not in draw.removed)
		backs.sort_custom(func(a,b): return absf(draw.fan_pose(a).step) < absf(draw.fan_pose(b).step))
		tap(game,draw.fan_pose(backs[0]).at)
	tap(game,Vector2(10,10)); tap(game,draw.row_point(0)); tap(game,draw.keep_rect().get_center())
	check(draw.state == "collect" and game.model.tarots.items.size() == 1,"Keeping a revealed card starts exactly one collection")
	tap(game,game.shop_ui.leave_rect().get_center())
	check(game.model.shop.active,"Shop stays open while the card flies into inventory")
	game.tarot_ui._process(1)
	check(not draw.active() and game.model.tarots.items[0].id == choices[0],"Collection finishes with the locked chosen card")
	check(game.model.reward_rng.state == rng_state,"Ceremony and collection do not reroll rewards")
	tap(game,game.shop_ui.leave_rect().get_center())
	var deadline: int = Time.get_ticks_msec()+2000
	while game.view_phase != "ready" and Time.get_ticks_msec() < deadline: await process_frame
	check(game.view_phase == "ready" and not game.shop_ui.visible and game.model.tarots.items.size() == 1,"Real shop coroutine returns to battle with the collected tarot")
	game._restart(); game.queue_free()
	await process_frame

func angular_swipe_checks(game) -> void:
	root.add_child(game)
	game.muted = true
	var ui = game.tarot_ui
	var reference_angle: float = 0
	var reference_coast: float = 0
	for count in [3,22,100]:
		game._restart()
		for i in range(count): game.model.tarots.add("strength")
		ui.opened = true
		ui.expansion = 1
		var at: Vector2 = ui.carousel_pose(0).at
		game._handle_click(at)
		game._handle_motion(at-Vector2(100,0))
		var angle: float = ui.scroll*TAU/count
		if count == 3: reference_angle = angle
		check(is_equal_approx(angle,reference_angle),"An equal swipe rotates small and large tarot inventories through the same angle")
		game._handle_release(at-Vector2(100,0))
		# Compare equal angular release speeds, independent of wall-clock test timing.
		ui.swipe.velocity = 3
		ui._process(0.15)
		var coast: float = ui.scroll*TAU/count-angle
		if count == 3: reference_coast = coast
		check(is_equal_approx(coast,reference_coast),"Inertia travels the same angle regardless of card count")
	game.queue_free()
	await process_frame

func skip_checks(game) -> void:
	root.add_child(game)
	game.muted = true
	game.set_process(false)
	game.tarot_ui.set_process(false)
	var draw = game.tarot_ui.ceremony
	for reduced in [false,true]:
		game._restart()
		game.reduced = reduced
		game.tarot_ui.begin_reward("debug")
		var choices: Array = draw.choices.duplicate()
		var rng_state: int = game.model.reward_rng.state
		tap(game,draw.fan_pose(0).at)
		check(draw.state == "fan" and draw.age >= 0.55 and draw.draws.is_empty(),"Preparation skip opens the fan and consumes the tap")
		for i in range(3):
			var backs: Array = draw.fan_order().filter(func(index): return index not in draw.removed)
			backs.sort_custom(func(a,b): return absf(draw.fan_pose(a).step) < absf(draw.fan_pose(b).step))
			tap(game,draw.fan_pose(backs[0]).at)
			check(draw.draws.size() == i+1 and draw.draws[0].age == 0,"Cards can be drawn consecutively without waiting for flight")
		check(draw.state == "drawing" and draw.removed.size() == 3,"Rapid taps draw exactly three distinct backs")
		tap(game,draw.row_point(0))
		check(draw.state == "choose" and draw.selected == -1 and game.model.tarots.items.is_empty(),"Reveal skip finishes movement without selecting or awarding a card")
		check(draw.choices == choices and game.model.reward_rng.state == rng_state,"Skipping and rapid draws preserve locked outcomes")
		tap(game,draw.row_point(1))
		tap(game,draw.keep_rect().get_center())
		draw.advance(1)
		check(not draw.active() and game.model.tarots.items.size() == 1,"Streamlined draw still collects exactly one chosen card")
	game.queue_free()
	await process_frame

func run() -> void:
	GameText.set_language("en" if "--english" in OS.get_cmdline_user_args() else "zh_CN",false)
	model_checks()
	await scene_checks(Battle.new())
	await scene_checks(Portrait.new())
	await angular_swipe_checks(Battle.new())
	await angular_swipe_checks(Portrait.new())
	await skip_checks(Battle.new())
	await skip_checks(Portrait.new())
	await integration_checks()
	await create_timer(0.15).timeout
	print("Tarot: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
