extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

## Report visual geometry and input routing failures by their actual behavior.
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Capture representative pages without changing their gameplay state.
func capture(g, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g._process(0); g.shop_ui.queue_redraw(); g.inventory_page.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/"+name+".png")

## Check every wave before and after targeting zoom, including intent headroom.
func formation(g, label: String) -> void:
	for wave in range(1,20):
		g._restart(wave)
		for focused in [false,true]:
			g.result = g.Rules.Patterns.classify([6,6])
			g.view_phase = "targeting" if focused else "ready"
			g._update_battlefield_view(1)
			for i in range(g.model.enemies.size()):
				var intent: Rect2 = g._enemy_intent_rect(i).grow(4*g.battlefield_view.zoom)
				if i in g.model.taunting_enemies():
					var size: int = roundi((22 if label == "portrait" else 16)*g.battlefield_view.zoom)
					var width: float = g.pixel_font.get_string_size(GameText.text("TAUNT"),HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
					var title := Rect2(g._enemy_intent_rect(i).get_center().x-width/2,g._enemy_intent_rect(i).position.y-(size+10)*g.battlefield_view.zoom,width,size*g.battlefield_view.zoom)
					intent = intent.merge(title)
				check(intent.end.y < g._enemy_sprite_rect(i).position.y,"Intent stays above its own head: "+label+str(wave))
				for j in range(g.model.enemies.size()):
					check(not intent.intersects(g._enemy_sprite_rect(j)),"Intent never covers another actor: "+label+str(wave)+" "+str(i)+"/"+str(j))
					check(not intent.intersects(g._enemy_health_rect(j).grow(3)),"Intent remains separate from health: "+label+str(wave))
					if i != j: check(not g._enemy_health_rect(i).grow(3).intersects(g._enemy_health_rect(j).grow(3)),"Health plates do not overlap")
			if wave in [4,6,18] and not focused: await capture(g,"formation-"+label+str(wave))

## Use actual mouse/touch entry points so overlays cannot leak clicks to rewards.
func tap(g, at: Vector2) -> void:
	g._handle_click(at); g._handle_release(at)

## Verify ten empty/owned slots, item pages and restoration across all contexts.
func inventory(g, label: String) -> void:
	g._restart()
	var page = g.inventory_page
	for id in ["heart","magic_sword","runestone","mithril_blade","cursed_skull","codex_page"]: g.model.acquire_relic(id)
	for context in ["ready","shop","reward","wave_reward"]:
		g.view_phase = context
		if context == "shop":
			g.model.shop.active = true; g.model.shop.wave = 5; g.model.shop.number = 1
			g.model.shop._restock(g.model); g.shop_ui.open()
		var rng_before: int = g.model.reward_rng.state
		var money: int = g.model.blood_gems
		tap(g,page.button_rect().get_center())
		check(page.opened and g._menus_open(),"Inventory opens above "+context)
		for i in range(10):
			check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(page.slot_rect(i)),"Ten slots stay on screen")
			check(is_equal_approx(page.slot_rect(i).position.y,page.slot_rect(0 if i < 5 else 5).position.y),"Exactly five slots per row")
		tap(g,page.slot_rect(9).get_center())
		check(page.selected < 0,"Empty slot has no item detail")
		await capture(g,"inventory-"+label+context)
		tap(g,page.slot_rect(1).get_center())
		check(page.selected == 1 and g.view_phase == context,"Item detail stays above the original context")
		await capture(g,"item-detail-"+label+context)
		tap(g,page.back_rect().get_center()); check(page.selected == -1,"Back returns to grid")
		tap(g,page.close_rect().get_center())
		check(not page.opened and g.view_phase == context and g.model.blood_gems == money and g.model.reward_rng.state == rng_before,"Browsing preserves purchases, rewards and RNG")
		g.shop_ui.cancel()
	g.model.shop.active = false

## Exercise drag cancellation, direct buys, duplicate protection and pickup layering.
func shop_drag(g, label: String) -> void:
	g._restart(5)
	for enemy in g.model.enemies: enemy.hp = 0
	g.model.wave_reward_resolved = true
	g.model.wave_kind = g.model.WaveRewards.SHOP
	g.model.blood_gems = 3000
	check(g.model.shop.open(g.model),"Shop opens for drag test")
	g.view_phase = "shop"; g.shop_ui.open()
	var ui = g.shop_ui
	for i in range(8):
		check(ui.offer_art_rect(i).end.y <= ui.offer_name_rect(i).position.y,"Shelf artwork never overlaps its name")
	check(not g.tarot_ui.icon_rect().intersects(ui.buy_rect()),"Tarot shortcut stays clear of buy button")
	var price: int = g.model.shop.offers[0].price
	g._handle_click(ui.offer_rect(0).get_center())
	g._handle_motion(ui.buy_rect().get_center())
	check(ui.dragging and ui.held_layer.z_index == g.HELD_ITEM_Z,"Held merchandise is above shop")
	await capture(g,"shop-drag-"+label)
	g._handle_release(Vector2(15,15))
	check(not ui.dragging and g.model.blood_gems == 3000 and not g.model.shop.offers[0].sold,"Dropping outside buy cancels without payment")
	g._handle_click(ui.offer_rect(0).get_center()); g._handle_motion(ui.buy_rect().get_center()); g._handle_release(ui.buy_rect().get_center())
	check(g.model.blood_gems == 3000-price and g.model.shop.offers[0].sold and g.relic_ui.pickup.active,"Drop buys exactly the held item")
	g._handle_release(ui.buy_rect().get_center())
	check(g.model.blood_gems == 3000-price,"Repeated release cannot buy twice")
	g.relic_ui.pickup.clear()
	var cards_before: int = g.model.tarots.items.size()
	g._handle_click(ui.offer_rect(6).get_center()); g._handle_motion(ui.buy_rect().get_center()); g._handle_release(ui.buy_rect().get_center())
	check(g.model.tarots.items.size() == cards_before+1 and not g.tarot_ui.ceremony.active(),"Dragged tarot is purchased without a draw")
	g.tarot_ui.pickup.reset()
	ui.selected = 1
	await capture(g,"shop-shelves-"+label)
	var language: String = GameText.language
	GameText.set_language("en",false)
	await capture(g,"shop-shelves-en-"+label)
	GameText.set_language(language,false)
	g.inventory_page.open()
	check(g.inventory_page.opened and not ui.dragging,"Inventory opening cancels captured merchandise")
	g.inventory_page.close(); g.shop_ui.cancel(); g.model.shop.close()

## Browsing a live chest must preserve its music, prizes and replacement transaction.
func chest_inventory(g, label: String) -> void:
	g._restart()
	for id in ["codex_page","heart","bracelet","armor","coin","magic_shield","magic_sword","twin_scythes","orange_stone","blue_stone"]: g.model.acquire_relic(id)
	g.model._roll_chest(0)
	g.model.open_rewards = [g.Rewards.Category.RELIC]
	g.model.chest_relics = {0:"contract"}
	g.model.chest_tarots.clear()
	g.view_phase = "reward"
	g.chest.audio_clock_enabled = false
	g.chest.start(g.model.open_rewards,g.fx.canvas_size,g.description_font,false,[g.model.reward_item(0)],0)
	g.chest.open_chest(); g.chest._process(4)
	g.chest.request_stop(); g.chest.skip_animation(); g.chest._process(4)
	check(not g.chest.active,"Chest fixture reached collectible prizes")
	var rng_before: int = g.model.reward_rng.state
	tap(g,g.inventory_page.button_rect().get_center())
	g._process(0)
	check(g.inventory_page.opened and not g.chest.paused and not g.chest.audio.payout.stream_paused,"Inventory does not pause chest payout music")
	tap(g,g.chest.reel_rect(0).get_center())
	check(g.model.claimed_slots.is_empty(),"Inventory taps cannot claim a chest prize underneath")
	tap(g,g.inventory_page.close_rect().get_center())
	tap(g,g.chest.reel_rect(0).get_center())
	check(g.relic_ui.chest_slot == 0 and g.model.claimed_slots.is_empty(),"Full inventory retains pending prize")
	check(g.inventory_page.opened and g.inventory_page.replacement == "chest","Full chest claim automatically opens the replacement backpack")
	check(g.inventory_page.incoming_relic() == "contract","The backpack shows the locked incoming relic")
	tap(g,g.inventory_page.close_rect().get_center())
	check(not g.inventory_page.opened and g.relic_ui.chest_slot == -1 and g.model.claimed_slots.is_empty(),"Cancelling returns to the chest without discarding its prize")
	tap(g,g.chest.reel_rect(0).get_center())
	check(g.inventory_page.opened and g.inventory_page.incoming_relic() == "contract","Retry opens the same unclaimed prize")
	tap(g,g.inventory_page.slot_rect(2).get_center())
	check(g.model.relics.items[2].id == "bracelet","Inspection does not replace an item")
	await capture(g,"chest-item-replace-"+label)
	tap(g,g.inventory_page.replace_rect().get_center())
	check(not g.inventory_page.opened and g.model.relics.items[2].id == "contract" and g.model.claimed_slots == [0],"Explicit item-page confirmation replaces once")
	check(g.model.reward_rng.state == rng_before,"Inventory never rerolls a chest")
	g.relic_ui.pickup.clear()
	g.model.claimed_slots.clear(); g.chest.collected.clear()
	g.model.chest_relics = {0:"runestone"}
	g.relic_ui.chest_slot = 0
	g.inventory_page.open("chest")
	var owned: Array = g.model.relics.items.duplicate(true)
	check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(g.inventory_page.discard_rect()),"Discard remains within the viewport")
	tap(g,g.inventory_page.discard_rect().get_center())
	check(not g.inventory_page.opened and g.model.claimed_slots == [0] and g.chest.collected == [0],"Discard resolves just the incoming chest prize")
	check(g.model.relics.items == owned and not g.relic_ui.pickup.active,"Discard keeps every owned item and creates no pickup")
	check(g.model.reward_rng.state == rng_before and g.relic_ui.chest_slot == -1,"Discard does not reroll or retain a stale replacement")
	g._restart()

## Run on both real scene variants and preserve the user's language preference.
func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false); g.set_process(false)
	var label: String = "portrait" if portrait else "landscape"
	await formation(g,label)
	await inventory(g,label)
	await shop_drag(g,label)
	await chest_inventory(g,label)
	g.queue_free(); await process_frame

func run() -> void:
	await layout(false)
	await layout(true)
	print("Inventory and layout: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
