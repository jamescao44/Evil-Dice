extends "res://scripts/combat/battle.gd"
## Alternate presentation only. Rolls, combat, growth, timings and audio are inherited.
## 804x1748 = twice the iPhone 16 Pro's 402x874 logical display size.
const PORTRAIT_SIZE := Vector2i(804, 1748)
const CITY_TRANSFORM := Transform2D(Vector2(0.9, 0), Vector2(0, 0.9), Vector2(-390, 336))
const GUIDE_PAIRS := Rect2(40, 432, 226, 88)
const GUIDE_TRIPLES := Rect2(289, 432, 226, 88)
var selected_status: int = -1
var status_until: float = 0

## Lay out phone controls and safe areas without resizing the browser canvas.
func _configure_layout() -> void:
	var window := get_window()
	if OS.get_name() in ["iOS", "Android"]:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	# The browser owns the canvas size, including its device-pixel ratio.
	# Forcing the desktop preview size here shrinks the WebGL drawing viewport.
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless" and OS.get_name() not in ["iOS", "Android"]:
		window.size = Vector2i(402, 874)
		window.move_to_center()
	preload("res://scripts/shared/display_quality.gd").configure(window, PORTRAIT_SIZE)
	window.title = "Evil Dice | Portrait"
	# All controls sit below the island and above the home-indicator safe zones.
	ARENA = Rect2(24, 228, 756, 722)
	DICE_CENTER = Vector2(402, 1346)
	DICE_RADIUS = 232
	MENU_RECT = Rect2(672, 124, 88, 88)
	MENU_CLOSE = Rect2(660, 132, 104, 88)
	MENU_RESUME = Rect2(88, 1164, 628, 112)
	MENU_HOME = Rect2(88, 1300, 628, 112)
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
	REWARD_CENTER = Vector2(402,1000)
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
	if is_instance_valid(inventory_page) and (inventory_page.opened or (inventory_page.available() and inventory_page.button_rect().has_point(point))):
		super._handle_click(point)
		return
	if guide:
		if GUIDE_PAIRS.has_point(point): guide_page = 0; guide_status_page = false
		elif GUIDE_TRIPLES.has_point(point): guide_page = 1; guide_status_page = false
		elif GUIDE_STATUSES.has_point(point): guide_status_page = true; return
		super._handle_click(point)
		return
	if view_phase in ["reward", "wave_reward", "skill", "targeting", "shop"]:
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

func _restart(wave_number: int = 0) -> void:
	selected_status = -1
	super._restart(wave_number)

func _player_world_feet() -> Vector2:
	return Vector2(222, 890)

## Keep front-row enemies beside the player with enough overhead for intent icons.
func _enemy_layout_feet(index: int) -> Vector2:
	if BossPresentation.present(model): return BossPresentation.feet(self,index)
	return preload("res://scripts/enemies/enemy_formation.gd").feet(ARENA,index,model.enemies.size(),_enemy_side(),true)

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
	_text(Vector2(48, 163), "%d-%d / 10" % [model.level_number(),model.level_wave()], 32, GOLD)
	_draw_currencies(_currency_point(),1.1)
	_button(SPEED_RECT, "%.1fx" % _roll_speed() if model.is_city() else "2x" if speed == 2 else "1x")
	_button(AUDIO_RECT, "")
	_button(MENU_RECT, "")
	_glyph(AUDIO_RECT.get_center(), "mute" if muted else "sound", MUTED if muted else GOLD, 2)
	_draw_menu_icon()

## Render portrait actors, dynamic shade and borders above the cached terrain.
func _draw_arena() -> void:
	if model.is_city(): _draw_city()
	_draw_player()
	if not model.is_city():
		for i in range(model.enemies.size()): _draw_enemy_overlay(i)
	draw_rect(ARENA, EDGE, false, 4)
	draw_rect(ARENA.grow(-5), Color("d2c29a"), false, 2)
	if view_phase == "transition":
		_center(Vector2(402, 720), "ADVANCING", 42, GOLD)

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
	if model.is_city(): _draw_player_actor(self)
	_draw_player_vitals()

## Leave room at the left for the level and below for the thin XP strip.
func player_health_rect() -> Rect2:
	return Rect2(140,904,616,28)

func _draw_enemy_health(index: int) -> void:
	var human: Dictionary = model.enemies[index]
	var bar: Rect2 = _enemy_health_rect(index)
	draw_rect(bar.grow(3),EDGE)
	draw_rect(bar,INK)
	_draw_health_fill(bar.grow(-2),human.hp,human.max_hp,human.shield,_elite_color(human.role) if human.elite else RED)
	_draw_enemy_health_text(index,bar,16 if human.get("summoned",false) and not Rules.EnemyCatalog.ITEMS[human.role].get("interruptible",false) else 22 if model.enemies.size() < 4 else 20)

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
		_draw_power_meter(Rect2(186, DICE_CENTER.y-284, 432, 24), 28)

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
	_center(Vector2(402, 858), "LEVEL CLEARED" if won and model.has_next_level() else "THE INNER SANCTUM FALLS" if won else "BACK TO THE ABYSS", 26, CREAM)
	_center(Vector2(402, 916), GameText.format("LEVEL %d   WAVE %d / 10", [model.level_number(),model.level_wave()]), 26, MUTED)
	_button(REPLAY_RECT, "START LEVEL 2" if won and model.has_next_level() else "RESTART LEVEL" if not won else "RESTART", not won or model.level_rewards_complete())
	if home_enabled: _button(_home_rect(), "HOME")

