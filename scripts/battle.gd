extends Node2D

signal home_requested
var home_enabled: bool = false
var selected_ancient_id: String = "horror"
var selected_dice_id: String = "bone"

const Rules = preload("res://scripts/battle_rules.gd")
const Run = preload("res://scripts/run_rules.gd")
const Die = preload("res://scripts/die.gd")
const Effects = preload("res://scripts/effects.gd")
const Pixel = preload("res://scripts/pixel_paint.gd")
const City = preload("res://scripts/city_paint.gd")
const CityLife = preload("res://scripts/city_life.gd")
const ThrowMeter = preload("res://scripts/throw_meter.gd")
const INK := Color("171b1a")
const PANEL := Color("30352c")
const EDGE := Color("776448")
const CREAM := Color("eee0b9")
const MUTED := Color("aca486")
const TEAL := Color("aed085")
const GOLD := Color("dfb866")
const PURPLE := Color("c5a4de")
const RED := Color("e99b81")
const BOON_INDICES := [1, 2, 5] # Pair faces 2, 3 and 6; attacks stay in the grimoire.
# Layout geometry is instance-local; the portrait scene overrides it before setup.
var ARENA := Rect2(24, 80, 1232, 409)
var DICE_CENTER := Vector2(639, 640)
var DICE_RADIUS := 144.0
var DICE_POSITIONS := [Vector2(639, 570), Vector2(574, 675), Vector2(704, 675)]
var GUIDE_RECT := Rect2(1200, 24, 40, 34)
var AUDIO_RECT := Rect2(1100, 24, 40, 34)
var FX_RECT := Rect2(1150, 24, 40, 34)
var SPEED_RECT := Rect2(1038, 24, 50, 34)
var DEBUG_RECT := Rect2(958, 24, 68, 34)
var REPLAY_RECT := Rect2(531, 433, 218, 53)
var GUIDE_CLOSE := Rect2(1132, 96, 40, 36)
var DEBUG_CLOSE := Rect2(1120, 121, 42, 36)
var DEBUG_REPEAT := Rect2(888, 176, 252, 40)
var CITY_POINT := Vector2(925, 282)
const HUMAN_SIZES := [192.0, 96.0, 48.0, 24.0, 16.0]
const PAVING_SIZES := [96.0, 48.0, 24.0, 16.0, 16.0]
const SCENERY_SIZES := [128.0, 64.0, 32.0, 16.0, 12.0]

var model = Run.new()
var pixel_font: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf").duplicate()
var dice: Array = []
var fx: Node2D
var view_phase: String = "ready"
var result: Dictionary = {}
var last_result: Dictionary = {}
var ring_hover: float = 0
var art: Dictionary = {}
var clock_time: float = 0
var attack_target: int = -1
var muted: bool = false
var reduced: bool = false
var speed: float = 1.0
var guide: bool = false
var debug_open: bool = false
var debug_choice: int = -1 # -1 natural; 0 all-different; 1..6 pairs; 7..12 triples.
var debug_repeat: bool = false
var status_title: String = "READY"
var status_color: Color = TEAL
var active_human: int = -1
var hit_times: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
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
var debug_rng = RandomNumberGenerator.new()
var active_touch: int = -1
var touch_position := Vector2.ZERO
var throw_meter = ThrowMeter.new()
var charge_stamp: int = 0
var throw_power: float = 0
var throw_perfect: bool = false
var power_lock_until: float = 0

func _ready() -> void:
	_configure_layout()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	pixel_font.oversampling = 1.0
	debug_rng.randomize()
	for i in range(3):
		var die = Die.new()
		die.position = DICE_POSITIONS[i]
		die.face = i + 1
		add_child(die)
		die.landed.connect(_die_landed.bind(i))
		dice.append(die)
	fx = Effects.new()
	fx.font = pixel_font
	add_child(fx)
	_configure_effects()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			start_snapshot = arg.trim_prefix("--capture=")
	for key in ["eldritch", "vanguard", "archer", "mage", "civilian", "civilian_gray", "aristocrat", "floor0", "floor1", "floor2", "floor3", "stone", "arch", "column", "mangrove", "grass", "book", "shield", "attack", "heal", "feast", "crown", "fx"]:
		art[key] = load("res://assets/art/fantasy/" + key + ".png")
	for key in ["hit", "crash", "rumble", "bell", "slash", "chop", "book"]:
		sounds[key] = load("res://assets/audio/combat/" + key + ".ogg")
	for key in ["click_001", "drop_001", "confirmation_002", "bong_001", "pluck_001"]:
		sounds[key] = load("res://assets/audio/" + key + ".ogg")
	if AudioServer.get_bus_index("Combat") == -1:
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Combat")
		AudioServer.add_bus_effect(bus, AudioEffectLimiter.new())
	_start_round()
	if not start_snapshot.is_empty():
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(start_snapshot)
		get_tree().quit()

