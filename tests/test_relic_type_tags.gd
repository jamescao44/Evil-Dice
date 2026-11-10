extends SceneTree
const Tags = preload("res://scripts/relics/relic_type_tags.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void: call_deferred("run")

## Capture real shop, replacement, inspection and chest surfaces without touching a saved run.
func capture(g, tag: String, phone: bool) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.shop_ui.queue_redraw(); g.inventory_page.queue_redraw(); g.chest.queue_redraw(); g.relic_ui.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/relic-tags-%s-%s-%s.png" % [tag,GameText.language,"portrait" if phone else "desktop"])

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800); root.size = root.content_scale_size
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.reduced = true; g.process_mode = Node.PROCESS_MODE_DISABLED
	g.player_animation.reset(); g.evolution.reset()
	g.model.relics.items = [{"id":"witch_ghost"},{"id":"codex_page","count":3}]
	for language in ["en","zh_CN"]:
		GameText.set_language(language,false)
		check(Tags.labels({"id":"witch_ghost"}) == (["Biotic ×5","Treasure"] if language == "en" else ["生物 ×5","宝物"]),"Fusion tags preserve bone and ring type counts")
		check(Tags.labels({"id":"codex_page","count":3}) == (["Artefact ×3"] if language == "en" else ["法具 ×3"]),"Stacked copies show their actual type count")
		check(not Catalog.description({"id":"witch_ghost"},GameText.text,[],false).contains(GameText.text("Type: %s").split("%")[0]),"Tagged details omit duplicate type prose")
		for id in Catalog.ITEMS:
			var badges: Array = Tags.layout({"id":id},g.description_font,124,17)
			for i in range(badges.size()):
				check(badges[i].rect.position.x >= 0 and badges[i].rect.end.x <= 124.01,"Narrow chest badge fits: "+id)
				for j in range(i): check(not badges[i].rect.intersects(badges[j].rect),"Wrapped badges do not overlap")
		g.model.shop.active = true; g.model.shop.offers.clear()
		for id in ["worn_bow","hamburger","codex_page","magic_sword","cursed_skull","witch_ghost"]:
			g.model.shop.offers.append({"kind":"relic","id":id,"price":180,"sold":false})
		for id in ["strength","emperor"]: g.model.shop.offers.append({"kind":"tarot","id":id,"price":200,"sold":false})
		g.model.shop.offers.append({"kind":"soul_bottle","id":"soul_bottle","souls":15,"price":160,"sold":false})
		g.view_phase = "shop"; g.shop_ui.open(); g.shop_ui.selected = 3
		for id in Catalog.ITEMS:
			g.model.shop.offers[0].id = id
			var name: String = GameText.text(Catalog.ITEMS[id].name)
			var size: int = g.shop_ui.offer_name_size(0,name)
			var at: Vector2 = g.shop_ui.offer_tags_top(0,name,size)
			var bottom: float = at.y+Tags.height({"id":id},g.description_font,g.shop_ui.offer_name_rect(0).size.x,g.shop_ui.offer_tag_size(0))
			check(bottom <= g.shop_ui.offer_rect(0).end.y-(35 if phone else 32),"Shelf badge leaves price space: "+id)
		g.model.shop.offers[0].id = "worn_bow"
		await capture(g,"shop",phone)
		g.inventory_page.open(); g.inventory_page.selected = 0
		await capture(g,"inventory",phone)
		g.inventory_page.close(false)
		g.shop_ui.replacing = true; g.inventory_page.open("shop")
		await capture(g,"replacement",phone)
		g.inventory_page.close(false); g.shop_ui.cancel(); g.model.shop.active = false
		g.view_phase = "reward"
		for ids in [["witch_ghost"],["worn_bow","magic_sword","codex_page","cursed_skull","witch_ghost"]]:
			g.chest.start(ids.map(func(_id): return 1),g.fx.canvas_size,g.description_font,true,ids.map(func(id): return {"relic_id":id}),3 if ids.size() == 5 else 0)
			g.chest.open_chest(); g.chest._begin_settle(0); g.chest.elapsed = g.chest.stop_time(ids.size()-1)+2; g.chest.active = false; g.chest.focused = 0
			await capture(g,"chest%d" % ids.size(),phone)
			g.chest.cancel()
	g.queue_free(); await process_frame

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--portrait-only" not in args: await scene(false)
	if "--desktop-only" not in args: await scene(true)
	print("Relic type tags: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
