extends RefCounted
## One tabbed debug layout drives drawing, hit testing and numeric fields in both screen sizes.
const Enemies = preload("res://scripts/enemies/enemy_debug.gd")
const Character = preload("res://scripts/player/character_debug.gd")
const TABS := ["骰子","战斗","奖励"]
const CHEST_LABELS := ["生成普通宝箱","生成完美宝箱","生成贪婪宝箱","生成究极宝箱"]
const CONTROL_HINTS := ["V1：单骰即点即重掷。","V2：多选后在中间确认重掷。","V3：中间投掷／取消，左侧重掷／结束，右侧确认。","V4：连击保留左侧，中间投掷／确认，右侧重掷／结束。"]
enum Page { DICE, BATTLE, REWARDS }
var battle
var page: int = Page.DICE
var portrait: bool = false
var level_input: LineEdit
var level_rect: Rect2
var apply_rect: Rect2
var character_input: LineEdit
var character_rect: Rect2
var character_apply_rect: Rect2

## Layout is shared by paint and input; only controls on the active tab accept clicks.
func setup(owner) -> void:
	battle = owner
	portrait = battle.DICE_RADIUS > 200
	battle.DEBUG_REPEAT = Rect2(40,480,350,88) if portrait else Rect2(480,244,316,44)
	battle.DEBUG_PERFECT = Rect2(414,480,350,88) if portrait else Rect2(824,244,316,44)
	battle.DEBUG_WAVE_INPUT = Rect2(260,390,150,88) if portrait else Rect2(302,256,140,48)
	battle.DEBUG_WAVE_LOAD = Rect2(440,390,324,88) if portrait else Rect2(478,256,292,48)
	level_rect = Rect2(260,566,150,88) if portrait else Rect2(302,356,140,48)
	apply_rect = Rect2(440,566,324,88) if portrait else Rect2(478,356,292,48)
	character_rect = Rect2(260,742,150,88) if portrait else Rect2(302,456,140,48)
	character_apply_rect = Rect2(440,742,324,88) if portrait else Rect2(478,456,292,48)
	battle.DEBUG_SHOP = Rect2(40,958,724,96) if portrait else Rect2(136,534,500,50)
	for entry in [["DEBUG_TAROTS",0],["DEBUG_TAROT_DRAW",1],["DEBUG_TREASURE",2],["DEBUG_GEMS",3],["DEBUG_CHEST",8]]:
		battle.set(entry[0],reward_rect(entry[1]))

## Keep the reward grid within the panel as new debug reward controls are added.
func reward_rect(index: int) -> Rect2:
	return Rect2(40+(index%2)*374,420+(index/2)*150,350,100) if portrait else Rect2(136+(index%2)*524,250+(index/2)*76,500,58)

func chest_option_rect(tier: int) -> Rect2:
	return reward_rect(4+tier)

func tab_rect(index: int) -> Rect2:
	return Rect2(40+index*249,262,226,88) if portrait else Rect2(136+index*344,176,316,48)

## Equal checkbox hit areas share a single mutually exclusive mode value.
func control_rect(version: int) -> Rect2:
	var count: int = battle.ControlVersion.size()
	var gap: float = 16 if portrait else 28
	var width: float = ((724.0 if portrait else 1004.0)-gap*(count-1))/count
	return Rect2(Vector2(40 if portrait else 136,1360 if portrait else 594)+Vector2(version*(width+gap),0),Vector2(width,88 if portrait else 44))

func option_rect(choice: int) -> Rect2:
	if choice == battle.DebugDice.NATURAL: return Rect2(40,374,724,80) if portrait else Rect2(136,244,316,44)
	var index: int = battle.DEBUG_DICE_PRESETS.keys().find(choice)
	if index < 0: return Rect2()
	return Rect2(40+(index%2)*374,606+(index/2)*242,350,222) if portrait else Rect2(136+(index%3)*344,318+(index/3)*140,316,120)

## Hide inactive text fields immediately so they cannot capture another tab's controls.
func sync_inputs() -> void:
	var show_fields: bool = battle.debug_open and page == Page.BATTLE
	battle.debug_wave_input.visible = show_fields
	level_input.visible = show_fields
	character_input.visible = show_fields
	if not show_fields:
		battle.debug_wave_input.release_focus()
		level_input.release_focus()
		character_input.release_focus()

func open() -> void:
	var living: Array = battle.model.living()
	level_input.text = str(battle.model.enemies[living[0]].level) if not living.is_empty() else "1"
	character_input.text = str(battle.model.character_level)
	sync_inputs()

