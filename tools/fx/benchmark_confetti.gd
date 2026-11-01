extends SceneTree
## Compare identical celebration workloads without loading or changing campaign saves.
const Original = preload("res://tools/fx/confetti_source.gd")
const Baked = preload("res://scripts/rewards/chest_confetti.gd")
var effect
var samples: Array[float] = []
var canvas: Node2D

func _initialize() -> void: call_deferred("run")

## Measure script-side update/draw submission separately from overall game frame rate.
func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Use a graphics renderer for the confetti benchmark"); quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.content_scale_size = Vector2i(804,1748)
	root.size = Vector2i(402,874)
	canvas = Node2D.new()
	root.add_child(canvas)
	canvas.draw.connect(func():
		var begin := Time.get_ticks_usec()
		effect.advance(1.0/120.0)
		effect.paint(canvas)
		samples.append((Time.get_ticks_usec()-begin)/1000.0))
	for busy in [false,true]:
		for baked in [false,true]:
			effect = Baked.new() if baked else Original.new()
			effect.rng.seed = 7391
			effect.entrance(Vector2(804,1748),false)
			if busy:
				for i in range(8): effect.bloom(Vector2(804,1748),false)
			samples.clear()
			for i in range(240):
				canvas.queue_redraw()
				await process_frame
				RenderingServer.force_draw()
			var trimmed: Array[float] = samples.slice(20)
			trimmed.sort()
			var sum := 0.0
			for value in trimmed: sum += value
			print("%s %s: %.3f ms mean / %.3f ms p95 update+draw submission" % ["baked" if baked else "original","8 taps" if busy else "entrance",sum/trimmed.size(),trimmed[int(trimmed.size()*0.95)]])
	print("Preloaded texture memory: %.1f MiB" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0))
	canvas.queue_free(); await process_frame
	quit()
