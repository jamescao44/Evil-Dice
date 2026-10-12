extends Node2D

signal home_requested
var home_enabled: bool = false
var selected_ancient_id: String = "horror"
var selected_dice_id: String = "bone"

const HELD_ITEM_Z := 400
const MENU_Z := 500
const Rules = preload("res://scripts/battle_rules.gd")
const Run = preload("res://scripts/run_rules.gd")
const SkillBubble = preload("res://scripts/skill_bubble.gd")
const ScreenRipple = preload("res://scripts/screen_ripple.gd")
var screen_ripple: CanvasLayer
const RelicUI = preload("res://scripts/relic_ui.gd")
var relic_ui: Node2D
const TarotUI = preload("res://scripts/tarot_ui.gd")
var tarot_ui: Node2D
const TarotCast = preload("res://scripts/tarot_cast.gd")
var tarot_cast: Node2D
var dice_group: Node2D
const DamageFeedback = preload("res://scripts/damage_feedback.gd")
var damage_feedback: Node2D
var status_layout_key: String = ""
var status_layout_points: Array = []
const Die = preload("res://scripts/die.gd")
const Effects = preload("res://scripts/effects.gd")
const Pixel = preload("res://scripts/pixel_paint.gd")
const City = preload("res://scripts/city_paint.gd")
const CityLife = preload("res://scripts/city_life.gd")
const ThrowMeter = preload("res://scripts/throw_meter.gd")
const ChargeAudio = preload("res://scripts/charge_audio.gd")
const RewardChest = preload("res://scripts/reward_chest.gd")
const RewardIcons = preload("res://scripts/reward_icons.gd")
const Rewards = preload("res://scripts/reward_catalog.gd")
const Statuses = preload("res://scripts/status_catalog.gd")
const Status = preload("res://scripts/status_effect.gd")
const StatusPaint = preload("res://scripts/status_paint.gd")
const StatusOverlay = preload("res://scripts/status_overlay.gd")
const EnemyInspection = preload("res://scripts/enemy_inspection.gd")
const INK := Color("171b1a")
const PANEL := Color("30352c")
const EDGE := Color("776448")
const CREAM := Color("eee0b9")
const MUTED := Color("aca486")
const TEAL := Color("aed085")
const GOLD := Color("dfb866")
const PURPLE := Color("c5a4de")
const RED := Color("e99b81")
# Layout geometry is instance-local; the portrait scene overrides it before setup.
var ARENA := Rect2(24, 80, 1232, 372)
var DICE_CENTER := Vector2(639, 640)
var DICE_RADIUS := 144.0
var DICE_POSITIONS := [Vector2(639, 570), Vector2(574, 675), Vector2(704, 675)]
var MENU_RECT := Rect2(1200, 24, 40, 34)
var MENU_CLOSE := Rect2(836, 148, 44, 40)
var MENU_RESUME := Rect2(400, 548, 480, 72)
var GUIDE_RECT := Rect2(400, 374, 480, 60)
var AUDIO_RECT := Rect2(1146, 24, 40, 34)
var FX_RECT := Rect2(400, 296, 480, 60)
var SPEED_RECT := Rect2(1084, 24, 50, 34)
var DEBUG_RECT := Rect2(400, 218, 480, 60)
var LANGUAGE_RECT := Rect2(400, 480, 480, 50)
var REPLAY_RECT := Rect2(531, 433, 218, 53)
var GUIDE_CLOSE := Rect2(1132, 96, 40, 36)
var DEBUG_CLOSE := Rect2(1120, 121, 42, 36)
var DEBUG_REPEAT := Rect2(888, 176, 252, 40)
var DEBUG_PERFECT := Rect2(888, 228, 252, 40)
var DEBUG_WAVE_INPUT := Rect2(238, 626, 100, 40)
var DEBUG_WAVE_LOAD := Rect2(356, 626, 160, 40)
var DEBUG_TAROTS := Rect2(808,568,332,44)
var REWARD_CENTER := Vector2(195, 625)
var CITY_POINT := Vector2(925, 282)
const HORROR_SIZES := [224.0, 248.0, 260.0, 272.0, 280.0, 288.0, 296.0, 308.0, 320.0, 288.0]
const HUMAN_SIZES := [192.0, 96.0, 100.0, 84.0, 86.0, 76.0, 64.0, 54.0, 44.0, 20.0]
const PAVING_SIZES := [96.0, 56.0, 48.0, 40.0, 32.0, 28.0, 24.0, 20.0, 16.0, 16.0]
const SCENERY_SIZES := [128.0, 80.0, 64.0, 56.0, 48.0, 40.0, 32.0, 24.0, 16.0, 12.0]

var model = Run.new()
var pixel_font: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf").duplicate()
var description_font: FontFile = GameText.description_font()
var dice: Array = []
var fx: Node2D
var view_phase: String = "ready"
var result: MultiHitSkill = MultiHitSkill.new()
var last_result: MultiHitSkill = MultiHitSkill.new()
var ring_hover: float = 0
var art: Dictionary = {}
var clock_time: float = 0
var attack_target: int = -1
var muted: bool = false
var reduced: bool = false
var speed: float = 1.0
var guide: bool = false
var debug_open: bool = false
var menu_open: bool = false
var menu_canvas: Node2D
var debug_wave_input: LineEdit
var debug_wave_error: String = ""
var debug_choice: int = -1 # -1 natural; 0 all-different; 1..6 pairs; 7..12 triples.
var debug_repeat: bool = false
var debug_perfect: bool = false
var status_title: String = "READY"
var status_color: Color = TEAL
var active_human: int = -1
var hit_times: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var chest: Node2D
var fallen: Dictionary = {}
var city_corpses: Array = []
var city_life = CityLife.new()
var corpse_alpha: float = 1
var visual_stage: float = 0
var monster_side: float = 224
var background_offset: float = 0
var travel_progress: float = 0
var transition_tween: Tween
var run_id: int = 0
var shake: float = 0
var rattle_clock: float = 0
var start_snapshot: String = ""
var sounds: Dictionary = {}
var charge_audio: Node
var debug_rng = RandomNumberGenerator.new()
var active_touch: int = -1
var touch_position := Vector2.ZERO
var throw_meter = ThrowMeter.new()
var charge_stamp: int = 0
var throw_power: float = 0
var throw_perfect: bool = false
var power_lock_until: float = 0
var combo_flash_until: float = 0
var skill_bubble: Node2D
var saved_bubble: Node2D
var skill_source: String = "current"
var skill_return_phase: String = "skill"
var casting_source: String = ""
var skill_pressed: bool = false
var skill_dragging: bool = false
var skill_press_origin := Vector2.ZERO
var skill_pointer := Vector2.ZERO
var hover_target: int = -1
const ENEMY_HOLD_DELAY := 0.25
var pressed_enemy: int = -1
var inspecting_enemy: int = -1
var enemy_hold_age: float = 0.0
var cinematic_remaining: float = 0
var cinematic_duration: float = 0
var cinematic_ultimate: bool = false
var cinematic_pause: float = 0
var cinematic_speed: float = 1
var cinematic_dim: float = 0
var cinematic_recovery: float = 0.25
const AUTO_CLAIM_DURATION := 2.4
const CHEST_NAMES := ["", "Common", "Rare", "Epic"]
var auto_claim_tier: int = 0
var auto_claim_remaining: float = 0
var auto_claim_notice: Node2D

func _ready() -> void:
	_configure_layout()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	GameText.prepare_font(pixel_font)
	pixel_font.oversampling = 1.0
	debug_rng.randomize()
	# Modal pages must cover every battle sprite and held item.
	menu_canvas = Node2D.new()
	menu_canvas.name = "MenuCanvas"
	menu_canvas.z_index = MENU_Z
	add_child(menu_canvas)
	menu_canvas.draw.connect(_draw_menu_canvas)
	_create_debug_wave_input()
	dice_group = Node2D.new()
	add_child(dice_group)
	for i in range(3):
		var die = Die.new()
		die.position = DICE_POSITIONS[i]
		die.face = i + 1
		dice_group.add_child(die)
		die.landed.connect(_die_landed.bind(i))
		dice.append(die)
	fx = Effects.new()
	fx.font = pixel_font
	add_child(fx)
	_configure_effects()
	skill_bubble = SkillBubble.new()
	skill_bubble.battle = self
	add_child(skill_bubble)
	saved_bubble = SkillBubble.new()
	saved_bubble.battle = self
	saved_bubble.stored = true
	add_child(saved_bubble)
	screen_ripple = ScreenRipple.new()
	screen_ripple.battle = self
	add_child(screen_ripple)
	relic_ui = RelicUI.new()
	relic_ui.battle = self
	add_child(relic_ui)
	model.relic_activated.connect(relic_ui.activate)
	damage_feedback = DamageFeedback.new()
	damage_feedback.battle = self
	add_child(damage_feedback)
	var status_overlay := StatusOverlay.new()
	status_overlay.battle = self
	add_child(status_overlay)
	var enemy_inspection := EnemyInspection.new()
	enemy_inspection.battle = self
	add_child(enemy_inspection)
	chest = RewardChest.new()
	add_child(chest)
	tarot_ui = TarotUI.new()
	tarot_ui.battle = self
	add_child(tarot_ui)
	tarot_cast = TarotCast.new()
	tarot_cast.battle = self
	add_child(tarot_cast)
	auto_claim_notice = Node2D.new()
	auto_claim_notice.z_index = 100
	add_child(auto_claim_notice)
	auto_claim_notice.draw.connect(_draw_auto_claim)
	chest.ticked.connect(func(): _sound("click_001", 0.9 + chest.elapsed * 0.08, -16))
	chest.opened.connect(func():
		_sound("book", 0.65, -10)
		_sound("crash", 1.25, -20)
		_sound("bell", 1.4, -15))
	chest.landed.connect(func(index):
		_sound("drop_001", 0.8, -9)
		_sound("pluck_001", 1.0 + index * 0.3, -10)
		_sound("bell", 1.0 + index * 0.2, -17))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			start_snapshot = arg.trim_prefix("--capture=")
	for key in ["eldritch", "vanguard", "archer", "mage", "civilian", "civilian_gray", "aristocrat", "floor0", "floor1", "floor2", "floor3", "stone", "arch", "column", "mangrove", "grass", "book", "shield", "attack", "heal", "feast", "crown", "fx"]:
		art[key] = load("res://assets/art/fantasy/" + key + ".png")
	for key in ["vanguard", "archer", "mage"]:
		var silhouette: Image = art[key].get_image()
		for y in range(silhouette.get_height()):
			for x in range(silhouette.get_width()):
				silhouette.set_pixel(x, y, Color(1, 1, 1, silhouette.get_pixel(x, y).a))
		art[key+"_glow"] = ImageTexture.create_from_image(silhouette)
	for key in ["hit", "crash", "rumble", "bell", "slash", "chop", "book"]:
		sounds[key] = load("res://assets/audio/combat/" + key + ".ogg")
	for key in ["click_001", "drop_001", "confirmation_002", "bong_001", "pluck_001"]:
		sounds[key] = load("res://assets/audio/" + key + ".ogg")
	for key in ["soft_sweep", "perfect"]:
		sounds[key] = load("res://assets/audio/" + key + ".wav")
	if AudioServer.get_bus_index("Combat") == -1:
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Combat")
		AudioServer.add_bus_effect(bus, AudioEffectLimiter.new())
	charge_audio = ChargeAudio.new()
	add_child(charge_audio)
	_start_round()
	if not start_snapshot.is_empty():
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(start_snapshot)
		get_tree().quit()

func _process(delta: float) -> void:
	_update_enemy_hold(delta)
	if not _menus_open() and inspecting_enemy < 0:
		cinematic_remaining = maxf(0, cinematic_remaining - delta)
		auto_claim_remaining = maxf(0, auto_claim_remaining - delta)
	var world_delta: float = delta * _world_time_scale()
	clock_time += world_delta
	_update_charge()
	shake = maxf(0, shake - delta * 24)
	var camera_offset := Vector2.ZERO if reduced else (Vector2(sin(clock_time * 67), cos(clock_time * 83)) * shake).snapped(Vector2.ONE * 2)
	get_viewport().canvas_transform = Transform2D(0, camera_offset)
	for i in range(hit_times.size()):
		hit_times[i] = maxf(0, hit_times[i] - delta * 2.8)
	for index in fallen:
		fallen[index] += delta
	var modal: bool = _menus_open()
	chest.paused = tarot_ui.ceremony.active()
	debug_wave_input.visible = debug_open
	menu_canvas.visible = menu_open or guide or debug_open
	menu_canvas.queue_redraw()
	auto_claim_notice.visible = not modal and view_phase == "over" and auto_claim_remaining > 0
	auto_claim_notice.queue_redraw()
	for die in dice:
		die.visible = true
		var brightness: float = 0.18 if modal else 0.38 if view_phase not in ["ready", "charging", "rolling"] else 1.0
		die.self_modulate = Color(brightness,brightness,brightness,0.18 if modal or view_phase == "over" else 1.0)
		die.set_process(not modal and not model.is_frozen())
		die.reduced = reduced
		die.playback_rate = _roll_speed() / 2.0 if model.is_city() else 1.0
	fx.visible = not modal
	fx.set_process(not modal)
	fx.time_factor = _world_time_scale()
	if model.is_city() and not modal and view_phase in ["ready", "charging", "rolling", "forming", "skill", "targeting", "resolving", "frozen"]:
		_show_events(model.tick_city(world_delta, delta))
		city_life.tick(world_delta, model.city_hp / float(Run.CITY_MAX_HP))
		if model.outcome() == "defeat" or view_phase != "resolving":
			_check_over()
	var mouse := _pointer_position()
	charge_audio.update(delta, view_phase == "charging" and not modal, throw_meter.sample().power, muted)
	if view_phase == "targeting": hover_target = _target_at(skill_pointer if skill_dragging else mouse)
	if view_phase == "charging" and not modal:
		rattle_clock -= delta
		if rattle_clock <= 0:
			var energy: float = throw_meter.sample().power
			rattle_clock = lerpf(0.19, 0.07, energy)
			_sound("click_001", lerpf(0.7, 1.5, energy), lerpf(-32, -23, energy))
	if view_phase == "rolling" and not modal and dice.any(func(die): return die.rolling):
		rattle_clock -= delta
		if rattle_clock <= 0:
			rattle_clock = 0.1 / _roll_speed()
			_sound("click_001", 0.8 + fmod(clock_time * 2, 0.6) + throw_power * 0.25, -27 + throw_power * 7)
	var in_ring: bool = _in_dice_range(mouse) and view_phase in ["ready", "charging"] and not modal
	ring_hover = move_toward(ring_hover, 1.0 if in_ring else 0.0, delta * 7)
	var interactive := in_ring or MENU_RECT.has_point(mouse) or AUDIO_RECT.has_point(mouse) or SPEED_RECT.has_point(mouse)
	if guide:
		interactive = GUIDE_CLOSE.has_point(mouse) or (home_enabled and _home_rect().has_point(mouse))
	elif debug_open:
		interactive = DEBUG_CLOSE.has_point(mouse) or DEBUG_REPEAT.has_point(mouse) or DEBUG_PERFECT.has_point(mouse) or DEBUG_WAVE_LOAD.has_point(mouse) or DEBUG_TAROTS.has_point(mouse)
		for i in range(-1, 13):
			interactive = interactive or _debug_option_rect(i).has_point(mouse)
	elif menu_open:
		interactive = [MENU_CLOSE, MENU_RESUME, DEBUG_RECT, FX_RECT, GUIDE_RECT, LANGUAGE_RECT].any(func(rect): return rect.has_point(mouse))
	elif view_phase == "over":
		interactive = interactive or REPLAY_RECT.has_point(mouse) or (home_enabled and _home_rect().has_point(mouse))
	if view_phase in ["skill", "targeting"]:
		interactive = interactive or _in_skill_bubble(mouse) or (view_phase == "targeting" and _target_at(mouse) != -1)
	interactive = interactive or (_can_use_saved() and _in_saved_slot(mouse))
	interactive = interactive or _chest_tier_at(mouse) > 0
	interactive = interactive or (_can_inspect_enemy() and _enemy_inspect_at(mouse) >= 0)
	interactive = interactive or (view_phase == "frozen" and not modal and (_ice_rect().has_point(mouse) or _player_ice_rect().has_point(mouse)))
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if interactive else Input.CURSOR_ARROW)
	queue_redraw()