func _process(delta: float) -> void:
	clock_time += delta
	_update_charge()
	shake = maxf(0, shake - delta * 24)
	var camera_offset := Vector2.ZERO if reduced else (Vector2(sin(clock_time * 67), cos(clock_time * 83)) * shake).snapped(Vector2.ONE * 2)
	get_viewport().canvas_transform = Transform2D(0, camera_offset)
	for i in range(hit_times.size()):
		hit_times[i] = maxf(0, hit_times[i] - delta * 2.8)
	for index in fallen:
		fallen[index] += delta
	var modal: bool = guide or debug_open
	for die in dice:
		die.visible = not modal and view_phase not in ["over", "feeding", "transition"]
		die.set_process(not modal)
		die.reduced = reduced
		die.playback_rate = _roll_speed() / 2.0 if model.is_city() else 1.0
	fx.visible = not modal
	fx.set_process(not modal)
	if model.is_city() and not modal and view_phase in ["ready", "charging", "rolling", "resolving"]:
		_show_events(model.tick_city(delta))
		city_life.tick(delta, model.city_hp / float(Run.CITY_MAX_HP))
		if model.outcome() == "defeat" or view_phase != "resolving":
			_check_over()
	var mouse := _pointer_position()
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
	var interactive := in_ring or GUIDE_RECT.has_point(mouse) or DEBUG_RECT.has_point(mouse) or AUDIO_RECT.has_point(mouse) or FX_RECT.has_point(mouse) or SPEED_RECT.has_point(mouse)
	if guide:
		interactive = GUIDE_CLOSE.has_point(mouse) or (home_enabled and _home_rect().has_point(mouse))
	elif debug_open:
		interactive = DEBUG_CLOSE.has_point(mouse) or DEBUG_REPEAT.has_point(mouse)
		for i in range(-1, 13):
			interactive = interactive or _debug_option_rect(i).has_point(mouse)
	elif view_phase == "over":
		interactive = interactive or REPLAY_RECT.has_point(mouse) or (home_enabled and _home_rect().has_point(mouse))
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if interactive else Input.CURSOR_ARROW)
	queue_redraw()

func _exit_tree() -> void:
	get_viewport().canvas_transform = Transform2D.IDENTITY

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		active_touch = -1
		_cancel_charge()
	if what == NOTIFICATION_APPLICATION_PAUSED:
		active_touch = -1
		_cancel_charge()

func _configure_layout() -> void:
	pass

func _configure_effects() -> void:
	for die in dice:
		die.base_scale = 0.75
		die.scale = Vector2.ONE * die.base_scale

