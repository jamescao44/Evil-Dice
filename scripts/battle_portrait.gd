extends "res://scripts/battle.gd"
## Alternate presentation only. Rolls, combat, growth, timings and audio are inherited.
## 804x1748 = twice the iPhone 16 Pro's 402x874 logical display size.
const PORTRAIT_SIZE := Vector2i(804, 1748)
const CITY_TRANSFORM := Transform2D(Vector2(0.9, 0), Vector2(0, 0.9), Vector2(-390, 336))
const GUIDE_PAIRS := Rect2(40, 432, 350, 88)
const GUIDE_TRIPLES := Rect2(414, 432, 350, 88)
var guide_page: int = 0
var selected_status: int = -1
var status_until: float = 0

func _configure_layout() -> void:
	var window := get_window()
	window.content_scale_size = PORTRAIT_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if OS.get_name() in ["iOS", "Android"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	# The browser owns the canvas size, including its device-pixel ratio.
	# Forcing the desktop preview size here shrinks the WebGL drawing viewport.
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless" and OS.get_name() not in ["iOS", "Android"]:
		window.size = Vector2i(402, 874)
		window.move_to_center()
	window.title = "Evil Dice | Portrait"
	# All controls sit below the island and above the home-indicator safe zones.
	ARENA = Rect2(24, 228, 756, 794)
	DICE_CENTER = Vector2(402, 1448)
	DICE_RADIUS = 232
	DICE_POSITIONS = [Vector2(402, 1338), Vector2(296, 1508), Vector2(508, 1508)]
	DEBUG_RECT = Rect2(280, 124, 88, 88)
	SPEED_RECT = Rect2(378, 124, 88, 88)
	AUDIO_RECT = Rect2(476, 124, 88, 88)
	FX_RECT = Rect2(574, 124, 88, 88)
	GUIDE_RECT = Rect2(672, 124, 88, 88)
	GUIDE_CLOSE = Rect2(660, 132, 104, 88)
	DEBUG_CLOSE = GUIDE_CLOSE
	DEBUG_REPEAT = Rect2(40, 1470, 350, 88)
	DEBUG_PERFECT = Rect2(414, 1470, 350, 88)
	REPLAY_RECT = Rect2(162, 1360, 480, 104)
	REWARD_CENTER = Vector2(402,1090)
	CITY_POINT = CITY_TRANSFORM * Vector2(925, 282)

func _configure_effects() -> void:
	fx.canvas_size = Vector2(PORTRAIT_SIZE)
	fx.skill_anchor = Vector2(402, 620)
	fx.skill_max_width = 716
	fx.combo_font_size = 80
	fx.ultimate_center = Vector2(448, 602)
	fx.ultimate_scale = 0.85
	for die in dice:
		die.base_scale = 1.25
		die.scale = Vector2.ONE * die.base_scale

func _handle_click(point: Vector2) -> void:
	if view_phase in ["reward", "skill", "targeting"]:
		super._handle_click(point)
		return
	if guide:
		if GUIDE_PAIRS.has_point(point): guide_page = 0
		elif GUIDE_TRIPLES.has_point(point): guide_page = 1
		super._handle_click(point)
		return
	if not debug_open and view_phase != "over":
		for item in _active_statuses():
			if _status_rect(item.id).has_point(point):
				selected_status = item.id if selected_status != item.id else -1
				status_until = clock_time + 5
				return
	selected_status = -1
	super._handle_click(point)

func _restart() -> void:
	selected_status = -1
	super._restart()

func _player_feet() -> Vector2:
	return Vector2(222, 930)

func _player_point() -> Vector2:
	return _player_feet() - Vector2(0, monster_side * 0.48)

func _enemy_feet(index: int) -> Vector2:
	var count: int = model.enemies.size()
	if count == 1: return Vector2(568, 662 if model.stage == 0 else 610)
	var columns: int = mini(5, count)
	var spacing: float = clampf(_enemy_side()*1.8, 104, 172)
	spacing = minf(spacing, 384.0/maxi(1,columns-1))
	var row: int = floori(index / float(columns))
	var row_count: int = mini(columns, count-row*columns)
	var column: int = index % columns
	# Leave room for move badges between rows and for two rows of player statuses.
	var bottom: float = minf(570, _player_feet().y-monster_side-154)
	if count > 5: bottom = maxf(bottom,462+_enemy_side())
	var center_x: float = 524 if columns == 3 else 540
	return Vector2(center_x+(column-(row_count-1)/2.0)*spacing, bottom-(161 if count>5 and row==0 else 0)+[0,-12,10,-6,7][column])

func _city_gate_point() -> Vector2:
	return CITY_TRANSFORM * City.gate_point()

func _city_wall_point(section: float) -> Vector2:
	return CITY_TRANSFORM * City.wall_point(section)

func _troop_point(index: int) -> Vector2:
	var progress: float = fposmod(city_life.clock * 0.1 + index * 0.17, 1.0)
	return _city_gate_point().lerp(Vector2(340, 890), progress) + Vector2((index % 2) * 7, 0)

func _draw() -> void:
	_stone(Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)), Color("303129"))
	_draw_header()
	_draw_arena()
	_draw_statuses()
	_draw_console()
	_draw_dice_circle()
	if view_phase == "over":
		_draw_ending()
		_draw_reward_progress(REWARD_CENTER,1.5)
	if guide: _draw_guide()
	elif debug_open: _draw_debug()
	else: _draw_tooltips()

