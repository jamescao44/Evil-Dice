extends SceneTree
## Real input regression for consumed tarot offers and explicit relic replacement.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const OWNED := ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","twin_scythes"]
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

## Fail by behavior rather than by the implementation of the transaction.
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func tap(g, at: Vector2) -> void:
	g._handle_click(at); g._handle_release(at)

## Drop the exact carousel card, including its normal press and release routing.
func drag_card(g, instance: int) -> void:
	g.tarot_ui.focus_instance(instance)
	g.tarot_ui.swallow_release = false
	g.tarot_ui.expansion = 1
	var origin: Vector2 = g.tarot_ui.carousel_pose(g.tarot_ui.front_index()).at
	g._handle_click(origin)
	g._handle_motion(origin-Vector2(0,70))
	g._handle_motion(g.ARENA.get_center())
	g._handle_release(g.ARENA.get_center())

## Wait for the committed pickup; no inventory page may block it after confirmation.
func settle(g) -> void:
	var deadline: int = Time.get_ticks_msec()+5000
	while (g.tarot_cast.busy or g.relic_ui.pickup.active) and Time.get_ticks_msec() < deadline: await process_frame
	check(not g.tarot_cast.busy and not g.relic_ui.pickup.active,"Confirmed grant animation finishes")

func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.inventory_page.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/grant-%s-%s.png" % ["portrait" if g is Portrait else "landscape",label])

## Consume both relic cards on offer, even when their replacement is cancelled.
func first_offer(g, id: String) -> void:
	g._restart()
	for relic in OWNED: g.model.acquire_relic(relic)
	for other in ["strength","emperor","sun","world"]: g.model.tarots.add(other)
	var card: Dictionary = g.model.tarots.add(id)
	for other in ["tower","moon","hermit"]: g.model.tarots.add(other)
	var cards: Array = g.model.tarots.items.filter(func(c): return c.instance_id != card.instance_id).duplicate(true)
	var items: Array = g.model.relics.items.duplicate(true)
	drag_card(g,card.instance_id)
	var page = g.inventory_page
	check(page.opened and page.replacement == "tarot" and g.tarot_cast.choice_type == "replace","Full tarot grant opens the shared backpack")
	var offered: String = page.incoming_relic()
	var rng: int = g.model.reward_rng.state
	check(not offered.is_empty() and g.model.tarots.items == cards,"Preparing a first offer consumes exactly its card")
	await capture(g,id+"-grid")
	tap(g,page.slot_rect(1).get_center())
	check(page.selected == 1 and g.model.relics.items == items and g.model.tarots.items == cards,"Inspecting an owned item does not commit the grant")
	await capture(g,id+"-inspect")
	tap(g,page.back_rect().get_center())
	tap(g,page.close_rect().get_center())
	await settle(g)
	check(not page.opened and not g.tarot_cast.active() and g.view_phase == "ready","Cancellation restores gameplay input")
	check(g.model.tarots.items == cards and g.model.relics.items == items,"Cancellation preserves other cards and all owned relics")
	check(g.model.tarots.find_instance(card.instance_id) < 0,"Cancelled card is not refunded")
	check(g.model.reward_rng.state == rng and not g.model.tarot_effects.locked_grants.has(card.instance_id),"Cancel resolves the offer without rerolling")
	card = g.model.tarots.add(id)
	drag_card(g,card.instance_id)
	offered = page.incoming_relic()
	tap(g,page.slot_rect(2).get_center())
	tap(g,page.replace_rect().get_center())
	check(not page.opened and g.model.relics.items[2].id == offered,"Only explicit replacement commits and closes the backpack")
	check(g.model.tarots.find_instance(card.instance_id) < 0 and g.model.tarots.items.any(func(c): return c.id == id),"Exactly the committed card instance is consumed")
	await settle(g)
	check(g.view_phase == "ready" and g.model.relics.items.size() == 10,"The completed grant resumes battle with ten relics")

## Declining Prophecy's second offer must not refund a card whose first gift was accepted.
func repeat_offer(g) -> void:
	g._restart()
	g.model.acquire_relic("ancient_prophecy")
	for relic in OWNED.slice(0,9): g.model.acquire_relic(relic)
	var card: Dictionary = g.model.tarots.add("emperor")
	g.model.tarot_effects.locked_grants[card.instance_id] = "contract"
	drag_card(g,card.instance_id)
	tap(g,g.inventory_page.slot_rect(1).get_center())
	tap(g,g.inventory_page.replace_rect().get_center())
	await settle(g)
	check(g.inventory_page.opened and g.tarot_cast.instance_id < 0,"A repeated grant opens its own replacement backpack")
	check(g.model.relics.has("contract") and g.model.tarots.find_instance(card.instance_id) < 0,"First grant commits once before the repeat")
	tap(g,g.inventory_page.close_rect().get_center())
	check(g.model.tarot_effects.pending_repeat.is_empty() and g.view_phase == "ready","Skipping a repeat finishes its transaction")
	check(g.model.relics.has("contract") and g.model.tarots.find_instance(card.instance_id) < 0,"Skipping a repeat keeps the accepted gift without duplicating its card")

func run() -> void:
	for portrait in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
		root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g); g.muted = true; g.speed = 2
		for id in ["emperor","world"]: await first_offer(g,id)
		await repeat_offer(g)
		g.queue_free(); await process_frame
	print("Relic grant cancellation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
