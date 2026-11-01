extends SceneTree
## Render the Bomber and a modified elite special without loading or writing campaign saves.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for phone in [true,false]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process_input(false)
		g.model.stage = 12
		g.model.enemies = [g.Rules.EnemyCatalog.make(g.Rules.EnemyCatalog.Role.BOMBER,4),g.Rules.EnemyCatalog.make(g.Rules.EnemyCatalog.Role.HIGH_PRIEST,4,true)]
		g.model.enemies[1].modifier = "shielding"
		g.model.phase = "new"; g.model.begin_round(); g.view_phase = "ready"
		g._update_battlefield_view(1.0)
		for i in range(2):
			if g._enemy_intent_data(i).description.is_empty() or not g.ARENA.encloses(g._enemy_health_rect(i)): failures += 1
		g.inspecting_enemy = 0
		g.queue_redraw()
		await process_frame; await process_frame
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://test-output/bomber-"+("phone" if phone else "desktop")+".png")
		g.queue_free(); await process_frame
	print("Bomber presentation: %d failures" % failures)
	quit(1 if failures else 0)
