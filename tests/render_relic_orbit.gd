extends SceneTree
## Capture orbit density, activation feedback and UI layering in both layouts.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
func _initialize() -> void: call_deferred("render")
func render() -> void:
	for portrait in [true,false]:
		root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
		root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g);g.muted=true;g.set_process(false);g.set_process_input(false);g.relic_ui.set_process(false)
		g._restart()
		for id in ["fries","fried_chicken","orange_stone","codex_page","magic_sword","bracelet","heart","armor","coin","four_leaf_clover","crystal_ball"]: g.model.acquire_relic(id)
		g.view_phase="ready"; g.relic_ui.ready_clock=3.0
		g.relic_ui.activate("orange_stone");g.relic_ui.activations.orange_stone.age=0.25
		g.model.character_passive.charge=2
		g._process(0);g.relic_ui.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/relic-orbit-"+("portrait" if portrait else "landscape")+".png")
		root.remove_child(g);g.free()
	quit()