func _pointer_position() -> Vector2:
	return touch_position if active_touch >= 0 else get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			touch_position = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_click(touch_position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
		return
	if event is InputEventScreenDrag:
		if event.index == active_touch:
			touch_position = get_global_transform_with_canvas().affine_inverse() * event.position
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Touch is handled directly: ignore its synthesized mouse events.
	if event.device == -1 or active_touch >= 0:
		return
	if not event.pressed:
		return
	var mouse: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	_handle_click(mouse)

func _in_dice_range(mouse: Vector2) -> bool:
	return mouse.distance_squared_to(DICE_CENTER) <= DICE_RADIUS * DICE_RADIUS

func _handle_click(mouse: Vector2) -> void:
	_update_charge()
	if home_enabled and (guide or (view_phase == "over" and not debug_open)) and _home_rect().has_point(mouse):
		_cancel_charge()
		home_requested.emit()
		return
	if guide:
		if GUIDE_CLOSE.has_point(mouse): guide = false
		return
	if debug_open:
		if DEBUG_CLOSE.has_point(mouse): debug_open = false
		elif DEBUG_REPEAT.has_point(mouse): debug_repeat = not debug_repeat
		else:
			for i in range(-1, 13):
				if _debug_option_rect(i).has_point(mouse):
					debug_choice = i
					debug_open = false
					_sound("book", 1.4, -17)
		return
	if AUDIO_RECT.has_point(mouse):
		muted = not muted
		if muted:
			for child in get_children():
				if child is AudioStreamPlayer: child.queue_free()
		return
	if FX_RECT.has_point(mouse):
		reduced = not reduced
		fx.reduced = reduced
		if reduced: shake = 0
		return
	if view_phase in ["ready", "charging", "over"]:
		if GUIDE_RECT.has_point(mouse):
			guide = true
			_sound("book", 1.0, -14)
			return
		if DEBUG_RECT.has_point(mouse):
			debug_open = true
			return
	if view_phase == "over":
		if REPLAY_RECT.has_point(mouse): _restart()
		return
	if SPEED_RECT.has_point(mouse) and not model.is_city():
		speed = 2.0 if speed == 1.0 else 1.0
		return
	if _in_dice_range(mouse):
		if view_phase == "ready": _start_charge()
		elif view_phase == "charging": _release_charge()

func _start_charge() -> void:
	if view_phase != "ready" or guide or debug_open or not model.outcome().is_empty(): return
	throw_meter.reset()
	charge_stamp = Time.get_ticks_usec()
	power_lock_until = 0
	view_phase = "charging"
	status_title = "POWER"
	status_color = GOLD
	last_result = {}
	rattle_clock = 0
	for die in dice: die.charge(0)

func _update_charge() -> void:
	var now: int = Time.get_ticks_usec()
	if view_phase == "charging" and not guide and not debug_open:
		# Also sampled at click time, not rounded to the last rendered marker position.
		throw_meter.advance((now - charge_stamp) / 1000000.0)
		for die in dice: die.charge(throw_meter.sample().power)
	charge_stamp = now

func _release_charge() -> void:
	if view_phase != "charging" or guide or debug_open: return
	_update_charge()
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
	draw_rect(Rect2(center - ThrowMeter.PERFECT_TOLERANCE * unit, rect.position.y, 2 * ThrowMeter.PERFECT_TOLERANCE * unit, rect.size.y), CREAM)
	if flash > 0: draw_rect(rect, Color(1, 1, 1, flash))
	var marker: float = rect.position.x + stopped.position * rect.size.x
	draw_rect(Rect2(marker - unit * 5, rect.position.y - 6, unit * 10, rect.size.y + 12), INK)
	draw_rect(Rect2(marker - unit * 3, rect.position.y - 4, unit * 6, rect.size.y + 8), GOLD.lerp(Color.WHITE, flash))
	_center(Vector2(center, rect.position.y - 12), "POWER %d%%" % roundi(stopped.power * 100), text_size, GOLD)

func _stage_size(sizes: Array) -> float:
	var stage: float = clampf(visual_stage, 0, sizes.size()-1)
	var index: int = floori(stage)
	return lerpf(sizes[index], sizes[mini(index+1,sizes.size()-1)], stage-index)

func _enemy_side() -> float:
	return _stage_size(HUMAN_SIZES)

func _enemy_feet(index: int) -> Vector2:
	var count: int = model.enemies.size()
	if count == 8:
		return [Vector2(834,366),Vector2(884,359),Vector2(936,368),Vector2(986,362),Vector2(856,408),Vector2(907,415),Vector2(958,405),Vector2(1011,411)][index]
	if count == 5:
		return [Vector2(777,397),Vector2(855,369),Vector2(936,412),Vector2(1017,382),Vector2(1095,406)][index]
	if count == 3:
		return [Vector2(760,405),Vector2(935,379),Vector2(1100,417)][index]
	return Vector2(946,414)

func _enemy_point(index: int) -> Vector2:
	return _enemy_feet(index) - Vector2(0,_enemy_side()*0.48)

func _player_point() -> Vector2:
	return Vector2(259, 414 - monster_side * 0.48)

func _city_gate_point() -> Vector2:
	return City.gate_point()

func _city_wall_point(section: float) -> Vector2:
	return City.wall_point(section)

func _roll_speed() -> float:
	return 2.0 if model.is_city() else speed

func _start_round() -> void:
	_show_events(model.begin_round())
	result = {}
	view_phase = "ready"
	status_title = "FEVER" if model.is_city() else "READY"
	status_color = GOLD if model.is_city() else TEAL
	active_human = -1
	attack_target = -1

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
	if view_phase != "ready" or guide or debug_open or not model.outcome().is_empty(): return
	var token: int = run_id
	if model.is_city() and model.phase == "round_end": _show_events(model.begin_round())
	if model.phase != "roll": return
	throw_power = clampf(strength, 0, 1)
	throw_perfect = perfect
	view_phase = "rolling"
	var forced: Array = _debug_values()
	result = model.roll(throw_power, throw_perfect) if forced.is_empty() else model.set_test_roll(forced)
	if not debug_repeat: debug_choice = -1
	last_result = {}
	status_title = "ROLLING"
	status_color = CREAM
	fx.activate_circle(DICE_CENTER, GOLD, DICE_RADIUS, 0.8 / _roll_speed())
	_sound("slash", lerpf(1.6, 0.8, throw_power), lerpf(-27, -14, throw_power))
	if throw_power > 0.7: _sound("rumble", 1.2, -24 + throw_power * 5)
	if throw_perfect:
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
			fx.flash(status_color, 0.1)
			_sound("bong_001", 0.8 if kind == Rules.Kind.SPECIAL else 0.55, -8)
			if not await _combo_chime(kind == Rules.Kind.ULTIMATE, token): return
	fx.channel_dice(result.dice, DICE_POSITIONS, DICE_CENTER, _player_point(), 0 if kind == Rules.Kind.NORMAL else result.face, status_color, 0.85 / _roll_speed())
	_sound("bell", 1.2, -20)
	if not await _wait(0.85, token): return
	fx.activate_circle(_player_point(), status_color, monster_side * 0.4, 0.45)
	fx.burst(_player_point(), status_color, 25, 100)
	_sound("confirmation_002", 0.85, -18)
	_reveal_skill(result)
	attack_target = model.player_target()
	await _resolve_player(attack_target)

func _combo_chime(ultimate: bool, token: int) -> bool:
	for pitch in [1.0, 1.25, 1.5, 2.0]:
		_sound("pluck_001", pitch * (0.75 if ultimate else 1.0), -14)
		if not await _wait(0.09, token): return false
	return true

func _reveal_skill(roll: Dictionary) -> void:
	var label: String = Rules.NORMAL_NAME
	var description: String = "attack"
	if roll.kind == Rules.Kind.PAIR:
		label = Rules.PAIR_NAMES[roll.face - 1]
		description = ["attack x1.5 +%d", "regen 5, %d turns", "power x1.5, %d turns", "attack all +%d", "3 hits +%d", "invincible, %d turns"][roll.face - 1] % roll.spare
	elif roll.kind >= Rules.Kind.SPECIAL:
		label = Rules.SPECIAL_NAMES[roll.face - 1]
		description = ["instant kill", "full heal", "power x3, 3 turns", "attack all x2", "6 quick hits", ""][roll.face - 1]
		if model.is_city() and roll.face == 1: description = "attack x5"
	fx.reveal_skill(label, description, status_color)

func _die_landed(index: int) -> void:
	_sound("drop_001", 0.95 + index * 0.13 - throw_power * 0.25, -17 + throw_power * 7)
	fx.burst(dice[index].position + Vector2(0, 35), GOLD, roundi(12 + throw_power * 18), 90 + throw_power * 70)

func _resolve_player(target: int) -> void:
	if model.phase != "player" or result.is_empty() or view_phase == "resolving" or not model.outcome().is_empty(): return
	var token: int = run_id
	view_phase = "resolving"
	var kind: int = result.kind
	var attacking: bool = Rules.is_attack(result)
	status_title = "CASTING" if kind >= Rules.Kind.SPECIAL else "ATTACKING" if attacking else "BLESSED"
	if not attacking:
		fx.activate_circle(_player_point(), TEAL, monster_side * 0.45, 0.85)
		fx.burst(_player_point(), TEAL, 30)
		_sound("bell", 1.6, -16)
		if not await _wait(0.3, token): return
		_show_events(model.apply_player_step())
	else:
		var count: int = Rules.hit_count(result)
		for impact in range(count):
			if not _valid_turn(token) or not model.outcome().is_empty(): break
			if impact > 0: target = model.player_target()
			attack_target = target
			var targets: Array = [CITY_POINT] if model.is_city() else []
			if not model.is_city():
				for hit in model.preview(result, target): targets.append(_enemy_point(hit.target))
			var face: int = result.face if kind >= Rules.Kind.SPECIAL or kind == Rules.Kind.PAIR else 0
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
			if not await _wait(0.10, token): return
	if not await _wait(0.75 if kind == Rules.Kind.ULTIMATE else 0.27, token): return
	attack_target = -1
	if _check_over(): return
	if model.is_city():
		result = {}
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
		if not human.canceled and human.intent.type == "attack":
			fx.enemy_cast(human.role, _enemy_point(i), _player_point(), 0.22 / speed)
			_sound("slash" if human.role != 2 else "bell", 1.4, -17)
			if not await _wait(0.18, token): return
		var events: Array = model.enemy_act(i)
		if not human.canceled and human.intent.type != "attack" and events.size() > 0:
			fx.activate_circle(_enemy_point(human.intent.target), TEAL, maxf(12,_enemy_side()*0.22), 0.4)
			_sound("bell", 1.7, -20)
		_show_events(events)
		_sync_corpses()
		if not await _wait(0.24, token): return
		if _check_over(): return
	active_human = -1
	model.end_round()
	_start_round()

func _sync_corpses() -> void:
	for i in range(model.enemies.size()):
		if model.enemies[i].hp <= 0 and not fallen.has(i):
			fallen[i] = 0.0
			fx.burst(_enemy_point(i), Color("b9857c"), 14, 80)
			_sound("chop", 0.7, -15)

func _check_over() -> bool:
	var outcome: String = model.outcome()
	if outcome.is_empty(): return false
	if outcome == "wave_clear":
		if view_phase not in ["feeding", "transition"]: _advance_wave()
		return true
	if view_phase == "over": return true
	view_phase = "over"
	for die in dice: die.stop_charge()
	active_human = -1
	if outcome == "victory":
		fx.activate_circle(CITY_POINT, GOLD, 200, 1.5)
		fx.burst(CITY_POINT, GOLD, 120, 320)
		_sound("crash", 0.55, -8)
		_sound("bell", 0.65, -12)
	else:
		_sound("rumble", 0.5, -13)
	return true

func _advance_wave() -> void:
	var token: int = run_id
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
	transition_tween.tween_property(self, "monster_side", minf(320,224.0 + model.stage * 32), 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "visual_stage", float(model.stage), 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "background_offset", background_offset + 960, 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "travel_progress", 1.0, 1.65 / speed)
	while transition_tween.is_running() and _valid_turn(token):
		await get_tree().process_frame
	if not _valid_turn(token): return
	_start_round()
	fx.activate_circle(_player_point() + Vector2(0, 60), GOLD, 100, 0.7)

func _restart() -> void:
	run_id += 1
	if transition_tween and transition_tween.is_running(): transition_tween.kill()
	model.reset_run()
	fx.clear()
	last_result = {}
	result = {}
	fallen.clear()
	city_corpses.clear()
	city_life.clear()
	corpse_alpha = 1
	visual_stage = 0
	monster_side = 224
	background_offset = 0
	travel_progress = 0
	throw_meter.reset()
	throw_power = 0
	throw_perfect = false
	power_lock_until = 0
	guide = false
	active_touch = -1
	debug_open = false
	debug_choice = -1
	debug_repeat = false
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

func _show_events(events: Array) -> void:
	var offsets: Dictionary = {}
	for event in events:
		var point: Vector2 = _player_point() if event.target == -1 else CITY_POINT if event.target == -2 else _enemy_point(event.target)
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
		var color: Color = RED if event.type == "damage" else PURPLE if event.type == "cancel" else TEAL
		var label: String = "INVINCIBLE" if event.type == "immune" else "-%d" % event.amount if event.type == "damage" else "+%d" % event.amount if event.type == "heal" else "DAZED" if event.type == "cancel" else "+ BOON"
		var offset: int = offsets.get(event.target, 0)
		fx.floating(point - Vector2(0, 45 + offset), label, color)
		offsets[event.target] = offset + 24
		if event.type == "damage":
			if event.target >= -1: hit_times[event.target + 1] = 1.0
			if event.amount > 0:
				fx.slash(point, event.target == -2)
				if event.target == -1: _sound("hit", 0.8, -17)
				elif event.target == -2:
					fx.burst(CITY_POINT, GOLD, 16, 190)
					city_life.sync_destruction(model.city_hp / float(Run.CITY_MAX_HP))

func _valid_turn(token: int) -> bool:
	return token == run_id and is_inside_tree() and view_phase != "over"

func _wait(seconds: float, token: int = -1) -> bool:
	await get_tree().create_timer(seconds / _roll_speed()).timeout
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
	_draw_console()
	_draw_dice_circle()
	if view_phase == "over":
		_draw_ending()
	if guide:
		_draw_guide()
	elif debug_open:
		_draw_debug()
	else:
		_draw_tooltips()

func _text(at: Vector2, value: String, size: int = 16, color: Color = CREAM) -> void:
	# Pixel font, integer baselines, no smoothing or fallback to a vector font.
	var p := at.round()
	draw_string(pixel_font, p + Vector2(2, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, color.a))
	draw_string(pixel_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(at: Vector2, value: String, size: int = 16, color: Color = CREAM) -> void:
	var width: float = pixel_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(at - Vector2(width / 2, 0), value, size, color)

func _wrapped(at: Vector2, value: String, width: float, color: Color = MUTED, size: int = 16) -> float:
	var row := ""
	var y := at.y
	for word in value.split(" "):
		var candidate: String = word if row.is_empty() else row + " " + word
		if not row.is_empty() and pixel_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			_text(Vector2(at.x, y), row, size, color)
			y += size + 6
			row = word
		else:
			row = candidate
	_text(Vector2(at.x, y), row, size, color)
	return y

func _art(key: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if art.has(key):
		draw_texture_rect(art[key], Rect2(rect.position.round(), rect.size), false, tint)

func _stone(rect: Rect2, tint: Color, key: String = "stone", unit: int = 64) -> void:
	draw_rect(rect, PANEL)
	if not art.has(key): return
	for y in range(int(rect.position.y), int(rect.end.y), unit):
		for x in range(int(rect.position.x), int(rect.end.x), unit):
			var size := Vector2(minf(unit, rect.end.x - x), minf(unit, rect.end.y - y))
			# Crop the dark grout from UI stone so it does not compete with text.
			var inset: float = 3.0 if key == "stone" else 0.0
			draw_texture_rect_region(art[key], Rect2(Vector2(x, y), size), Rect2(Vector2.ONE * inset, size * (32.0 - inset * 2) / unit), tint)

func _frame(rect: Rect2, fill: Color = PANEL, border: Color = EDGE) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(INK, 0.6))
	_stone(rect, fill)
	draw_rect(rect, INK, false, 4)
	draw_rect(rect.grow(-3), border.darkened(0.35), false, 2)
	draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 2)), border)
	draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(2, rect.size.y - 10)), border)
	for p in [rect.position + Vector2(5, 5), Vector2(rect.end.x - 9, rect.position.y + 5), rect.end - Vector2(9, 9), Vector2(rect.position.x + 5, rect.end.y - 9)]:
		draw_rect(Rect2(p, Vector2(4, 4)), border.lightened(0.2))