func _exit_tree() -> void:
	get_viewport().canvas_transform = Transform2D.IDENTITY

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(tarot_ui): tarot_ui.cancel_gesture()
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(relic_ui): relic_ui.cancel_hold()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		active_touch = -1
		_cancel_charge()
		_cancel_targeting()
	if what == NOTIFICATION_APPLICATION_PAUSED:
		active_touch = -1
		_cancel_charge()
		_cancel_targeting()

func _configure_layout() -> void:
	pass

func _configure_effects() -> void:
	for die in dice:
		die.base_scale = 0.75
		die.scale = Vector2.ONE * die.base_scale

func _menus_open() -> bool:
	return menu_open or guide or debug_open or (is_instance_valid(tarot_ui) and tarot_ui.ceremony.active())

func _draw_menu_canvas() -> void:
	if guide: _draw_guide(menu_canvas)
	elif debug_open: _draw_debug(menu_canvas)
	elif menu_open: _draw_menu(menu_canvas)

func _create_debug_wave_input() -> void:
	debug_wave_input = LineEdit.new()
	debug_wave_input.position = DEBUG_WAVE_INPUT.position
	debug_wave_input.size = DEBUG_WAVE_INPUT.size
	debug_wave_input.z_index = 1
	debug_wave_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_wave_input.max_length = 2
	debug_wave_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	debug_wave_input.placeholder_text = "1-10"
	debug_wave_input.add_theme_font_override("font", preload("res://assets/fonts/Silkscreen-Regular.ttf"))
	debug_wave_input.add_theme_font_size_override("font_size", 28 if DEBUG_WAVE_INPUT.size.y > 50 else 22)
	debug_wave_input.add_theme_color_override("font_color", CREAM)
	debug_wave_input.add_theme_color_override("caret_color", GOLD)
	for style_name in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = INK
		style.border_color = GOLD if style_name == "focus" else EDGE
		style.set_border_width_all(3 if style_name == "focus" else 2)
		debug_wave_input.add_theme_stylebox_override(style_name, style)
	debug_wave_input.hide()
	menu_canvas.add_child(debug_wave_input)
	debug_wave_input.text_submitted.connect(_debug_load_wave)
	debug_wave_input.text_changed.connect(func(_value): debug_wave_error = "")

func _open_debug() -> void:
	menu_open = false
	debug_open = true
	debug_wave_error = ""
	debug_wave_input.text = str(model.stage + 1)
	debug_wave_input.show()

func _close_debug(to_menu: bool = true) -> void:
	debug_open = false
	menu_open = to_menu
	debug_wave_input.hide()
	debug_wave_input.release_focus()

func _debug_load_wave(value: String) -> void:
	if not debug_open: return
	var trimmed: String = value.strip_edges()
	if not trimmed.is_valid_int() or trimmed.to_int() < 1 or trimmed.to_int() > Run.WAVE_NAMES.size():
		debug_wave_error = "Enter a wave from 1 to 10."
		return
	_restart(trimmed.to_int())

func _debug_give_tarots() -> void:
	if not debug_open: return
	# Debug grants deliberately ignore ownership and Hanged Man's reward exclusions.
	for id in Run.Tarot.ITEMS: model.tarots.add(id)
	_sound("confirmation_002",1,-14)

func _pointer_position() -> Vector2:
	return touch_position if active_touch >= 0 else get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			touch_position = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_click(touch_position)
		elif not event.pressed and event.index == active_touch:
			touch_position = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_release(touch_position)
			active_touch = -1
		return
	if event is InputEventScreenDrag:
		if event.index == active_touch:
			touch_position = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_motion(touch_position)
		return
	if event is InputEventMouseMotion:
		if event.device != -1 and active_touch < 0:
			_handle_motion(get_global_transform_with_canvas().affine_inverse() * event.position)
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Touch is handled directly: ignore its synthesized mouse events.
	if event.device == -1 or active_touch >= 0:
		return
	var mouse: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event.pressed: _handle_click(mouse)
	else: _handle_release(mouse)

func _in_dice_range(mouse: Vector2) -> bool:
	return mouse.distance_squared_to(DICE_CENTER) <= DICE_RADIUS * DICE_RADIUS

func _handle_click(mouse: Vector2) -> void:
	if is_instance_valid(tarot_cast) and tarot_cast.click(mouse): return
	if is_instance_valid(tarot_ui) and tarot_ui.click(mouse): return
	if view_phase == "reward" and chest.can_skip() and chest.skip_rect().has_point(mouse):
		model.discard_unclaimed_rewards()
		chest.skip_remaining()
		relic_ui.reset()
		fx.skill.clear()
		return
	if is_instance_valid(relic_ui) and relic_ui.click(mouse): return
	if view_phase == "reward":
		_pick_reward(mouse)
		return
	_update_charge()
	if home_enabled and (guide or (view_phase == "over" and not _menus_open())) and _home_rect().has_point(mouse):
		_cancel_charge()
		home_requested.emit()
		return
	if guide:
		if GUIDE_CLOSE.has_point(mouse):
			guide = false
			menu_open = true
		return
	if debug_open:
		if DEBUG_CLOSE.has_point(mouse): _close_debug()
		elif DEBUG_REPEAT.has_point(mouse): debug_repeat = not debug_repeat
		elif DEBUG_PERFECT.has_point(mouse): debug_perfect = not debug_perfect
		elif DEBUG_TAROTS.has_point(mouse): _debug_give_tarots()
		elif DEBUG_WAVE_LOAD.has_point(mouse): _debug_load_wave(debug_wave_input.text)
		else:
			for i in range(-1, 13):
				if _debug_option_rect(i).has_point(mouse):
					debug_choice = i
					_close_debug(false)
					_sound("book", 1.4, -17)
		return
	if menu_open:
		if MENU_CLOSE.has_point(mouse) or MENU_RESUME.has_point(mouse): menu_open = false
		elif DEBUG_RECT.has_point(mouse): _open_debug()
		elif GUIDE_RECT.has_point(mouse):
			menu_open = false
			guide = true
			_sound("book", 1.0, -14)
		elif FX_RECT.has_point(mouse):
			reduced = not reduced
			fx.reduced = reduced
			if reduced: shake = 0
		else:
			for i in range(GameText.LANGUAGES.size()):
				if _language_rect(i).has_point(mouse): GameText.set_language(GameText.LANGUAGES[i])
		return
	if AUDIO_RECT.has_point(mouse):
		muted = not muted
		if muted:
			charge_audio.silence()
			for child in get_children():
				if child is AudioStreamPlayer: child.queue_free()
		return
	if view_phase in ["ready", "charging", "skill", "targeting", "frozen", "over"]:
		if MENU_RECT.has_point(mouse):
			_cancel_targeting()
			menu_open = true
			return
	var tier: int = _chest_tier_at(mouse)
	if tier > 0:
		_reward_sequence(tier)
		return
	if view_phase == "over":
		if REPLAY_RECT.has_point(mouse): _restart()
		return
	if SPEED_RECT.has_point(mouse) and not model.is_city():
		speed = 2.0 if speed == 1.0 else 1.0
		return
	if view_phase == "frozen":
		if _ice_rect().has_point(mouse) or _player_ice_rect().has_point(mouse): _hit_ice(mouse)
		return
	if _can_inspect_enemy() and not skill_pressed and (result.is_empty() or not _in_skill_bubble(mouse)) and not _in_saved_slot(mouse):
		var enemy: int = _enemy_inspect_at(mouse)
		if enemy >= 0:
			pressed_enemy = enemy
			enemy_hold_age = 0.0
			return
	if view_phase in ["skill", "targeting"] or (view_phase == "ready" and _can_use_saved() and _in_saved_slot(mouse)):
		_handle_skill_click(mouse)
		return
	if _in_dice_range(mouse):
		if view_phase == "ready": _start_charge()
		elif view_phase == "charging": _release_charge()

func _skill_radius() -> float:
	return 104.0 if fx.canvas_size.y > fx.canvas_size.x else 74.0

func _skill_reveal_point() -> Vector2:
	return Vector2(402, 668) if fx.canvas_size.y > fx.canvas_size.x else Vector2(640, 340)

func _skill_rest_point() -> Vector2:
	return Vector2(402, 1320) if fx.canvas_size.y > fx.canvas_size.x else Vector2(640, 440)

func _skill_center() -> Vector2:
	return skill_bubble.center_at() if is_instance_valid(skill_bubble) else _skill_rest_point()

func _in_skill_bubble(point: Vector2) -> bool:
	return point.distance_to(_skill_center()) <= _skill_radius() + 12

func _skill_needs_target(roll: MultiHitSkill = null) -> bool:
	if roll == null: roll = _source_roll(skill_source)
	return not roll.is_empty() and Rules.is_attack(roll) and not Rules.hits_all(roll) and not roll.random_target_per_use()

func _saved_slot_center() -> Vector2:
	return Vector2(676, 1272) if fx.canvas_size.y > fx.canvas_size.x else Vector2(834, 576)

func _saved_slot_radius() -> float:
	return 56.0 if fx.canvas_size.y > fx.canvas_size.x else 40.0

func _perfect_combo_center() -> Vector2:
	var saved: Vector2 = _saved_slot_center()
	return Vector2(2 * DICE_CENTER.x - saved.x, saved.y)

func _in_saved_slot(point: Vector2) -> bool:
	return point.distance_to(_saved_slot_center()) <= _saved_slot_radius()+12

func _can_use_saved() -> bool:
	if is_instance_valid(tarot_ui) and tarot_ui.inventory_visible(): return false
	return not model.saved_skill.is_empty() and view_phase in ["ready", "skill", "targeting"] and not _menus_open() and model.outcome().is_empty()

func _source_roll(source: String) -> MultiHitSkill:
	return model.saved_skill if source == "saved" else result

func _source_bubble(source: String) -> Node2D:
	return saved_bubble if source == "saved" else skill_bubble

func _sync_saved_bubble() -> void:
	if not is_instance_valid(saved_bubble): return
	if model.saved_skill.is_empty(): saved_bubble.clear()
	elif not saved_bubble.roll.same_as(model.saved_skill):
		saved_bubble.begin(model.saved_skill)
		saved_bubble.age = saved_bubble.formation

func _field_drop_valid(point: Vector2) -> bool:
	return ARENA.grow(-8).has_point(point)

func _skill_targets() -> Array:
	if model.is_city(): return [-2] if model.city_hp > 0 else []
	return model.living()

func _target_rect(target: int) -> Rect2:
	if target == -2:
		var size := Vector2(560, 360) if fx.canvas_size.y > fx.canvas_size.x else Vector2(530, 260)
		return Rect2(CITY_POINT-size/2, size)
	var side: float = _enemy_side()
	var minimum: float = 88 if fx.canvas_size.y > fx.canvas_size.x else 48
	return Rect2(_enemy_point(target)-Vector2(maxf(minimum,side*0.82),maxf(minimum,side+30))/2,Vector2(maxf(minimum,side*0.82),maxf(minimum,side+30)))

func _target_at(point: Vector2) -> int:
	var closest: int = -1
	var distance: float = INF
	for target in _skill_targets():
		var rect: Rect2 = _target_rect(target)
		var d: float = point.distance_squared_to(rect.get_center())
		if rect.has_point(point) and d < distance:
			closest = target
			distance = d
	return closest

func _can_inspect_enemy() -> bool:
	return not model.is_city() and not _menus_open() and view_phase in ["ready", "skill", "targeting"] and model.outcome().is_empty()

func _enemy_hold_rect(index: int) -> Rect2:
	return _target_rect(index).merge(_enemy_intent_rect(index))

func _enemy_inspect_at(point: Vector2) -> int:
	if model.is_city(): return -1
	var closest: int = -1
	var distance: float = INF
	for index in model.living():
		if _enemy_intent_data(index).is_empty(): continue
		var d: float = point.distance_squared_to(_enemy_point(index))
		if _enemy_hold_rect(index).has_point(point) and d < distance:
			closest = index
			distance = d
	return closest

func _update_enemy_hold(delta: float) -> void:
	if pressed_enemy < 0: return
	if not _can_inspect_enemy() or pressed_enemy >= model.enemies.size() or _enemy_intent_data(pressed_enemy).is_empty():
		_cancel_enemy_hold()
		return
	enemy_hold_age += delta
	if enemy_hold_age >= ENEMY_HOLD_DELAY: inspecting_enemy = pressed_enemy

func _cancel_enemy_hold() -> void:
	pressed_enemy = -1
	inspecting_enemy = -1
	enemy_hold_age = 0.0

func _handle_skill_click(point: Vector2) -> void:
	var source: String = "saved" if _in_saved_slot(point) and _can_use_saved() else "current" if not result.is_empty() and _in_skill_bubble(point) else ""
	if view_phase == "targeting" and skill_source == "saved" and source == "current": return
	if not source.is_empty():
		if view_phase == "targeting" and skill_source == source:
			_cancel_targeting()
			return
		if view_phase == "targeting": _cancel_targeting()
		skill_return_phase = view_phase
		skill_source = source
		view_phase = "targeting"
		status_title = "CHOOSE A FOE" if _skill_needs_target() else "DRAG TO CAST"
		skill_pressed = true
		skill_press_origin = point
		skill_pointer = point
		_sound("book", 1.3, -19)
	elif view_phase == "targeting" and _skill_needs_target():
		var target: int = _target_at(point)
		if target != -1: _activate_skill(target)
		else: _cancel_targeting()

func _handle_motion(point: Vector2) -> void:
	if is_instance_valid(tarot_cast) and tarot_cast.active(): return
	if is_instance_valid(tarot_ui) and tarot_ui.motion(point): return
	if is_instance_valid(relic_ui) and relic_ui.motion(point): return
	if pressed_enemy >= 0:
		if not _enemy_hold_rect(pressed_enemy).grow(12).has_point(point): _cancel_enemy_hold()
		return
	if view_phase != "targeting": return
	skill_pointer = point
	if skill_pressed and point.distance_to(skill_press_origin) > (14 if fx.canvas_size.y > fx.canvas_size.x else 8): skill_dragging = true
	hover_target = _target_at(point)

func _handle_release(point: Vector2) -> void:
	if is_instance_valid(tarot_cast) and tarot_cast.active(): return
	if is_instance_valid(tarot_ui) and tarot_ui.release(point): return
	if is_instance_valid(relic_ui) and relic_ui.release(point): return
	if pressed_enemy >= 0:
		var target: int = pressed_enemy
		var held: bool = inspecting_enemy >= 0
		_cancel_enemy_hold()
		if not held and view_phase == "targeting" and _skill_needs_target() and _enemy_inspect_at(point) == target:
			_activate_skill(target)
		return
	if not skill_pressed: return
	_handle_motion(point)
	var dragged: bool = skill_dragging
	var cast_point: Vector2 = _source_bubble(skill_source).display_center()
	skill_pressed = false
	skill_dragging = false
	if view_phase != "targeting": return
	if not dragged:
		if not _skill_needs_target(): _cancel_targeting()
		return
	if skill_source == "current" and _in_saved_slot(point):
		if model.saved_skill.is_empty(): _save_skill()
		else: _cancel_targeting()
		return
	var target: int = _target_at(point)
	if _skill_needs_target():
		if target != -1: _activate_skill(target, cast_point)
		else: _cancel_targeting()
	elif _field_drop_valid(point): _activate_skill(-1, cast_point)
	else: _cancel_targeting()

