extends SceneTree
## Capture owned set artwork and descriptions in both supported inventory layouts.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
func _initialize() -> void: call_deferred("render")
func render() -> void:
	for portrait in [true,false]:
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g)
		g.muted=true; g.set_process(false); g.set_process_input(false)
		g._restart()
		for id in ["fries","lemon_soda","hamburger","oreo_sundae","fried_chicken"]: g.model.acquire_relic(id)
		g.view_phase="ready"; g.inventory_page.open(); g.inventory_page.selected=0
		g._process(0);g.inventory_page.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/meal-"+("portrait" if portrait else "landscape")+".png")
		root.remove_child(g);g.free()
	quit()
