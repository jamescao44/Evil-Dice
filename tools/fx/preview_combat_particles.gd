extends SceneTree
## Renderer-only visual/seam checks and CPU submission benchmark; never loads saves.
const Source = preload("res://tools/fx/combat_particle_source.gd")
const Baked = preload("res://scripts/effects/baked_particles.gd")
const Emitter = preload("res://scripts/effects/baked_emitter.gd")
const Player = preload("res://scripts/player/player_sprite.gd")
const Storm = preload("res://scripts/effects/fire_storm.gd")
const Beam = preload("res://scripts/effects/brimstone.gd")
var clock := 0.0
var native := false
var samples: Array[float] = []
var sources: Dictionary = {}
var storm: Dictionary
var beam: Dictionary
var rng := RandomNumberGenerator.new()
var canvas: Node2D
var failures := 0

func _initialize() -> void: call_deferred("run")

## Compare equal steady-state particle workloads, including multiple overlapping packets.
func paint_bench() -> void:
	var begin := Time.get_ticks_usec()
	for target in range(6):
		var at := Vector2(100+target*175,350)
		canvas.draw_set_transform(at)
		for packet in range(3):
			var age: float = 0.1+packet*0.35+fmod(clock,0.35)
			if native: sources["storm_%d" % packet].paint(canvas,age)
			else: Baked.paint(canvas,"storm_%d" % packet,age)
	canvas.draw_set_transform(Vector2(500,700))
	for packet in range(4):
		var age: float = 0.1+packet*0.4+fmod(clock,0.4)
		if native: sources["beam_%d" % (packet%2)].paint(canvas,age)
		else: Baked.paint(canvas,"beam_%d" % (packet%2),age)
	canvas.draw_set_transform(Vector2.ZERO)
	samples.append((Time.get_ticks_usec()-begin)/1000.0)

## Show the exact in-game layers at useful sizes, with labels kept outside the art.
func paint_preview() -> void:
	canvas.draw_rect(Rect2(0,0,1100,800),Color("11131d"))
	var font := ThemeDB.fallback_font
	canvas.draw_string(font,Vector2(30,35),"Baked combat particles — full / reduced",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	for i in range(2):
		var reduced: bool = i == 1
		var x: float = 40+i*540
		canvas.draw_string(font,Vector2(x,65),"Reduced effects" if reduced else "Full effects",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffc561"))
		Player.paint_actor(canvas,Rect2(x+100,100,220,220),1,clock,Color.WHITE,reduced)
		canvas.draw_set_transform(Vector2(x+300,480))
		Storm.paint(canvas,storm,0,reduced)
		canvas.draw_set_transform(Vector2.ZERO)
		var display: Dictionary = beam.duplicate()
		display.brimstone_anchor = Vector2(x+100,765)
		display.brimstone_side = 350.0
		Beam.paint(canvas,display,reduced)
		Baked.burst(canvas,"fire_burst",Vector2(x+380,650),0.3,1.0,reduced)

## A loop's exact endpoint must render identically to its beginning, before compression.
func check_seams() -> void:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true; viewport.size = Vector2i(200,200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var node := Node2D.new(); viewport.add_child(node); node.position = Vector2(100,100)
	var sample = Source.new()
	var sample_time := [0.0]
	node.draw.connect(func(): sample.paint(node,sample_time[0]))
	for spec in Source.recipes():
		if spec.kind not in ["orbit","outward"]: continue
		sample.prepare(spec)
		var images: Array[Image] = []
		for t in [0.0,spec.duration-1.0/60,spec.duration,spec.duration+1.0/60]:
			sample_time[0] = t; node.queue_redraw()
			await process_frame; RenderingServer.force_draw()
			images.append(viewport.get_texture().get_image())
		var mismatch := 0
		for y in range(200):
			for x in range(200):
				if not images[0].get_pixel(x,y).is_equal_approx(images[2].get_pixel(x,y)): mismatch += 1
		print("%s loop seam: %d / 40000 pixels differ at exact restart" % [spec.name,mismatch])
		if mismatch > 8: failures += 1
		for i in range(images.size()): images[i].save_png("res://test-output/baked-particles/%s-seam-%d.png" % [spec.name,i])
	viewport.queue_free(); await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Preview requires a renderer"); quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 0
	root.size = Vector2i(1100,800); root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute("res://test-output/baked-particles")
	for spec in Source.recipes():
		var source = Source.new(); source.prepare(spec); sources[spec.name] = source
	await check_seams()
	canvas = Node2D.new(); root.add_child(canvas)
	canvas.draw.connect(paint_bench)
	for original in [true,false]:
		native = original; samples.clear()
		for frame in range(180):
			clock = frame/120.0; canvas.queue_redraw()
			await process_frame; RenderingServer.force_draw()
		var values: Array[float] = samples.slice(20); values.sort()
		var sum := 0.0
		for value in values: sum += value
		print("%s particle draw submission: %.3f ms mean / %.3f ms p95" % ["procedural" if native else "baked",sum/values.size(),values[floori(values.size()*0.95)]])
	canvas.draw.disconnect(paint_bench); canvas.draw.connect(paint_preview)
	storm = {"targets":[Vector2.ZERO],"hold_damage":true}
	Storm.prepare(storm,rng); Storm.begin_damage(storm)
	beam = {"world_targets":[Vector2.ZERO],"hold_damage":true}
	Beam.prepare(beam,false,rng); Beam.begin_damage(beam)
	for frame in range(120):
		clock = 3.0+frame/60.0
		Storm.advance(storm,1.0/60); Beam.advance(beam,1.0/60)
		canvas.queue_redraw(); await process_frame; RenderingServer.force_draw()
		if frame == 70: root.get_texture().get_image().save_png("res://test-output/baked-particles/preview.png")
	print("Preloaded textures: %.1f MiB (whole preview, not incremental)" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0))
	canvas.queue_free(); await process_frame
	quit(1 if failures else 0)