func _cancel_targeting() -> void:
	_cancel_enemy_hold()
	skill_pressed = false
	skill_dragging = false
	hover_target = -1
	if view_phase == "targeting":
		view_phase = skill_return_phase
		status_title = "SKILL READY" if view_phase == "skill" else "FEVER" if model.is_city() else "READY"
	skill_source = "current"

func _save_skill() -> void:
	if not model.save_pending_skill():
		_cancel_targeting()
		return
	_cancel_targeting()
	_clear_skill()
	result = MultiHitSkill.new()
	last_result = MultiHitSkill.new()
	fx.activate_circle(_saved_slot_center(), GOLD, _saved_slot_radius()+8, 0.6)
	_sound("book", 1.1, -14)
	view_phase = "resolving"
	status_title = "SAVED"
	if model.is_city():
		view_phase = "ready"
		status_title = "FEVER"
	else: await _enemy_phase()

func _activate_skill(target: int, cast_point: Vector2 = Vector2.INF) -> void:
	if view_phase not in ["skill", "targeting"] or _menus_open() or not model.outcome().is_empty(): return
	var source: String = skill_source
	var roll: MultiHitSkill = _source_roll(source)
	if roll.is_empty(): return
	if source == "current" and model.phase != "player": return
	if _skill_needs_target() and target not in _skill_targets(): return
	var bubble: Node2D = _source_bubble(source)
	if cast_point == Vector2.INF: cast_point = bubble.display_center()
	_cancel_targeting()
	if source == "saved" and not model.begin_saved_cast(): return
	casting_source = source
	bubble.lock_cast_position(cast_point)
	status_color = [CREAM, TEAL, PURPLE, GOLD][roll.kind]
	fx.burst(cast_point, status_color, 20, 150)
	fx.activate_circle(_player_point(), status_color, monster_side*0.4, 0.4)
	_sound("confirmation_002", 0.85, -18)
	_resolve_player(target, source)

func _begin_cinematic(ultimate: bool) -> void:
	cinematic_ultimate = ultimate
	cinematic_pause = 0
	cinematic_speed = 0.12 if ultimate else 0.25
	cinematic_dim = 0.58 if ultimate else 0.0
	cinematic_recovery = 0.25
	cinematic_duration = 1.65 if ultimate else 0.9
	cinematic_remaining = cinematic_duration
	fx.flash(Color.WHITE, 0.6 if ultimate else 0.42)

func _begin_cast_cinematic(kind: int) -> void:
	# Real-time anticipation stays perceptible at 2x fever speed, including each rapid cast.
	cinematic_ultimate = kind == Rules.Kind.ULTIMATE
	cinematic_pause = [0.06, 0.08, 0.10, SkillBubble.SLAM_IMPACT_TIME][kind]
	cinematic_speed = [0.5, 0.45, 0.3, 0.18][kind]
	cinematic_dim = [0.4, 0.44, 0.52, 0.62][kind]
	cinematic_recovery = 0.18
	cinematic_duration = cinematic_pause + [0.16, 0.20, 0.26, 0.44][kind] + cinematic_recovery
	cinematic_remaining = cinematic_duration
	fx.time_factor = 0

func _world_time_scale() -> float:
	if is_instance_valid(tarot_ui) and tarot_ui.ceremony.active(): return 0.0
	if inspecting_enemy >= 0: return 0.0
	if is_instance_valid(damage_feedback) and damage_feedback.building: return 0.0
	if cinematic_remaining <= 0: return 1.0
	if cinematic_duration-cinematic_remaining < cinematic_pause: return 0.0
	return lerpf(cinematic_speed, 1.0, 1.0-clampf(cinematic_remaining/cinematic_recovery,0,1))

func _cinematic_gloom() -> float:
	if cinematic_remaining <= 0: return 0.0
	return cinematic_dim * minf(1, cinematic_remaining/(0.4 if cinematic_pause == 0 else cinematic_recovery))

func _clear_skill() -> void:
	if is_instance_valid(damage_feedback): damage_feedback.clear()
	if is_instance_valid(screen_ripple): screen_ripple.clear()
	_cancel_targeting()
	cinematic_remaining = 0
	cinematic_ultimate = false
	cinematic_pause = 0
	cinematic_speed = 1
	cinematic_dim = 0
	if is_instance_valid(skill_bubble): skill_bubble.clear()
	casting_source = ""
	_sync_saved_bubble()
	if is_instance_valid(fx): fx.time_factor = 1.0

func _start_charge() -> void:
	if view_phase != "ready" or _menus_open() or not model.outcome().is_empty(): return
	throw_meter.reset(model.is_stunned())
	charge_stamp = Time.get_ticks_usec()
	power_lock_until = 0
	view_phase = "charging"
	status_title = "POWER"
	status_color = GOLD
	last_result = MultiHitSkill.new()
	rattle_clock = 0
	for die in dice: die.charge(0)

func _update_charge() -> void:
	var now: int = Time.get_ticks_usec()
	if view_phase == "charging" and not _menus_open():
		# Also sampled at click time, not rounded to the last rendered marker position.
		throw_meter.advance((now - charge_stamp) / 1000000.0)
		for die in dice: die.charge(throw_meter.sample().power)
	charge_stamp = now

func _release_charge() -> void:
	if view_phase != "charging" or _menus_open(): return
	_update_charge()
	if debug_perfect or model.forces_perfect():
		throw_meter.erratic = false
		throw_meter.elapsed = ThrowMeter.PERIOD / 4.0
	var stopped: Dictionary = throw_meter.sample()
	power_lock_until = clock_time + 0.65
	for die in dice: die.stop_charge()
	view_phase = "ready"
	_roll(stopped.power, stopped.perfect)

func _cancel_charge() -> void:
	if view_phase != "charging": return
	for die in dice: die.stop_charge()
	throw_meter.reset()
	power_lock_until = 0
	view_phase = "ready"
	status_title = "FEVER" if model.is_city() else "READY"
	status_color = GOLD if model.is_city() else TEAL

func _power_meter_visible() -> bool:
	return view_phase == "charging" or (clock_time < power_lock_until and view_phase == "rolling")

func _power_flash_strength() -> float:
	if view_phase != "rolling" or not throw_perfect: return 0.0
	var age: float = clock_time - (power_lock_until - 0.65)
	# One brief white flash on a successful stop, followed by a smooth fade.
	return clampf(1.0 - (age - 0.06) / 0.22, 0, 1)

func _draw_power_meter(rect: Rect2, text_size: int = 16) -> void:
	var stopped: Dictionary = throw_meter.sample()
	var unit: float = rect.size.x / ThrowMeter.WIDTH
	var flash: float = _power_flash_strength()
	_frame(rect.grow(4), PANEL, GOLD.lerp(Color.WHITE, flash))
	for x in range(0, ceili(rect.size.x), 4):
		var central: float = 1.0 - absf(float(x) / rect.size.x - 0.5) * 2
		draw_rect(Rect2(rect.position + Vector2(x, 0), Vector2(minf(4, rect.size.x - x), rect.size.y)), PURPLE.darkened(0.65).lerp(GOLD, central * central))
	var center: float = rect.get_center().x
	draw_rect(Rect2(center - ThrowMeter.perfect_tolerance_pixels() * unit, rect.position.y, 2 * ThrowMeter.perfect_tolerance_pixels() * unit, rect.size.y), CREAM)
	if flash > 0: draw_rect(rect, Color(1, 1, 1, flash))
	var marker: float = rect.position.x + stopped.position * rect.size.x
	draw_rect(Rect2(marker - unit * 5, rect.position.y - 6, unit * 10, rect.size.y + 12), INK)
	draw_rect(Rect2(marker - unit * 3, rect.position.y - 4, unit * 6, rect.size.y + 8), GOLD.lerp(Color.WHITE, flash))
	_center(Vector2(center, rect.position.y - 12), GameText.format("POWER %d%%", roundi(stopped.power * 100)), text_size, GOLD)

func _stage_size(sizes: Array) -> float:
	var stage: float = clampf(visual_stage / float(Run.WAVE_NAMES.size()-1) * (sizes.size()-1), 0, sizes.size()-1)
	var index: int = floori(stage)
	return lerpf(sizes[index], sizes[mini(index+1,sizes.size()-1)], stage-index)

func _enemy_side() -> float:
	return _stage_size(HUMAN_SIZES)

func _enemy_feet(index: int) -> Vector2:
	var count: int = model.enemies.size()
	if count == 1: return Vector2(856,414)
	var cols: int = ceili(count/2.0) if count > 5 else count
	var row: int = index / cols
	var row_count: int = mini(cols,count-row*cols)
	var spacing: float = clampf(_enemy_side()*1.6,92,128)
	return Vector2(824 + (index%cols-(row_count-1)/2.0)*spacing, (254 if count > 5 else 396) + row*160 + [0,-10,8,-5,4][index%cols])

func _enemy_point(index: int) -> Vector2:
	return _enemy_feet(index) - Vector2(0,_enemy_side()*0.48)

func _enemy_impact_point(index: int) -> Vector2:
	var point: Vector2 = _enemy_point(index)
	if model.is_enemy_alive(index): return point
	var fall: float = minf(1,fallen.get(index,0.0)/0.3)
	return point.lerp(_enemy_feet(index)-Vector2(0,_enemy_side()*0.08),fall)

func _player_feet() -> Vector2:
	return Vector2(259, 414)

func _player_point() -> Vector2:
	return Vector2(259, 414 - monster_side * 0.48)

func _city_gate_point() -> Vector2:
	return City.gate_point()

func _city_wall_point(section: float) -> Vector2:
	return City.wall_point(section)

func _roll_speed() -> float:
	return 2.0 if model.is_city() else speed

func _start_round() -> void:
	_clear_skill()
	_show_events(model.begin_round())
	result = MultiHitSkill.new()
	view_phase = "ready"
	status_title = "FEVER" if model.is_city() else "READY"
	status_color = GOLD if model.is_city() else TEAL
	active_human = -1
	attack_target = -1
	if model.phase == "frozen":
		view_phase = "frozen"
		status_title = "FROZEN"
		status_color = Statuses.ENTRIES[Status.FROZEN].color

func _ice_rect() -> Rect2:
	var radius: float = DICE_RADIUS+8
	return Rect2(DICE_CENTER-Vector2.ONE*radius,Vector2.ONE*radius*2)

func _player_ice_rect() -> Rect2:
	return Rect2(_player_feet()+Vector2(-monster_side*0.5,-monster_side*0.93),Vector2(monster_side,monster_side*0.95))

func _hit_ice(point: Vector2) -> void:
	if view_phase != "frozen" or _menus_open(): return
	var token: int = run_id
	var events: Array = model.break_ice()
	if events.is_empty(): return
	fx.burst(point,Color("b9f2ff"),12,140)
	_sound("crash",1.7,-21)
	if model.is_frozen(): return
	_show_events(events)
	view_phase = "resolving"
	if model.is_city():
		if not await _resolve_turn_end(token): return
		_start_round()
	else: await _enemy_phase()

func _debug_values() -> Array:
	if debug_choice < 0: return []
	if debug_choice == 0:
		var choices: Array = [1, 2, 3, 4, 5, 6]
		var values: Array = []
		for i in range(3):
			var at: int = debug_rng.randi_range(0, choices.size() - 1)
			values.append(choices.pop_at(at))
		return values
	if debug_choice <= 6:
		var other: int = debug_rng.randi_range(1, 5)
		if other >= debug_choice: other += 1
		var values: Array = [debug_choice, debug_choice, other]
		var slot: int = debug_rng.randi_range(0, 2)
		values[2] = values[slot]
		values[slot] = other
		return values
	var face: int = debug_choice - 6
	return [face, face, face]

func _roll(strength: float = 0.0, perfect: bool = false) -> void:
	if view_phase != "ready" or _menus_open() or not model.outcome().is_empty(): return
	var token: int = run_id
	if model.is_city() and model.phase == "round_end": _show_events(model.begin_round())
	if model.phase != "roll": return
	throw_power = 1.0 if debug_perfect or model.forces_perfect() else clampf(strength, 0, 1)
	throw_perfect = perfect or debug_perfect or model.forces_perfect()
	view_phase = "rolling"
	var forced: Array = _debug_values()
	result = model.roll(throw_power, throw_perfect) if forced.is_empty() else model.set_test_roll(forced, throw_perfect)
	if result.is_empty(): return
	throw_perfect = result.perfect
	combo_flash_until = clock_time + 0.45 if throw_perfect else 0.0
	if not debug_repeat:
		debug_choice = -1
	last_result = MultiHitSkill.new()
	status_title = "ROLLING"
	status_color = CREAM
	fx.activate_circle(DICE_CENTER, GOLD, DICE_RADIUS, 0.8 / _roll_speed())
	_sound("soft_sweep", 1.0, lerpf(-21, -8, throw_power))
	if throw_power > 0.7: _sound("rumble", 1.2, -24 + throw_power * 5)
	if throw_perfect:
		_sound("perfect", 1.0, -14)
		fx.reveal_perfect(DICE_CENTER - Vector2(0, DICE_RADIUS * 0.62))
		fx.burst(DICE_CENTER, GOLD, 35, 200)
		_sound("confirmation_002", 1.7, -10)
		_sound("bell", 1.8, -19)
	for i in range(3):
		dice[i].roll_to(result.dice[i], i, 2.0 if model.is_city() else speed, throw_power)
	while dice.any(func(die): return die.rolling):
		await get_tree().process_frame
		if not _valid_turn(token): return
	if not await _wait(0.12, token): return
	if model.perfect_relic_ready:
		_show_events(model.resolve_perfect_relic())
		_sync_corpses()
		fx.burst(_player_point(), Color("d9bfff"), 30, 180)
		_sound("bell", 1.3, -12)
		if not await _wait(0.25,token): return
		if _check_over(): return
	last_result = result.duplicate(true)
	var kind: int = result.kind
	status_color = [CREAM, TEAL, PURPLE, GOLD][kind]
	if kind != Rules.Kind.NORMAL:
		for die in dice:
			if die.face == result.face:
				die.celebrate(status_color, kind >= Rules.Kind.SPECIAL)
				fx.burst(die.position, status_color, 18 if kind == Rules.Kind.PAIR else 35, 150)
		var combo_word: String = "PAIR" if kind == Rules.Kind.PAIR else "666" if kind == Rules.Kind.ULTIMATE else "TRIPLE"
		status_title = combo_word
		fx.reveal_combo(combo_word, DICE_CENTER, status_color)
		fx.activate_circle(DICE_CENTER, status_color, DICE_RADIUS + 7, 0.9)
		if kind == Rules.Kind.PAIR:
			_sound("confirmation_002", 1.1, -12)
			if not await _wait(0.35, token): return
		else:
			_sound("bong_001", 0.8 if kind == Rules.Kind.SPECIAL else 0.55, -8)
			if not await _combo_chime(kind == Rules.Kind.ULTIMATE, token): return
			_begin_cinematic(kind == Rules.Kind.ULTIMATE)
	view_phase = "forming"
	last_result = MultiHitSkill.new()
	fx.skill.clear()
	skill_bubble.begin(result)
	_sound("bell", 1.2, -20)
	while skill_bubble.age < skill_bubble.formation:
		await get_tree().process_frame
		if not _valid_turn(token): return
	view_phase = "skill"
	status_title = "SKILL READY"
	if model.is_city():
		# City rolls cast as soon as their reveal finishes; menus still pause the action.
		while _menus_open():
			await get_tree().process_frame
			if not _valid_turn(token): return
		skill_source = "current"
		_activate_skill(-2)