## Only change evolution when no roll, cast or advancing animation is in flight.
func can_apply_character_level() -> bool:
	return Character.can_apply(battle.model) and battle.view_phase in ["ready","charging","skill","targeting","frozen","wave_reward","reward","shop"]

## Apply stats now and queue the visual transition until the menu closes.
func apply_character_level(value: String) -> void:
	if not battle.debug_open or page != Page.BATTLE: return
	var text: String = value.strip_edges()
	if not text.is_valid_int() or int(text) < 1 or int(text) > Character.MAX_LEVEL:
		battle.debug_wave_error = "请输入1到%d之间的角色等级。" % Character.MAX_LEVEL
		return
	if not can_apply_character_level() or not Character.set_level(battle.model,int(text)):
		battle.debug_wave_error = "请在战斗等待操作或商店中调整角色等级。"
		return
	battle.player_animation.reset()
	battle.soul_pickup.reset()
	battle.evolution.queue_debug_level(battle.model.character_level)
	battle.health_trails.reset(battle.model)
	battle.damage_feedback.clear()
	battle.dice_selection._refresh_preview()
	battle._cancel_enemy_hold()
	battle.debug_wave_error = "角色已设为 LV.%d · 形态%d。" % [battle.model.character_level,battle.evolution.form_index(battle.model.character_level)+1]
	battle.queue_redraw()

## Retain the encounter and current HP percentages; invalid/busy submissions change nothing.
func apply_level(value: String) -> void:
	if not battle.debug_open or page != Page.BATTLE: return
	var text: String = value.strip_edges()
	if not text.is_valid_int() or int(text) < 1 or int(text) > Enemies.MAX_LEVEL:
		battle.debug_wave_error = "请输入1到%d之间的敌人等级。" % Enemies.MAX_LEVEL
	elif not Enemies.set_level(battle.model,int(text)):
		battle.debug_wave_error = "请在战斗等待操作时调整敌人等级。"
	else:
		battle.debug_wave_error = "当前存活敌人已设为 LV.%d。" % int(text)
		battle._cancel_enemy_hold()
		battle.queue_redraw()

## Each row is a visible button, its action and its current availability.
func buttons() -> Array:
	if page == Page.DICE:
		var rows: Array = [[battle.DEBUG_REPEAT,"重复："+("开" if battle.debug_repeat else "关"),"repeat",true],[battle.DEBUG_PERFECT,"完美投掷："+("开" if battle.debug_perfect else "关"),"perfect",true]]
		for version in battle.ControlVersion.values(): rows.append([control_rect(version),"V%d" % (version+1),"control_version",true,version])
		return rows
	if page == Page.BATTLE:
		return [[battle.DEBUG_WAVE_LOAD,"载入关卡","wave",true],[apply_rect,"应用等级","level",Enemies.can_apply(battle.model)],[character_apply_rect,"设置角色等级","character_level",can_apply_character_level()],[battle.DEBUG_SHOP,"商店 · 无限血宝石","_debug_open_shop",battle._can_debug_shop()]]
	var rows: Array = [[battle.DEBUG_TAROTS,"获得全部22张塔罗牌","_debug_give_tarots",true],[battle.DEBUG_TAROT_DRAW,"抽取塔罗牌","_debug_draw_tarot",true],[battle.DEBUG_TREASURE,"充满重投宝箱进度","_debug_charge_treasure",true],[battle.DEBUG_GEMS,"获得全部种类宝石","_debug_give_gemstones",true]]
	for tier in range(CHEST_LABELS.size()):
		rows.append([chest_option_rect(tier),CHEST_LABELS[tier],"chest",battle._can_debug_chest(),tier])
	rows.append([battle.DEBUG_CHEST,"普通宝箱（可升级）","_debug_spawn_chest",battle._can_debug_chest()])
	return rows

func hit(point: Vector2) -> bool:
	if battle.DEBUG_CLOSE.has_point(point): return true
	for i in range(TABS.size()):
		if tab_rect(i).has_point(point): return true
	for row in buttons():
		if row[3] and row[0].has_point(point): return true
	if page == Page.DICE:
		for choice in [battle.DebugDice.NATURAL]+battle.DEBUG_DICE_PRESETS.keys():
			if option_rect(choice).has_point(point): return true
	return page == Page.BATTLE and (level_rect.has_point(point) or character_rect.has_point(point) or battle.DEBUG_WAVE_INPUT.has_point(point))

