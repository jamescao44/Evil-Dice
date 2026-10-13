extends SceneTree
## Regenerate the reel icon atlas from the same sourced sprites as inventory icons.
const Paint = preload("res://scripts/relic_paint.gd")
const Catalog = preload("res://scripts/relic_catalog.gd")

func _initialize() -> void: call_deferred("render")

func render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(Catalog.ITEMS.size()*64,64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Node2D.new()
	viewport.add_child(canvas)
	canvas.draw.connect(func():
		var i := 0
		for id in Catalog.ITEMS:
			Paint.paint(canvas,id,Vector2(i*64+32,32),26,false) # Reels paint the glow dynamically with clipping.
			i += 1)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://assets/art/relic_atlas.png")
	quit()