func _combo_chime(ultimate: bool, token: int) -> bool:
	for pitch in [1.0, 1.25, 1.5, 2.0]:
		_sound("pluck_001", pitch * (0.75 if ultimate else 1.0), -14)
		if not await _wait(0.09, token): return false
	return true

func _skill_caption(roll: MultiHitSkill) -> Dictionary:
	var label: String = Rules.NORMAL_NAME
	var description: String = "attack"
	if roll.kind == Rules.Kind.PAIR:
		label = Rules.PAIR_NAMES[roll.face - 1]
		var spare_text: String = str(roll.spare * Rules.DAMAGE_PER_PIP) if roll.face in [1,4,5] else str(roll.spare)
		var template: String = ["attack x1.5 +%s", "regen 5 for %s turns", "DMG +0.5 for %s turns", "attack all +%s", "random attack +%s", "invincible for %s turns"][roll.face - 1]
		if model.is_city() and roll.face == 5: template = "city attack +%s"
		description = GameText.format(template,spare_text)
		if model.is_city() and roll.face == 6: description = GameText.format("invincible for %d seconds",roll.spare*2)
	elif roll.kind >= Rules.Kind.SPECIAL:
		label = Rules.SPECIAL_NAMES[roll.face - 1]
		description = ["instant kill", "full heal", "DMG +2.0 for 3 turns", "attack all x2", "random attack", ""][roll.face - 1]
		if model.is_city() and roll.face == 1: description = "attack x5"
	if model.is_city() and roll.kind >= Rules.Kind.SPECIAL and roll.face == 5: description = "city attack"
	var factor: float = model.tarot_effects.skill_factor(roll)
	if not Rules.is_attack(roll) and factor > 1:
		if roll.face == 2 and roll.kind == Rules.Kind.PAIR: description = GameText.format("regen %d for %d turns",[roundi(5*factor),roll.spare])
		elif roll.face == 3: description = GameText.format("DMG +%.1f for %d turns",[(0.5 if roll.kind == Rules.Kind.PAIR else 2.0)*factor,roll.spare if roll.kind == Rules.Kind.PAIR else 3])
	return {"name": label, "description": description}

func _die_landed(index: int) -> void:
	_sound("drop_001", 0.95 + index * 0.13 - throw_power * 0.25, -17 + throw_power * 7)
	fx.burst(dice[index].position + Vector2(0, 35), GOLD, roundi(12 + throw_power * 18), 90 + throw_power * 70)

func _resolve_player(target: int, source: String = "current") -> void:
	if model.phase != "player" or model.pending.is_empty() or view_phase == "resolving" or not model.outcome().is_empty(): return
	var token: int = run_id
	if not model.begin_player_cast(): return
	var roll: MultiHitSkill = model.pending.duplicate()
	var bubble: Node2D = _source_bubble(source)
	bubble.roll = roll.duplicate()
	view_phase = "resolving"
	var kind: int = roll.kind
	var attacking: bool = Rules.is_attack(roll)
	_begin_cast_cinematic(kind)
	status_title = "CASTING" if kind >= Rules.Kind.SPECIAL else "ATTACKING" if attacking else "BLESSED"
	# A cast starts consuming its visual use budget immediately; damage still
	# waits for the modifier buildup and impact animation below.
	bubble.consume_use()
	if attacking and not model.is_instant_kill(roll):
		damage_feedback.start(model.attack_damage_steps(roll))
		while damage_feedback.building:
			await get_tree().process_frame
			if not _valid_turn(token): return
	if kind == Rules.Kind.ULTIMATE:
		bubble.begin_slam()
		# Presentation time keeps the slam readable during fever and fast-forward.
		while bubble.slam_age < SkillBubble.SLAM_IMPACT_TIME:
			await get_tree().process_frame
			if not _valid_turn(token): return
		screen_ripple.trigger(bubble.cast_position)
		fx.ring(bubble.cast_position, GOLD, _skill_radius() * 2.0)
		fx.burst(bubble.cast_position, GOLD, 16 if reduced else 48, 240)
		shake = 0.0 if reduced else 14.0
		_sound("crash", 0.55, -12)
	var count: int = model.skill_use_count(roll)
	for impact in range(count):
		if attacking: damage_feedback.sync_value(model.cast_damage_multiplier(roll))
		if impact > 0: bubble.consume_use()
		if not attacking:
			fx.activate_circle(_player_point(), TEAL, monster_side * 0.45, 0.85)
			fx.burst(_player_point(), TEAL, 30)
			_sound("bell", 1.6, -16)
			if not await _wait(0.3, token): return
			_show_events(model.apply_player_step())
		else:
			if roll.random_target_per_use() or (not model.is_city() and target not in model.living()): target = model.player_target()
			attack_target = target
			var targets: Array = [CITY_POINT] if model.is_city() else []
			if not model.is_city():
				for hit in model.preview(roll, target): targets.append(_enemy_impact_point(hit.target))
			var face: int = roll.face if kind >= Rules.Kind.SPECIAL or kind == Rules.Kind.PAIR else 0
			var duration: float = 0.18 if count > 1 else 1.6 if kind == Rules.Kind.ULTIMATE else 0.7 if kind >= Rules.Kind.SPECIAL else 0.38
			fx.cast(face, _player_point(), targets, duration / _roll_speed())
			_sound("slash", 1.0 + impact * 0.08 if count > 1 else 0.8, -9)
			if kind >= Rules.Kind.SPECIAL and impact == 0: _sound("rumble", 0.5 if kind == Rules.Kind.ULTIMATE else 0.8, -12)
			if not await _wait(duration * 0.55, token): return
			if not model.outcome().is_empty(): return
			for point in targets:
				fx.burst(point, status_color, 32 if kind >= Rules.Kind.SPECIAL else 14, 205)
			if kind >= Rules.Kind.SPECIAL and impact == 0: fx.flash(status_color, 0.12)
			shake = (12.0 if kind >= Rules.Kind.SPECIAL else 3.0) if not reduced else 0.0
			_sound("crash" if kind == Rules.Kind.ULTIMATE else "hit", 0.65 + impact * 0.08 if kind >= Rules.Kind.SPECIAL else 1.0, -9)
			_show_events(model.apply_player_step(target))
			_sync_corpses()
		if model.phase != "executing": break
		if not await _wait(0.12, token): return
	damage_feedback.finish()
	bubble.dissolve()
	# The particle finish uses presentation time so it stays readable at fever speed.
	while bubble.dissolving and bubble.dissolve_age < bubble.DISSOLVE_TIME:
		await get_tree().process_frame
		if not _valid_turn(token): return
	if not await _wait(0.25 if kind == Rules.Kind.ULTIMATE else 0.05, token): return
	attack_target = -1
	if model.phase == "turn_end" and not await _resolve_turn_end(token): return
	if _check_over(): return
	bubble.clear()
	casting_source = ""
	if source == "saved":
		view_phase = "skill" if model.phase == "player" else "ready"
		status_title = "SKILL READY" if view_phase == "skill" else "FEVER" if model.is_city() else "READY"
		status_color = [CREAM, TEAL, PURPLE, GOLD][result.kind] if not result.is_empty() else GOLD if model.is_city() else TEAL
		return
	if model.phase == "roll":
		result = MultiHitSkill.new()
		view_phase = "ready"
		status_title = "EXTRA THROW"
	elif model.is_city():
		result = MultiHitSkill.new()
		view_phase = "ready"
		status_title = "FEVER"
	else:
		await _enemy_phase()

func _enemy_phase() -> void:
	var token: int = run_id
	status_color = RED
	for i in range(model.enemies.size()):
		if model.enemies[i].hp <= 0: continue
		active_human = i
		var human: Dictionary = model.enemies[i]
		status_title = "ENEMY TURN"
		if not await _wait(0.12, token): return
		if not human.canceled and model.status_count(Status.HIDDEN) == 0 and model.enemy_status_count(i, Status.FROZEN) == 0 and human.intent.type == "attack":
			fx.enemy_cast(human.role, _enemy_point(i), _player_point(), 0.22 / speed, human.intent.get("attribute", Status.Attribute.NONE))
			_sound("slash" if human.role != 2 else "bell", 1.4, -17)
			if not await _wait(0.18, token): return
		var events: Array = model.enemy_act(i)
		if not human.canceled and human.intent.type != "attack" and events.size() > 0:
			for event in events:
				if event.target >= 0: fx.activate_circle(_enemy_point(event.target), PURPLE if human.intent.type == "empower" else TEAL, maxf(12,_enemy_side()*0.22), 0.4)
			_sound("bell", 1.7, -20)
		_show_events(events)
		_sync_corpses()
		if not await _wait(0.24, token): return
		if _check_over(): return
	active_human = -1
	if not await _resolve_turn_end(token): return
	_start_round()

func _resolve_turn_end(token: int) -> bool:
	while model.phase in ["enemy", "turn_end"]:
		if not _valid_turn(token): return false
		var events: Array = model.end_round_step()
		# An incomplete enemy phase must return to its caller, never spin here.
		if model.phase == "enemy": return false
		_show_events(events)
		if not events.is_empty():
			status_title = "BURNING"
			if not await _wait(0.18, token): return false
		if _check_over(): return false
	return _valid_turn(token)

func _can_claim_chest() -> bool:
	if model.chest_tier() == 0 or _menus_open(): return false
	if view_phase == "over": return true
	# This also blocks claims between individual casts of a multi-use skill.
	return view_phase == "ready" and model.pending.is_empty() and skill_bubble.roll.is_empty()

func _pick_reward(point: Vector2) -> void:
	var index: int = chest.pickup_at(point)
	if index < 0: return
	if not _claim_chest_reward(index) and model.reward_item(index).has("relic_id"):
		relic_ui.chest_slot = index

func _claim_chest_reward(index: int, replace_index: int = -1, discard: bool = false) -> bool:
	if not discard and model.reward_item(index).get("id","") == "tarot": return tarot_ui.begin_reward("chest",index)
	var previous_ids: Array = model.relics.items.map(func(relic): return relic.id)
	var item: Dictionary = model.claim_reward(index,replace_index,discard)
	if item.is_empty(): return false
	chest.collected.append(index)
	if not discard: chest.celebrate(index)
	if not discard and item.has("relic_id"):
		var replacing: bool = relic_ui.chest_slot >= 0
		var origin: Vector2 = Vector2(fx.canvas_size.x/2,620 if relic_ui.portrait() else 280) if replacing else chest.reel_rect(index).get_center()
		relic_ui.collect(item.relic_id,origin,80 if replacing else chest.reel_rect(index).size.x*0.305,previous_ids)
	fx.reveal_skill(item.name, item.text, item.color)
	_sound("rumble" if item.id == "curse" else "confirmation_002", 0.65 if item.id == "curse" else 1.0, -12)
	return true

func _reward_sequence(tier: int = 0, automatic: bool = false, bonus: bool = false) -> void:
	if automatic:
		if view_phase != "over" or model.outcome() != "victory" or model.open_rewards.is_empty(): return
	elif bonus:
		if view_phase not in ["ready","skill"]: return
	elif not _can_claim_chest(): return
	var token: int = run_id
	var previous_phase: String = view_phase
	var previous_title: String = status_title
	var outcomes: Array = model.open_rewards.duplicate() if automatic else model.open_bonus_chest() if bonus else model.open_chest(tier)
	if outcomes.is_empty(): return
	view_phase = "reward"
	status_title = "TREASURE"
	fx.skill.clear()
	fx.floats.clear()
	fx.sigils.clear()
	# Banked treasure can only open between actions, including the ending screen.
	if not await _wait(0.38 * _roll_speed(), token): return
	fx.z_index = 90
	fx.flash(Color.WHITE, 0.65)
	_sound("bong_001", 0.7, -12)
	if not await _wait(0.18 * _roll_speed(), token): return
	var prizes: Array = []
	for slot in range(outcomes.size()): prizes.append(model.reward_item(slot))
	chest.start(outcomes, fx.canvas_size, pixel_font, reduced, prizes)
	_sound("rumble", 0.7, -18)
	while chest.active or not model.rewards_collected() or relic_ui.pickup.active or tarot_ui.ceremony.active():
		await get_tree().process_frame
		if not _valid_turn(token): return
	if not chest.skip_requested and not await _wait(1.65 * _roll_speed(), token): return
	model.close_chest()
	chest.cancel()
	fx.z_index = 0
	view_phase = previous_phase
	status_title = previous_title

func _sync_corpses() -> void:
	for i in range(model.enemies.size()):
		if model.enemies[i].hp <= 0 and not fallen.has(i):
			fallen[i] = 0.0
			fx.burst(_enemy_point(i), Color("b9857c"), 14, 80)
			_sound("chop", 0.7, -15)

func _check_over() -> bool:
	# Finish both sides' status ticks before treating a damage-over-time kill as
	# victory. Otherwise the relic screen can interrupt player burning midway.
	if model.phase == "turn_end" and model.hp > 0: return false
	var outcome: String = model.outcome()
	if outcome.is_empty(): return false
	if is_instance_valid(tarot_ui): tarot_ui.close_inventory()
	if view_phase in ["over", "reward", "relic_reward"]: return true
	_clear_skill()
	if outcome == "wave_clear":
		if view_phase not in ["feeding", "transition"]: _advance_wave()
		return true
	if outcome == "victory":
		_finish_victory(run_id)
		return true
	view_phase = "over"
	for die in dice: die.stop_charge()
	active_human = -1
	_sound("rumble", 0.5, -13)
	return true

func _offer_relics(token: int) -> bool:
	model.open_relic_offer()
	view_phase = "relic_reward"
	status_title = "CHOOSE ONE REWARD"
	relic_ui.reset()
	while not model.relic_offer_resolved or relic_ui.pickup.active or tarot_ui.ceremony.active():
		await get_tree().process_frame
		if not _valid_turn(token): return false
	_sound("book", 1.0, -12)
	return _valid_turn(token)

func _finish_victory(token: int) -> void:
	if not await _offer_relics(token): return
	view_phase = "over"
	for die in dice: die.stop_charge()
	active_human = -1
	auto_claim_tier = model.auto_claim_victory_chest()
	auto_claim_remaining = AUTO_CLAIM_DURATION if auto_claim_tier > 0 else 0.0
	fx.activate_circle(CITY_POINT, GOLD, 200, 1.5)
	fx.burst(CITY_POINT, GOLD, 120, 320)
	_sound("crash", 0.55, -8)
	_sound("bell", 0.65, -12)
	if auto_claim_tier > 0: _victory_rewards(token)

func _victory_rewards(token: int) -> void:
	# Let the success screen and claim notice land before opening the reels.
	while auto_claim_remaining > 0 or _menus_open():
		await get_tree().process_frame
		if token != run_id or not is_inside_tree() or view_phase != "over": return
	if token == run_id and is_inside_tree(): _reward_sequence(0, true)

