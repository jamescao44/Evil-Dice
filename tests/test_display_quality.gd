extends SceneTree
const Quality = preload("res://scripts/shared/display_quality.gd")
const Home = preload("res://scripts/home/home.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

## Fail if higher rendering resolution changes presentation or real window input.
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Exercise both layouts at multiple screen densities and through scene changes.
func run() -> void:
	for portrait in [true, false]:
		var home = Home.new()
		home.portrait = portrait
		root.add_child(home)
		var design := Vector2i(804,1748) if portrait else Vector2i(1280,800)
		for density in [0.5, 1.0, 1.5]:
			root.size = Vector2i(Vector2(design) * density)
			Quality.configure(root, design)
			await process_frame
			var fit := minf(float(root.size.x) / design.x, float(root.size.y) / design.y)
			var expected := Vector2i(Vector2(design) * maxf(1.0, fit * 1.5))
			check(root.content_scale_size == expected, "Render buffer increases with screen density")
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.pressed = true
			tap.position = root.get_final_transform() * home.tab_rect(0).get_center()
			root.push_input(tap, false)
			tap.pressed = false
			root.push_input(tap, false)
			check(home.page == 0, "Window-space click reaches the same logical tab")
			var touch := InputEventScreenTouch.new()
			touch.position = root.get_final_transform() * home.tab_rect(2).get_center()
			touch.pressed = true
			root.push_input(touch, false)
			touch.pressed = false
			root.push_input(touch, false)
			check(home.page == 2, "Window-space touch reaches the same logical tab")
			var overlay = root.get_node("DisplayQuality")
			overlay.next_sample_ms = 0
			overlay._process(0)
			check(overlay.fps_label.position.y > design.y - 70, "FPS stays at bottom left")
			check(overlay.fps_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "FPS cannot block controls")
			if DisplayServer.get_name() != "headless":
				await process_frame
				RenderingServer.force_draw()
				check(root.get_texture().get_size() == Vector2(expected), "Actual GPU buffer uses increased resolution")
		home.queue_free()
		await process_frame
	print("Display quality: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