func _button(rect: Rect2, value: String, enabled: bool = true) -> void:
	var hover: bool = enabled and rect.has_point(get_global_mouse_position())
	_frame(rect, Color("5f563a") if hover else Color("443c2d"), GOLD if hover else EDGE)
	_center(rect.get_center() + Vector2(0, 6), value, 16, GOLD if enabled else MUTED)

func _draw_header() -> void:
	_text(Vector2(42, 53), "%d / %d" % [model.stage + 1, Run.WAVE_NAMES.size()], 32, GOLD)
	_button(SPEED_RECT, "%.1f" % _roll_speed() if model.is_city() else "2x" if speed == 2 else "1x")
	_button(DEBUG_RECT, "DBG")
	for rect in [AUDIO_RECT, FX_RECT, GUIDE_RECT]:
		_frame(rect, Color("443c2d"), GOLD if rect.has_point(get_global_mouse_position()) else EDGE)
	_glyph(AUDIO_RECT.get_center(), "mute" if muted else "sound", MUTED if muted else GOLD)
	_glyph(FX_RECT.get_center(), "fx", MUTED if reduced else GOLD)
	_art("book", Rect2(GUIDE_RECT.get_center() - Vector2(16, 16), Vector2(32, 32)))

func _arena_art(key: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var clipped: Rect2 = rect.intersection(ARENA.grow(-6))
	if not clipped.has_area(): return
	var ratio: Vector2 = Vector2(art[key].get_size()) / rect.size
	draw_texture_rect_region(art[key], clipped, Rect2((clipped.position - rect.position) * ratio, clipped.size * ratio), tint)

func _draw_arena() -> void:
	draw_rect(ARENA, Color("a5a182"))
	var tile: int = roundi(_stage_size(PAVING_SIZES))
	var shift: int = int(background_offset) % tile
	var tint: Color = Color("b6b8a0").lerp(Color("c3a889"), visual_stage / 4.0)
	var city_blend: float = clampf(visual_stage - 3, 0, 1)
	var field_blend: float = clampf((visual_stage-1)/2.0,0,1)
	for y in range(80, 489, tile):
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
	if model.is_city(): _draw_city()
	_draw_player()
	if not model.is_city():
		for i in range(model.enemies.size()): _draw_human(i)
	for i in range(4):
		draw_rect(Rect2(24, 477 + i * 3, 1232, 3), Color(INK, 0.08 + i * 0.06))
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
		_art(["vanguard", "archer", "mage"][corpse.role], Rect2(-8, -8, 16, 16), Color("796c64"))
		draw_set_transform(Vector2.ZERO)
	for i in range(model.troops):
		var point := _troop_point(i)
		var stride: float = city_life.clock * 16 + i * 2.3
		var hop: float = 0 if reduced else snappedf(absf(sin(stride)) * 2, 1)
		var lean: float = 0 if reduced else sin(stride) * 0.16
		_shadow(point, 5, 0.22)
		draw_set_transform((point - Vector2(0, hop)).round(), lean)
		_art(["vanguard", "archer", "mage"][i % 3], Rect2(-8, -16, 16, 16))
		draw_set_transform(Vector2.ZERO)
	_hp_plate(Rect2(531, 88, 683, 55), "THE CITY", model.city_hp, Run.CITY_MAX_HP, 0, GOLD)
	if model.volley_warned:
		_center(City.wall_point(0) - Vector2(15,61), "VOLLEY", 16, RED)

func _shadow(point: Vector2, radius: float, alpha: float) -> void:
	Pixel.disc(self, point, radius, Color(INK, alpha), 8, 0.19)

func _draw_player() -> void:
	var hurt: float = hit_times[0]
	var bob: float = 0 if reduced else snappedf(sin(clock_time * (8 if view_phase == "transition" else 1.8)) * 3, 2)
	var dx: float = snappedf(sin(clock_time * 45) * hurt * 5, 2) if not reduced else 0.0
	_shadow(Vector2(259, 413), monster_side * 0.48, 0.27)
	if model.shield > 0 or model.buffs[6] > 0: Pixel.circle(self, _player_point(), monster_side * 0.47, Color(TEAL, 0.45), 4)
	_art("eldritch", Rect2(Vector2(259 - monster_side / 2 + dx, 414 - monster_side + bob), Vector2.ONE * monster_side), Color.WHITE.lerp(RED, hurt * 0.6))
	_hp_plate(Rect2(129, 422, 260, 56), "HORROR " + ["I", "II", "III", "IV", "V"][model.stage], model.hp, model.max_hp, model.shield, TEAL)

func _draw_human(index: int) -> void:
	if view_phase == "transition": return
	var human: Dictionary = model.enemies[index]
	var point: Vector2 = _enemy_point(index)
	var floor_y: float = _enemy_feet(index).y
	var side: float = _enemy_side()
	var width: float = 128 if model.enemies.size() == 3 else 168
	var key: String = ["vanguard", "archer", "mage"][human.role]
	var selected: bool = attack_target == index and view_phase == "resolving"
	if human.hp <= 0:
		var t: float = minf(1, fallen.get(index, 1.0) / 0.3)
		var center: Vector2 = point.lerp(Vector2(point.x, floor_y-side*0.08), t)
		_shadow(Vector2(point.x, floor_y-2), side * 0.42, 0.2 * corpse_alpha)
		draw_set_transform(center, t * PI / 2, Vector2(lerpf(1, 0.36, t), 1))
		_art(key, Rect2(Vector2.ONE * -side / 2, Vector2.ONE * side), Color(0.64, 0.52, 0.49, corpse_alpha))
		draw_set_transform(Vector2.ZERO)
		return
	if selected or active_human == index:
		var color: Color = GOLD if selected else RED
		Pixel.disc(self, Vector2(point.x, floor_y-2), side * 0.35, Color(color, 0.35), 6, 0.23)
		_rune(point - Vector2(0, side * 0.55), 3, color, 3)
	var hurt: float = hit_times[index + 1]
	var dx: float = snappedf(sin(clock_time * 46) * hurt * minf(6,side*0.03), 2) if not reduced else 0.0
	var bob: float = 0 if reduced else snappedf(sin(clock_time * 2 + index * 2) * minf(2,side/64.0), 2)
	_shadow(Vector2(point.x, floor_y-1), side * 0.25, 0.25)
	_art(key, Rect2(Vector2(point.x - side / 2 + dx, floor_y - side + bob), Vector2.ONE * side), Color.WHITE.lerp(RED, hurt * 0.6))
	if human.canceled: _glyph(point - Vector2(0, side * 0.5), "close", PURPLE)
	elif active_human == index: _glyph(point - Vector2(0, side * 0.62), human.intent.type, RED if human.intent.type == "attack" else TEAL)
	if model.enemies.size() >= 5:
		_draw_small_enemy_health(index)
		return
	var title: String = ["VANGUARD", "ARCHER", "MAGE"][human.role] if model.enemies.size() == 5 else human.name.to_upper()
	_hp_plate(Rect2(point.x - width / 2, floor_y + 8, width, 56), title, human.hp, human.max_hp, human.shield, RED)

func _draw_small_enemy_health(index: int) -> void:
	var human: Dictionary = model.enemies[index]
	var point: Vector2 = _enemy_point(index)
	var floor_y: float = _enemy_feet(index).y
	var bar_width: float = 40 if model.enemies.size() == 8 else 52
	var bar := Rect2(point.x-bar_width/2, floor_y-_enemy_side()-19 if model.enemies.size()==8 and index<4 else floor_y+7, bar_width,14)
	draw_rect(bar.grow(2), EDGE)
	draw_rect(bar, INK)
	draw_rect(Rect2(bar.position+Vector2(2,2),Vector2((bar_width-4)*human.hp/float(human.max_hp),10)),RED.darkened(0.3))
	_center(bar.get_center()+Vector2(0,5), str(human.hp), 12, CREAM)
	if human.shield > 0:
		_glyph(bar.position+Vector2(5,-10),"shield",TEAL)
		_text(bar.position+Vector2(17,-5),str(human.shield),12,TEAL)

func _hp_plate(rect: Rect2, title: String, hp: int, maximum: int, shield: int, color: Color) -> void:
	_frame(rect, Color("32382c"), EDGE)
	_center(Vector2(rect.get_center().x, rect.position.y + 22), title, 16, CREAM if hp else MUTED)
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

func _boon_center(index: int) -> Vector2:
	return Vector2(92 + BOON_INDICES.find(index) * 103, 655)

func _boon_rect(index: int) -> Rect2:
	return Rect2(_boon_center(index) - Vector2(36, 36), Vector2(72, 72))

func _draw_console() -> void:
	_frame(Rect2(34, 574, 322, 142), Color("363b2e"))
	_center(Vector2(195, 602), "BOONS", 16, GOLD)
	var icons := ["attack", "heal", "crown", "thorns", "feast", "shield"]
	for i in BOON_INDICES:
		var center := _boon_center(i)
		var amount: int = model.boon_turns(i + 1)
		var active: bool = amount > 0
		_frame(_boon_rect(i), Color("53613d") if active else Color("34372d"), TEAL if active else EDGE.darkened(0.3))
		_glyph(center - Vector2(0, 3), icons[i], TEAL if active else MUTED.darkened(0.4), 2)
		if active:
			draw_rect(Rect2(center + Vector2(15, 14), Vector2(28, 24)), INK)
			_center(center + Vector2(29, 32), str(amount), 16, TEAL)
	_frame(Rect2(905, 524, 341, 231), Color("363b2e"))
	_center(Vector2(1075, 557), "CITY FEVER" if model.is_city() else "OMEN", 20 if model.is_city() else 16, GOLD)
	if not model.is_city() and view_phase != "charging": _center(Vector2(1075, 597), status_title, 16, status_color)
	if model.is_city():
		_center(Vector2(1075, 606), "%.1fx" % _roll_speed(), 44, GOLD)
		_center(Vector2(1075, 737), "CLICK TO STOP" if view_phase == "charging" else "CLICK TO CHARGE" if view_phase == "ready" else "LOCKED", 20, GOLD)
	elif debug_choice >= 0:
		_center(Vector2(1075, 728), "DEBUG QUEUED", 16, PURPLE)
	else:
		_center(Vector2(1075, 728), "CLICK TO CHARGE" if view_phase == "ready" else "", 16, GOLD)
	if _power_meter_visible():
		_draw_power_meter(Rect2(931, 672 if model.is_city() else 628, 288, 28))
		if not model.is_city(): _center(Vector2(1075, 699), "CLICK TO STOP" if view_phase == "charging" else "LOCKED", 16, GOLD)

func _draw_dice_circle() -> void:
	var layout_scale: float = DICE_RADIUS / 144.0
	var available: bool = view_phase in ["ready", "charging"] and not guide and not debug_open
	var fever: bool = model.is_city() and view_phase in ["ready", "charging", "rolling", "resolving"] and not guide and not debug_open
	var color: Color = GOLD if available or fever else status_color
	Pixel.disc(self, DICE_CENTER + Vector2(0, 6), DICE_RADIUS + 6, Color(INK, 0.7))
	Pixel.disc(self, DICE_CENTER, DICE_RADIUS, Color("303529"))
	Pixel.disc(self, DICE_CENTER, DICE_RADIUS - 10, Color("252d25"))
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
	for offset in [0.0, PI]:
		for i in range(3):
			var a: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + offset + i * TAU / 3) * 106 * layout_scale
			var b: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + offset + (i + 1) * TAU / 3) * 106 * layout_scale
			Pixel.line(self, a, b, Color(color, 0.35 + ring_hover * 0.25), 2)
	for i in range(12):
		var p: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + i * TAU / 12) * 124 * layout_scale
		_rune(p.snapped(Vector2.ONE * 2), i % 6, Color(color, 0.65 + ring_hover * 0.35), 2)
	if not last_result.is_empty() and last_result.kind != Rules.Kind.NORMAL:
		var match_color: Color = [CREAM, TEAL, PURPLE, GOLD][last_result.kind]
		for i in range(3):
			for j in range(i + 1, 3):
				if last_result.dice[i] == last_result.dice[j]:
					Pixel.line(self, DICE_POSITIONS[i], DICE_POSITIONS[j], Color(match_color, 0.75), 3)
	var label: String = "STOP!" if view_phase == "charging" else "CHARGE" if available else "..."
	_center(DICE_CENTER + Vector2(0, 104 * layout_scale), label, roundi((22 if fever else 16) * layout_scale), color if available or fever else MUTED)
	if available and ring_hover > 0.1:
		var at := get_global_mouse_position().snapped(Vector2.ONE * 2)
		Pixel.line(self, at - Vector2(10, 0), at + Vector2(10, 0), Color(GOLD, ring_hover), 2)
		Pixel.line(self, at - Vector2(0, 10), at + Vector2(0, 10), Color(GOLD, ring_hover), 2)

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
	if GUIDE_RECT.has_point(mouse): value = "Dice grimoire"
	elif AUDIO_RECT.has_point(mouse): value = "Sound off" if muted else "Sound on"
	elif FX_RECT.has_point(mouse): value = "Reduced effects" if reduced else "Full effects"
	elif SPEED_RECT.has_point(mouse): value = "Fever speed" if model.is_city() else "Animation speed"
	elif DEBUG_RECT.has_point(mouse): value = "Debug dice picker"
	if not value.is_empty():
		_frame(Rect2(988, 66, 256, 36), PANEL, GOLD)
		_center(Vector2(1116, 91), value, 16, CREAM)
	for i in BOON_INDICES:
		if _boon_rect(i).has_point(mouse):
			_frame(Rect2(38, 405, 566, 111), PANEL, GOLD)
			_text(Vector2(55, 433), _boon_label(i), 16, TEAL)
			var description: String = _boon_description(i)
			_wrapped(Vector2(55, 462), description, 526, CREAM)

