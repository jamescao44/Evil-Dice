extends "res://scripts/combat/battle.gd"
## Alternate presentation only. Rolls, combat, growth, timings and audio are inherited.
## 804x1748 = twice the iPhone 16 Pro's 402x874 logical display size.
const PORTRAIT_SIZE := Vector2i(804, 1748)
const CITY_TRANSFORM := Transform2D(Vector2(0.9, 0), Vector2(0, 0.9), Vector2(-390, 336))
const GUIDE_PAIRS := Rect2(40, 432, 226, 88)
const GUIDE_TRIPLES := Rect2(289, 432, 226, 88)
var guide_page: int = 0
var selected_status: int = -1
var status_until: float = 0

## Lay out phone controls and safe areas without resizing the browser canvas.
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
	ARENA = Rect2(24, 228, 756, 722)
	DICE_CENTER = Vector2(402, 1410)
	DICE_RADIUS = 232
	MENU_RECT = Rect2(672, 124, 88, 88)
	MENU_CLOSE = Rect2(660, 132, 104, 88)
	MENU_RESUME = Rect2(88, 1164, 628, 112)
	DEBUG_RECT = Rect2(88, 420, 628, 112)
	SPEED_RECT = Rect2(476, 124, 88, 88)
	AUDIO_RECT = Rect2(574, 124, 88, 88)
	FX_RECT = Rect2(88, 580, 628, 112)
	GUIDE_RECT = Rect2(88, 740, 628, 112)
	LANGUAGE_RECT = Rect2(88, 944, 628, 112)
	GUIDE_CLOSE = Rect2(660, 132, 104, 88)
	GUIDE_STATUSES = Rect2(538,432,226,88)
	DEBUG_CLOSE = GUIDE_CLOSE
	DEBUG_TAROTS = Rect2(40,1240,350,88)
	DEBUG_TAROT_DRAW = Rect2(414,1240,350,88)
	DEBUG_CHEST = Rect2(40,1350,350,88)
	DEBUG_TREASURE = Rect2(414,1350,350,88)
	DEBUG_REPEAT = Rect2(40, 1470, 350, 88)
	DEBUG_PERFECT = Rect2(414, 1470, 350, 88)
	DEBUG_WAVE_INPUT = Rect2(220, 1578, 150, 88)
	DEBUG_WAVE_LOAD = Rect2(414, 1578, 350, 88)
	REPLAY_RECT = Rect2(162, 1360, 480, 104)
	REWARD_CENTER = Vector2(402,1064)
	CITY_POINT = CITY_TRANSFORM * Vector2(925, 282)

func _configure_effects() -> void:
	fx.canvas_size = Vector2(PORTRAIT_SIZE)
	fx.skill_anchor = Vector2(402, 620)
	fx.skill_max_width = 716
	fx.combo_font_size = 80
	fx.ultimate_center = Vector2(448, 602)
	fx.ultimate_scale = 0.85
	for die in dice:
		die.base_scale = 0.94
		die.scale = Vector2.ONE * die.base_scale

func _handle_click(point: Vector2) -> void:
	if guide:
		if GUIDE_PAIRS.has_point(point): guide_page = 0; guide_status_page = false
		elif GUIDE_TRIPLES.has_point(point): guide_page = 1; guide_status_page = false
		elif GUIDE_STATUSES.has_point(point): guide_status_page = true; return
		super._handle_click(point)
		return
	if view_phase in ["reward", "wave_reward", "skill", "targeting"]:
		super._handle_click(point)
		return
	if not _menus_open() and view_phase != "over":
		for item in _active_statuses():
			if _status_rect(item.id).has_point(point):
				selected_status = item.id if selected_status != item.id else -1
				status_until = clock_time + 5
				return
	selected_status = -1
	super._handle_click(point)

func _restart(wave_number: int = 1) -> void:
	selected_status = -1
	super._restart(wave_number)

func _player_feet() -> Vector2:
	return Vector2(222, 890)

func _player_point() -> Vector2:
	return _player_feet() - Vector2(0, monster_side * 0.48)

