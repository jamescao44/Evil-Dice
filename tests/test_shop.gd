extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Stock = preload("res://scripts/rewards/shop_stock.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

## Report economy and actual scene-flow failures with a useful label.
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Finish a wave's locked chest without depending on cosmetic timing.
func clear_wave(m, wave: int) -> void:
	m.load_debug_wave(wave)
	m.wave_kind = m.WaveRewards.RELIC
	for enemy in m.enemies: enemy.hp = 0
	m.begin_wave_reward(); m.open_wave_chest()
	m.discard_unclaimed_rewards(); m.close_chest(); m.finish_wave_reward()

## Enter a deliberately chosen shop destination, with a completed prior battle.
func prepare_shop(m, wave: int) -> void:
	clear_wave(m,wave-1)
	m.route_choices = [m.WaveRewards.SHOP,m.WaveRewards.SOULS]
	m.choose_route(0)
	check(m.advance_wave(),"Chosen shop advances the wave counter")

## Continue into route selection after the shop's NPC transition and visit.
func visit(g) -> void:
	g.travel_progress = 1
	g.wave_chest.present_keeper()
	await g._visit_shop(g.run_id)
	g._advance_wave()

## Exercise checkpoint gating, guaranteed slots, pricing and transaction safety.
func economy() -> void:
	var m = Run.new(761)
	var contents_by_price: Dictionary = {}
	for wave in [1,4,6,9,11,14,16,19]:
		clear_wave(m,wave)
		check(not m.shop.open(m),"Battle routes never open shops")
	for visit in range(1,4):
		for seed_value in range(50):
			prepare_shop(m,visit*5)
			m.shop.number = visit-1
			m.reward_rng.seed = seed_value
			check(not m.advance_wave(),"Unvisited shop cannot advance")
			check(m.shop.open(m) and m.shop.active,"Chosen shop opens once")
			check(m.shop.offers.size() == Stock.OFFER_COUNT,"Six relics, two tarot offers and one soul bottle")
			var ids: Array = []
			for i in range(Stock.OFFER_COUNT):
				var o: Dictionary = m.shop.offers[i]
				check(not o.id.is_empty() and not o.sold,"Every fresh listing is available")
				if i < 6:
					check(o.kind == "relic" and o.id not in ids and o.id not in Relics.DISABLED and not Relics.ITEMS[o.id].get("fusion",false),"Eligible unique shelf relic")
					ids.append(o.id)
				elif i < 8: check(o.kind == "tarot" and o.id not in m.Tarot.DISABLED,"Direct eligible tarot listing")
				else:
					check(o.kind == "soul_bottle" and o.souls*10 <= o.price and o.souls*20 >= o.price,"Bottle pays one soul per ten to twenty gems")
					if not contents_by_price.has(o.price): contents_by_price[o.price] = []
					if o.souls not in contents_by_price[o.price]: contents_by_price[o.price].append(o.souls)
				var limits: Vector2i = Stock.PRICE_RANGES[Relics.ITEMS[o.id].rarity] if i < 6 else Stock.TAROT_PRICE if i < 8 else Stock.BOTTLE_PRICE
				check(o.price >= roundi(limits.x*m.shop.price_multiplier()) and o.price <= roundi(limits.y*m.shop.price_multiplier()),"Random price stays in fixed base range")
			check(Relics.ITEMS[m.shop.offers[m.shop.guaranteed_slot].id].rarity == Relics.Rarity.RARE,"Every shop guarantees rare with no rarity escalation")
			var snapshot: Array = m.shop.offers.duplicate(true)
			check(not m.shop.open(m) and snapshot == m.shop.offers,"Opening twice cannot reroll stock")
			m.shop.close()
			m.offer_routes(); m.choose_route(0)
			check(not m.shop.open(m) and m.advance_wave(),"Leaving resumes next wave without reopening")
	check(contents_by_price.values().any(func(amounts): return amounts.size() > 1),"Identically priced bottles can contain different soul amounts")
	prepare_shop(m,5); m.blood_gems = 10000; m.shop.open(m)
	var o: Dictionary = m.shop.offers[0].duplicate()
	check(not m.shop.buy(m,0).is_empty() and m.relics.has(o.id) and m.blood_gems == 10000-o.price,"Relic purchase grants exactly once at its listed price")
	var balance: int = m.blood_gems
	check(m.shop.buy(m,0).is_empty() and m.blood_gems == balance,"Double tap cannot spend or grant twice")
	var count: int = m.tarots.items.size()
	var card: Dictionary = m.shop.offers[6].duplicate()
	check(not m.shop.buy(m,6).is_empty() and m.tarots.items.size() == count+1 and m.tarots.items[-1].id == card.id and m.tarot_source.is_empty(),"Tarot goes directly to inventory without drawing")
	balance = m.blood_gems
	var snapshot: Array = m.shop.offers.duplicate(true)
	check(m.shop.refresh(m) and m.blood_gems == balance-50 and m.shop.offers != snapshot and m.shop.offers.all(func(x): return not x.sold),"Fifty gems refresh all nine listings including the bottle")
	check(m.shop.offers.slice(0,6).all(func(x): return x.id != o.id or x.id == "codex_page"),"Refresh excludes owned unique relics")
	m.blood_gems = 49; snapshot = m.shop.offers.duplicate(true)
	var rng_state: int = m.reward_rng.state
	check(not m.shop.refresh(m) and m.blood_gems == 49 and snapshot == m.shop.offers and rng_state == m.reward_rng.state,"Unaffordable refresh changes neither stock nor RNG")
	check(m.shop.buy(m,0).is_empty() and m.blood_gems == 49,"Unaffordable purchase has no side effects")
	m.blood_gems = 10000
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","bloodstone","contract","worn_dagger","worn_bow"]:
		if m.relics.items.size() < 10: m.acquire_relic(id)
	m.shop.offers[0] = {"kind":"relic","id":"mithril_blade","price":456,"sold":false}
	check(m.shop.needs_replacement(m,0) and m.shop.buy(m,0).is_empty() and m.blood_gems == 10000,"Full inventory requires a replacement before charging")
	check(not m.shop.buy(m,0,2).is_empty() and m.relics.items[2].id == "mithril_blade" and m.blood_gems == 9544,"Replacement and payment commit together")
	m.shop.offers[1] = {"kind":"relic","id":"codex_page","price":110,"sold":false}
	m.relics.items[1] = m.relics._new_item("codex_page")
	check(not m.shop.needs_replacement(m,1) and not m.shop.buy(m,1).is_empty() and m.relics.items[1].count == 2,"Stackable Codex Pages do not require replacement")
	var bottle: Dictionary = m.shop.offers[8].duplicate()
	m.souls = 29
	check(not m.shop.needs_replacement(m,8),"Bottle consumes no relic slot even in a full inventory")
	m.blood_gems = bottle.price-1
	check(m.shop.buy(m,8).is_empty() and m.souls == 29 and not m.shop.offers[8].sold,"Unaffordable bottle remains sealed without awarding souls")
	m.blood_gems = bottle.price
	rng_state = m.reward_rng.state
	check(not m.shop.buy(m,8).is_empty() and m.blood_gems == 0 and m.souls == 29+bottle.souls-30 and m.character_level == 2,"Bottle grants its locked contents and automatically levels the player")
	check(rng_state == m.reward_rng.state and m.relics.items.size() == 10,"Purchase never rerolls contents or occupies inventory")
	check(m.shop.buy(m,8).is_empty() and m.souls == 29+bottle.souls-30,"Repeated bottle purchase cannot duplicate souls")
	m.reset_run()
	check(not m.shop.active and m.shop.wave == -1 and m.shop.offers.is_empty(),"Restart clears visit and stock")

## Verify store controls, layering, banner duration and return-to-battle in both layouts.
func scene(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g.speed = 20
	prepare_shop(g.model,5); g.model.blood_gems = 2000
	visit(g)
	await create_timer(0.6).timeout
	for frame in range(100):
		if g.shop_ui.visible and g.shop_ui.modulate.a >= 0.99: break
		await process_frame
	check(g.shop_ui.modulate.a >= 0.99,"Storefront finishes fading before inspection")
	check(g.view_phase == "shop" and g.shop_ui.visible,"Keeper transition opens storefront")
	check(g.bonus_turn_banner.message == "Shop" and g.bonus_turn_banner.HOLD == 1.0,"Shop and bonus share a one-second hold")
	check(g.shop_ui.z_index < g.relic_ui.z_index and g.dice_group.z_index < g.shop_ui.z_index,"Shop covers dice and leaves inventory above it")
	var ui = g.shop_ui
	var canvas := Rect2(Vector2.ZERO,g.fx.canvas_size)
	for i in range(Stock.OFFER_COUNT):
		check(canvas.encloses(ui.offer_rect(i)),"All offer hit areas fit canvas")
		for j in range(i+1,Stock.OFFER_COUNT): check(not ui.offer_rect(i).intersects(ui.offer_rect(j)),"Offer hit areas never overlap")
		check(not ui.offer_rect(i).intersects(ui.detail_rect()) and not ui.offer_rect(i).intersects(ui.inventory_rect()),"Merchandise stays clear of descriptions and inventory")
		check(not ui.offer_rect(i).intersects(g.tarot_ui.icon_rect()),"Tarot collection icon stays clear of all merchandise")
	check(not ui.inventory_rect().intersects(ui.detail_rect()) and not ui.leave_rect().intersects(ui.inventory_rect()),"Owned rail is clear of details and footer")
	g._handle_click(ui.offer_rect(0).get_center())
	check(ui.selected == 0 and not g.model.shop.offers[0].sold,"First tap inspects without purchasing")
	g._handle_click(ui.buy_rect().get_center())
	check(g.model.shop.offers[0].sold and g.relic_ui.pickup.active,"Buy starts existing relic landing")
	g.relic_ui.pickup.clear()
	var count: int = g.model.tarots.items.size()
	g._handle_click(ui.offer_rect(6).get_center()); g._handle_click(ui.buy_rect().get_center())
	check(g.model.tarots.items.size() == count+1 and not g.tarot_ui.ceremony.active(),"Shop tarot bypasses hand-picking ceremony")
	await process_frame
	check(not g.tarot_ui.pickup.paused(),"Direct tarot pickup can animate above shop")
	g.bonus_turn_banner.clear()
	g._handle_click(ui.offer_rect(8).get_center())
	check(ui.hit(ui.offer_rect(8).get_center()) and ui.selected == 8,"Bottle shelf supports normal inspection")
	var bottle: Dictionary = g.model.shop.offers[8]
	var mystery: String = ui.offer_description(bottle)
	var altered: Dictionary = bottle.duplicate()
	altered.souls += 3
	check(mystery == ui.offer_description(altered),"Sealed bottle description does not leak its hidden amount")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		g.tarot_ui.pickup.reset()
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://test-output/shop-"+("portrait" if portrait else "landscape")+".png")
	var offer_id: String = g.model.shop.offers[1].id
	for id in Relics.ITEMS:
		if id != offer_id and id != "codex_page" and g.model.relics.items.size() < 10 and id not in Relics.DISABLED and not Relics.ITEMS[id].get("fusion",false): g.model.acquire_relic(id)
	g.tarot_ui.pickup.reset()
	var money: int = g.model.blood_gems
	g._handle_click(ui.offer_rect(1).get_center()); g._handle_click(ui.buy_rect().get_center())
	check(ui.replacing and g.model.blood_gems == money,"Replacement selection waits without spending")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://test-output/shop-replace-"+("portrait" if portrait else "landscape")+".png")
	g._handle_click(g.inventory_page.close_rect().get_center())
	g._handle_click(ui.buy_rect().get_center())
	check(not ui.replacing and g.model.blood_gems == money,"Cancelling replacement preserves currency and stock")
	g._handle_click(ui.buy_rect().get_center())
	g._handle_click(g.inventory_page.slot_rect(3).get_center())
	check(g.inventory_page.selected == 3 and g.model.blood_gems == money,"Inspecting a replacement does not spend crystals")
	g._handle_click(g.inventory_page.replace_rect().get_center())
	check(g.model.shop.offers[1].sold and g.model.relics.items[3].id == offer_id,"Owned slot confirms replacement without triggering inventory drag")
	g.relic_ui.pickup.clear()
	g.model.souls = 29
	var soul_gain: int = g.model.shop.offers[8].souls
	var bottle_price: int = g.model.shop.offers[8].price
	money = g.model.blood_gems
	g._handle_click(ui.offer_rect(8).get_center())
	ui.motion(ui.buy_rect().get_center()); ui.release(ui.buy_rect().get_center())
	check(g.model.shop.offers[8].sold and g.model.souls == 29+soul_gain-30 and g.model.blood_gems == money-bottle_price,"Drag-to-buy opens the bottle and grants its souls once")
	check(ui.offer_description(g.model.shop.offers[8]) == GameText.format("Opened: +%d souls.",soul_gain),"Purchased bottle displays its exact contents")
	await process_frame
	check(g.evolution.active() and g.evolution.age < 0,"Shop upgrade waits to show its transformation on the battlefield")
	g._handle_click(ui.leave_rect().get_center())
	await process_frame
	check(not g.model.shop.active and not ui.visible,"Leave closes visit and releases wave coroutine")
	check(g.wave_chest.phase == "routes","Leaving shop offers the next battle routes")
	g._handle_click(g.wave_chest.route_rect(0).get_center())
	for frame in range(100):
		if g.model.stage == 5 and g.view_phase == "ready": break
		await create_timer(0.01).timeout
	check(g.model.stage == 5 and g.view_phase == "ready","After leaving, growth completes and wave six accepts dice input")
	g._restart(); check(g.view_phase != "shop" and not g.model.shop.active,"Restart leaves no shop overlay")
	g.queue_free(); await process_frame

func run() -> void:
	economy()
	await scene(false)
	await scene(true)
	print("Shop: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