func _boon_label(index: int) -> String:
	return "333  " + Rules.SPECIAL_NAMES[2] if index == 2 and model.buffs[33] > 0 else "%d%d  %s" % [index+1,index+1,Rules.PAIR_NAMES[index]]

func _boon_description(index: int) -> String:
	return _special_description(2) if index == 2 and model.buffs[33] > 0 else _pair_description(index)

func _remaining_turns(amount: int) -> String:
	return "%d %s remaining." % [amount, "turn" if amount == 1 else "turns"]

func _pair_description(index: int) -> String:
	var remaining: int = int(model.buffs.get(index + 1, 0))
	if remaining > 0:
		match index:
			1: return "Heal 5 at turn start. " + _remaining_turns(remaining)
			2: return "1.5x attack power. " + _remaining_turns(remaining)
			5: return "Invincible. " + _remaining_turns(remaining)
	return Rules.PAIR_TEXT[index]

func _special_description(index: int) -> String:
	if index == 2 and model.buffs[33] > 0:
		return "3x attack power. " + _remaining_turns(model.buffs[33])
	return Rules.CITY_SPECIAL_TEXT[index] if model.is_city() else Rules.SPECIAL_TEXT[index]

func _draw_ending() -> void:
	draw_rect(Rect2(0, 80, 1280, 720), Color(0.06, 0.08, 0.05, 0.88))
	var won: bool = model.outcome() == "victory"
	var color: Color = GOLD if won else RED
	_frame(Rect2(350, 207, 580, 317), Color("39402e"), color)
	_rune(Vector2(640, 245), 5, color, 3)
	_center(Vector2(640, 284), "THE CITY REQUESTS A REFUND" if won else "BACK TO THE ABYSS", 16, color)
	_center(Vector2(640, 354), "VICTORY" if won else "DEFEAT", 48)
	_center(Vector2(640, 397), "STAGE %d / %d   -   %d HP" % [model.stage + 1, Run.WAVE_NAMES.size(), model.hp], 16, MUTED)
	_button(REPLAY_RECT, "RESTART")
	if home_enabled: _button(_home_rect(), "HOME")