func _advance_wave() -> void:
	var token: int = run_id
	if not await _offer_relics(token): return
	view_phase = "feeding"
	status_title = "FEEDING"
	status_color = RED
	active_human = -1
	_sync_corpses()
	if not await _wait(0.65, token): return
	for i in fallen:
		fx.feed(_enemy_feet(i) - Vector2(0,_enemy_side()*0.1), _player_point(), 0.85 / speed)
	fx.activate_circle(_player_point() + Vector2(0, 50), RED, 118, 1.2 / speed)
	_sound("rumble", 0.55, -10)
	transition_tween = create_tween()
	transition_tween.tween_property(self, "corpse_alpha", 0.0, 1.2 / speed)
	while transition_tween.is_running() and _valid_turn(token):
		await get_tree().process_frame
	if not _valid_turn(token): return
	if not model.advance_wave(): return
	fallen.clear()
	city_corpses.clear()
	city_life.clear()
	corpse_alpha = 1
	fx.floating(_player_point() - Vector2(0, 65), "+30 MAX HP", TEAL)
	fx.burst(_player_point(), RED, 42, 140)
	view_phase = "transition"
	status_title = "ADVANCING"
	travel_progress = 0
	transition_tween = create_tween().set_parallel(true)
	transition_tween.tween_property(self, "monster_side", HORROR_SIZES[model.stage], 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "visual_stage", float(model.stage), 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "background_offset", background_offset + 960, 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "travel_progress", 1.0, 1.65 / speed)
	while transition_tween.is_running() and _valid_turn(token):
		await get_tree().process_frame
	if not _valid_turn(token): return
	_start_round()
	fx.activate_circle(_player_point() + Vector2(0, 60), GOLD, 100, 0.7)

func _restart(wave_number: int = 1) -> void:
	run_id += 1
	if is_instance_valid(relic_ui): relic_ui.reset()
	if is_instance_valid(tarot_ui): tarot_ui.reset()
	if is_instance_valid(tarot_cast): tarot_cast.reset()
	_clear_skill()
	chest.cancel()
	auto_claim_tier = 0
	auto_claim_remaining = 0
	fx.z_index = 0
	if transition_tween and transition_tween.is_running(): transition_tween.kill()
	model.load_debug_wave(wave_number)
	fx.clear()
	last_result = MultiHitSkill.new()
	result = MultiHitSkill.new()
	fallen.clear()
	city_corpses.clear()
	city_life.clear()
	corpse_alpha = 1
	visual_stage = model.stage
	monster_side = HORROR_SIZES[model.stage]
	background_offset = model.stage * 960
	travel_progress = 0
	throw_meter.reset()
	throw_power = 0
	throw_perfect = false
	combo_flash_until = 0
	power_lock_until = 0
	guide = false
	menu_open = false
	active_touch = -1
	debug_open = false
	debug_choice = -1
	debug_repeat = false
	debug_wave_error = ""
	debug_wave_input.hide()
	debug_wave_input.release_focus()
	shake = 0
	get_viewport().canvas_transform = Transform2D.IDENTITY
	hit_times.fill(0.0)
	for i in range(3):
		dice[i].stop_charge()
		dice[i].rolling = false
		dice[i].position = DICE_POSITIONS[i]
		dice[i].rotation = 0
		dice[i].face = i + 1
		dice[i].glow = 0
		dice[i].marked = false
	_start_round()

static func _damage_popup(event: Dictionary) -> String:
	return "" if event.get("instant_kill",false) else "-%d" % event.get("display_amount",event.amount)

static func _event_font_size(event: Dictionary) -> int:
	return Effects.damage_font_size(event.get("display_amount",event.amount)) if event.type in ["damage","burn","shield_hit"] else Effects.FLOAT_FONT_SIZE

func _show_events(events: Array) -> void:
	var offsets: Dictionary = {}
	for event in events:
		var point: Vector2 = _player_point() if event.target == -1 else CITY_POINT if event.target == -2 else _enemy_point(event.target)
		if event.target >= 0 and event.get("corpse_hit",false): point = _enemy_impact_point(event.target)
		if event.type == "spawn":
			fx.burst(_city_gate_point(), GOLD, 10, 40)
			continue
		if event.type == "warning":
			fx.activate_circle(_city_wall_point(0) - Vector2(0,38), RED, 23, 0.8)
			continue
		if event.type == "volley":
			fx.enemy_cast(1, _city_wall_point(0) - Vector2(0,38), _player_point(), 0.35)
			_sound("slash", 0.65, -14)
			continue
		if event.type == "sweep":
			for i in range(int(event.get("first", 0)), int(event.get("first", 0)) + event.amount):
				city_corpses.append({"p": _troop_point(i), "role": i % 3})
				fx.burst(_troop_point(i), RED, 8, 70)
			while city_corpses.size() > 24: city_corpses.pop_front()
			continue
		if event.type == "shield_hit":
			fx.floating(point-Vector2(0,69), _damage_popup(event), PURPLE,_event_font_size(event))
			fx.floating(point-Vector2(0,41), event.text, PURPLE)
			fx.activate_circle(point, PURPLE, maxf(18,_enemy_side()*0.3), 0.3)
			_sound("bell", 0.7, -14)
			continue
		if event.type == "relic":
			fx.floating(point-Vector2(0,65),event.text,GOLD)
			fx.activate_circle(point,GOLD,55,0.6)
			continue
		if event.type in ["status", "skip", "burn"]:
			var tint: Color = Statuses.ENTRIES[Status.BURNING].color if event.type == "burn" else Statuses.ENTRIES[event.get("status", Status.FROZEN)].color
			var status_text: String = event.text
			if event.type == "burn": status_text = _damage_popup(event)
			elif event.has("status"): status_text = GameText.format("%s +%d",[GameText.text(Statuses.ENTRIES[event.status].name),event.amount])
			fx.floating(point-Vector2(0,45),status_text,tint,_event_font_size(event))
			if event.type == "burn":
				if event.target >= -1: hit_times[event.target+1] = 0.35
				fx.burst(point, tint, 3, 35)
			else: fx.activate_circle(point, tint, monster_side*0.42, 0.45)
			continue
		var color: Color = RED if event.type == "damage" else PURPLE if event.type == "cancel" else TEAL
		var label: String = "INVINCIBLE" if event.type == "immune" else _damage_popup(event) if event.type == "damage" else "+%d" % event.amount if event.type == "heal" else "DAZED" if event.type == "cancel" else "+ BOON"
		var offset: int = offsets.get(event.target, 0)
		if not label.is_empty():
			fx.floating(point - Vector2(0, 45 + offset), label, color,_event_font_size(event))
			offsets[event.target] = offset + _event_font_size(event)
		if event.type == "damage":
			if event.target >= -1: hit_times[event.target + 1] = 1.0
			if event.amount > 0 or event.get("corpse_hit",false):
				fx.slash(point, event.target == -2)
				if event.target == -1: _sound("hit", 0.8, -17)
				elif event.target == -2:
					fx.burst(CITY_POINT, GOLD, 16, 190)
					city_life.sync_destruction(model.city_hp / float(Run.CITY_MAX_HP))

func _valid_turn(token: int) -> bool:
	return token == run_id and is_inside_tree() and view_phase != "over"

func _wait(seconds: float, token: int = -1) -> bool:
	var remaining: float = seconds
	while remaining > 0:
		await get_tree().process_frame
		if token != -1 and not _valid_turn(token): return false
		if _menus_open(): continue
		remaining -= get_process_delta_time() * _roll_speed() * _world_time_scale()
	return token == -1 or _valid_turn(token)

func _sound(clip: String, pitch: float = 1.0, volume: float = -15.0) -> void:
	if muted or DisplayServer.get_name() == "headless" or not sounds.has(clip): return
	var voices: Array = get_children().filter(func(c): return c is AudioStreamPlayer)
	if voices.size() >= 12: voices[0].queue_free()
	var player := AudioStreamPlayer.new()
	player.stream = sounds[clip]
	player.bus = "Combat"
	player.pitch_scale = pitch
	player.volume_db = volume
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
func _draw() -> void:
	_stone(Rect2(0, 0, 1280, 800), Color("303129"))
	_draw_header()
	_draw_arena()
	_draw_statuses()
	_draw_console()
	_draw_dice_circle()
	if view_phase == "over":
		_draw_ending()
		_draw_reward_progress(REWARD_CENTER,1.0)
	if not _menus_open(): _draw_tooltips()