func _button(rect: Rect2, value: String, enabled: bool = true) -> void:
	var hover: bool = enabled and rect.has_point(_pointer_position())
	_frame(rect, Color("5f563a") if hover else Color("443c2d"), GOLD if hover else EDGE)
	_center(rect.get_center() + Vector2(0, 10), value, 28, GOLD if enabled else MUTED)

func _draw_header() -> void:
	_text(Vector2(48, 163), "%d / %d" % [model.stage + 1, Run.WAVE_NAMES.size()], 32, GOLD)
	_draw_currencies(Vector2(58, 199),1.1)
	_button(DEBUG_RECT, "DBG")
	_button(SPEED_RECT, "%.1fx" % _roll_speed() if model.is_city() else "2x" if speed == 2 else "1x")
	_button(AUDIO_RECT, "")
	_button(FX_RECT, "")
	_button(GUIDE_RECT, "")
	_glyph(AUDIO_RECT.get_center(), "mute" if muted else "sound", MUTED if muted else GOLD, 2)
	_glyph(FX_RECT.get_center(), "fx", MUTED if reduced else GOLD, 2)
	_art("book", Rect2(GUIDE_RECT.get_center() - Vector2(26, 26), Vector2(52, 52)))

func _draw_arena() -> void:
	draw_rect(ARENA, Color("a5a182"))
	var tile: int = roundi(_stage_size(PAVING_SIZES))
	var shift: int = int(background_offset) % tile
	var progress: float = visual_stage / float(Run.WAVE_NAMES.size()-1)
	var tint: Color = Color("b6b8a0").lerp(Color("c3a889"), progress)
	var field: float = clampf((progress * 4 - 1) / 2.0, 0, 1)
	for y in range(int(ARENA.position.y), int(ARENA.end.y), tile):
		for x in range(24 - shift, 780, tile):
			var variant: int = posmod(int((x + background_offset) / tile) + int(y / tile), 4)
			if field < 1: _arena_art("floor%d" % variant, Rect2(x, y, tile, tile), tint)
			if field > 0: _arena_art("grass", Rect2(x, y, tile, tile), Color(0.76, 0.83, 0.66, field))
	var prop: float = _stage_size(SCENERY_SIZES)
	var spacing: float = prop * 2.25
	var drift: float = fposmod(background_offset * 0.65, spacing)
	for i in range(-1, ceili(ARENA.size.x / spacing) + 1):
		var x: float = 24 + i * spacing - drift
		_arena_art("mangrove" if model.is_city() else "arch", Rect2(x, ARENA.position.y + 60 - prop * 0.3, prop, prop), Color("939e79"))
	if visual_stage >= 1 and not model.is_city():
		var height: float = _stage_size([96.0, 64.0, 40.0, 24.0, 18.0])
		for i in range(9):
			var x: float = 42 + i * 113 - fposmod(background_offset * 0.2, 113)
			_draw_building(Rect2(x, ARENA.position.y + 104 - height, height * 0.7, height), Color("a1a184"), false)
	draw_rect(ARENA, Color(0.84, 0.85, 0.67, 0.13))
	_draw_backdrop_shade()
	if model.is_city(): _draw_city()
	_draw_player()
	if not model.is_city():
		for i in range(model.enemies.size()): _draw_human(i)
	draw_rect(ARENA, EDGE, false, 4)
	draw_rect(ARENA.grow(-5), Color("d2c29a"), false, 2)
	if view_phase in ["feeding", "transition"]:
		_center(Vector2(402, 720), "THE FEAST" if view_phase == "feeding" else "ADVANCING", 42, GOLD)

