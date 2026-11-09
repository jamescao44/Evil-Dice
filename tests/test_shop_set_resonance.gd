extends SceneTree
## Match real set holdings to stable shop slots without touching loot or transactions.
const Run = preload("res://scripts/progression/run_rules.gd")
const Resonance = preload("res://scripts/rewards/shop_set_resonance.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Use fixed offers and no persistence, including a partial meal and duplicate page listings.
func fixture(m) -> void:
	m.relics.clear()
	for id in ["lemon_soda","fries","armor","worn_spear","orange_stone","codex_page"]: m.acquire_relic(id)
	m.shop.open_debug(m)
	m.shop.offers.clear()
	for id in ["hamburger","bracelet","rusty_round_shield","blue_stone","codex_page","codex_page"]:
		m.shop.offers.append({"kind":"relic","id":id,"price":250,"sold":false})
	m.shop.offers.append({"kind":"tarot","id":"strength","price":100,"sold":false})
	m.shop.offers.append({"kind":"tarot","id":"emperor","price":100,"sold":false})
	m.shop.offers.append({"kind":"soul_bottle","id":"soul_bottle","price":200,"sold":false,"souls":10})
	m.shop.gift = {"kind":"relic","id":"spiked_helmet","price":0,"sold":false}
	m.shop.divination_used = false

## Verify sequential matching, fused holdings, sold stock, completion, reordering and RNG isolation.
func model_checks() -> void:
	var m = Run.new(441)
	fixture(m)
	var hint = Resonance.new()
	var rng: int = m.reward_rng.state
	var items: Array = m.relics.items.duplicate(true)
	var stock: Array = m.shop.offers.duplicate(true)
	hint.advance(0,m.shop,m.relics.items,true,false)
	check(hint.groups.map(func(g): return g.slots) == [[0],[2,9],[3],[4,5]],"Sets follow first shelf appearance, grouping duplicate listings and keeper gift")
	check(hint.groups[0].owned == [0] and m.relics.items[0].id == "budget_meal","Partial fusion resonates as its actual owned icon")
	check(hint.groups[1].owned == [1,2],"All owned pieces of the matching set resonate together")
	for index in range(hint.groups.size()):
		hint.age = Resonance.Motion.REST+index*(Resonance.Motion.DURATION+Resonance.Motion.GAP)+0.3
		var group: Dictionary = hint.current_group()
		check(group == hint.groups[index],"Next matching listing keeps display order")
		check(hint.offer_pose(group.slots[0]).x > 0 and hint.offer_pose(group.slots[0]).y != 0,"Offer enlarges and rocks")
		for slot in group.slots: check(hint.offer_pose(slot) == hint.pose(),"Every shop listing in the current set hints together")
		for owned in group.owned: check(hint.owned_pose(owned) == hint.offer_pose(group.slots[0]),"Owned and shop item share exact timing")
		check(hint.groups.filter(func(g): return hint.offer_pose(g.slots[0]).z > 0).size() == 1,"Only one set hints at a time")
	hint.age = Resonance.Motion.REST+0.3
	var paused: float = hint.age
	hint.advance(1,m.shop,m.relics.items,false,false)
	check(hint.pose() == Vector3.ZERO and hint.age == paused,"Gesture pause hides pose without spending the sequence")
	hint.advance(0,m.shop,m.relics.items,true,true)
	check(hint.pose().x == 0 and hint.pose().y == 0 and hint.pose().z > 0,"Reduced effects retain light without rocking or scaling")
	check(rng == m.reward_rng.state and stock == m.shop.offers and items == m.relics.items,"All hints are cosmetic and consume no gameplay RNG")
	m.shop.offers[0].sold = true
	hint.advance(0,m.shop,m.relics.items,true,false)
	check(hint.groups[0].slots == [2,9] and hint.age == 0,"Buying removes the old listing and safely restarts the queue")
	m.move_relic(1,4)
	hint.advance(0,m.shop,m.relics.items,true,false)
	check(hint.groups[0].owned == [1,4],"Reordering follows current inventory indices")
	m.shop.divination_used = true
	hint.advance(0,m.shop,m.relics.items,true,false)
	check(hint.groups.all(func(g): return 9 not in g.slots),"Claimed keeper gift no longer hints")
	m.shop.offers[0].sold = false
	m.shop.offers[0].id = "fries"
	hint.advance(0,m.shop,m.relics.items,true,false)
	check(hint.groups.all(func(g): return 0 not in g.slots),"Already fused ingredients do not falsely suggest progress")
	for id in ["blue_stone","purple_stone","yellow_stone","green_stone","black_stone"]: m.acquire_relic(id)
	for i in range(9): m.acquire_relic("codex_page")
	hint.advance(0,m.shop,m.relics.items,true,false)
	check(hint.groups.all(func(g): return g.slots.all(func(slot): return slot not in [3,4,5])),"Completed Stones and Codex stop hinting stale shop stock")
	hint.reset()
	check(hint.groups.is_empty() and hint.pose() == Vector3.ZERO,"Leaving clears the presentation")

## Optional native captures show the actual shelf and rail in each layout.
func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	g.queue_redraw(); g.shop_ui.queue_redraw(); g.shop_ui.keeper_overlay.queue_redraw(); g.relic_ui.queue_redraw(); g.inventory_page.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/shop-resonance-"+label+".png")

## Preserve touch hitboxes, menu layering, purchase gestures and the inventory grid.
func scene_checks() -> void:
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED; g.reduced = false
		fixture(g.model); g.view_phase = "shop"; g.shop_ui.open()
		var ui = g.shop_ui
		ui.modulate.a = 0.5; ui._process(1)
		check(ui.resonance.age == 0,"Fade-in preserves the initial hint delay")
		ui.modulate.a = 1; ui._process(0.95)
		check(ui.set_hint_for_offer(0) == ui.set_hint_for_owned(0) and ui.set_hint_for_offer(0).z > 0,"Shelf and owned rail share the live clock")
		var hitbox: Rect2 = ui.offer_art_rect(0)
		await capture(g,"phone" if phone else "wide")
		ui.click(hitbox.get_center()); ui.motion(hitbox.get_center()+Vector2(40,40))
		check(ui.dragging and ui.set_hint_for_offer(0) == Vector3.ZERO,"Dragging immediately overrides the hint")
		check(ui.offer_art_rect(0) == hitbox,"Resonance never moves the touch target")
		ui.cancel_drag(); g.menu_open = true; ui._process(1)
		check(ui.set_hint_for_owned(0) == Vector3.ZERO,"System menus hide inventory resonance")
		g.menu_open = false; ui._process(0)
		var hint_age: float = ui.resonance.age
		g.inventory_page.open(); ui._process(0.05)
		check(ui.set_hint_for_owned(0) == Vector3.ZERO and ui.set_hint_for_offer(0) == Vector3.ZERO,"Opaque inventory suppresses both sides of shop resonance")
		check(ui.resonance.age == hint_age,"Hidden shop does not advance the set sequence")
		await capture(g,"inventory-phone" if phone else "inventory-wide")
		g.inventory_page.selected = 0; ui._process(1)
		check(ui.set_hint_for_owned(0) == Vector3.ZERO,"Detailed item inspection stays motionless")
		g.inventory_page.close(); ui._process(0)
		check(ui.set_hint_for_owned(0).z > 0 and ui.set_hint_for_owned(0) == ui.set_hint_for_offer(0),"Returning to the shop resumes synchronized hints")
		g.reduced = true; ui._process(0)
		check(ui.set_hint_for_offer(0).x == 0 and ui.set_hint_for_owned(0).y == 0,"Reduced motion works on both layouts")
		ui.cancel()
		check(ui.set_hint_for_owned(0) == Vector3.ZERO,"Closed shop leaves no inventory hint")
		g.queue_free(); await process_frame

func run() -> void:
	GameText.set_language("zh_CN",false)
	model_checks()
	await scene_checks()
	print("Shop set resonance: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