func _enemy_feet(index: int) -> Vector2:
	var count: int = model.enemies.size()
	if count == 1: return Vector2(530, 662 if model.stage == 0 else 610)
	if count <= 3:
		var bottom: float = minf(550, _player_feet().y-monster_side-132)
		return Vector2(486+(index-(count-1)/2.0)*maxf(144,_enemy_side()+12),bottom+[-12,0,-8][index])
	# Stagger compact groups through the upper center and open right flank.
	# The lower left stays clear for the Horror and its two rows of statuses.
	var rows: Array = [2,2] if count == 4 else [3,2] if count == 5 else [3,3] if count == 6 and _enemy_side() > 110 else [4,count-4] if count <= 7 else [4,3,count-7]
	var row: int = 0
	var column: int = index
	while column >= rows[row]:
		column -= rows[row]
		row += 1
	var center: float = (436 if count == 4 else 444) if count <= 5 and row == 0 else 556 if row > 0 else 402
	var bottom: float = (470+row*166) if count <= 5 else (438+row*182) if count <= 7 else (408+row*158)
	var spacing: float = maxf(112 if count <= 5 else 108,_enemy_side()+12)
	center = minf(center,ARENA.end.x-10-_enemy_side()/2-(rows[row]-1)*spacing/2)
	return Vector2(center+(column-(rows[row]-1)/2.0)*spacing,bottom+[0,-8,-4,0][column])

func _city_gate_point() -> Vector2:
	return CITY_TRANSFORM * City.gate_point()

func _city_wall_point(section: float) -> Vector2:
	return CITY_TRANSFORM * City.wall_point(section)

func _currency_point() -> Vector2:
	return Vector2(58,199)

func _troop_point(index: int) -> Vector2:
	var progress: float = fposmod(city_life.clock * 0.1 + index * 0.17, 1.0)
	return _city_gate_point().lerp(Vector2(340, 890), progress) + Vector2((index % 2) * 7, 0)

## Draw portrait battle actors and controls over the retained scenery layer.
func _draw() -> void:
	_draw_header()
	_draw_arena()
	_draw_statuses()
	_draw_console()
	_draw_dice_circle()
	if view_phase == "over":
		_draw_ending()
		_draw_reward_progress(REWARD_CENTER,1.5)
	if not _menus_open(): _draw_tooltips()