func _text(at: Vector2, value: String, size: int = 16, color: Color = CREAM, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	value = GameText.text(value)
	# Latin pixel font with bundled CJK fallback; integer baselines.
	var p := at.round()
	canvas.draw_string(pixel_font, p + Vector2(2, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, color.a))
	canvas.draw_string(pixel_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(at: Vector2, value: String, size: int = 16, color: Color = CREAM, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	value = GameText.text(value)
	var width: float = pixel_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(at - Vector2(width / 2, 0), value, size, color, canvas)

func _wrapped(at: Vector2, value: String, width: float, color: Color = MUTED, size: int = 16, canvas: CanvasItem = null) -> float:
	if canvas == null: canvas = self
	size = maxi(size,22)
	var y: float = at.y
	for line in GameText.lines(value, description_font, size, width):
		canvas.draw_string(description_font,Vector2(at.x,y).round(),line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		y += size+6
	return maxf(at.y,y-size-6)

func _buff_drag_active() -> bool:
	if view_phase != "targeting" or not skill_dragging or _menus_open(): return false
	var roll: MultiHitSkill = _source_roll(skill_source)
	return not roll.is_empty() and not Rules.is_attack(roll)

func _art(key: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if _buff_drag_active() and key.trim_suffix("_glow") in ["vanguard", "archer", "mage"]:
		tint *= Color(0.38, 0.38, 0.38, 1)
	if art.has(key):
		draw_texture_rect(art[key], Rect2(rect.position.round(), rect.size), false, tint)

func _stone(rect: Rect2, tint: Color, key: String = "stone", unit: int = 64, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(rect, PANEL)
	if not art.has(key): return
	for y in range(int(rect.position.y), int(rect.end.y), unit):
		for x in range(int(rect.position.x), int(rect.end.x), unit):
			var size := Vector2(minf(unit, rect.end.x - x), minf(unit, rect.end.y - y))
			# Crop the dark grout from UI stone so it does not compete with text.
			var inset: float = 3.0 if key == "stone" else 0.0
			canvas.draw_texture_rect_region(art[key], Rect2(Vector2(x, y), size), Rect2(Vector2.ONE * inset, size * (32.0 - inset * 2) / unit), tint)

func _frame(rect: Rect2, fill: Color = PANEL, border: Color = EDGE, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(INK, 0.6))
	_stone(rect, fill, "stone", 64, canvas)
	canvas.draw_rect(rect, INK, false, 4)
	canvas.draw_rect(rect.grow(-3), border.darkened(0.35), false, 2)
	canvas.draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 2)), border)
	canvas.draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(2, rect.size.y - 10)), border)
	for p in [rect.position + Vector2(5, 5), Vector2(rect.end.x - 9, rect.position.y + 5), rect.end - Vector2(9, 9), Vector2(rect.position.x + 5, rect.end.y - 9)]:
		canvas.draw_rect(Rect2(p, Vector2(4, 4)), border.lightened(0.2))

func _button(rect: Rect2, value: String, enabled: bool = true, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var hover: bool = enabled and rect.has_point(get_global_mouse_position())
	_frame(rect, Color("5f563a") if hover else Color("443c2d"), GOLD if hover else EDGE, canvas)
	_center(rect.get_center() + Vector2(0, 6), value, 16, GOLD if enabled else MUTED, canvas)

func _draw_header() -> void:
	_text(Vector2(42, 53), "%d / %d" % [model.stage + 1, Run.WAVE_NAMES.size()], 32, GOLD)
	_draw_currencies(Vector2(284, 40))
	_button(SPEED_RECT, "%.1f" % _roll_speed() if model.is_city() else "2x" if speed == 2 else "1x")
	for rect in [AUDIO_RECT, MENU_RECT]:
		_frame(rect, Color("443c2d"), GOLD if rect.has_point(get_global_mouse_position()) else EDGE)
	_glyph(AUDIO_RECT.get_center(), "mute" if muted else "sound", MUTED if muted else GOLD)
	_draw_menu_icon()

func _draw_menu_icon() -> void:
	var scale_factor: float = 2 if fx.canvas_size.y > fx.canvas_size.x else 1
	for row in [-1,0,1]:
		var at: Vector2 = MENU_RECT.get_center() + Vector2(0,row*6*scale_factor)
		draw_rect(Rect2(at-Vector2(10*scale_factor,scale_factor),Vector2(20*scale_factor,2*scale_factor)),GOLD)

func _draw_menu(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	canvas.draw_rect(Rect2(Vector2.ZERO,fx.canvas_size),INK)
	if not portrait: _frame(Rect2(360,120,560,560),PANEL,GOLD, canvas)
	_text(Vector2(40,188) if portrait else Vector2(400,184),"MENU",42 if portrait else 32,GOLD, canvas)
	_button(MENU_CLOSE,"X", true, canvas)
	_button(DEBUG_RECT,"DEBUG", true, canvas)
	_button(FX_RECT,"EFFECTS: " + ("REDUCED" if reduced else "FULL"), true, canvas)
	_button(GUIDE_RECT,"HELP / GRIMOIRE", true, canvas)
	_text(LANGUAGE_RECT.position-Vector2(0,14 if portrait else 12),"LANGUAGE",24 if portrait else 16,MUTED, canvas)
	for i in range(GameText.LANGUAGES.size()):
		var rect := _language_rect(i)
		_button(rect,GameText.LANGUAGE_NAMES[i], true, canvas)
		if GameText.language == GameText.LANGUAGES[i]: canvas.draw_rect(rect.grow(-4),TEAL,false,3)
	_button(MENU_RESUME,"RESUME", true, canvas)
	_center(Vector2(402,1350) if portrait else Vector2(640,650),"BATTLE PAUSED",24 if portrait else 16,MUTED, canvas)

func _language_rect(index: int) -> Rect2:
	var gap: float = 16 if fx.canvas_size.y > fx.canvas_size.x else 12
	var width: float = (LANGUAGE_RECT.size.x-gap)/2
	return Rect2(LANGUAGE_RECT.position+Vector2(index*(width+gap),0),Vector2(width,LANGUAGE_RECT.size.y))

func _arena_art(key: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var clipped: Rect2 = rect.intersection(ARENA.grow(-6))
	if not clipped.has_area(): return
	var ratio: Vector2 = Vector2(art[key].get_size()) / rect.size
	draw_texture_rect_region(art[key], clipped, Rect2((clipped.position - rect.position) * ratio, clipped.size * ratio), tint)

func _backdrop_dim() -> float:
	if _menus_open(): return 0.0
	return maxf(0.58 if view_phase == "targeting" else 0.0, _cinematic_gloom())

func _draw_backdrop_shade() -> void:
	# Draw beneath the actors so targeting and cast anticipation never dim them.
	var amount: float = _backdrop_dim()
	if amount > 0: draw_rect(ARENA, Color(0.035,0.025,0.065,amount))

func _draw_arena() -> void:
	draw_rect(ARENA, Color("a5a182"))
	var tile: int = roundi(_stage_size(PAVING_SIZES))
	var shift: int = int(background_offset) % tile
	var tint: Color = Color("b6b8a0").lerp(Color("c3a889"), visual_stage / float(Run.WAVE_NAMES.size()-1))
	var scenery_stage: float = visual_stage / float(Run.WAVE_NAMES.size()-1) * 4
	var city_blend: float = clampf(scenery_stage - 3, 0, 1)
	var field_blend: float = clampf((scenery_stage-1)/2.0,0,1)
	for y in range(int(ARENA.position.y), int(ARENA.end.y), tile):
		for x in range(24 - shift, 1256, tile):
			var variant: int = posmod(int((x + background_offset) / tile) + int(y / tile), 4)
			if field_blend < 1: _arena_art("floor%d" % variant, Rect2(x, y, tile, tile), tint)
			if field_blend > 0:
				_arena_art("grass", Rect2(x,y,tile,tile), Color(0.76,0.83,0.66,field_blend))
	var prop_side: float = _stage_size(SCENERY_SIZES)
	var prop_space: float = prop_side * 2.25
	var prop_shift: float = fposmod(background_offset * 0.65, prop_space)
	var horizon: float = 180
	for i in range(-1, ceili(ARENA.size.x / prop_space)+1):
		var x: float = 24 + i * prop_space - prop_shift
		_arena_art("arch", Rect2(x, horizon-prop_side*0.65, prop_side, prop_side), Color(tint, (1-city_blend)*0.8))
		_arena_art("column", Rect2(x + prop_side * 1.18, horizon-prop_side*0.3, prop_side * 0.66, prop_side * 0.66), Color(tint, (1-city_blend)*0.8))
	var tree_shift: float = fposmod(background_offset * 0.4, 420)
	for i in range(-1, 5):
		_arena_art("mangrove", Rect2(25 + i * 420 - tree_shift, horizon-prop_side*0.3, prop_side, prop_side), Color("939e79"))
	if city_blend > 0:
		for tree in [Vector2(476,184),Vector2(511,213),Vector2(474,230),Vector2(1160,430),Vector2(1210,390),Vector2(1134,451)]:
			_arena_art("mangrove", Rect2(tree,Vector2(24,24)), Color(0.67,0.74,0.55,city_blend))
	if visual_stage >= 1 and not model.is_city():
		var building_height: float = _stage_size([96.0,64.0,40.0,24.0,18.0])
		for i in range(12):
			var x: float = 42 + i * 113 - fposmod(background_offset * 0.2, 113)
			_draw_building(Rect2(x, horizon-building_height, building_height*0.7, building_height), Color(0.7, 0.7, 0.55, minf(0.8, visual_stage * 0.35)), false)
	draw_rect(ARENA, Color(0.84, 0.85, 0.67, 0.13))
	_draw_backdrop_shade()
	if model.is_city(): _draw_city()
	_draw_player()
	if not model.is_city():
		for i in range(model.enemies.size()): _draw_human(i)
	for i in range(4):
		draw_rect(Rect2(ARENA.position.x, ARENA.end.y - 12 + i * 3, ARENA.size.x, 3), Color(INK, 0.08 + i * 0.06))
	draw_rect(ARENA, EDGE, false, 4)
	draw_rect(ARENA.grow(-5), Color("d2c29a"), false, 2)
	if view_phase in ["feeding", "transition"]:
		_frame(Rect2(440, 105, 400, 45), PANEL, GOLD)
		_center(Vector2(640, 136), "THE FEAST" if view_phase == "feeding" else Run.WAVE_NAMES[model.stage], 24, GOLD)

func _draw_building(rect: Rect2, tint: Color, ruined: bool) -> void:
	if ruined:
		_arena_art("column", Rect2(rect.position.x, rect.end.y - 24, rect.size.x, 28), tint)
		return
	_arena_art("stone", rect, tint)
	var roof: Rect2 = Rect2(rect.position - Vector2(4, 12), Vector2(rect.size.x + 8, 20)).intersection(ARENA.grow(-7))
	if roof.has_area():
		draw_rect(roof, Color("785752") * tint)
		for x in range(int(roof.position.x), int(roof.end.x), 12):
			draw_rect(Rect2(x, roof.position.y, minf(6, roof.end.x - x), 6), Color("c09c79") * tint)
	for y in range(int(rect.position.y + 16), int(rect.end.y - 12), 24):
		for x in range(int(rect.position.x + 12), int(rect.end.x - 8), 22):
			var window := Rect2(x, y, 8, 12).intersection(ARENA.grow(-7))
			if window.has_area(): draw_rect(window, Color("e2ba69") * tint)

func _troop_point(index: int) -> Vector2:
	var progress: float = fposmod(city_life.clock * 0.1 + index * 0.17, 1.0)
	return City.gate_point().lerp(Vector2(425,410),progress) + Vector2(0,(index % 2)*5)

func _draw_city() -> void:
	var remaining: float = model.city_hp / float(Run.CITY_MAX_HP)
	City.paint(self, art, remaining, city_life.clock, city_life.people, city_life.houses, reduced)
	for corpse in city_corpses:
		draw_set_transform(corpse.p, PI / 2, Vector2(0.35, 1))
		var side: float = _enemy_side()
		_art(["vanguard", "archer", "mage"][corpse.role], Rect2(-side/2, -side/2, side, side), Color("796c64"))
		draw_set_transform(Vector2.ZERO)
	for i in range(model.troops):
		var point := _troop_point(i)
		var stride: float = city_life.clock * 16 + i * 2.3
		var hop: float = 0 if reduced else snappedf(absf(sin(stride)) * 2, 1)
		var lean: float = 0 if reduced else sin(stride) * 0.16
		_shadow(point, 5, 0.22)
		draw_set_transform((point - Vector2(0, hop)).round(), lean)
		var side: float = _enemy_side()
		_art(["vanguard", "archer", "mage"][i % 3], Rect2(-side/2, -side, side, side))
		draw_set_transform(Vector2.ZERO)
	_hp_plate(Rect2(531, 88, 683, 55), "THE CITY", model.city_hp, Run.CITY_MAX_HP, 0, GOLD)
	if model.volley_warned:
		_center(City.wall_point(0) - Vector2(15,61), "VOLLEY", 16, RED)

func _shadow(point: Vector2, radius: float, alpha: float) -> void:
	Pixel.disc(self, point, radius, Color(INK, alpha), 8, 0.19)

func _draw_player() -> void:
	var hurt: float = hit_times[0]
	var bob: float = 0 if reduced or model.is_frozen() else snappedf(sin(clock_time * (8 if view_phase == "transition" else 1.8)) * 3, 2)
	var dx: float = snappedf(sin(clock_time * 45) * hurt * 5, 2) if not reduced and not model.is_frozen() else 0.0
	_shadow(Vector2(259, 413), monster_side * 0.48, 0.27)
	if model.shield > 0 or model.statuses[6].count > 0: Pixel.circle(self, _player_point(), monster_side * 0.47, Color(TEAL, 0.45), 4)
	_art("eldritch", Rect2(Vector2(259 - monster_side / 2 + dx, 414 - monster_side + bob), Vector2.ONE * monster_side), Color(Color.WHITE.lerp(RED, hurt * 0.6),0.32 if model.status_count(Status.HIDDEN) > 0 else 1.0))
	_draw_player_afflictions()
	_hp_plate(Rect2(129, 382, 260, 56), "HORROR %d" % (model.stage+1), model.hp, model.max_hp, model.shield, TEAL)

func _draw_human(index: int) -> void:
	if view_phase == "transition": return
	var human: Dictionary = model.enemies[index]
	var point: Vector2 = _enemy_point(index)
	var floor_y: float = _enemy_feet(index).y
	var side: float = _enemy_side()
	var key: String = ["vanguard", "archer", "mage"][human.role]
	var selected: bool = attack_target == index and view_phase == "resolving"
	if human.hp <= 0:
		var t: float = minf(1, fallen.get(index, 1.0) / 0.3)
		var center: Vector2 = point.lerp(Vector2(point.x, floor_y-side*0.08), t)
		var hurt: float = hit_times[index + 1]
		if not reduced: center.x += sin(clock_time*46)*hurt*minf(6,side*0.03)
		_shadow(Vector2(point.x, floor_y-2), side * 0.42, 0.2 * corpse_alpha)
		draw_set_transform(center, t * PI / 2, Vector2(lerpf(1, 0.36, t), 1))
		_art(key, Rect2(Vector2.ONE * -side / 2, Vector2.ONE * side), Color(0.64, 0.52, 0.49, corpse_alpha).lerp(Color(RED,corpse_alpha),hurt*0.6))
		draw_set_transform(Vector2.ZERO)
		return
	if selected or active_human == index:
		var color: Color = GOLD if selected else RED
		Pixel.disc(self, Vector2(point.x, floor_y-2), side * 0.35, Color(color, 0.35), 6, 0.23)
		_rune(point - Vector2(0, side * 0.55), 3, color, 3)
	var hurt: float = hit_times[index + 1]
	var dx: float = snappedf(sin(clock_time * 46) * hurt * minf(6,side*0.03), 2) if not reduced else 0.0
	var bob: float = 0 if reduced or model.enemy_status_count(index, Status.FROZEN) > 0 else snappedf(sin(clock_time * 2 + index * 2) * minf(2,side/64.0), 2)
	_shadow(Vector2(point.x, floor_y-1), side * 0.25, 0.25)
	if human.elite:
		var glow: Color = _elite_color(human.role)
		StatusPaint.aura(self, Vector2(point.x,floor_y), side, glow, clock_time, reduced)
		var pulse: float = 1.0 if reduced else 0.9 + sin(clock_time * 3 + index) * 0.1
		var sprite := Rect2(Vector2(point.x-side/2+dx, floor_y-side+bob), Vector2.ONE*side)
		# White alpha silhouettes keep the halo bright even around dark sprite pixels.
		for ring in [2, 1]:
			var spread: float = ring * maxf(3, side * 0.045)
			for ray in range(8):
				var offset := Vector2.from_angle(ray*TAU/8)*spread
				_art(key+"_glow", Rect2(sprite.position+offset, sprite.size), Color(glow.lightened(0.2 if ring == 1 else 0), pulse*(0.6 if ring == 1 else 0.12)))
		var ground_glow: Color = glow.darkened(0.62) if _buff_drag_active() else glow
		Pixel.disc(self, Vector2(point.x, floor_y), maxf(16,side*0.42), Color(ground_glow,0.65*pulse), 3, 0.25)
	_art(key, Rect2(Vector2(point.x - side / 2 + dx, floor_y - side + bob), Vector2.ONE * side), Color.WHITE.lerp(RED, hurt * 0.6))
	if human.elite: StatusPaint.ellipse(self,Vector2(point.x,floor_y),maxf(22,side*0.53),_elite_color(human.role))
	if model.enemy_status_count(index,Status.FROZEN) > 0:
		StatusPaint.ice(self,Rect2(point.x-side*0.45,floor_y-side,side*0.9,side),false)
	_draw_enemy_intent(index)
	_draw_enemy_health(index)
	_draw_enemy_statuses(index)

func _draw_enemy_statuses(index: int) -> void:
	var effects: Dictionary = model.enemies[index].get("statuses",{})
	var items: Array = Statuses.active(effects)
	var bar: Rect2 = _enemy_health_rect(index)
	var radius: float = 8 if fx.canvas_size.y > fx.canvas_size.x else 5
	var step: float = minf(radius*3,bar.size.x/maxi(1,items.size()))
	for i in range(items.size()):
		var at: Vector2 = bar.get_center()+Vector2((i-(items.size()-1)/2.0)*step,bar.size.y/2+radius+8)
		Pixel.disc(self,at,radius+3,INK,2)
		StatusPaint.icon(self,at,radius,items[i].icon,items[i].color)
		_text(at+Vector2(radius*0.55,radius+5),"∞" if items[i].permanent else str(items[i].turns),12,CREAM)

func _elite_color(role: int) -> Color:
	return [Color("ffe388"), Color("82dfff"), Color("ff9955")][role]

func _draw_player_afflictions() -> void:
	var feet: Vector2 = _player_feet()
	if model.is_frozen():
		StatusPaint.ice(self,_player_ice_rect(),true,3-model.ice_hits_remaining if model.phase == "frozen" else 0)
	if model.is_stunned():
		StatusPaint.orbiting_stars(self,feet-Vector2(0,monster_side*0.89),monster_side,clock_time,reduced)

func _enemy_intent_data(index: int) -> Dictionary:
	var enemy: Dictionary = model.enemies[index]
	if enemy.hp <= 0 or enemy.acted or enemy.intent.is_empty(): return {}
	if model.enemy_status_count(index,Status.FROZEN) > 0:
		return {"label":"FROZEN","detail":"SKIP","color":Statuses.ENTRIES[Status.FROZEN].color,"icon":"skip","name":"Frozen","description":"Cannot act this turn. One freeze stack is consumed."}
	var intent: Dictionary = enemy.intent
	var label: String = ""
	var detail: String = ""
	var color: Color = TEAL
	var icon: String = "sword"
	var name: String = "Attack"
	var description: String = ""
	if enemy.canceled:
		label = "SKIP"
		color = MUTED
		icon = "skip"
		name = "Distracted"
		description = "This enemy will skip its next move."
	elif intent.type == "attack":
		var attribute: int = intent.get("attribute",Status.Attribute.NONE)
		label = ["ATK","ICE","FIRE","STUN"][attribute]
		detail = str(roundi(intent.amount*(1.5 if enemy.attack_boost else 1.0)*(0.5 if model.enemy_status_count(index,Status.DARKNESS) > 0 else 1.0)))
		description = GameText.format("Deal %s damage.",detail)
		name = ["Attack","Ice Arrow","Burning Bolt","Stunning Blow"][attribute]
		if attribute == Status.Attribute.ICE: description += " " + GameText.text("Freeze: tap the ice 3 times to end your turn.")
		elif attribute == Status.Attribute.FIRE: description += " " + GameText.text("Apply 2 burning stacks.")
		elif attribute == Status.Attribute.SHOCK: description += " " + GameText.text("Stun: randomize your next throw's power marker.")
		if attribute != Status.Attribute.NONE:
			label += " " + detail
			detail = "BURN +2" if attribute == Status.Attribute.FIRE else "SKIP TURN" if attribute == Status.Attribute.ICE else "NEXT THROW"
		color = [RED,Color("82dfff"),Color("ff9955"),Color("ffe388")][attribute]
	elif intent.type == "shield":
		icon = "shield"
		name = "Raise Shield"
		label = "SHIELD"
		detail = "+%d" % (0 if model.enemy_status_count(index,Status.CORROSION) > 0 else mini(intent.amount,Rules.SHIELD_CAP-enemy.shield))
		description = GameText.format("Gain %s shield.",detail.trim_prefix("+"))
	elif intent.type == "heal":
		icon = "plus"
		name = "Heal"
		label = "HEAL"
		detail = "+%d" % (0 if model.enemy_status_count(index,Status.DARKNESS) > 0 else mini(intent.amount,enemy.max_hp-enemy.hp))
		description = GameText.format("Restore %s health.",detail.trim_prefix("+"))
	elif intent.type == "team_heal":
		icon = "plus"
		name = "Group Heal"
		label = "HEAL ALL"
		detail = "20%"
		description = "Restore 20% max health to living allies. Darkness blocks healing."
	else:
		icon = "boost"
		name = "Empower"
		label = "BOOST"
		detail = "ALLY x1.5"
		color = PURPLE
		description = "Give one ally 1.5x damage on its next attack."
	return {"label":label,"detail":detail,"color":color,"icon":icon,"name":name,"description":description}

func _enemy_intent_rect(index: int) -> Rect2:
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var width: float = 40 if portrait else 26
	var feet: Vector2 = _enemy_feet(index)
	var columns: int = mini(5,model.enemies.size())
	if columns > 1:
		var spacing: float = absf(_enemy_feet(1).x-_enemy_feet(0).x)
		width = minf(width,spacing-6)
	var height: float = width
	return Rect2(Vector2(feet.x-width/2,maxf(ARENA.position.y+8,feet.y-_enemy_side()-height-12)),Vector2(width,height))

func _draw_enemy_intent(index: int) -> void:
	var data: Dictionary = _enemy_intent_data(index)
	if data.is_empty(): return
	var rect: Rect2 = _enemy_intent_rect(index)
	Pixel.disc(self,rect.get_center(),rect.size.x*0.53,Color(INK,0.82),2)
	StatusPaint.intent_icon(self,rect.get_center(),rect.size.x*0.4,data.icon,data.color)

func _reward_scale() -> float:
	return 1.5 if fx.canvas_size.y > fx.canvas_size.x else 1.0

func _diamond_center(index: int) -> Vector2:
	return REWARD_CENTER + Vector2((index-4)*28+(index/3-1)*8, 0)*_reward_scale()

func _chest_milestone_rect(tier: int) -> Rect2:
	var side: float = 88 if _reward_scale() > 1 else 48
	return Rect2(_diamond_center(tier*3-1)-Vector2.ONE*side/2,Vector2(side,side/2+45*_reward_scale()))

func _chest_tier_at(point: Vector2) -> int:
	if not _can_claim_chest(): return 0
	var tier: int = model.chest_tier()
	return tier if _chest_milestone_rect(tier).has_point(point) else 0

func _draw_reward_progress(at: Vector2, scale_factor: float) -> void:
	var available_tier: int = model.chest_tier() if _can_claim_chest() else 0
	for i in range(9):
		var group: int = i / 3
		var claimable: bool = available_tier == group+1
		var p := _diamond_center(i)
		var milestone: bool = i % 3 == 2
		var filled: bool = i < model.perfect_progress
		var radius: float = (15 if milestone else 10)*scale_factor
		var tint: Color = [GOLD,PURPLE,Color("9dcedb")][group]
		if milestone and filled:
			var pulse: float = 0.9 if reduced else 0.85+sin(clock_time*4.5)*0.15
			for j in range(5,0,-1):
				var glow_radius: float = radius+j*3.5*scale_factor
				var glow := PackedVector2Array([p+Vector2(0,-glow_radius),p+Vector2(glow_radius,0),p+Vector2(0,glow_radius),p+Vector2(-glow_radius,0)])
				draw_colored_polygon(glow,Color(tint,pulse*(0.2 if claimable else 0.1)))
			if claimable:
				var halo: float = radius+(7+pulse*3)*scale_factor
				var corners := PackedVector2Array([p+Vector2(0,-halo),p+Vector2(halo,0),p+Vector2(0,halo),p+Vector2(-halo,0)])
				for edge in range(4): Pixel.line(self,corners[edge],corners[(edge+1)%4],Color(tint.lightened(0.5),pulse*0.8),2)
		var points := PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,0),p+Vector2(0,radius),p+Vector2(-radius,0)])
		draw_colored_polygon(points,tint if filled else INK)
		for edge in range(4): Pixel.line(self,points[edge],points[(edge+1)%4],CREAM if milestone and filled else tint if filled else EDGE,3 if milestone else 2)
		if filled: draw_rect(Rect2(p-Vector2.ONE*(3 if milestone else 2),Vector2.ONE*(6 if milestone else 4)),CREAM)
		if milestone and filled and claimable:
			var label := Rect2(p+Vector2(-25,24)*scale_factor,Vector2(50,21)*scale_factor)
			draw_rect(label, tint.darkened(0.68))
			draw_rect(label,tint.lightened(0.25),false,2)
			_center(p+Vector2(0,39*scale_factor), "CLAIM", roundi(12*scale_factor), CREAM)

func _draw_auto_claim() -> void:
	if view_phase != "over" or auto_claim_tier == 0 or auto_claim_remaining <= 0: return
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var rect := Rect2(82,476,640,92) if portrait else Rect2(380,143,520,64)
	var alpha: float = minf(1.0, minf((AUTO_CLAIM_DURATION-auto_claim_remaining)/0.12,auto_claim_remaining/0.35))
	var color: Color = [GOLD,PURPLE,Color("9dcedb")][auto_claim_tier-1]
	for i in range(3,0,-1): auto_claim_notice.draw_rect(rect.grow(i*4),Color(color,0.055*alpha))
	auto_claim_notice.draw_rect(rect,Color(INK,0.97*alpha))
	auto_claim_notice.draw_rect(rect,Color(color,alpha),false,3)
	var side: float = 64 if portrait else 44
	var icon_at := Vector2(rect.position.x+side*0.65,rect.get_center().y)
	auto_claim_notice.draw_texture_rect(chest.art.chest_open,Rect2(icon_at-Vector2.ONE*side/2,Vector2.ONE*side),false,Color(1,1,1,alpha))
	var label: String = GameText.format("%s chest auto claimed",GameText.text(CHEST_NAMES[auto_claim_tier]))
	var font_size: int = 26 if portrait else 20
	var width: float = pixel_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline: Vector2 = (rect.get_center()+Vector2((side-width)/2,9 if portrait else 7)).round()
	auto_claim_notice.draw_string(pixel_font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(color.lightened(0.35),alpha))

func _damage_multiplier_label() -> String:
	return damage_feedback.label() if is_instance_valid(damage_feedback) and damage_feedback.active else ""

func _draw_currencies(at: Vector2, scale_factor: float = 1.0) -> void:
	var side: float = 32*scale_factor
	RewardIcons.paint(self,chest.art,"ruby",Rect2(at-Vector2.ONE*side/2,Vector2.ONE*side))
	_text(at+Vector2(23,7)*scale_factor,str(model.rubies),roundi(18*scale_factor),Color("fa6086"))
	var shard_at: Vector2 = at+Vector2(126,0)*scale_factor
	RewardIcons.paint(self,chest.art,"shard",Rect2(shard_at-Vector2.ONE*side/2,Vector2.ONE*side))
	_text(shard_at+Vector2(23,7)*scale_factor,str(model.summon_shards),roundi(18*scale_factor),PURPLE)

func _enemy_health_rect(index: int) -> Rect2:
	var count: int = model.enemies.size()
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var feet: Vector2 = _enemy_feet(index)
	var width: float = (168 if count < 4 else 60) if portrait else (148 if count < 4 else 40 if count > 5 else 52)
	# Include an explicit gutter between adjacent bars, including their borders.
	if count > 1:
		var spacing: float = absf(_enemy_feet(1).x-_enemy_feet(0).x)
		width = minf(width, spacing-16)
	var height: float = (30 if count < 4 else 24) if portrait else (20 if count < 4 else 14)
	var y: float = feet.y+8
	return Rect2(feet.x-width/2, y, width, height)

func _draw_enemy_health(index: int) -> void:
	var human: Dictionary = model.enemies[index]
	var bar: Rect2 = _enemy_health_rect(index)
	var color: Color = _elite_color(human.role) if human.elite else RED
	var size: int = 16 if model.enemies.size() < 4 else 12
	draw_rect(bar.grow(2), EDGE)
	draw_rect(bar, INK)
	draw_rect(Rect2(bar.position+Vector2(2,2),Vector2((bar.size.x-4)*human.hp/float(human.max_hp),bar.size.y-4)),color.darkened(0.3))
	_center(bar.get_center()+Vector2(0,size*0.4), str(human.hp), size, CREAM)
	if human.shield > 0:
		_glyph(bar.position+Vector2(5,-10),"shield",TEAL)
		_text(bar.position+Vector2(17,-5),str(human.shield),12,TEAL)

func _hp_plate(rect: Rect2, title: String, hp: int, maximum: int, shield: int, color: Color) -> void:
	_frame(rect, Color("32382c"), EDGE)
	var localized_title: String = GameText.format("HORROR %d",title.trim_prefix("HORROR ").to_int()) if title.begins_with("HORROR ") else title
	_center(Vector2(rect.get_center().x, rect.position.y + 22), localized_title, 16, CREAM if hp else MUTED)
	var bar := Rect2(rect.position + Vector2(10, 30), Vector2(rect.size.x - 20, 18))
	draw_rect(bar, INK)
	var filled: int = floori((bar.size.x - 4) * hp / float(maximum))
	for x in range(0, filled, 4):
		var w: float = minf(4, filled - x)
		draw_rect(Rect2(bar.position + Vector2(2 + x, 2), Vector2(w, 14)), color.darkened(0.4 if x % 12 == 0 else 0.2))
		draw_rect(Rect2(bar.position + Vector2(2 + x, 2), Vector2(w, 3)), color)
		draw_rect(Rect2(bar.position + Vector2(2 + x, 13), Vector2(w, 3)), color.darkened(0.55))
	_center(bar.get_center() + Vector2(0, 6), "%d / %d" % [hp, maximum] if title.begins_with("HORROR") or title == "THE CITY" else str(hp), 16, CREAM)
	if shield > 0:
		var badge := Rect2(rect.end.x - 57, rect.position.y - 29, 55, 28)
		_frame(badge, PANEL, TEAL.darkened(0.25))
		_glyph(badge.position + Vector2(15, 13), "shield", TEAL)
		_text(badge.position + Vector2(28, 19), str(shield), 16, TEAL)

func _active_statuses() -> Array:
	return Statuses.active(model.statuses)

func _status_center(id: int) -> Vector2:
	var items: Array = _active_statuses()
	var slot: int = items.find_custom(func(item): return item.id == id)
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	if portrait:
		var key: String = "%d:%d:%.2f" % [model.stage,model.enemies.size(),monster_side]
		if key == status_layout_key and slot >= 0 and slot < status_layout_points.size(): return status_layout_points[slot]
		var base_y: float = _player_feet().y + 40 - monster_side - 44 + (16 if model.enemies.size() > 5 else 0)
		var candidates: Array = []
		for row in [0,1,-1,2,-2,3,-3]:
			for column in range(3):
				var point := Vector2(72+column*92,base_y+row*92)
				var rect := Rect2(point-Vector2.ONE*44,Vector2.ONE*88)
				if rect.position.y < ARENA.position.y+60 or rect.end.y > 896: continue
				var blocked: bool = false
				for enemy in range(model.enemies.size()):
					if rect.intersects(_target_rect(enemy)) or rect.intersects(_enemy_health_rect(enemy).grow(4)) or rect.intersects(_enemy_intent_rect(enemy).grow(3)): blocked = true; break
				if not blocked: candidates.append(point)
		status_layout_key = key
		status_layout_points = candidates
		if slot >= 0 and slot < candidates.size(): return candidates[slot]
		return Vector2(72+maxi(0,slot)%3*92,844-floori(maxi(0,slot)/3.0)*92)
	var step: float = 48
	var columns: int = 7
	var row: int = floori(slot/float(columns))
	var count: int = mini(columns, items.size() - row*columns)
	var anchor := _player_feet() - Vector2(0, monster_side + 24)
	var downward: bool = anchor.y-(ceili(items.size()/float(columns))-1)*step < ARENA.position.y+76
	if downward:
		# Keep top-row statuses clear of the damage readout in late waves.
		anchor.y = maxf(ARENA.position.y+80,anchor.y)
	return anchor + Vector2((slot % columns - (count-1)/2.0)*step, row*step*(1 if downward else -1))

func _status_rect(id: int) -> Rect2:
	var side: float = 88 if fx.canvas_size.y > fx.canvas_size.x else 44
	return Rect2(_status_center(id)-Vector2.ONE*side/2, Vector2.ONE*side)

func _draw_statuses() -> void:
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var side: float = 40 if portrait else 28
	for item in _active_statuses():
		var at := _status_center(item.id)
		Pixel.disc(self, at, side*0.65, Color(INK,0.85), 2)
		Pixel.circle(self, at, side*0.65, Color(item.color,0.6), 2)
		if item.id >= Status.FROZEN: StatusPaint.icon(self, at, side*0.42, item.icon, item.color)
		else: _art(item.icon, Rect2(at-Vector2.ONE*side/2, Vector2.ONE*side), item.color.lightened(0.3))
		var badge := at + Vector2(side*0.5, side*0.55)
		var timed: bool = model.is_city() and item.id == Status.IMMUNITY
		var value: String = "%ds" % ceili(model.city_immunity_seconds()) if timed else str(item.turns)
		var width: float = 48 if timed and portrait else 36 if timed else 20
		draw_rect(Rect2(badge-Vector2(width/2,13),Vector2(width,20)), INK)
		_center(badge+Vector2(0,4), value, 22 if portrait else 16, item.color)

func _status_description(id: int, count: int) -> String:
	if id == Status.IMMUNITY and model.is_city():
		return GameText.format("Invincible for %.1f more seconds. Each stack lasts 2 seconds.",model.city_immunity_seconds())
	if id == Status.REGEN: return GameText.format("Heal %d at turn start.",roundi(5*model.statuses[id].potency))+" "+GameText.remaining(count,"turn")
	if id in [Status.MIGHT,Status.ASCENSION]: return GameText.format("Adds +%.1f to DMG. Stacks with other bonuses.",(0.5 if id == Status.MIGHT else 2.0)*model.statuses[id].potency)+" "+GameText.remaining(count,"turn")
	var unit: String = "stack" if id in [Status.BURNING,Status.DARKNESS,Status.CORROSION,Status.PLAGUE] else "throw" if id == Status.STUNNED else "turn"
	return GameText.text(Statuses.ENTRIES[id].text)+" "+GameText.remaining(count,unit)

func _draw_console() -> void:
	_draw_reward_progress(REWARD_CENTER, 1.0)
	_frame(Rect2(905, 524, 341, 231), Color("363b2e"))
	_center(Vector2(1075, 557), "CITY FEVER" if model.is_city() else "OMEN", 20 if model.is_city() else 16, GOLD)
	if not model.is_city() and view_phase != "charging": _center(Vector2(1075, 597), status_title, 16, status_color)
	if model.is_city():
		_center(Vector2(1075, 606), "%.1fx" % _roll_speed(), 44, GOLD)
		_center(Vector2(1075, 737), "CLICK TO STOP" if view_phase == "charging" else "CLICK TO CHARGE" if view_phase == "ready" else "LOCKED", 20, GOLD)
	elif debug_choice >= 0 or debug_perfect:
		_center(Vector2(1075, 728), "DEBUG QUEUED", 16, PURPLE)
	else:
		_center(Vector2(1075, 728), "CLICK TO CHARGE" if view_phase == "ready" else "", 16, GOLD)
	if _power_meter_visible():
		_draw_power_meter(Rect2(967, 672 if model.is_city() else 628, 216, 28))
		if not model.is_city(): _center(Vector2(1075, 699), "CLICK TO STOP" if view_phase == "charging" else "LOCKED", 16, GOLD)

func _dice_spent() -> bool:
	return view_phase in ["forming", "skill", "targeting", "resolving"]

func _show_dice_links() -> bool:
	return view_phase == "rolling" and dice.all(func(die): return die.visible) and not last_result.is_empty() and last_result.kind != Rules.Kind.NORMAL

func _draw_saved_slot() -> void:
	if is_instance_valid(tarot_ui) and tarot_ui.inventory_visible(): return
	if view_phase in ["over", "reward"]: return
	var at: Vector2 = _saved_slot_center()
	var radius: float = _saved_slot_radius()
	var accepts: bool = skill_dragging and skill_source == "current" and model.saved_skill.is_empty()
	var hovered: bool = accepts and _in_saved_slot(skill_pointer)
	var color: Color = GOLD if hovered else TEAL if accepts else MUTED
	Pixel.disc(self,at,radius,Color(INK,0.75),2)
	Pixel.circle(self,at,radius,Color(color,0.95 if accepts else 0.45),3)
	Pixel.circle(self,at,radius-7,Color(color,0.3),2)
	for i in range(4):
		var p: Vector2 = at+Vector2.from_angle(PI/4+i*PI/2)*(radius+5)
		_rune(p,i,color,1)
	if model.saved_skill.is_empty() and casting_source != "saved":
		Pixel.line(self,at-Vector2(12,0),at+Vector2(12,0),Color(color,0.7),3)
		Pixel.line(self,at-Vector2(0,12),at+Vector2(0,12),Color(color,0.7),3)
	_center(at+Vector2(0,radius+27 if fx.canvas_size.y > fx.canvas_size.x else radius+20),"SAVE" if model.saved_skill.is_empty() else "SAVED",20 if fx.canvas_size.y > fx.canvas_size.x else 12,color)

func _draw_perfect_combo() -> void:
	if is_instance_valid(tarot_ui) and tarot_ui.inventory_visible(): return
	if view_phase in ["over", "reward"]: return
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var at: Vector2 = _perfect_combo_center()
	var radius: float = _saved_slot_radius()
	var active: bool = model.perfect_combo > 0
	var color: Color = GOLD if active else MUTED
	var flash: float = 0.0 if reduced else clampf((combo_flash_until-clock_time)/0.45,0,1)
	if active:
		for i in range(3,0,-1):
			Pixel.circle(self,at,radius+i*4,Color(GOLD,0.08+flash*0.16),3)
	Pixel.disc(self,at,radius,Color(INK,0.9),2)
	Pixel.circle(self,at,radius,Color(color,0.9 if active else 0.4),3)
	Pixel.circle(self,at,radius-7,Color(color,0.35),2)
	_center(at+Vector2(0,-radius-12),"PERFECT",20 if portrait else 12,color)
	var count_text: String = str(model.perfect_combo)
	var count_size: int = 44 if portrait else 30
	while pixel_font.get_string_size(count_text,HORIZONTAL_ALIGNMENT_LEFT,-1,count_size).x > radius*1.5 and count_size > 12:
		count_size -= 2
	_center(at+Vector2(0,8),count_text,count_size,CREAM if active else MUTED)
	_center(at+Vector2(0,radius+27 if portrait else radius+20),"COMBO",20 if portrait else 12,color)

func _draw_dice_circle() -> void:
	_draw_saved_slot()
	_draw_perfect_combo()
	if is_instance_valid(tarot_ui): draw_set_transform_matrix(tarot_ui.dice_transform())
	var layout_scale: float = DICE_RADIUS / 144.0
	var available: bool = view_phase in ["ready", "charging"] and not _menus_open()
	var spent: bool = _dice_spent()
	var fever: bool = model.is_city() and view_phase in ["ready", "charging", "rolling"] and not _menus_open()
	var color: Color = Color("696a70") if spent else GOLD if available or fever else status_color
	Pixel.disc(self, DICE_CENTER + Vector2(0, 6), DICE_RADIUS + 6, Color(INK, 0.7))
	Pixel.disc(self, DICE_CENTER, DICE_RADIUS, Color("29292d") if spent else Color("303529"))
	Pixel.disc(self, DICE_CENTER, DICE_RADIUS - 10, Color("202024") if spent else Color("252d25"))
	for i in range(4, 0, -1):
		Pixel.circle(self, DICE_CENTER, DICE_RADIUS + i * 3, Color(color, ring_hover * (0.13 - i * 0.02)), 3)
	Pixel.circle(self, DICE_CENTER, DICE_RADIUS, Color(color, 0.6 + ring_hover * 0.4), 3)
	Pixel.circle(self, DICE_CENTER, DICE_RADIUS - 8, Color(color, 0.25 + ring_hover * 0.25), 2)
	if fever:
		var pulse: float = 0.7 if reduced else (sin(city_life.clock * TAU * 1.8) + 1) * 0.5
		Pixel.circle(self, DICE_CENTER, DICE_RADIUS+8, Color(GOLD,0.35+pulse*0.65),4)
		Pixel.circle(self, DICE_CENTER, DICE_RADIUS-3, Color(CREAM,0.15+pulse*0.6),3)
		for i in range(8):
			var direction := Vector2.from_angle(-PI/8 + i*TAU/8)
			var at: Vector2 = DICE_CENTER + direction*(DICE_RADIUS+13+(0 if reduced else pulse*4))
			var wing: Vector2 = direction.orthogonal()*7
			Pixel.line(self,at+direction*8-wing,at,Color(GOLD,0.5+pulse*0.5),3)
			Pixel.line(self,at+direction*8+wing,at,Color(GOLD,0.5+pulse*0.5),3)
	Pixel.circle(self, DICE_CENTER, 108 * layout_scale, Color(color, 0.3 + ring_hover * 0.2), 2)
	# Two interlaced triangles and twelve hand-drawn pixel runes form a seal.
	for offset in ([] if spent else [0.0, PI]):
		for i in range(3):
			var a: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + offset + i * TAU / 3) * 106 * layout_scale
			var b: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + offset + (i + 1) * TAU / 3) * 106 * layout_scale
			Pixel.line(self, a, b, Color(color, 0.35 + ring_hover * 0.25), 2)
	for i in range(12):
		var p: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + i * TAU / 12) * 124 * layout_scale
		_rune(p.snapped(Vector2.ONE * 2), i % 6, Color(color, 0.65 + ring_hover * 0.35), 2)
	if _show_dice_links():
		var match_color: Color = [CREAM, TEAL, PURPLE, GOLD][last_result.kind]
		for i in range(3):
			for j in range(i + 1, 3):
				if last_result.dice[i] == last_result.dice[j]:
					Pixel.line(self, DICE_POSITIONS[i], DICE_POSITIONS[j], Color(match_color, 0.75), 3)
	var label: String = "STOP!" if view_phase == "charging" else "CHARGE" if available else "" if spent else "..."
	_center(DICE_CENTER + Vector2(0, 104 * layout_scale), label, roundi((22 if fever else 16) * layout_scale), color if available or fever else MUTED)
	if available and ring_hover > 0.1:
		var at := get_global_mouse_position().snapped(Vector2.ONE * 2)
		Pixel.line(self, at - Vector2(10, 0), at + Vector2(10, 0), Color(GOLD, ring_hover), 2)
		Pixel.line(self, at - Vector2(0, 10), at + Vector2(0, 10), Color(GOLD, ring_hover), 2)
	draw_set_transform(Vector2.ZERO)

