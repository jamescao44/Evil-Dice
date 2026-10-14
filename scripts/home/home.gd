extends Node2D
const Run = preload("res://scripts/progression/run_rules.gd")
## Collection shell. Battles remain separate scenes with the same combat model.
const Catalog = preload("res://scripts/home/home_catalog.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Die = preload("res://scripts/dice/die.gd")
const PortraitBattle = preload("res://scenes/battle_portrait.tscn")
const LandscapeBattle = preload("res://scenes/battle.tscn")
const TABS := ["Dices", "Ancients", "Play", "Summon", "Shop"]
const INK := Color("141c1c")
const CREAM := Color("eee0b9")
const MUTED := Color("a49e86")
const GOLD := Color("dfb866")
const GREEN := Color("aed085")
const PURPLE := Color("c5a4de")
const EDGE := Color("716044")
@export var portrait: bool = true
var page: int = 2
var modal: String = ""
var skill_page: int = 1
var city_skills: bool = false
var ancients: Array = Catalog.ANCIENTS.duplicate(true)
var dices: Array = Catalog.DICES.duplicate(true)
var ancient_index: int = 0
var dice_index: int = 0
var detail_dice: int = 0
var picker_offset: int = 0
var age: float = 0
var reveal: float = 1
var swipe_nudge: float = 0
var active_touch: int = -1
var pointer_down: bool = false
var press_at := Vector2.ZERO
var pointer := Vector2.ZERO
var drag_distance: float = 0
var battle: Node2D
var muted: bool = false
var reduced: bool = false
var speed: float = 1
var art: Dictionary = {}
var pixel_font: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf").duplicate()
var preview_die: Node2D
var click_audio: AudioStreamPlayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	GameText.prepare_font(pixel_font)
	pixel_font.oversampling = 1
	for key in ["eldritch", "stone", "arch", "column", "floor0", "book", "crown", "fx", "attack", "vanguard", "archer", "mage"]:
		art[key] = load("res://assets/art/fantasy/" + key + ".png")
	preview_die = Die.new()
	preview_die.set_process(false)
	add_child(preview_die)
	click_audio = AudioStreamPlayer.new()
	click_audio.stream = preload("res://assets/audio/ui/click_001.ogg")
	click_audio.volume_db = -20
	add_child(click_audio)
	_configure_layout()
	_update_preview()

func _configure_layout() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(804, 1748) if portrait else Vector2i(1280, 800)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	# Web owns the backing resolution; never apply a native preview size to its canvas.
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless" and OS.get_name() not in ["iOS", "Android"]:
		window.size = Vector2i(402, 874) if portrait else Vector2i(1280, 800)
		window.move_to_center()
	window.title = "Evil Dice"
	get_viewport().canvas_transform = Transform2D.IDENTITY

func canvas_size() -> Vector2:
	return Vector2(804, 1748) if portrait else Vector2(1280, 800)

func tab_rect(index: int) -> Rect2:
	var area := Rect2(24, 1536, 756, 140) if portrait else Rect2(300, 694, 680, 88)
	var width: float = area.size.x / 5
	return Rect2(area.position + Vector2(index * width, 0), Vector2(width, area.size.y))

func stage_rect() -> Rect2:
	return Rect2(40, 260, 724, 680) if portrait else Rect2(48, 132, 550, 520)

func play_rect() -> Rect2:
	return Rect2(88, 1336, 628, 112) if portrait else Rect2(680, 530, 500, 88)

func skills_rect() -> Rect2:
	return Rect2(48, 1268, 708, 96) if portrait else Rect2(656, 493, 560, 70)

func picker_rect() -> Rect2:
	return Rect2(48, 1392, 708, 88) if portrait else Rect2(656, 581, 560, 70)

func arrow_rect(direction: int) -> Rect2:
	var area := stage_rect()
	return Rect2(area.position.x + (16 if direction < 0 else area.size.x - 104), area.get_center().y - 44, 88, 88)

func dice_card(index: int) -> Rect2:
	return Rect2(48 + (index % 2) * 366, 282 + floori(index / 2.0) * 364, 342, 336) if portrait else Rect2(64 + (index % 4) * 296, 158 + floori(index / 4.0) * 252, 272, 228)

func modal_rect() -> Rect2:
	return Rect2(24, 244, 756, 1260) if portrait else Rect2(144, 64, 992, 604)

func close_rect() -> Rect2:
	var area := modal_rect()
	return Rect2(area.end.x - (112 if portrait else 78), area.position.y + 20, 88 if portrait else 58, 88 if portrait else 58)

func settings_rect() -> Rect2:
	return Rect2(590,124,174,80) if portrait else Rect2(1060,34,172,56)

func language_rect(index: int) -> Rect2:
	return Rect2(88,530+index*144,628,112) if portrait else Rect2(368,260+index*100,544,72)

func skill_tab_rect(index: int) -> Rect2:
	return Rect2(48 + index * 240, 370, 228, 84) if portrait else Rect2(168 + index * 232, 142, 220, 52)

func city_rect() -> Rect2:
	return Rect2(48, 1394, 708, 80) if portrait else Rect2(886, 142, 224, 52)

func equip_rect() -> Rect2:
	return Rect2(88, 1320, 628, 104) if portrait else Rect2(670, 544, 380, 76)

func collection_rect(slot: int) -> Rect2:
	return Rect2(48 + (slot % 2) * 366, 398 + floori(slot / 2.0) * 286, 342, 264) if portrait else Rect2(174 + (slot % 4) * 232, 202 + floori(slot / 4.0) * 180, 220, 164)

func pager_rect(direction: int) -> Rect2:
	var area := modal_rect()
	return Rect2(area.position.x + (24 if direction < 0 else area.size.x - 112), area.end.y - 108, 88, 80)

func _process(delta: float) -> void:
	age += delta
	reveal = move_toward(reveal, 1, delta * 5)
	swipe_nudge = move_toward(swipe_nudge, 0, delta * 150)
	if active_touch == -1 and not pointer_down: pointer = get_global_mouse_position()
	_update_preview()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _interactive(pointer) else Input.CURSOR_ARROW)
	queue_redraw()