func _home_rect() -> Rect2:
	return Rect2(478, 132, 160, 88) if guide else Rect2(162, 1490, 480, 104)

func _draw_guide(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(Vector2.ZERO,Vector2(PORTRAIT_SIZE)),INK)
	_text(Vector2(40,188),"GRIMOIRE",42,GOLD,canvas)
	_button(GUIDE_CLOSE,"X",true,canvas)
	if home_enabled: _button(_home_rect(),"HOME",true,canvas)
	_wrapped(Vector2(40,258),"Matching dice auto-attack. Connect 3-6 consecutive faces for a fire skill. Three rolls per turn.",718,CREAM,26,canvas)
	_wrapped(Vector2(40,350),Rules.Patterns.BONUS_TURN_HELP,718,MUTED,24,canvas)
	_button(GUIDE_PAIRS,"AUTO ATTACKS",true,canvas)
	_button(GUIDE_TRIPLES,"STRAIGHTS",true,canvas)
	_button(GUIDE_STATUSES,"STATUSES",true,canvas)
	canvas.draw_rect((GUIDE_STATUSES if guide_status_page else GUIDE_PAIRS if guide_page == 0 else GUIDE_TRIPLES).grow(-3),GOLD,false,3)
	if guide_status_page:
		_draw_status_help(canvas)
		return
	character_guide.paint(canvas)
	var entries: Array = character_guide.entries(guide_page == 1)
	for i in range(entries.size()):
		var y: float = 824+i*156
		_text(Vector2(40,y),entries[i].name,28,TEAL if guide_page == 0 else PURPLE,canvas)
		_wrapped(Vector2(40,y+42),entries[i].text,718,CREAM,28,canvas)
		if i < entries.size()-1: canvas.draw_rect(Rect2(40,y+120,724,2),EDGE.darkened(0.35))
	_wrapped(Vector2(40,1440 if guide_page == 0 else 1400),"End Turn: leftover pip sum x 1% of maximum HP is restored. Darkness blocks healing.",718,CREAM,26,canvas)
	_wrapped(Vector2(40,1550),"Unused rolls fill Reroll Treasure. Perfect still adds +0.1 DMG per consecutive success.",718,MUTED,24,canvas)
	_wrapped(Vector2(40,1640),"Reroll Treasure: bank 10 unused rolls for a Perfect Chest. It can upgrade when opened.",718,MUTED,22,canvas)

func _debug_option_rect(choice: int) -> Rect2:
	if choice == DebugDice.NATURAL: return Rect2(40, 262, 724, 88)
	var item: int = DEBUG_DICE_PRESETS.keys().find(choice)
	if item < 0: return Rect2()
	return Rect2(40+(item%2)*374,414+floori(item/2.0)*242,350,222)

func _draw_debug(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)), INK)
	_text(Vector2(40, 188), "调试", 42, GOLD, canvas)
	_button(DEBUG_CLOSE, "X", true, canvas)
	_button(_debug_option_rect(-1), "自然随机", true, canvas)
	_text(Vector2(40, 390), "指定下一次掷骰结果", 26, MUTED, canvas)
	_draw_debug_dice(canvas)
	_text(Vector2(40, 1178), "仅重掷未用骰；数量不足时保留设置。", 24, MUTED, canvas)
	_button(DEBUG_TAROTS,"获得全部22张塔罗牌", true, canvas)
	_button(DEBUG_TAROT_DRAW,"抽取塔罗牌", true, canvas)
	_button(DEBUG_CHEST,"生成普通宝箱",_can_debug_chest(),canvas)
	_button(DEBUG_TREASURE,"充满重投宝箱进度",true,canvas)
	_button(DEBUG_REPEAT, "重复：" + ("开" if debug_repeat else "关"), true, canvas)
	_button(DEBUG_PERFECT, "完美投掷：" + ("开" if debug_perfect else "关"), true, canvas)
	if debug_perfect: canvas.draw_rect(DEBUG_PERFECT.grow(-3), GOLD, false, 3)
	_text(Vector2(40,1634),"关卡",28,GOLD, canvas)
	_button(DEBUG_WAVE_LOAD,"载入", true, canvas)
	_text(Vector2(40,1706),debug_wave_error if not debug_wave_error.is_empty() else "从第1–20关重新开始；城市狂热暂时跳过。",24,RED if not debug_wave_error.is_empty() else MUTED, canvas)