func _home_rect() -> Rect2:
	return Rect2(974, 96, 140, 36) if guide else Rect2(531, 548, 218, 53)

func _draw_guide() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.06, 0.08, 0.05, 0.97))
	_frame(Rect2(86, 76, 1108, 681), Color("333b2e"), GOLD)
	_text(Vector2(116, 126), "DICE GRIMOIRE", 32, GOLD)
	_button(GUIDE_CLOSE, "X")
	if home_enabled: _button(_home_rect(), "HOME")
	_text(Vector2(116, 165), "Click to charge; click again to throw. Aim for the center. City attacks continue while charging." if model.is_city() else "Click to charge; click again to throw. Aim for the center. Attacks choose foes; pairs auto-apply.", 16, CREAM)
	var caps: String = ["1/3", "1/3", "1/2", "3/4"][mini(model.stage,3)]
	_text(Vector2(116, 194), "CITY: 666 deals 800 damage and clears troops. Buff durations count rolls." if model.is_city() else "Damage x1.5 + growth. Normal cap %s HP. Skills ignore caps; 666 clears the wave." % caps, 16, MUTED)
	_text(Vector2(116, 238), "PAIRS / SKILLS", 16, TEAL)
	_text(Vector2(656, 238), "TRIPLES / SPELLS", 16, PURPLE)
	draw_rect(Rect2(632, 220, 2, 478), EDGE.darkened(0.25))
	for i in range(6):
		var y: float = 280 + i * 67
		_text(Vector2(116, y), "%d%d  %s" % [i+1,i+1,Rules.PAIR_NAMES[i]], 16, TEAL)
		_wrapped(Vector2(116, y + 25), _pair_description(i), 496)
		_text(Vector2(656, y), "%d%d%d  %s" % [i+1,i+1,i+1,Rules.SPECIAL_NAMES[i]], 16, GOLD if i==5 else PURPLE)
		_wrapped(Vector2(656, y + 25), _special_description(i), 504)
	_text(Vector2(116, 713), "Perfect: guaranteed triple in city fever; pair or triple elsewhere. City speed is fixed at 2x.", 16, MUTED)
	_text(Vector2(116, 739), "Art: Dungeon Crawl Stone Soup / CC0    Sound: Kenney", 16, MUTED)