func _interactive(point: Vector2) -> bool:
	if not modal.is_empty(): return modal_rect().has_point(point)
	if settings_rect().has_point(point): return true
	for i in range(5):
		if tab_rect(i).has_point(point): return true
	if page == 2: return play_rect().has_point(point)
	if page == 1: return skills_rect().has_point(point) or picker_rect().has_point(point) or (ancients.size() > 1 and stage_rect().has_point(point))
	if page == 0:
		for i in range(dices.size()):
			if dice_card(i).has_point(point): return true
	return false

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		pointer_down = false
		active_touch = -1

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_press(get_global_transform_with_canvas().affine_inverse() * event.position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			if event.canceled: pointer_down = false
			else: _release(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_drag(get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == -1 or active_touch >= 0: return
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed: _press(point)
		else: _release(point)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_down and active_touch == -1:
		_drag(get_global_transform_with_canvas().affine_inverse() * event.position)

func _press(point: Vector2) -> void:
	pointer_down = true
	press_at = point
	pointer = point
	drag_distance = 0

func _drag(point: Vector2) -> void:
	pointer = point
	drag_distance = maxf(drag_distance, point.distance_to(press_at))

func _release(point: Vector2) -> void:
	if not pointer_down: return
	pointer_down = false
	_drag(point)
	var distance: Vector2 = point - press_at
	if modal.is_empty() and page == 1 and stage_rect().has_point(press_at) and absf(distance.x) > 72 and absf(distance.x) > absf(distance.y) * 1.3:
		_cycle_ancient(1 if distance.x < 0 else -1)
	elif drag_distance < 28:
		_activate(point)

func _cycle_ancient(direction: int) -> void:
	if ancients.size() > 1:
		ancient_index = posmod(ancient_index + direction, ancients.size())
		reveal = 0
		_click()
	swipe_nudge = -direction * 24

func _activate(point: Vector2) -> void:
	if not modal.is_empty():
		if close_rect().has_point(point) or not modal_rect().has_point(point):
			modal = ""
			_click()
		elif modal == "skills":
			for i in range(3):
				if skill_tab_rect(i).has_point(point):
					skill_page = i
					_click()
			if city_rect().has_point(point):
				city_skills = not city_skills
				_click()
		elif modal == "settings":
			for i in range(GameText.LANGUAGES.size()):
				if language_rect(i).has_point(point):
					GameText.set_language(GameText.LANGUAGES[i])
					_click()
		elif modal == "ancients":
			for slot in range(6 if portrait else 8):
				var index: int = picker_offset + slot
				if index < ancients.size() and collection_rect(slot).has_point(point):
					ancient_index = index
					modal = ""
					reveal = 0
					_click()
			var capacity: int = 6 if portrait else 8
			for direction in [-1, 1]:
				if pager_rect(direction).has_point(point):
					picker_offset = clampi(picker_offset + direction * capacity, 0, floori((ancients.size() - 1.0) / capacity) * capacity)
		elif modal == "dice" and equip_rect().has_point(point):
			dice_index = detail_dice
			modal = ""
			_click()
		_update_preview()
		return
	if settings_rect().has_point(point):
		modal = "settings"
		_click()
		_update_preview()
		return
	for i in range(5):
		if tab_rect(i).has_point(point):
			page = i
			reveal = 0
			_click()
			_update_preview()
			return
	match page:
		2:
			if play_rect().has_point(point): start_battle()
		1:
			if picker_rect().has_point(point):
				modal = "ancients"
				picker_offset = 0
			elif skills_rect().has_point(point): modal = "skills"
			elif arrow_rect(-1).has_point(point): _cycle_ancient(-1)
			elif arrow_rect(1).has_point(point): _cycle_ancient(1)
			_click()
		0:
			for i in range(dices.size()):
				if dice_card(i).has_point(point):
					detail_dice = i
					modal = "dice"
					_click()
	_update_preview()

func _click() -> void:
	if not muted and DisplayServer.get_name() != "headless": click_audio.play()

func start_battle() -> void:
	if is_instance_valid(battle): return
	modal = ""
	pointer_down = false
	active_touch = -1
	battle = (PortraitBattle if portrait else LandscapeBattle).instantiate()
	battle.home_enabled = true
	battle.selected_ancient_id = ancients[ancient_index].id
	battle.selected_dice_id = dices[dice_index].id
	battle.muted = muted
	battle.reduced = reduced
	battle.speed = speed
	battle.home_requested.connect(_return_home, CONNECT_DEFERRED)
	get_parent().add_child(battle)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED

func _return_home() -> void:
	if not is_instance_valid(battle): return
	muted = battle.muted
	reduced = battle.reduced
	speed = battle.speed
	# Free only after the input callback has finished; exiting also cancels scene tweens.
	battle.get_parent().remove_child(battle)
	battle.queue_free()
	battle = null
	page = 2
	modal = ""
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	_configure_layout()
	reveal = 0
	_update_preview()

func _update_preview() -> void:
	preview_die.visible = modal == "dice" or (modal.is_empty() and page == 0)
	if not preview_die.visible: return
	preview_die.face = dices[detail_dice if modal == "dice" else 0].face
	preview_die.position = (Vector2(402, 672) if portrait else Vector2(430, 358)) if modal == "dice" else dice_card(0).get_center() - Vector2(0, 34)
	preview_die.position.y += roundf(sin(age * 1.6) * 5)
	preview_die.scale = Vector2.ONE * ((2.6 if portrait else 2.0) if modal == "dice" else (1.55 if portrait else 1.05))
	preview_die.queue_redraw()

func _draw() -> void:
	_background()
	_button(settings_rect(),"Settings")
	var header := Vector2(48, 168) if portrait else Vector2(48, 70)
	_text(header, TABS[page], 48 if portrait else 36, GOLD)
	_text(header + Vector2(0, 46 if portrait else 32), ["Relics of chance", "Choose your awakening", "Let the world tremble", "Beyond the veil", ""][page], 24 if portrait else 18, MUTED)
	match page:
		2: _draw_play()
		1: _draw_ancient()
		0: _draw_dices()
		3: _draw_summon()
	_draw_tabs()
	if not modal.is_empty():
		draw_rect(Rect2(Vector2.ZERO, canvas_size()), Color(INK, 0.93))
		_frame(modal_rect(), Color("253029"), GOLD)
		_button(close_rect(), "X")
		match modal:
			"ancients": _draw_picker()
			"dice": _draw_dice_detail()
			"skills": _draw_skills()
			"settings": _draw_settings()

func _draw_settings() -> void:
	var area := modal_rect()
	_text(area.position+Vector2(24,68 if portrait else 50),"SETTINGS",34 if portrait else 28,GOLD)
	_center(Vector2(area.get_center().x,450 if portrait else 225),"Choose your language",28 if portrait else 22,CREAM)
	for i in range(GameText.LANGUAGES.size()):
		var rect := language_rect(i)
		var selected: bool = GameText.language == GameText.LANGUAGES[i]
		_button(rect,GameText.LANGUAGE_NAMES[i],true,GREEN if selected else EDGE)
		if selected: draw_rect(rect.grow(-5),GREEN,false,3)

func _background() -> void:
	var size := canvas_size()
	_stone(Rect2(Vector2.ZERO, size), Color("242c28"), 128)
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.62))
	for x in [16, int(size.x) - 20]:
		draw_rect(Rect2(x, 96 if portrait else 24, 3, size.y - (188 if portrait else 48)), Color(EDGE, 0.45))
	for i in range(36):
		var x: float = fposmod(i * 137.0 + 29, size.x - 80) + 40
		var y: float = fposmod(i * 199.0 - age * (6 + i % 4), size.y - 160) + 80
		draw_rect(Rect2(Vector2(x, y).snapped(Vector2.ONE * 4), Vector2.ONE * (2 if i % 3 else 4)), Color(GREEN, 0.09 + sin(age + i) * 0.04))

func _draw_shrine() -> void:
	var rect := stage_rect()
	var center := rect.get_center() + Vector2(swipe_nudge, 0)
	_art("arch", Rect2(rect.position + Vector2(rect.size.x * 0.06, -10), Vector2(rect.size.x * 0.88, rect.size.y * 0.91)), Color("425647"))
	for direction in [-1, 1]:
		_art("column", Rect2(center.x + direction * rect.size.x * 0.36 - 62, rect.end.y - 192, 124, 154), Color("737760"))
	var radius: float = rect.size.x * 0.35
	var feet := Vector2(center.x, rect.end.y - 84)
	Pixel.disc(self, feet, radius, Color("344333"), 6, 0.24)
	_seal(feet, radius, 0.27, GREEN)
	var side: float = 352 if portrait else 280
	var lift: float = roundf(sin(age * 1.6) * 8) + (1 - reveal) * 18
	var sprite := Rect2(center.x - side / 2, feet.y - side - 20 + lift, side, side)
	_art(ancients[ancient_index].art, sprite.grow(6), Color(0.43, 0.7, 0.3, 0.08))
	_art(ancients[ancient_index].art, sprite, Color(1, 1, 1, 0.55 + reveal * 0.45))
	for i in range(9):
		var angle: float = i * TAU / 9 + age * 0.16
		var point := feet + Vector2(cos(angle) * radius * 0.95, sin(angle) * radius * 0.22 - 18 - fposmod(age * 16 + i * 21, 110))
		draw_rect(Rect2(point.snapped(Vector2.ONE * 4), Vector2(4, 8)), Color(GREEN, 0.5))
	_center(Vector2(center.x, rect.position.y + 36), ancients[ancient_index].epithet, 22 if portrait else 18, MUTED)

func _draw_play() -> void:
	_draw_shrine()
	var at := Vector2(402, 1010) if portrait else Vector2(936, 244)
	_center(at, ancients[ancient_index].name, 42 if portrait else 36, CREAM)
	_center(at + Vector2(0, 50 if portrait else 42), ancients[ancient_index].style, 24 if portrait else 20, GREEN)
	var y: float = 1128 if portrait else 348
	var start: float = 78 if portrait else 702
	var step: float = 72 if portrait else 52
	for i in range(Run.Waves.COUNT):
		var p := Vector2(start+(i%10)*step,y+floori(i/10.0)*(84 if portrait else 74))
		if i%10 < 9: Pixel.line(self,p,p+Vector2(step,0),EDGE.darkened(0.4),3)
		var special: bool = i == Run.Waves.CITY_STAGE or not Run.Waves.SQUADS[i].special.is_empty() or Run.Waves.SQUADS[i].general[1] > 0
		var key: String = "crown" if i == Run.Waves.CITY_STAGE else Run.EnemyCatalog.ITEMS[Run.Waves.SQUADS[i].special[0][0]].art if not Run.Waves.SQUADS[i].special.is_empty() else ["vanguard","archer","mage"][i%3]
		Pixel.disc(self,p,23 if portrait else 19,INK,4)
		_art(key,Rect2(p-Vector2.ONE*18,Vector2.ONE*36),GOLD if special else MUTED)
		_center(p+Vector2(0,43),str(i+1),20 if portrait else 16,GOLD if special else MUTED)
	_center(Vector2(at.x, 1290 if portrait else 482), dices[dice_index].name, 24 if portrait else 20, MUTED)
	var button := play_rect()
	_button(button, "", true, GREEN)
	_mini_die(button.get_center() + Vector2(-92, 0), dices[dice_index].face, 48 if portrait else 38)
	_center(button.get_center() + Vector2(34, 14), "PLAY", 46 if portrait else 36, CREAM)

func _draw_ancient() -> void:
	_draw_shrine()
	for direction in [-1, 1]: _button(arrow_rect(direction), "<" if direction < 0 else ">", ancients.size() > 1)
	var rect := stage_rect()
	_center(Vector2(rect.get_center().x, rect.end.y + 12), "%02d / %02d" % [ancient_index + 1, ancients.size()], 22 if portrait else 16, MUTED)
	var at := Vector2(48, 1028) if portrait else Vector2(656, 212)
	_text(at, ancients[ancient_index].name, 42 if portrait else 36, CREAM)
	_text(at + Vector2(0, 50), ancients[ancient_index].style, 24 if portrait else 20, GREEN)
	_wrapped(at + Vector2(0, 106), ancients[ancient_index].lore, 708 if portrait else 550, 24 if portrait else 22, MUTED)
	_button(skills_rect(), "DICE SKILLS", true, GREEN)
	_button(picker_rect(), GameText.format("ANCIENTS  /  %02d", ancients.size()))

func _draw_dices() -> void:
	for i in range(dices.size()):
		var card := dice_card(i)
		_frame(card, Color("364031"), GREEN if dice_index == i else EDGE)
		if i > 0: _mini_die(card.get_center() - Vector2(0, 34), dices[i].face, 92 if portrait else 68)
		_text(card.position + Vector2(20, 36), dices[i].rarity, 22 if portrait else 16, MUTED)
		_center(Vector2(card.get_center().x, card.end.y - 58), dices[i].name, 28 if portrait else 22, CREAM)
		_center(Vector2(card.get_center().x, card.end.y - 24), "EQUIPPED" if dice_index == i else "VIEW", 20 if portrait else 16, GREEN)
	_text(Vector2(48, 690) if portrait else Vector2(64, 446), "Tap a die to inspect it.", 24 if portrait else 20, MUTED)

func _draw_summon() -> void:
	var at := Vector2(402, 800) if portrait else Vector2(640, 366)
	_seal(at, 220 if portrait else 150, 0.72, PURPLE.darkened(0.45))
	_art("book", Rect2(at - Vector2.ONE * 64, Vector2.ONE * 128), MUTED)
	_center(at + Vector2(0, 280 if portrait else 206), "THE VEIL IS QUIET", 28 if portrait else 24, MUTED)
	_center(at + Vector2(0, 326 if portrait else 244), "Summoning comes later.", 22 if portrait else 18, MUTED)

func _draw_tabs() -> void:
	for i in range(5):
		var rect := tab_rect(i)
		var selected: bool = page == i
		_frame(rect.grow(-2), Color("404630") if selected else Color("252d27"), GOLD if selected else EDGE.darkened(0.3))
		if selected: draw_rect(Rect2(rect.position + Vector2(16, 4), Vector2(rect.size.x - 32, 4)), GOLD)
		var center := Vector2(rect.get_center().x, rect.position.y + (51 if portrait else 31))
		var color: Color = GOLD if selected else MUTED
		match i:
			0: _mini_die(center, 5, 42 if portrait else 28, color)
			1: _art("eldritch", Rect2(center - Vector2.ONE * 28, Vector2.ONE * 56), color)
			2:
				Pixel.circle(self, center, 27 if portrait else 19, color, 3)
				var s: float = 16 if portrait else 11
				draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.45, -s), center + Vector2(s, 0), center + Vector2(-s * 0.45, s)]), color)
			3:
				Pixel.circle(self, center, 24 if portrait else 18, color, 3)
				_art("fx", Rect2(center - Vector2.ONE * 22, Vector2.ONE * 44), color)
			4:
				draw_rect(Rect2(center - Vector2(24, 16), Vector2(48, 34)), color)
				draw_rect(Rect2(center - Vector2(21, 3), Vector2(42, 4)), INK)
				draw_rect(Rect2(center - Vector2(4, 6), Vector2(8, 15)), GOLD.darkened(0.5))
		_center(Vector2(center.x, rect.end.y - (24 if portrait else 14)), TABS[i], 22 if portrait else 18, color)

