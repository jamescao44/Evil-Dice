extends SceneTree
## Renderer round-trip: translucent orange must not darken a second time after baking.
const BakeImage = preload("res://tools/fx/bake_image.gd")
const OPACITY := 0.85
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Color round-trip needs a renderer"); quit(1); return
	var colors := [Color(1,0.5,0.05,1),Color(1,0.5,0.05,0.5),Color(1,0.5,0.05,0.1)]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(60,20); viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var source := Node2D.new(); viewport.add_child(source)
	source.draw.connect(func():
		for i in range(colors.size()): source.draw_rect(Rect2(i*20,0,20,20),colors[i]))
	await process_frame; RenderingServer.force_draw()
	var capture: Image = viewport.get_texture().get_image()
	var normalized := BakeImage.straight_alpha(capture)
	for i in range(3):
		var pixel: Color = normalized.get_pixel(i*20+10,10)
		check(pixel.r > 0.98 and absf(pixel.g-colors[i].g) < 0.025,"Bake retains orange RGB at each opacity")
		check(absf(pixel.a-colors[i].a) < 0.005,"Bake preserves the original transparency")
	var texture := ImageTexture.create_from_image(normalized)
	var raw_texture := ImageTexture.create_from_image(capture)
	viewport.size = Vector2i(180,60)
	source.queue_free(); await process_frame
	var replay := Node2D.new(); viewport.add_child(replay)
	var backgrounds := [Color("11131d"),Color("96753b"),Color("d6d0bb")]
	replay.draw.connect(func():
		for row in range(3):
			replay.draw_rect(Rect2(0,row*20,180,20),backgrounds[row])
			for i in range(3): replay.draw_rect(Rect2(i*20,row*20,20,20),Color(colors[i],colors[i].a*OPACITY))
			replay.draw_texture(texture,Vector2(60,row*20),Color(1,1,1,OPACITY))
			replay.draw_texture(raw_texture,Vector2(120,row*20),Color(1,1,1,OPACITY)))
	await process_frame; RenderingServer.force_draw()
	var result: Image = viewport.get_texture().get_image()
	for row in range(3):
		for i in range(3):
			var direct: Color = result.get_pixel(i*20+10,row*20+10)
			var baked: Color = result.get_pixel(i*20+70,row*20+10)
			check(absf(direct.r-baked.r) < 0.012 and absf(direct.g-baked.g) < 0.012 and absf(direct.b-baked.b) < 0.012,"Replayed colors match direct drawing over dark, battlefield and light backgrounds")
	result.save_png("res://test-output/particle-color-roundtrip.png")
	viewport.queue_free(); await process_frame
	print("Particle bake color: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