func _rune(at: Vector2, index: int, color: Color, unit: int = 2) -> void:
	var patterns := ["00100/01110/10101/00100/01010/10001/00100", "10001/01010/00100/11111/00100/00100/00100", "11110/10001/11110/10100/10010/10001/10000", "00100/01010/10001/01010/00100/00100/01110", "10001/10001/01110/00100/01110/10001/10001", "00100/10101/01110/10101/00100/01010/10001"]
	var rows: PackedStringArray = patterns[index % patterns.size()].split("/")
	for y in range(7):
		for x in range(5):
			if rows[y][x] == "1":
				draw_rect(Rect2((at + Vector2(x - 2, y - 3) * unit).round(), Vector2.ONE * unit), color)

func _glyph(at: Vector2, kind: String, color: Color, scale_factor: int = 1) -> void:
	if art.has(kind):
		var side: int = 32 * scale_factor
		_art(kind, Rect2(at - Vector2.ONE * side / 2, Vector2.ONE * side), color)
		return
	var patterns := {"thorns": "1001001/0101010/0011100/1111111/0011100/0101010/1001001", "sound": "0001000/0011010/1111001/1111001/1111001/0011010/0001000", "mute": "1001001/0111010/1111100/1111000/1111100/0011010/0001001", "close": "1000001/0100010/0010100/0001000/0010100/0100010/1000001"}
	var rows: PackedStringArray = patterns.get(kind, patterns.close).split("/")
	var unit: int = 2 * scale_factor
	for y in range(7):
		for x in range(7):
			if rows[y][x] == "1":
				draw_rect(Rect2((at + Vector2(x - 3, y - 3) * unit).round(), Vector2.ONE * unit), color)