func _draw_picker() -> void:
	var area := modal_rect()
	_text(area.position + Vector2(24, 68 if portrait else 50), "ANCIENTS", 34 if portrait else 28, GOLD)
	for slot in range(6 if portrait else 8):
		var index: int = picker_offset + slot
		if index >= ancients.size(): break
		var rect := collection_rect(slot)
		_frame(rect, Color("364031"), GREEN if index == ancient_index else EDGE)
		var side: float = 140 if portrait else 88
		_art(ancients[index].art, Rect2(rect.get_center().x - side / 2, rect.position.y + 20, side, side))
		_center(Vector2(rect.get_center().x, rect.end.y - 62 if portrait else rect.end.y - 42), ancients[index].name, 24 if portrait else 18, CREAM)
		_center(Vector2(rect.get_center().x, rect.end.y - 24), "SELECTED" if index == ancient_index else "SELECT", 20 if portrait else 16, GREEN)
	if ancients.size() > (6 if portrait else 8):
		for direction in [-1, 1]: _button(pager_rect(direction), "<" if direction < 0 else ">")
	_center(Vector2(area.get_center().x, area.end.y - 45), "Swipe the portrait to browse.", 22 if portrait else 18, MUTED)

func _draw_dice_detail() -> void:
	var area := modal_rect()
	_text(area.position + Vector2(24, 68 if portrait else 50), "DICE RELIC", 34 if portrait else 28, GOLD)
	var at := Vector2(402, 672) if portrait else Vector2(430, 358)
	_seal(at + Vector2(0, 84), 236 if portrait else 192, 0.46, GOLD.darkened(0.2))
	var info := Vector2(72, 962) if portrait else Vector2(670, 202)
	_text(info, dices[detail_dice].name, 40 if portrait else 32, CREAM)
	_text(info + Vector2(0, 48), "BASIC  /  D6  /  THREE DICE", 22 if portrait else 16, GOLD)
	var y := _wrapped(info + Vector2(0, 100), dices[detail_dice].description, 660 if portrait else 412, 24 if portrait else 18, CREAM)
	_wrapped(Vector2(info.x, y + (54 if portrait else 32)), dices[detail_dice].effect, 660 if portrait else 412, 22 if portrait else 18, MUTED)
	_button(equip_rect(), "EQUIPPED" if detail_dice == dice_index else "EQUIP", true, GREEN)