func _button(rect: Rect2, value: String, enabled: bool = true, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var hover: bool = enabled and rect.has_point(_pointer_position())
	_frame(rect, Color("5f563a") if hover else Color("443c2d"), GOLD if hover else EDGE, canvas)
	_center(rect.get_center() + Vector2(0, 10), value, 28, GOLD if enabled else MUTED, canvas)

func _draw_header() -> void:
	_text(Vector2(48, 163), "%d / %d" % [model.stage + 1, Run.PLAYABLE_WAVES], 32, GOLD)
	_draw_currencies(_currency_point(),1.1)
	_button(SPEED_RECT, "%.1fx" % _roll_speed() if model.is_city() else "2x" if speed == 2 else "1x")
	_button(AUDIO_RECT, "")
	_button(MENU_RECT, "")
	_glyph(AUDIO_RECT.get_center(), "mute" if muted else "sound", MUTED if muted else GOLD, 2)
	_draw_menu_icon()

## Render portrait actors, dynamic shade and borders above the cached terrain.
func _draw_arena() -> void:
	_draw_backdrop_shade()
	if model.is_city(): _draw_city()
	_draw_player()
	if not model.is_city():
		for i in range(model.enemies.size()): _draw_human(i)
	draw_rect(ARENA, EDGE, false, 4)
	draw_rect(ARENA.grow(-5), Color("d2c29a"), false, 2)
	if view_phase in ["feeding", "transition"]:
		_center(Vector2(402, 720), "THE FEAST" if view_phase == "feeding" else "ADVANCING", 42, GOLD)

## Render city scenery and troops through the portrait coordinate transform.
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
	var dx: float = combat_motion.offset(-1,monster_side,clock_time,false,reduced)
	var feet := _player_feet()
	_shadow(feet, monster_side * _player_growth_scale().x * 0.48, 0.27)
	if model.shield > 0 or model.statuses[6].count > 0: Pixel.circle(self, _player_point(), monster_side * 0.47, Color(TEAL, 0.45), 4)
	_art("eldritch", _player_sprite_rect(dx,bob), Color(Color.WHITE.lerp(RED, hurt * 0.6),0.32 if model.status_count(Status.HIDDEN) > 0 else 1.0))
	_draw_player_afflictions()
	_meter(Rect2(48, 910, 708, 34), model.hp / float(model.max_hp), TEAL)
	_center(Vector2(402, 935), "%d / %d" % [model.hp, model.max_hp], 28)
	if model.shield > 0:
		_glyph(Vector2(625, 882), "shield", TEAL, 2)
		_text(Vector2(654, 892), str(model.shield), 28, TEAL)

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
		_draw_power_meter(Rect2(186, 1126, 432, 24), 28)

func _draw_tooltips() -> void:
	var index: int = selected_status if clock_time < status_until else -1
	if index == -1 and active_touch == -1:
		for item in _active_statuses():
			if _status_rect(item.id).has_point(get_global_mouse_position()): index = item.id
	if index < 0 or model.status_count(index) <= 0: return
	var item: Dictionary = Statuses.ENTRIES[index]
	var description: String = _status_description(index,model.status_count(index))
	var lines := GameText.lines(description,description_font,30,688)
	var height: float = 90+lines.size()*36
	var top: float = 934-height
	_frame(Rect2(38,top,728,height), PANEL, GOLD)
	_text(Vector2(58,top+38), item.name, 28, item.color)
	_wrapped(Vector2(58,top+78),description,688,CREAM,30)

func _draw_ending() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)), Color(INK, 0.92))
	var won: bool = model.outcome() == "victory"
	var color: Color = GOLD if won else RED
	_rune(Vector2(402, 662), 5, color, 8)
	_center(Vector2(402, 790), "VICTORY" if won else "DEFEAT", 72, color)
	_center(Vector2(402, 858), "THE INNER SANCTUM FALLS" if won else "BACK TO THE ABYSS", 26, CREAM)
	_center(Vector2(402, 916), GameText.format("STAGE %d / %d   -   %d HP", [model.stage + 1, Run.PLAYABLE_WAVES, model.hp]), 26, MUTED)
	_button(REPLAY_RECT, "RESTART")
	if home_enabled: _button(_home_rect(), "HOME")

func _home_rect() -> Rect2:
	return Rect2(478, 132, 160, 88) if guide else Rect2(162, 1490, 480, 104)

func _draw_guide(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)), INK)
	_text(Vector2(40, 188), "GRIMOIRE", 42, GOLD, canvas)
	_button(GUIDE_CLOSE, "X", true, canvas)
	if home_enabled: _button(_home_rect(), "HOME", true, canvas)
	var intro: String = "Tap the center to roll. Drag through three dice and release to summon a skill. Three rolls per turn."
	var rule: String = "Return a skill to the red center to unlock its dice. Use all six dice to end the turn."
	if model.is_city():
		intro = "Tap twice to throw. City skills cast automatically after the reveal. Drag saved skills out for a bonus cast."
		rule = "Perfect: triple. 666: 2000 x DMG; clear troops; +12 HP."
	_wrapped(Vector2(40, 258), intro, 718, CREAM, 26, canvas)
	_wrapped(Vector2(40, 350), rule, 718, MUTED, 24, canvas)
	_button(GUIDE_PAIRS, "PAIRS", true, canvas)
	_button(GUIDE_TRIPLES, "TRIPLES", true, canvas)
	_button(GUIDE_STATUSES, "STATUSES", true, canvas)
	canvas.draw_rect((GUIDE_STATUSES if guide_status_page else GUIDE_PAIRS if guide_page == 0 else GUIDE_TRIPLES).grow(-3), GOLD if guide_status_page else TEAL if guide_page == 0 else PURPLE, false, 3)
	if guide_status_page:
		_draw_status_help(canvas)
		return
	for i in range(6):
		var y: float = 584 + i * 145
		var code: String = str(i + 1).repeat(2 if guide_page == 0 else 3)
		var label: String = Rules.PAIR_NAMES[i] if guide_page == 0 else Rules.SPECIAL_NAMES[i]
		_text(Vector2(40, y), code + "  " + GameText.text(label), 28, TEAL if guide_page == 0 else GOLD if i == 5 else PURPLE, canvas)
		_wrapped(Vector2(40, y + 42), _pair_description(i) if guide_page == 0 else _special_description(i), 718, CREAM, 28, canvas)
		canvas.draw_rect(Rect2(40, y + 108, 724, 2), EDGE.darkened(0.35))
	var caps: String = ["1/3", "1/3", "1/2", "3/4"][mini(model.stage, 3)]
	_wrapped(Vector2(40, 1490), "City damage has no squad caps." if model.is_city() else GameText.format("Damage x DMG; bonuses add. Normal cap %s HP; skills ignore caps.", caps), 718, MUTED, 24, canvas)
	_wrapped(Vector2(40, 1554), "Perfect combo: +0.1 DMG per consecutive Perfect. A miss resets it.", 718, MUTED, 24, canvas)
	_wrapped(Vector2(40, 1620), "Reroll Treasure: after a throw, unused rolls add 1 each at turn end. Chests: 3 / 8 / 15.", 718, MUTED, 22, canvas)
	_wrapped(Vector2(40, 1692), "Art: DCSS / CC0. Audio: Kenney.", 718, MUTED, 22, canvas)

