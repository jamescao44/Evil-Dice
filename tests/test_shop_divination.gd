extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Open a visit without awarding or purchasing anything first.
func open_shop(m) -> void:
	m.wave_kind = m.WaveRewards.SHOP
	m.wave_reward_resolved = true
	check(m.shop.open(m),"A fresh shop visit opens")

## A free reading is committed once, survives refreshes and renews only on a new visit.
func economy() -> void:
	var m = Run.new(6633)
	var rng_before: int = m.reward_rng.state
	check(m.begin_tarot_reward("shop").is_empty() and m.reward_rng.state == rng_before,"No free reading outside an active shop")
	open_shop(m)
	m.blood_gems = 0
	var stock: Array = m.shop.offers.duplicate(true)
	var choices: Array = m.begin_tarot_reward("shop")
	check(choices.size() == 3 and m.shop.divination_used and m.tarots.items.is_empty(),"Beginning reserves three choices without granting a card")
	rng_before = m.reward_rng.state
	check(m.begin_tarot_reward("shop").is_empty() and m.reward_rng.state == rng_before,"Double start does not reroll candidates")
	check(m.choose_tarot(-1).is_empty() and not m.tarot_source.is_empty(),"An invalid choice leaves the reading pending")
	check(m.choose_tarot(1).id == choices[1] and m.tarots.items.size() == 1,"Exactly the chosen card is kept")
	check(m.blood_gems == 0 and m.shop.offers == stock,"The reading is free and does not change shelf stock")
	check(m.choose_tarot(1).is_empty() and m.begin_tarot_reward("shop").is_empty() and m.reward_rng.state == rng_before,"Repeated claims and later taps cannot grant extra cards")
	m.blood_gems = 100
	check(m.shop.refresh(m) and m.shop.divination_used,"Paid refresh does not reset the free reading")
	check(m.begin_tarot_reward("shop").is_empty(),"Refreshing cannot buy another free draw")
	m.shop.close(); m.stage += 3
	open_shop(m)
	check(not m.shop.divination_used and m.begin_tarot_reward("shop").size() == 3,"A different shop visit grants one new reading")
	m.reset_run()
	check(not m.shop.divination_used and m.tarot_source.is_empty(),"Restart clears the visit and pending reading")

func tap(g, at: Vector2) -> void:
	g._handle_click(at); g._handle_release(at)

func capture(g, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.inventory_page.queue_redraw(); g.tarot_ui.queue_redraw(); g.shop_ui.queue_redraw(); g.shop_ui.keeper_overlay.queue_redraw(); g.tarot_ui.ceremony.queue_redraw(); g.wave_chest.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/"+name+".png")

## Exercise the real shop input dispatcher and complete a hand-picked three-card reading.
func presentation(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
	for child in g.get_children(): child.set_process(false)
	open_shop(g.model); g.view_phase = "shop"; g.shop_ui.open()
	var ui = g.shop_ui
	var draw = g.tarot_ui.ceremony
	var name: String = "portrait" if portrait else "landscape"
	check(ui.dialogue_text() == "Would you like a divination?","Keeper invites a reading before use")
	for i in range(g.model.shop.offers.size()):
		check(not ui.keeper_rect().intersects(ui.offer_rect(i)),"Keeper hitbox is clear of merchandise")
		check(not ui.dialogue_rect().intersects(ui.offer_rect(i)),"Speech does not cover merchandise")
	check(not ui.dialogue_rect().intersects(g.tarot_ui.icon_rect()),"Speech does not cover the tarot shortcut")
	var language: String = GameText.language
	GameText.set_language("zh_CN",false)
	await capture(g,"divination-invite-"+name)
	GameText.set_language("en",false)
	await capture(g,"divination-invite-en-"+name)
	GameText.set_language(language,false)
	var origin: Vector2 = ui.divination_deck_position()
	tap(g,ui.keeper_rect().position+Vector2(12,12))
	check(draw.state == "arrive" and draw.arrival_origin == origin,"Any point on the keeper starts the deck flight from its visible position")
	check(g.model.shop.divination_used and g._menus_open(),"Reading is reserved before the transition and blocks shop input")
	draw.advance(0.25)
	await capture(g,"divination-flight-"+name)
	draw.advance(0.31)
	check(draw.state == "shuffle" and draw.age == 0,"Arrival flows into the existing shuffle without advancing gameplay")
	draw.advance(1.01)
	check(draw.state == "drop","Shuffle flows into the fan drop")
	var money: int = g.model.blood_gems
	var rng_before: int = g.model.reward_rng.state
	tap(g,ui.leave_rect().get_center())
	check(g.model.shop.active and draw.state == "fan" and draw.draws.is_empty(),"Preparation skip consumes the tap without leaving the shop or drawing a card")
	check(g.model.reward_rng.state == rng_before and g.model.blood_gems == money,"Transition and skip preserve locked choices and currency")
	for i in range(3):
		var backs: Array = draw.fan_order().filter(func(index): return index not in draw.removed)
		backs.sort_custom(func(a,b): return absf(draw.fan_pose(a).step) < absf(draw.fan_pose(b).step))
		tap(g,draw.fan_pose(backs[0]).at)
		check(draw.draws.size() == i+1,"Shop input reaches each card in the fan")
	draw.advance(0.6); draw.advance(1.1)
	check(draw.state == "choose","Three drawn cards reach the choice stage")
	var chosen: String = draw.choices[1]
	tap(g,draw.row_rect(1).get_center()); tap(g,draw.keep_rect().get_center())
	check(g.model.tarots.items.size() == 1 and g.model.tarots.items[0].id == chosen,"Keep grants exactly one selected tarot")
	tap(g,draw.keep_rect().get_center())
	check(g.model.tarots.items.size() == 1,"Repeat taps during pickup cannot duplicate the card")
	draw.advance(0.9)
	check(not draw.active() and ui.visible and ui.dialogue_text().is_empty(),"Finished reading returns to the shop without the invitation")
	tap(g,ui.keeper_rect().get_center())
	check(ui.dialogue_text() == "Fate has spoken." and not draw.active(),"Later keeper taps show the final line without another draw")
	check(g.model.reward_rng.state == rng_before and g.model.blood_gems == money,"Reading selection and later dialogue do not reroll rewards or charge gems")
	await capture(g,"divination-fate-"+name)
	ui.cancel(); g.model.shop.close(); g.tarot_ui.reset()
	g.view_phase = "wave_reward"
	g.model.enemies.clear(); g._process(0)
	for kind in [g.model.WaveRewards.BLOOD_GEMS,g.model.WaveRewards.SOULS,g.model.WaveRewards.RELIC]:
		g.wave_chest.present_chest(kind)
		await capture(g,"chest-closed-"+kind+"-"+name)
		if kind == g.model.WaveRewards.RELIC: continue
		for amount in ([333,666] if kind == g.model.WaveRewards.BLOOD_GEMS else [10,40]):
			g.wave_chest.reveal_amount(amount); g.wave_chest.age = 0.5
			await capture(g,"chest-receipt-"+kind+"-"+str(amount)+"-"+name)
	root.remove_child(g); g.free()
	await process_frame

func run() -> void:
	economy()
	await presentation(false)
	await presentation(true)
	print("Shop divination: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