func _draw_skills() -> void:
	var area := modal_rect()
	_text(area.position + Vector2(24, 68 if portrait else 50), "DICE SKILLS", 34 if portrait else 28, GOLD)
	for i in range(3): _button(skill_tab_rect(i), ["NORMAL", "DOUBLES", "TRIPLES"][i], true, GREEN if skill_page == i else EDGE)
	_button(city_rect(), "CITY" if city_skills else "SQUAD", true, PURPLE if city_skills else GOLD)
	if skill_page == 0:
		var at := Vector2(402, 650) if portrait else Vector2(640, 292)
		for i in range(3): _mini_die(at + Vector2((i - 1) * 112, 0), i + 1, 80 if portrait else 60)
		_center(at + Vector2(0, 144 if portrait else 86), Rules.NORMAL_NAME, 36 if portrait else 28, CREAM)
		var point := Vector2(80, 934) if portrait else Vector2(248, 438)
		var info: String = "Three different faces combine into one sum. Choose a foe and cast the skill for the total, multiplied by attack power and growth."
		if city_skills: info = "Three different faces combine into one sum. Strike the city with the total, attack power, growth and the siege multiplier."
		var y := _wrapped(point, info, 640 if portrait else 784, 28 if portrait else 22, CREAM)
		_wrapped(Vector2(point.x, y + 70), "Aim near the center of the power bar for more doubles and triples.", 640 if portrait else 784, 24 if portrait else 20, MUTED)
		return
	for i in range(6):
		var rect := Rect2(48, 490 + i * 146, 708, 138) if portrait else Rect2(168 + (i % 2) * 480, 218 + floori(i / 2.0) * 140, 464, 132)
		var color: Color = GREEN if skill_page == 1 else GOLD if i == 5 else PURPLE
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 4), Vector2(rect.size.x, 2)), Color(EDGE, 0.55))
		var count: int = 2 if skill_page == 1 else 3
		var mini_side: float = 36 if portrait else 24
		for n in range(count): _mini_die(rect.position + Vector2(22 + n * (mini_side + 8), 34 if portrait else 20), i + 1, mini_side)
		var name_at := rect.position + (Vector2(158, 38) if portrait else Vector2(106, 27))
		var label: String = Rules.PAIR_NAMES[i] if skill_page == 1 else Rules.SPECIAL_NAMES[i]
		var description: String = Rules.PAIR_TEXT[i] if skill_page == 1 else (Rules.CITY_SPECIAL_TEXT[i] if city_skills else Rules.SPECIAL_TEXT[i])
		if city_skills and skill_page == 1 and i == 1: description = "City is immune to freeze."
		_text(name_at, label, 24 if portrait else 18, color)
		_wrapped(rect.position + (Vector2(12, 76) if portrait else Vector2(10, 62)), description, 684 if portrait else 440, 28 if portrait else 22, CREAM)

