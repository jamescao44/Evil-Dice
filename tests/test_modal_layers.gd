extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
## Render regression: changing dice/held sprites cannot change modal-page pixels.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func capture() -> Image:
	await process_frame
	RenderingServer.force_draw()
	return root.get_texture().get_image()

func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.set_process_input(false)
	g._restart(Waves.COUNT)
	g.touch_position = Vector2(-100,-100)
	g.active_touch = 0
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,1748),Vector2(0,1748)])
	marker.color = Color.MAGENTA
	marker.z_index = g.HELD_ITEM_Z
	marker.hide()
	g.add_child(marker)
	for mode in ["menu", "debug", "help"]:
		g.menu_open = mode == "menu"
		g.debug_open = mode == "debug"
		g.guide = mode == "help"
		g.debug_wave_input.text = "10"
		g.debug_wave_input.release_focus()
		marker.hide()
		for die in g.dice: die.face = 1
		g._process(0)
		check(g.menu_canvas.visible and g.menu_canvas.z_index > marker.z_index,mode+" covers held sprites")
		check(g.dice.all(func(d): return d.visible),"Dice stay present beneath the modal")
		check(g.debug_wave_input.is_visible_in_tree() == (mode == "debug"),"Wave field only appears in debug")
		if DisplayServer.get_name() != "headless":
			var before: Image = await capture()
			marker.show()
			for die in g.dice:
				die.face = 6
				die.queue_redraw()
			var after: Image = await capture()
			check(before.get_data() == after.get_data(),mode+" fully occludes changing dice and foreground sprites")
			if "--capture" in OS.get_cmdline_user_args():
				after.save_png("res://test-output/layers-"+mode+("-portrait" if portrait else "-landscape")+".png")
	marker.hide()
	g.guide = false
	g.menu_open = true
	g._handle_click(g.DEBUG_RECT.get_center())
	g._process(0)
	check(g.debug_wave_input.is_visible_in_tree(),"Opening debug exposes its interactive field")
	g.debug_wave_input.text = "4"
	g.debug_wave_input.text_submitted.emit("4")
	g._process(0)
	check(g.model.stage == 3 and not g.menu_canvas.visible,"Submitting the modal field loads the wave and restores the battle")
	g.queue_free()
	await process_frame

func run() -> void:
	await layout(false)
	await layout(true)
	print("Modal layers: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
