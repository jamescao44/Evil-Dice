extends RefCounted
## One tabbed debug layout drives drawing, hit testing and numeric fields in both screen sizes.
const Enemies = preload("res://scripts/enemies/enemy_debug.gd")
const TABS := ["骰子","战斗","奖励"]
const CHEST_LABELS := ["生成普通宝箱","生成完美宝箱","生成贪婪宝箱","生成究极宝箱"]
enum Page { DICE, BATTLE, REWARDS }
var battle
var page: int = Page.DICE
var portrait: bool = false
var level_input: LineEdit
var level_rect: Rect2
var apply_rect: Rect2

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
	battle.DEBUG_SHOP = Rect2(40,780,724,96) if portrait else Rect2(136,470,500,50)
	for entry in [["DEBUG_TAROTS",0],["DEBUG_TAROT_DRAW",1],["DEBUG_TREASURE",2],["DEBUG_GEMS",3],["DEBUG_CHEST",8]]:
		battle.set(entry[0],reward_rect(entry[1]))

## Keep the reward grid within the panel as new debug reward controls are added.
func reward_rect(index: int) -> Rect2:
	return Rect2(40+(index%2)*374,420+(index/2)*150,350,100) if portrait else Rect2(136+(index%2)*524,250+(index/2)*76,500,58)

func chest_option_rect(tier: int) -> Rect2:
	return reward_rect(4+tier)

func tab_rect(index: int) -> Rect2:
	return Rect2(40+index*249,262,226,88) if portrait else Rect2(136+index*344,176,316,48)

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
	if not show_fields:
		battle.debug_wave_input.release_focus()
		level_input.release_focus()

func open() -> void:
	var living: Array = battle.model.living()
	level_input.text = str(battle.model.enemies[living[0]].level) if not living.is_empty() else "1"
	sync_inputs()

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
		return [[battle.DEBUG_REPEAT,"重复："+("开" if battle.debug_repeat else "关"),"repeat",true],[battle.DEBUG_PERFECT,"完美投掷："+("开" if battle.debug_perfect else "关"),"perfect",true]]
	if page == Page.BATTLE:
		return [[battle.DEBUG_WAVE_LOAD,"载入关卡","wave",true],[apply_rect,"应用等级","level",Enemies.can_apply(battle.model)],[battle.DEBUG_SHOP,"商店 · 无限血宝石","_debug_open_shop",battle._can_debug_shop()]]
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
	return page == Page.BATTLE and (level_rect.has_point(point) or battle.DEBUG_WAVE_INPUT.has_point(point))

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
			"wave": battle._debug_load_wave(battle.debug_wave_input.text)
			"level": apply_level(level_input.text)
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
	for row in buttons(): battle._button(row[0],row[1],row[3],canvas)
	if page == Page.DICE:
		battle._button(option_rect(-1),"自然随机",true,canvas)
		battle._draw_debug_dice(canvas)
		if battle.debug_perfect: canvas.draw_rect(battle.DEBUG_PERFECT.grow(-3),battle.GOLD,false,3)
		battle._text(Vector2(40,1390) if portrait else Vector2(136,620),"数量不足时保留设置。",24 if portrait else 20,battle.MUTED,canvas)
	elif page == Page.BATTLE:
		battle._text(Vector2(40,444) if portrait else Vector2(136,286),"关卡",28 if portrait else 22,battle.GOLD,canvas)
		battle._text(Vector2(40,620) if portrait else Vector2(136,386),"敌人等级",28 if portrait else 22,battle.GOLD,canvas)
		battle._wrapped(Vector2(40,950) if portrait else Vector2(136,565),"调整当前存活敌人；保留生命比例、状态和蓄力。",724 if portrait else 1000,battle.MUTED,26 if portrait else 20,canvas)
	battle._wrapped(Vector2(40,1560) if portrait else Vector2(136,650),battle.debug_wave_error,724 if portrait else 1000,battle.GOLD,26 if portrait else 18,canvas)