func _debug_option_rect(choice: int) -> Rect2:
	if choice == -1: return Rect2(40, 262, 724, 88)
	if choice == 0: return Rect2(40, 370, 724, 88)
	var item: int = (choice - 1) % 6
	return Rect2(40 + (item % 3) * 248, (550 if choice <= 6 else 930) + floori(item / 3.0) * 146, 228, 128)

func _draw_debug(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)), INK)
	_text(Vector2(40, 188), "调试", 42, GOLD, canvas)
	_button(DEBUG_CLOSE, "X", true, canvas)
	_button(_debug_option_rect(-1), "自然随机", true, canvas)
	_button(_debug_option_rect(0), "随机单骰", true, canvas)
	_text(Vector2(40, 516), "两个一样 / 技能", 28, TEAL, canvas)
	_text(Vector2(40, 896), "三个一样 / 法术", 28, PURPLE, canvas)
	for choice in range(1, 13):
		var rect := _debug_option_rect(choice)
		var face: int = choice if choice <= 6 else choice - 6
		var color: Color = TEAL if choice <= 6 else GOLD if choice == 12 else PURPLE
		_frame(rect, Color("53613d") if debug_choice == choice else PANEL, color if debug_choice == choice or rect.has_point(_pointer_position()) else EDGE, canvas)
		for i in range(3): _mini_die(rect.position + Vector2(54 + i * 60, 48), 0 if choice <= 6 and i == 2 else face, CREAM, canvas)
		_center(rect.get_center() + Vector2(0, 44), str(face).repeat(2 if choice <= 6 else 3), 30, color, canvas)
	_button(DEBUG_TAROTS,"获得全部22张塔罗牌", true, canvas)
	_button(DEBUG_TAROT_DRAW,"抽取塔罗牌", true, canvas)
	_button(DEBUG_CHEST,"生成普通宝箱",_can_debug_chest(),canvas)
	_button(DEBUG_TREASURE,"充满重投宝箱进度",true,canvas)
	_button(DEBUG_REPEAT, "重复：" + ("开" if debug_repeat else "关"), true, canvas)
	_button(DEBUG_PERFECT, "完美投掷：" + ("开" if debug_perfect else "关"), true, canvas)
	if debug_perfect: canvas.draw_rect(DEBUG_PERFECT.grow(-3), GOLD, false, 3)
	_text(Vector2(40,1634),"关卡",28,GOLD, canvas)
	_button(DEBUG_WAVE_LOAD,"载入", true, canvas)
	_text(Vector2(40,1706),debug_wave_error if not debug_wave_error.is_empty() else "从第1–19关重新开始；城市狂热暂时跳过。",24,RED if not debug_wave_error.is_empty() else MUTED, canvas)
