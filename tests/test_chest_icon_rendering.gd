extends SceneTree
## Pixel-compare every chest relic with inventory art, including clipping and shuffled symbol order.
const Chest = preload("res://scripts/rewards/reward_chest.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Glow = preload("res://scripts/shared/item_glow.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func viewport_for_icons() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,ceil(Paint.Catalog.ITEMS.size()/8.0)*80)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func run() -> void:
	var actual := viewport_for_icons()
	var reference := viewport_for_icons()
	var chest = Chest.new()
	actual.add_child(chest); chest.set_process(false); chest.show()
	var expected := Node2D.new()
	expected.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reference.add_child(expected)
	# The renderer must use each symbol's ID, even when symbol order is entirely different.
	chest.symbols.reverse()
	var ids: Array = Paint.Catalog.ITEMS.keys()
	chest.draw.connect(func():
		for i in range(ids.size()):
			var rect := Rect2(Vector2(i%8*80+8,i/8*80+8),Vector2.ONE*64)
			var clip := rect.grow(-12) if i%2 else Rect2()
			var tint := Color(1,1,1,0.55 if i%3 else 1.0)
			var index: int = chest.symbols.find_custom(func(item): return item.get("relic_id","") == ids[i])
			chest._paint_symbol(index,rect,clip,tint))
	expected.draw.connect(func():
		for i in range(ids.size()):
			var rect := Rect2(Vector2(i%8*80+8,i/8*80+8),Vector2.ONE*64)
			var clip := rect.grow(-12) if i%2 else Rect2()
			var tint := Color(1,1,1,0.55 if i%3 else 1.0)
			Glow.paint(expected,rect.get_center(),rect.size.x*0.49,Paint.Catalog.rarity_color(ids[i]),clip,tint.a)
			Paint.paint(expected,ids[i],rect.get_center(),26,false,{},clip,tint))
	chest.queue_redraw(); expected.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	var image: Image = actual.get_texture().get_image()
	var comparison: Image = reference.get_texture().get_image()
	if image.get_data() != comparison.get_data(): failures += 1; push_error("Chest icons differ from inventory art")
	DirAccess.make_dir_recursive_absolute("res://test-output/chest-icons-20261025")
	image.save_png("res://test-output/chest-icons-20261025/chest.png")
	comparison.save_png("res://test-output/chest-icons-20261025/inventory.png")
	print("Chest artwork: %d item identities, clipping and tint; %d failures" % [ids.size(),failures])
	quit(1 if failures else 0)