func _text(at: Vector2, value: String, size: int, color: Color = CREAM) -> void:
	value = GameText.text(value)
	draw_string(pixel_font, at.round() + Vector2(2, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
	draw_string(pixel_font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(at: Vector2, value: String, size: int, color: Color = CREAM) -> void:
	value = GameText.text(value)
	_text(at - Vector2(pixel_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, 0), value, size, color)

func _wrapped(at: Vector2, value: String, width: float, size: int, color: Color) -> float:
	var font: Font = GameText.description_font()
	size = maxi(size,28 if portrait else 22)
	var y: float = at.y
	for line in GameText.lines(value, font, size, width):
		draw_string(font,Vector2(at.x,y).round(),line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		y += size+10
	return maxf(at.y,y-size-10)

func _art(key: String, rect: Rect2, color: Color = Color.WHITE) -> void:
	if not art.has(key): art[key] = load("res://assets/art/fantasy/" + key + ".png")
	draw_texture_rect(art[key], Rect2(rect.position.round(), rect.size), false, color)

func _stone(rect: Rect2, tint: Color, unit: int = 64) -> void:
	for y in range(int(rect.position.y), int(rect.end.y), unit):
		for x in range(int(rect.position.x), int(rect.end.x), unit):
			var size := Vector2(minf(unit, rect.end.x - x), minf(unit, rect.end.y - y))
			draw_texture_rect_region(art.stone, Rect2(Vector2(x, y), size), Rect2(Vector2(3, 3), size * 26 / unit), tint)

func _frame(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(INK, 0.65))
	_stone(rect, fill)
	draw_rect(rect, INK, false, 4)
	draw_rect(rect.grow(-4), border.darkened(0.25), false, 2)
	for corner in [rect.position, Vector2(rect.end.x - 12, rect.position.y), rect.end - Vector2(12, 12), Vector2(rect.position.x, rect.end.y - 12)]:
		draw_rect(Rect2(corner + Vector2(4, 4), Vector2(4, 4)), border)

func _button(rect: Rect2, label: String, enabled: bool = true, accent: Color = GOLD) -> void:
	var hover: bool = enabled and rect.has_point(pointer)
	_frame(rect, Color("46523b") if hover else Color("333b2e"), accent if enabled else EDGE.darkened(0.5))
	_center(rect.get_center() + Vector2(0, 10 if portrait else 7), label, 28 if portrait else 22, accent if enabled else MUTED.darkened(0.6))

func _mini_die(at: Vector2, face: int, side: float, tint: Color = CREAM) -> void:
	draw_rect(Rect2((at - Vector2.ONE * side / 2 + Vector2(0, 4)).round(), Vector2.ONE * side), Color("786343"))
	draw_rect(Rect2((at - Vector2.ONE * side / 2).round(), Vector2.ONE * side), tint)
	var layouts := [[4], [0,8], [0,4,8], [0,2,6,8], [0,2,4,6,8], [0,2,3,5,6,8]]
	for pip in layouts[face - 1]:
		var point := at + Vector2(pip % 3 - 1, floori(pip / 3.0) - 1) * side * 0.27 - Vector2.ONE * side * 0.065
		draw_rect(Rect2(point.round(), Vector2.ONE * maxf(3, roundf(side * 0.13))), INK)

func _seal(at: Vector2, radius: float, squash: float, color: Color) -> void:
	for ring in [1.0, 0.89, 0.64]:
		for i in range(80):
			var a: float = i * TAU / 80
			var b: float = (i + 1) * TAU / 80
			Pixel.line(self, at + Vector2(cos(a), sin(a) * squash) * radius * ring, at + Vector2(cos(b), sin(b) * squash) * radius * ring, Color(color, 0.4 if ring == 0.64 else 0.66), 3)
	for i in range(12):
		var angle: float = i * TAU / 12 + age * 0.045
		var p := at + Vector2(cos(angle), sin(angle) * squash) * radius * 0.77
		Pixel.line(self, p - Vector2(6, 5), p + Vector2(6, 5), color, 3)
		Pixel.line(self, p + Vector2(-6, 5), p + Vector2(6, -5), color, 3)
