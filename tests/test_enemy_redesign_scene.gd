extends SceneTree
## Check the new class art and elite inspection in the real phone and desktop presentations.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output/enemy-redesign")
	for phone in [true,false]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process_input(false)
		g.model.enemies = [g.Rules.EnemyCatalog.make(g.Rules.EnemyCatalog.Role.CLERIC,4,true),g.Rules.EnemyCatalog.make(g.Rules.EnemyCatalog.Role.ASSASSIN,4,true)]
		g.model.enemies[0].modifier = "shielding"
		g.model.enemies[1].modifier = "manic"
		g.model.phase = "new"; g.model.begin_round(); g.view_phase = "ready"
		g._update_battlefield_view(1.0)
		for i in range(2):
			var text: String = g._enemy_intent_data(i).description
			if text.is_empty() or not g.ARENA.encloses(g._enemy_health_rect(i)): failures += 1
		await process_frame; await process_frame
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://test-output/enemy-redesign/"+("phone" if phone else "desktop")+".png")
		g.inspecting_enemy = 1
		g.queue_redraw(); await process_frame
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://test-output/enemy-redesign/"+("phone" if phone else "desktop")+"-inspection.png")
		g._restart(); g.queue_free(); await process_frame
	print("Enemy redesign presentation: %d failures" % failures)
	quit(1 if failures else 0)