func _draw_city() -> void:
	City.paint(self, art, model.city_hp / float(Run.CITY_MAX_HP), city_life.clock, city_life.people, city_life.houses, reduced, CITY_TRANSFORM)
	for corpse in city_corpses:
		draw_set_transform(corpse.p, PI / 2, Vector2(0.35, 1))
		var side: float = _enemy_side()
		_art(["vanguard", "archer", "mage"][corpse.role], Rect2(-side/2, -side/2, side, side), Color("796c64"))
		draw_set_transform(Vector2.ZERO)
	for i in range(model.troops):
		var point := _troop_point(i)
		var stride: float = city_life.clock * 16 + i * 2.3
		var hop: float = 0 if reduced else snappedf(absf(sin(stride)) * 2, 1)
		_shadow(point, 5, 0.22)
		draw_set_transform(point - Vector2(0, hop), 0 if reduced else sin(stride) * 0.16)
		var side: float = _enemy_side()
		_art(["vanguard", "archer", "mage"][i % 3], Rect2(-side/2, -side, side, side))
		draw_set_transform(Vector2.ZERO)
	_meter(Rect2(48, ARENA.position.y + 42, 708, 34), model.city_hp / float(Run.CITY_MAX_HP), GOLD)
	_center(Vector2(402, ARENA.position.y + 67), "%d / %d" % [model.city_hp, Run.CITY_MAX_HP], 28)
	if model.volley_warned: _center(Vector2(616, ARENA.position.y + 125), "VOLLEY", 26, RED)

func _draw_player() -> void:
	var hurt: float = hit_times[0]
	var bob: float = 0 if reduced or model.is_frozen() else snappedf(sin(clock_time * (8 if view_phase == "transition" else 1.8)) * 3, 2)
	var dx: float = 0 if reduced or model.is_frozen() else snappedf(sin(clock_time * 45) * hurt * 5, 2)
	var feet := _player_feet()
	_shadow(feet, monster_side * 0.48, 0.27)
	if model.shield > 0 or model.statuses[6].count > 0: Pixel.circle(self, _player_point(), monster_side * 0.47, Color(TEAL, 0.45), 4)
	_art("eldritch", Rect2(feet + Vector2(-monster_side / 2 + dx, -monster_side + bob), Vector2.ONE * monster_side), Color.WHITE.lerp(RED, hurt * 0.6))
	_draw_player_afflictions()
	if skill_bubble.roll.is_empty() or skill_bubble.age >= skill_bubble.formation:
		_text(Vector2(492, 910), "%.2fx" % model.power, 32, TEAL)
	_meter(Rect2(48, 962, 708, 34), model.hp / float(model.max_hp), TEAL)
	_center(Vector2(402, 987), "%d / %d" % [model.hp, model.max_hp], 28)
	if model.shield > 0:
		_glyph(Vector2(625, 934), "shield", TEAL, 2)
		_text(Vector2(654, 944), str(model.shield), 28, TEAL)

func _draw_enemy_health(index: int) -> void:
	var human: Dictionary = model.enemies[index]
	var bar: Rect2 = _enemy_health_rect(index)
	_meter(bar, human.hp / float(human.max_hp), _elite_color(human.role) if human.elite else RED)
	_center(bar.get_center() + Vector2(0, 8), str(human.hp), 22)
	if human.shield > 0:
		_glyph(bar.position + Vector2(3, -15), "shield", TEAL)
		_text(bar.position + Vector2(16, -8), str(human.shield), 20, TEAL)

func _meter(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect.grow(3), EDGE)
	draw_rect(rect, INK)
	var fill: float = (rect.size.x - 6) * clampf(ratio, 0, 1)
	for x in range(0, ceili(fill), 8):
		var width: float = minf(7, fill - x)
		draw_rect(Rect2(rect.position + Vector2(x + 3, 3), Vector2(width, rect.size.y - 6)), color.darkened(0.3))
		draw_rect(Rect2(rect.position + Vector2(x + 3, 3), Vector2(width, 5)), color)

func _draw_console() -> void:
	_draw_reward_progress(REWARD_CENTER, 1.5)
	if _power_meter_visible():
		_draw_power_meter(Rect2(186, 1164, 432, 24), 28)

func _draw_tooltips() -> void:
	var index: int = selected_status if clock_time < status_until else -1
	if index == -1 and active_touch == -1:
		for item in _active_statuses():
			if _status_rect(item.id).has_point(get_global_mouse_position()): index = item.id
	if index < 0 or model.status_count(index) <= 0: return
	var item: Dictionary = Statuses.ENTRIES[index]
	_frame(Rect2(38, 762, 728, 172), PANEL, GOLD)
	_text(Vector2(58, 800), item.name, 28, item.color)
	_wrapped(Vector2(58, 840), _status_description(index,model.status_count(index)), 688, CREAM, 24)

func _draw_ending() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)), Color(INK, 0.92))
	var won: bool = model.outcome() == "victory"
	var color: Color = GOLD if won else RED
	_rune(Vector2(402, 662), 5, color, 8)
	_center(Vector2(402, 790), "VICTORY" if won else "DEFEAT", 72, color)
	_center(Vector2(402, 858), "THE CITY REQUESTS A REFUND" if won else "BACK TO THE ABYSS", 26, CREAM)
	_center(Vector2(402, 916), "STAGE %d / %d   -   %d HP" % [model.stage + 1, Run.WAVE_NAMES.size(), model.hp], 26, MUTED)
	_button(REPLAY_RECT, "RESTART")
	if home_enabled: _button(_home_rect(), "HOME")

