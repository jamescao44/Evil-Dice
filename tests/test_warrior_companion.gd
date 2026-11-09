extends SceneTree
## Companion visuals share world transforms and attack receipts in both battlefield layouts.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func capture(g, label: String) -> void:
	g.queue_redraw(); g.arena_actors.queue_redraw(); g.fx.queue_redraw(); g.inventory_page.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/warrior-"+label+".png")
func run() -> void:
	GameText.set_language("zh_CN",false)
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
		g.model.relics.items.clear()
		g.model.acquire_relic("golden_warrior"); g.model.acquire_relic("magic_shield")
		g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1)]
		for e in g.model.enemies: e.hp = 9999; e.max_hp = 9999; e.shield = 0
		g.model.phase = "player"; g.view_phase = "ready"
		g.evolution.reset()
		g.warrior_companion.advance(1,g.model)
		var rng: int = g.model.rng.state
		var rect: Rect2 = g.warrior_companion.sprite_rect(g)
		check(g.ARENA.encloses(rect),"Warrior stays in battlefield")
		check(rect.get_center().x > g.evolution.visible_rect(g._player_world_sprite_rect()).get_center().x,"Warrior beside player's right")
		check(g.model.rng.state == rng,"Cosmetic placement uses no combat RNG")
		var desc: String = g.model.relics.Catalog.description(g.model.relics.items[0],GameText.text,g.model.relics.items)
		check("同伴生命" in desc and "战士 5/5" in desc,"Chinese description has health and collected set count")
		if "--capture" in OS.get_cmdline_user_args(): await capture(g,"phone" if phone else "wide")
		g._show_events(g.model.RelicEffects.Attack.apply(g.model,"golden_warrior",0,false,false,0,{"base_scale":1.0}))
		check(g.relic_attacks.flights.size() == 1,"Guardian attack has one flight")
		check(g.relic_attacks.flights[0].kind == "spear","Guardian uses spear projectile")
		check(g.relic_attacks.flights[0].start.is_equal_approx(g.warrior_companion.hand(g)),"Spear originates at the warrior hand")
		g.relic_attacks.advance(0.31)
		if "--capture" in OS.get_cmdline_user_args(): await capture(g,"shot-phone" if phone else "shot-wide")
		g.relic_attacks.advance(1)
		check(not g.relic_attacks.pending(),"Spear completes impact queue")
		g.model.relics.items[0].guardian_hp = 0
		g.model.relics.items[0].guardian_recovery = 3
		g.warrior_companion.advance(1,g.model)
		check(g.warrior_companion.opacity == 0,"Downed companion disappears")
		check("3回合" in g.model.relics.Catalog.description(g.model.relics.items[0],GameText.text),"Inventory reports recovery")
		g.model.relics.items[0].guardian_hp = 300; g.model.relics.items[0].guardian_recovery = 0
		g.warrior_companion.advance(1,g.model)
		g.inventory_page.open(); g.inventory_page.selected = 0
		if "--capture" in OS.get_cmdline_user_args(): await capture(g,"inventory-phone" if phone else "inventory-wide")
		g.inventory_page.close()
		for id in ["bracelet","codex_page","coin","bloodstone","orange_stone","blue_stone","worn_bow","contract"]: g.model.acquire_relic(id)
		for level in [1,5,10]:
			g.model.character_level = level; g.evolution.reset()
			var beside: Rect2 = g.warrior_companion.sprite_rect(g)
			check(g.ARENA.encloses(beside) and beside.position.x > g.RelicOrbit.right_clearance(g),"Every form leaves the full activated relic orbit clear")
			for time in [0.0,6.0,12.0,18.0]:
				g.relic_ui.ready_clock = time
				check(g.warrior_companion.sprite_rect(g) == beside,"Warrior does not chase moving relics")
				for pose in g.RelicOrbit.poses(g):
					check(not beside.intersects(Rect2(pose.at-Vector2.ONE*pose.radius,Vector2.ONE*pose.radius*2)),"Orbiting artwork never passes behind the warrior")
		g.model.character_level = 10; g.evolution.reset()
		var large_rect: Rect2 = g.warrior_companion.sprite_rect(g)
		check(g.ARENA.encloses(large_rect),"Warrior stays visible beside final form")
		if "--capture" in OS.get_cmdline_user_args(): await capture(g,"final-phone" if phone else "final-wide")
		g.model.relics.remove(0)
		g.warrior_companion.advance(1,g.model)
		check(g.warrior_companion.opacity == 0,"Selling removes companion")
		g.queue_free(); await process_frame
	print("Warrior presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