func _debug_option_rect(choice: int) -> Rect2:
	if choice == -1: return Rect2(136, 176, 250, 40)
	if choice == 0: return Rect2(407, 176, 360, 40)
	var face: int = choice if choice <= 6 else choice - 6
	return Rect2(136 + (face - 1) * 158, 282 if choice <= 6 else 449, 148, 103)

func _mini_die(at: Vector2, face: int, tint: Color = CREAM) -> void:
	draw_rect(Rect2(at - Vector2(17, 17), Vector2(34, 36)), Color("6e583e"))
	draw_rect(Rect2(at - Vector2(16, 18), Vector2(32, 32)), tint)
	if face == 0:
		_center(at + Vector2(0, 4), "?", 16, INK)
		return
	var layouts := [[4], [0,8], [0,4,8], [0,2,6,8], [0,2,4,6,8], [0,2,3,5,6,8]]
	for pip in layouts[face - 1]:
		var p: Vector2 = at + Vector2((pip % 3 - 1) * 9 - 2, (floori(pip / 3.0) - 1) * 9 - 4)
		draw_rect(Rect2(p, Vector2(4, 4)), INK)

func _draw_debug() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(INK, 0.96))
	_frame(Rect2(106, 100, 1070, 592), PANEL, GOLD)
	_text(Vector2(136, 148), "DEBUG DICE", 32, GOLD)
	_button(DEBUG_CLOSE, "X")
	_button(_debug_option_rect(-1), "NATURAL RANDOM")
	_button(_debug_option_rect(0), "RANDOM SINGLES")
	_button(DEBUG_REPEAT, "REPEAT: " + ("ON" if debug_repeat else "OFF"))
	_text(Vector2(136, 259), "DOUBLES / SKILLS", 16, TEAL)
	_text(Vector2(136, 426), "TRIPLES / SPELL", 16, PURPLE)
	for choice in range(1, 13):
		var rect: Rect2 = _debug_option_rect(choice)
		var face: int = choice if choice <= 6 else choice - 6
		var color: Color = TEAL if choice <= 6 else GOLD if choice == 12 else PURPLE
		_frame(rect, Color("53613d") if choice == debug_choice else PANEL, color if rect.has_point(get_global_mouse_position()) or choice == debug_choice else EDGE)
		for i in range(3):
			_mini_die(rect.position + Vector2(30 + i * 44, 38), 0 if choice <= 6 and i == 2 else face, CREAM.darkened(0.3) if choice <= 6 and i == 2 else CREAM)
		_center(rect.get_center() + Vector2(0, 32), "%d%d" % [face, face] if choice <= 6 else "%d%d%d" % [face, face, face], 16, color)
	_text(Vector2(136, 601), "Choose a result, then click the magic circle.", 16, CREAM)
	_text(Vector2(136, 628), "Singles = three different faces. Doubles randomize the spare die.", 16, MUTED)
	_text(Vector2(136, 655), "One roll only unless Repeat is on. The city pauses while this is open.", 16, MUTED)