func _home_rect() -> Rect2:
	return Rect2(478, 132, 160, 88) if guide else Rect2(162, 1490, 480, 104)

func _draw_guide() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)), Color(INK, 0.98))
	_text(Vector2(40, 188), "GRIMOIRE", 42, GOLD)
	_button(GUIDE_CLOSE, "X")
	if home_enabled: _button(_home_rect(), "HOME")
	var intro: String = "Tap twice to throw. Drag skills to the field, or tap targeted skills to choose a foe. SAVE banks a bonus cast."
	var rule: String = "Perfect: pair or triple. Normal: sum. 666 clears the squad."
	if model.is_city():
		intro = "Tap twice to throw. City skills cast automatically after the reveal. Drag saved skills out for a bonus cast."
		rule = "Perfect: triple. 666: 800 city damage; clear troops; +12 HP."
	_wrapped(Vector2(40, 274), intro, 718, CREAM, 28)
	_wrapped(Vector2(40, 370), rule, 718, MUTED, 24)
	_button(GUIDE_PAIRS, "PAIRS")
	_button(GUIDE_TRIPLES, "TRIPLES")
	draw_rect((GUIDE_PAIRS if guide_page == 0 else GUIDE_TRIPLES).grow(-3), TEAL if guide_page == 0 else PURPLE, false, 3)
	for i in range(6):
		var y: float = 584 + i * 145
		var code: String = str(i + 1).repeat(2 if guide_page == 0 else 3)
		var label: String = Rules.PAIR_NAMES[i] if guide_page == 0 else Rules.SPECIAL_NAMES[i]
		_text(Vector2(40, y), code + "  " + label, 28, TEAL if guide_page == 0 else GOLD if i == 5 else PURPLE)
		_wrapped(Vector2(40, y + 42), _pair_description(i) if guide_page == 0 else _special_description(i), 718, CREAM, 24)
		draw_rect(Rect2(40, y + 108, 724, 2), EDGE.darkened(0.35))
	var caps: String = ["1/3", "1/3", "1/2", "3/4"][mini(model.stage, 3)]
	_wrapped(Vector2(40, 1490), "City damage has no squad caps." if model.is_city() else "Damage x1.5 + growth. Normal cap %s HP; skills ignore caps." % caps, 718, MUTED, 24)
	_wrapped(Vector2(40, 1620), "Art: DCSS / CC0. Audio: Kenney.", 718, MUTED, 22)

func _debug_option_rect(choice: int) -> Rect2:
	if choice == -1: return Rect2(40, 262, 724, 88)
	if choice == 0: return Rect2(40, 370, 724, 88)
	var item: int = (choice - 1) % 6
	return Rect2(40 + (item % 3) * 248, (550 if choice <= 6 else 998) + floori(item / 3.0) * 164, 228, 140)

func _draw_debug() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)), Color(INK, 0.98))
	_text(Vector2(40, 188), "DEBUG DICE", 42, GOLD)
	_button(DEBUG_CLOSE, "X")
	_button(_debug_option_rect(-1), "NATURAL RANDOM")
	_button(_debug_option_rect(0), "RANDOM SINGLES")
	_text(Vector2(40, 516), "DOUBLES / SKILLS", 28, TEAL)
	_text(Vector2(40, 964), "TRIPLES / SPELL", 28, PURPLE)
	for choice in range(1, 13):
		var rect := _debug_option_rect(choice)
		var face: int = choice if choice <= 6 else choice - 6
		var color: Color = TEAL if choice <= 6 else GOLD if choice == 12 else PURPLE
		_frame(rect, Color("53613d") if debug_choice == choice else PANEL, color if debug_choice == choice or rect.has_point(_pointer_position()) else EDGE)
		for i in range(3): _mini_die(rect.position + Vector2(54 + i * 60, 48), 0 if choice <= 6 and i == 2 else face)
		_center(rect.get_center() + Vector2(0, 44), str(face).repeat(2 if choice <= 6 else 3), 30, color)
	_button(DEBUG_REPEAT, "REPEAT: " + ("ON" if debug_repeat else "OFF"))
	_button(DEBUG_PERFECT, "PERFECT: " + ("ON" if debug_perfect else "OFF"))
	if debug_perfect: draw_rect(DEBUG_PERFECT.grow(-3), GOLD, false, 3)
	_wrapped(Vector2(40, 1620), "Choose, then tap the seal. City is paused here.", 724, MUTED, 24)
