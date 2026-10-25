extends SceneTree
## Review capped hits and translated new relics in both layouts; exercise a real split cast.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func capture(g, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.inventory_page.queue_redraw(); g.fx.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/builds-20261025/"+label+".png")

func run() -> void:
	for phone in [false,true]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
		var label: String = "portrait" if phone else "landscape"
		g._restart(21)
		for e in g.model.enemies: e.hp = 10000000; e.max_hp = 10000000; e.shield = 0
		for id in ["vodka","mysterious_seed","magic_bandage","steel_sword","split_arrow","book_of_dead","pet_orb","cursed_die","prismatic_stone","contract"]: g.model.acquire_relic(id)
		g.inventory_page.open(); g.inventory_page.selected = -1
		await capture(g,label+"-inventory")
		g.inventory_page.selected = 1
		await capture(g,label+"-seed")
		g.inventory_page.close()
		g.fx.damage_stage = 20
		for sample in [[0,100],[1,1000],[2,1000000]]:
			var point: Vector2 = g._enemy_point(sample[0])
			g.fx.damage_number(point,str(sample[1]),g.RED,g.fx.damage_font_size(sample[1],20))
			g.fx.slash(point,false,sample[1])
		await capture(g,label+"-damage")
		g.model.relics.clear(); g.model.acquire_relic("split_arrow"); g.model.acquire_relic("worn_dagger")
		g.model.character_passive.charge = 2
		g.model.pending = g.model.Patterns.classify([3,4,5]); g.model.phase = "player"
		g._show_pending_skill(false); g._resolve_player(0)
		var deadline: int = Time.get_ticks_msec()+25000
		while (g.model.phase != "roll" or g.view_phase != "ready") and Time.get_ticks_msec() < deadline: await process_frame
		if g.model.phase != "roll" or g.view_phase != "ready": failures += 1; push_error("Split and bonus skills did not return control: "+label)
		g.queue_free(); await process_frame
	print("Build scene layouts: ",failures," failures")
	quit(1 if failures else 0)
