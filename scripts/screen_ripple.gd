extends CanvasLayer
## Capture the finished battle AND HUD before applying the ultimate shockwave.
const RippleShader = preload("res://scripts/screen_ripple.gdshader")
const DURATION := 1.15
var battle
var age: float = DURATION
var origin := Vector2.ZERO
var capture: BackBufferCopy
var surface: ColorRect
var ripple_material: ShaderMaterial

func _ready() -> void:
	layer = 128
	capture = BackBufferCopy.new()
	capture.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(capture)
	surface = ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripple_material = ShaderMaterial.new()
	ripple_material.shader = RippleShader
	surface.material = ripple_material
	surface.hide()
	add_child(surface)

func trigger(at: Vector2) -> void:
	origin = at
	age = 0
	_update_surface()

func clear() -> void:
	age = DURATION
	if is_instance_valid(surface): surface.hide()
	if is_instance_valid(capture): capture.copy_mode = BackBufferCopy.COPY_MODE_DISABLED

func _process(delta: float) -> void:
	if age >= DURATION: return
	if not battle._menus_open() and battle.inspecting_enemy < 0:
		age = minf(DURATION, age + delta)
	_update_surface()

func _update_surface() -> void:
	var active: bool = age < DURATION and not battle._menus_open() and battle.inspecting_enemy < 0
	surface.visible = active
	capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if active else BackBufferCopy.COPY_MODE_DISABLED
	if not active: return
	var size: Vector2 = get_viewport().get_visible_rect().size
	surface.size = size
	# Both the sampled image and the impact follow the battle's camera shake.
	var screen_origin: Vector2 = battle.get_global_transform_with_canvas() * origin
	ripple_material.set_shader_parameter("origin", screen_origin / size)
	ripple_material.set_shader_parameter("canvas_size", size)
	ripple_material.set_shader_parameter("progress", age / DURATION)
	ripple_material.set_shader_parameter("strength", 0.0 if battle.reduced else 16.0)
	ripple_material.set_shader_parameter("glow", 0.04 if battle.reduced else 0.13)
