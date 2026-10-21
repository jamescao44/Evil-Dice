extends CanvasLayer
## Render the whole game above screen resolution without changing layout or input coordinates.
const RENDER_SCALE := 1.5
var fps_label: Label
var next_sample_ms := 0

## Configure either layout; the global transform also keeps native input correctly mapped.
static func configure(window: Window, design_size: Vector2i) -> void:
	window.set_meta("design_size", design_size)
	refresh_resolution(window)

## Recalculate the offscreen buffer after resizing, rotating or changing scenes.
static func refresh_resolution(window: Window) -> void:
	if window.get_meta("updating_resolution", false): return
	window.set_meta("updating_resolution", true)
	var design: Vector2i = window.get_meta("design_size", Vector2i(1280, 800))
	var fit := minf(float(window.size.x) / design.x, float(window.size.y) / design.y)
	var scale_factor := maxf(1.0, fit * RENDER_SCALE)
	var resolution := Vector2i(Vector2(design) * scale_factor)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = resolution
	window.global_canvas_transform = Transform2D().scaled(Vector2(resolution) / Vector2(design))
	window.set_meta("updating_resolution", false)

## Keep the FPS overlay above menus without intercepting clicks or touches.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	fps_label = Label.new()
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	fps_label.add_theme_constant_override("outline_size", 5)
	add_child(fps_label)
	get_window().size_changed.connect(_resize)
	_resize()

## Preserve the chosen design size while the actual window changes.
func _resize() -> void:
	refresh_resolution(get_window())
	var design: Vector2i = get_window().get_meta("design_size", Vector2i(1280, 800))
	var portrait := design.y > design.x
	fps_label.add_theme_font_size_override("font_size", 26 if portrait else 18)
	fps_label.position = Vector2(20, design.y - 62) if portrait else Vector2(12, design.y - 32)

## Sample Godot's FPS counter in real time, including during pauses and kill slow motion.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < next_sample_ms: return
	next_sample_ms = now + 250
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
