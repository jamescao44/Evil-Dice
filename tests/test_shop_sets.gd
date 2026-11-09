extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Inventory = preload("res://scripts/relics/relic_inventory.gd")
const Sets = preload("res://scripts/relics/relic_sets.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Drops = preload("res://scripts/relics/relic_drop_table.gd")
const Assist = preload("res://scripts/rewards/shop_sets.gd")
const Stock = preload("res://scripts/rewards/shop_stock.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Check every recipe, hidden ingredient rule, stack and completed fusion through live eligibility.
func eligibility() -> void:
	var inventory = Inventory.new()
	check(Assist.item_weights(inventory).is_empty(),"No set holdings means no steering")
	for recipe in Sets.RECIPES.values():
		inventory.clear(); inventory.add(recipe.ingredients[0])
		var pools: Dictionary = Sets.missing_collections(inventory,Catalog.ITEMS,Catalog.DISABLED)
		check(pools.size() == 1 and pools.has(recipe.name),"Each recipe counts as exactly one started set")
		check(recipe.ingredients[0] not in pools[recipe.name],"Owned unique components cannot be offered")
		if recipe.name == "Remains": check("unidentified_ring" not in pools[recipe.name],"Ring remains gated behind all five bones")
		for id in recipe.ingredients:
			if inventory.can_add(id): inventory.add(id)
		check(Assist.item_weights(inventory).is_empty(),"Completed fused recipes do not attract more ingredients")
	inventory.clear(); inventory.add("lemon_soda"); inventory.add("fries")
	var weights: Dictionary = Assist.item_weights(inventory)
	check(inventory.has("budget_meal") and weights.size() == 3 and weights.get("hamburger") == 1.2,"Partial meal fusion retains missing-piece steering")
	check(not weights.has("fries") and not weights.has("lemon_soda"),"Fused ingredients are not offered again")
	inventory.clear(); inventory.add("orange_stone")
	check(Assist.item_weights(inventory).size() == 5,"Stones participate without a normal recipe")
	for id in Catalog.STONES:
		if inventory.can_add(id): inventory.add(id)
	check(inventory.has("prismatic_stone") and Assist.item_weights(inventory).is_empty(),"Completed stones stop receiving assistance")
	inventory.clear(); inventory.add("codex_page")
	check(Assist.item_weights(inventory) == {"codex_page":1.2},"Stackable pages remain eligible within one set")
	for i in range(9): inventory.add("codex_page")
	check(Assist.item_weights(inventory).is_empty(),"Completed Codex stops receiving pages")
	inventory.clear()
	for id in ["unknown_arm","unknown_pelvis","unknown_leg","unknown_sternum","unknown_skull"]: inventory.add(id)
	check(Assist.item_weights(inventory) == {"unidentified_ring":1.2},"Ring becomes eligible only with all five bones")
	inventory.remove(0)
	check(not Assist.item_weights(inventory).has("unidentified_ring"),"Selling a requirement removes conditional ring eligibility")

## Measure per-set probability and in-rarity weighting rather than depending on one lucky seed.
func probabilities() -> void:
	var inventory = Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 88241
	for set_count in [0,1,2]:
		if set_count == 1: inventory.add("lemon_soda")
		if set_count == 2: inventory.add("pet_bat")
		var gifts := 0
		var chosen := {"Meal":0,"Pets":0}
		for sample in range(12000):
			var gift: Dictionary = Assist.roll_gift(inventory,rng,Catalog.RARITY_WEIGHTS)
			if gift.is_empty(): continue
			gifts += 1; chosen[gift.set] += 1
			check(inventory.can_add(gift.id) and gift.price == 0,"Every gift is eligible and free")
		var expected: float = 1.0-pow(0.8,set_count)
		check(absf(gifts/12000.0-expected) < 0.015,"Each set adds an independent twenty-percent chance")
		if set_count == 2: check(abs(chosen.Meal-chosen.Pets) < 250,"Successful sets have equal selection chance")
	var item_counts := {"fries":0,"bracelet":0}
	var rare_count := 0
	for sample in range(60000):
		var id: String = Drops.draw(rng,["fries","bracelet","runestone"],[70,0,30,0,0],0,{"fries":1.2})
		if id == "runestone": rare_count += 1
		else: item_counts[id] += 1
	check(absf(rare_count/60000.0-0.3) < 0.01,"Steering preserves the rolled rarity rates")
	check(absf(float(item_counts.fries)/item_counts.bracelet-1.2) < 0.04,"Missing piece receives twenty percent more relative weight")

## Six independent shelf checks stay at five percent, rather than multiplying with owned sets.
func shelf_assistance() -> void:
	var inventory = Inventory.new()
	var rng := RandomNumberGenerator.new(); rng.seed = 810572
	var before: int = rng.state
	check(Assist.roll_stock_piece(rng,{},[],Catalog.RARITY_WEIGHTS).is_empty() and rng.state == before,"No started set leaves ordinary stock RNG unchanged")
	for held in ["pet_bat","lemon_soda"]:
		inventory.add(held)
		var missing: Dictionary = Assist.item_weights(inventory)
		var hits: Array = [0,0,0,0,0,0]
		var valid := true
		for sample in range(20000):
			for slot in range(Stock.RELIC_COUNT):
				var floor: int = Catalog.Rarity.RARE if slot == 0 else 0
				var id: String = Assist.roll_stock_piece(rng,missing,[],Catalog.RARITY_WEIGHTS,floor)
				if id.is_empty(): continue
				hits[slot] += 1
				valid = valid and missing.has(id) and inventory.can_add(id) and Catalog.ITEMS[id].rarity >= floor
		check(valid,"Extra rolls offer only eligible missing pieces and respect the rarity floor")
		for slot in range(Stock.RELIC_COUNT):
			check(absf(hits[slot]/20000.0-0.05) < 0.006,"Each shelf position has one five-percent check with %d started sets" % (1 if held == "pet_bat" else 2))
	var missing: Dictionary = Assist.item_weights(inventory)
	var exhausted := true
	for sample in range(1000):
		exhausted = exhausted and Assist.roll_stock_piece(rng,missing,missing.keys(),Catalog.RARITY_WEIGHTS).is_empty()
	check(exhausted,"Reserved gifts and already-listed unique ingredients cannot be drawn again")
	var m = Run.new(72451)
	m.relics.add("pet_bat"); m.relics.add("lemon_soda"); m.relics.add("armor")
	m.stage = 2; m.shop.open_debug(m)
	var valid_stock := true
	var upgraded_guarantees := 0
	for refresh in range(300):
		if refresh > 0: m.shop.refresh(m)
		var ids: Array = []
		for slot in range(Stock.RELIC_COUNT):
			var offer: Dictionary = m.shop.offers[slot]
			valid_stock = valid_stock and not offer.id.is_empty() and m.relics.can_add(offer.id) and (offer.id == "codex_page" or offer.id not in ids)
			ids.append(offer.id)
			if not m.shop.gift.is_empty(): valid_stock = valid_stock and offer.id != m.shop.gift.id
		var guaranteed: String = m.shop.offers[m.shop.guaranteed_slot].id
		valid_stock = valid_stock and Catalog.ITEMS[guaranteed].rarity >= Catalog.Rarity.RARE
		if Catalog.ITEMS[guaranteed].rarity > Catalog.Rarity.RARE: upgraded_guarantees += 1
		valid_stock = valid_stock and m.shop.offers.slice(6,8).all(func(o): return o.kind == "tarot") and m.shop.offers[8].kind == "soul_bottle"
	check(valid_stock,"Entry and paid refresh preserve eligibility, unique stock, keeper reservation and non-relic slots")
	check(upgraded_guarantees > 0,"The guaranteed shelf slot also receives the extra set-piece roll")

## Create a real gift-bearing visit from seeded entry, never by repainting or refreshing.
func gift_visit(m) -> void:
	m.shop.close(); m.relics.clear(); m.acquire_relic("pet_bat")
	m.stage = 2; m.at_shop = true; m.wave_reward_resolved = true
	for seed_value in range(100):
		m.shop.reset(); m.reward_rng.seed = seed_value
		m.shop.open(m)
		if not m.shop.gift.is_empty(): return
	check(false,"At least one seeded visit offers a gift")

## Gifts persist through refresh/cancellation and share atomic replacement and salvage rules.
func transactions() -> void:
	var m = Run.new(72)
	gift_visit(m)
	var gift: Dictionary = m.shop.gift.duplicate(true)
	check(m.shop.offers.size() == 9 and m.shop.offers.slice(6,8).all(func(o): return o.kind == "tarot"),"Gift replaces the reading, preserving all nine paid listings")
	check(m.shop.offers.all(func(o): return o.id != gift.id),"Keeper gift is reserved out of shelf stock")
	var state: int = m.reward_rng.state
	check(m.begin_tarot_reward("shop").is_empty() and m.reward_rng.state == state,"Gift cannot also claim the free reading")
	m.blood_gems = 2000
	for expected in [50,75,113,170]:
		var before: int = m.blood_gems
		check(m.shop.refresh_price == expected and m.shop.refresh(m) and m.blood_gems == before-expected,"Refresh charges rounded-up 1.5x steps")
		check(m.shop.gift == gift and not m.shop.divination_used,"Refresh neither rerolls nor consumes the locked gift")
		check(m.shop.offers.all(func(o): return o.id != gift.id),"Refreshed shelf still reserves the pending gift")
	m.blood_gems = 0
	state = m.reward_rng.state
	check(not m.shop.buy(m,m.shop.GIFT_SLOT).is_empty() and m.relics.has(gift.id) and m.blood_gems == 0,"Gift can be claimed with zero blood gems")
	check(m.shop.divination_used and m.shop.gift.sold and m.reward_rng.state == state,"Claim consumes the keeper reward once without rerolling")
	check(m.shop.buy(m,m.shop.GIFT_SLOT).is_empty() and m.shop.discard_gift(m) == 0,"Repeat claims and forfeits cannot duplicate rewards")
	check(m.begin_tarot_reward("shop").is_empty(),"Claimed gift never unlocks a second free reward")
	gift_visit(m)
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","bloodstone","contract"]: m.acquire_relic(id)
	var owned: Array = m.relics.items.duplicate(true)
	gift = m.shop.gift.duplicate(true); state = m.reward_rng.state
	check(m.relics.items.size() == 10 and m.shop.needs_replacement(m,m.shop.GIFT_SLOT),"Full backpack requires the usual replacement")
	check(m.shop.buy(m,m.shop.GIFT_SLOT).is_empty() and m.relics.items == owned and not m.shop.divination_used,"Failed gift acquisition leaves both inventories intact")
	var refund: int = m.replacement_gem_preview(gift.id,1)
	check(not m.shop.buy(m,m.shop.GIFT_SLOT,1).is_empty() and m.relics.has(gift.id) and m.blood_gems == refund,"Free gift replacement salvages the old item without charging")
	check(m.reward_rng.state == state,"Replacement does not choose a new gift")
	gift_visit(m)
	var quoted: int = m.relic_forfeit_preview(m.shop.gift.id)
	check(m.shop.discard_gift(m) == quoted and m.shop.divination_used and m.shop.discard_gift(m) == 0,"Explicit gift forfeit pays once")
	m.shop.reset()
	check(m.shop.gift.is_empty() and not m.shop.divination_used,"New runs clear keeper gifts")
	var session = Session.new(72)
	gift_visit(session.model)
	var snapshot: Dictionary = session.snapshot()
	check(snapshot.has("free_gift") and not snapshot.free_divination and "gift" in snapshot.actions,"CLI exposes the same keeper choice")
	check(not session.command({"action":"divination"}).ok,"CLI cannot substitute a free reading for a gift")
	check(session.command({"action":"gift"}).ok and session.model.shop.divination_used,"CLI claims the locked gift through the shared model")
	check(not session.command({"action":"gift"}).ok,"CLI cannot duplicate gift claims")
	session.model = null

func tap(g, at: Vector2) -> void:
	g._handle_click(at); g._handle_release(at)

## Exercise the keeper hitbox, translated line, floating art, modal cancellation and landing.
func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	gift_visit(g.model); g.view_phase = "shop"; g.shop_ui.open()
	g._process(0)
	var ui = g.shop_ui
	check(ui.dialogue_text() == "Looking for this?","Keeper uses the shorter requested invitation")
	check(GameText.text("Looking for this?") == "在找这个吗？" if GameText.language == "zh_CN" else true,"Gift line has Chinese localization")
	ui.age = 0.0; var first: Vector2 = ui.divination_deck_position()
	ui.age = 0.6
	check(ui.divination_deck_position().y > first.y,"Free relic shares the deck's floating motion")
	tap(g,ui.keeper_rect().get_center())
	check(ui.selected_gift() and not g.tarot_ui.ceremony.active() and not g.model.shop.divination_used,"Keeper tap inspects the gift before claiming")
	g._handle_click(ui.divination_deck_position())
	g._handle_motion(ui.divination_deck_position()+Vector2(100,40))
	check(ui.dragging and ui.pressed_offer == g.model.shop.GIFT_SLOT,"Free gift can be lifted from the keeper")
	g._handle_release(Vector2(10,10))
	check(not ui.dragging and not g.model.shop.divination_used,"Dropping away from Claim returns the gift without granting it")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		var language: String = GameText.language
		for locale in ["en","zh_CN"]:
			GameText.set_language(locale,false)
			await process_frame; await process_frame; RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/shop-gift-"+("portrait" if phone else "landscape")+"-"+locale+".png")
		GameText.set_language(language,false)
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","bloodstone","contract"]: g.model.acquire_relic(id)
	var gift_id: String = g.model.shop.gift.id
	g._handle_click(ui.divination_deck_position()); g._handle_motion(ui.buy_rect().get_center()); g._handle_release(ui.buy_rect().get_center())
	check(ui.replacing and g.inventory_page.opened and g.inventory_page.incoming_relic() == gift_id,"Full gift inventory opens the comparison page")
	tap(g,g.inventory_page.close_rect().get_center())
	check(not ui.replacing and ui.selected == -1 and not g.model.shop.divination_used,"Cancel exits comparison and leaves the same gift available")
	tap(g,ui.keeper_rect().get_center()); tap(g,ui.buy_rect().get_center())
	tap(g,g.inventory_page.slot_rect(1).get_center())
	tap(g,g.inventory_page.replace_rect().get_center())
	check(g.model.relics.has(gift_id) and g.model.shop.divination_used and g.relic_ui.pickup.active,"Confirmed replacement launches the inventory pickup")
	g.relic_ui.pickup.clear(); tap(g,ui.keeper_rect().get_center())
	check(ui.dialogue_text() == "Fate has spoken." and not g.tarot_ui.ceremony.active(),"Used gift cannot start tarot drawing")
	check(ui.pressed_offer == -1,"A claimed gift cannot be dragged or claimed again")
	g.queue_free(); await process_frame

func run() -> void:
	if "--shelf-only" in OS.get_cmdline_user_args():
		eligibility(); shelf_assistance()
		print("Shop shelf sets: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0)
		return
	eligibility(); probabilities(); shelf_assistance(); transactions()
	await scene(false); await scene(true)
	print("Shop sets: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