func click(point: Vector2) -> void:
	if battle.DEBUG_CLOSE.has_point(point): battle._close_debug(); return
	for i in range(TABS.size()):
		if tab_rect(i).has_point(point):
			page = i; battle.debug_wave_error = ""; sync_inputs(); return
	for row in buttons():
		if not row[0].has_point(point): continue
		if not row[3]: return
		match row[2]:
			"repeat": battle.debug_repeat = not battle.debug_repeat
			"perfect": battle.debug_perfect = not battle.debug_perfect
			"control_version": battle.dice_selection.set_control_version(row[4])
			"wave": battle._debug_load_wave(battle.debug_wave_input.text)
			"level": apply_level(level_input.text)
			"character_level": apply_character_level(character_input.text)
			"chest": battle._debug_spawn_chest(row[4])
			_: battle.call(row[2])
		return
	if page == Page.DICE:
		for choice in [battle.DebugDice.NATURAL]+battle.DEBUG_DICE_PRESETS.keys():
			if option_rect(choice).has_point(point):
				battle.debug_choice = choice
				battle._close_debug(false)
				battle._sound("ui/book",1.4,-17)
				return

func paint(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,Vector2(804,1748) if portrait else Vector2(1280,800)),battle.INK)
	if not portrait: battle._frame(Rect2(106,100,1070,592),battle.PANEL,battle.GOLD,canvas)
	battle._text(Vector2(40,188) if portrait else Vector2(136,148),"调试",42 if portrait else 32,battle.GOLD,canvas)
	battle._button(battle.DEBUG_CLOSE,"X",true,canvas)
	for i in range(TABS.size()):
		battle._button(tab_rect(i),TABS[i],true,canvas)
		if i == page: canvas.draw_rect(tab_rect(i).grow(-3),battle.GOLD,false,3)
	for row in buttons():
		if row[2] == "control_version": _paint_control_version(canvas,row[4])
		else: battle._button(row[0],row[1],row[3],canvas)
	if page == Page.DICE:
		battle._button(option_rect(-1),"自然随机",true,canvas)
		battle._draw_debug_dice(canvas)
		if battle.debug_perfect: canvas.draw_rect(battle.DEBUG_PERFECT.grow(-3),battle.GOLD,false,3)
		var hint: String = CONTROL_HINTS[battle.debug_control_version]
		battle._text(Vector2(40,1498) if portrait else Vector2(136,670),hint,24 if portrait else 20,battle.MUTED,canvas)
	elif page == Page.BATTLE:
		battle._text(Vector2(40,444) if portrait else Vector2(136,286),"关卡",28 if portrait else 22,battle.GOLD,canvas)
		battle._text(Vector2(40,620) if portrait else Vector2(136,386),"敌人等级",28 if portrait else 22,battle.GOLD,canvas)
		battle._text(Vector2(40,796) if portrait else Vector2(136,486),"角色等级",28 if portrait else 22,battle.GOLD,canvas)
		battle._wrapped(Vector2(40,1128) if portrait else Vector2(136,608),"敌人：保留生命比例、状态和蓄力。\n角色：同步进化，回满生命，当前经验归零。",724 if portrait else 1000,battle.MUTED,26 if portrait else 18,canvas)
	battle._wrapped(Vector2(40,1560) if portrait else Vector2(136,676 if page == Page.BATTLE else 650),battle.debug_wave_error,724 if portrait else 1000,battle.GOLD,26 if portrait else 18,canvas)

## A visible tick marks the active version; clicking it again leaves it selected.
func _paint_control_version(canvas: CanvasItem, version: int) -> void:
	var rect: Rect2 = control_rect(version)
	var checked: bool = battle.debug_control_version == version
	var color: Color = battle.GOLD if checked else battle.MUTED
	var side: float = 36 if portrait else 24
	var box := Rect2(rect.position+Vector2(20,(rect.size.y-side)/2),Vector2.ONE*side)
	canvas.draw_rect(box,battle.PANEL)
	canvas.draw_rect(box,color,false,3 if portrait else 2)
	if checked:
		canvas.draw_polyline(PackedVector2Array([box.position+box.size*Vector2(0.2,0.5),box.position+box.size*Vector2(0.43,0.75),box.position+box.size*Vector2(0.83,0.22)]),color,4 if portrait else 3,true)
	battle._text(Vector2(box.end.x+16,rect.get_center().y+(10 if portrait else 8)),"V%d" % (version+1),30 if portrait else 24,color,canvas)