func _draw_tooltips() -> void:
	var mouse := get_global_mouse_position()
	var value: String = ""
	if MENU_RECT.has_point(mouse): value = "Menu"
	elif AUDIO_RECT.has_point(mouse): value = "Sound off" if muted else "Sound on"
	elif SPEED_RECT.has_point(mouse): value = "Fever speed" if model.is_city() else "Animation speed"
	if not value.is_empty():
		_frame(Rect2(988, 66, 256, 36), PANEL, GOLD)
		_center(Vector2(1116, 91), value, 16, CREAM)
	for item in _active_statuses():
		if _status_rect(item.id).has_point(mouse):
			var description: String = _status_description(item.id,item.turns)
			var lines := GameText.lines(description,description_font,22,526)
			var top: float = 434-(74+lines.size()*28)
			_frame(Rect2(38,top,566,74+lines.size()*28), PANEL, GOLD)
			_text(Vector2(55,top+30), item.name, 20, item.color)
			_wrapped(Vector2(55,top+66), description, 526, CREAM,22)

func _remaining_turns(amount: int) -> String:
	return GameText.remaining(amount)

func _pair_description(index: int) -> String:
	var remaining: int = int(model.status_count(index + 1))
	if index == 5 and model.is_city():
		return _status_description(Status.IMMUNITY,remaining) if remaining > 0 else "Invincible for 2 seconds per spare-die stack."
	if remaining > 0:
		match index:
			1: return GameText.text("Heal 5 at turn start.") + " " + _remaining_turns(remaining)
			2: return GameText.text("Adds +0.5 to DMG. Stacks with other bonuses.") + " " + _remaining_turns(remaining)
			5: return GameText.text("Invincible.") + " " + _remaining_turns(remaining)
	return Rules.PAIR_TEXT[index]

func _special_description(index: int) -> String:
	if index == 2 and model.statuses[33].count > 0:
		return GameText.text("Adds +2.0 to DMG. Stacks with other bonuses.") + " " + _remaining_turns(model.statuses[33].count)
	return Rules.CITY_SPECIAL_TEXT[index] if model.is_city() else Rules.SPECIAL_TEXT[index]

func _draw_ending() -> void:
	draw_rect(Rect2(0, 80, 1280, 720), Color(0.06, 0.08, 0.05, 0.88))
	var won: bool = model.outcome() == "victory"
	var color: Color = GOLD if won else RED
	_frame(Rect2(350, 207, 580, 317), Color("39402e"), color)
	_rune(Vector2(640, 245), 5, color, 3)
	_center(Vector2(640, 284), "THE CITY REQUESTS A REFUND" if won else "BACK TO THE ABYSS", 16, color)
	_center(Vector2(640, 354), "VICTORY" if won else "DEFEAT", 48)
	_center(Vector2(640, 397), GameText.format("STAGE %d / %d   -   %d HP", [model.stage + 1, Run.WAVE_NAMES.size(), model.hp]), 16, MUTED)
	_button(REPLAY_RECT, "RESTART")
	if home_enabled: _button(_home_rect(), "HOME")

func _home_rect() -> Rect2:
	return Rect2(974, 96, 140, 36) if guide else Rect2(531, 548, 218, 53)

func _draw_guide(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(0, 0, 1280, 800), Color(0.06, 0.08, 0.05))
	_frame(Rect2(86, 76, 1108, 681), Color("333b2e"), GOLD, canvas)
	_text(Vector2(116, 126), "DICE GRIMOIRE", 32, GOLD, canvas)
	_button(GUIDE_CLOSE, "X", true, canvas)
	if home_enabled: _button(_home_rect(), "HOME", true, canvas)
	_text(Vector2(116, 165), "City rolls cast automatically after the reveal. Drag saved skills out for a bonus cast." if model.is_city() else "Drag skills to the field. Tap targeted skills to choose a foe. SAVE banks one bonus cast.", 16, CREAM, canvas)
	var caps: String = ["1/3", "1/3", "1/2", "3/4"][mini(model.stage,3)]
	_text(Vector2(116, 194), "CITY: 666 deals 2000 x DMG. Invincibility lasts 2 seconds per stack." if model.is_city() else GameText.format("Damage x DMG; bonuses add. Normal cap %s HP. Skills ignore caps; 666 clears the wave.", caps), 16, MUTED, canvas)
	_text(Vector2(116, 238), "PAIRS / SKILLS", 16, TEAL, canvas)
	_text(Vector2(656, 238), "TRIPLES / SPELLS", 16, PURPLE, canvas)
	canvas.draw_rect(Rect2(632, 220, 2, 478), EDGE.darkened(0.25))
	for i in range(6):
		var y: float = 280 + i * 67
		_text(Vector2(116, y), "%d%d  %s" % [i+1,i+1,GameText.text(Rules.PAIR_NAMES[i])], 16, TEAL, canvas)
		_wrapped(Vector2(116, y + 25), _pair_description(i), 496, MUTED, 16, canvas)
		_text(Vector2(656, y), "%d%d%d  %s" % [i+1,i+1,i+1,GameText.text(Rules.SPECIAL_NAMES[i])], 16, GOLD if i==5 else PURPLE, canvas)
		_wrapped(Vector2(656, y + 25), _special_description(i), 504, MUTED, 16, canvas)
	_text(Vector2(116, 713), "Perfect combo: +0.1 DMG per consecutive Perfect. A missed Perfect resets the combo.", 16, MUTED, canvas)
	_text(Vector2(116, 739), "Art: Dungeon Crawl Stone Soup / CC0    Sound: Kenney", 16, MUTED, canvas)

func _debug_option_rect(choice: int) -> Rect2:
	if choice == -1: return Rect2(136, 176, 250, 40)
	if choice == 0: return Rect2(407, 176, 360, 40)
	var face: int = choice if choice <= 6 else choice - 6
	return Rect2(136 + (face - 1) * 158, 282 if choice <= 6 else 449, 148, 103)

func _mini_die(at: Vector2, face: int, tint: Color = CREAM, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(at - Vector2(17, 17), Vector2(34, 36)), Color("6e583e"))
	canvas.draw_rect(Rect2(at - Vector2(16, 18), Vector2(32, 32)), tint)
	if face == 0:
		_center(at + Vector2(0, 4), "?", 16, INK, canvas)
		return
	var layouts := [[4], [0,8], [0,4,8], [0,2,6,8], [0,2,4,6,8], [0,2,3,5,6,8]]
	for pip in layouts[face - 1]:
		var p: Vector2 = at + Vector2((pip % 3 - 1) * 9 - 2, (floori(pip / 3.0) - 1) * 9 - 4)
		canvas.draw_rect(Rect2(p, Vector2(4, 4)), INK)

func _draw_debug(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(0, 0, 1280, 800), INK)
	_frame(Rect2(106, 100, 1070, 592), PANEL, GOLD, canvas)
	_text(Vector2(136, 148), "DEBUG", 32, GOLD, canvas)
	_button(DEBUG_CLOSE, "X", true, canvas)
	_button(_debug_option_rect(-1), "NATURAL RANDOM", true, canvas)
	_button(_debug_option_rect(0), "RANDOM SINGLES", true, canvas)
	_button(DEBUG_REPEAT, "REPEAT: " + ("ON" if debug_repeat else "OFF"), true, canvas)
	_button(DEBUG_PERFECT, "PERFECT: " + ("ON" if debug_perfect else "OFF"), true, canvas)
	if debug_perfect: canvas.draw_rect(DEBUG_PERFECT.grow(-3), GOLD, false, 2)
	_text(Vector2(136, 259), "DOUBLES / SKILLS", 16, TEAL, canvas)
	_text(Vector2(136, 426), "TRIPLES / SPELL", 16, PURPLE, canvas)
	for choice in range(1, 13):
		var rect: Rect2 = _debug_option_rect(choice)
		var face: int = choice if choice <= 6 else choice - 6
		var color: Color = TEAL if choice <= 6 else GOLD if choice == 12 else PURPLE
		_frame(rect, Color("53613d") if choice == debug_choice else PANEL, color if rect.has_point(get_global_mouse_position()) or choice == debug_choice else EDGE, canvas)
		for i in range(3):
			_mini_die(rect.position + Vector2(30 + i * 44, 38), 0 if choice <= 6 and i == 2 else face, CREAM.darkened(0.3) if choice <= 6 and i == 2 else CREAM, canvas)
		_center(rect.get_center() + Vector2(0, 32), "%d%d" % [face, face] if choice <= 6 else "%d%d%d" % [face, face, face], 16, color, canvas)
	_text(Vector2(136, 601), "Choose dice, load a wave, or add tarot cards.", 16, CREAM, canvas)
	_button(DEBUG_TAROTS,"GIVE ALL 22 TAROTS", true, canvas)
	_text(Vector2(136, 653), "WAVE", 16, GOLD, canvas)
	_button(DEBUG_WAVE_LOAD,"LOAD", true, canvas)
	_text(Vector2(548,653),debug_wave_error,16,RED, canvas)
