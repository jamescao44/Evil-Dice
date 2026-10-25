extends RefCounted
## Size-aware boss formation and icon/charge HUD shared by both layouts.
const CHARGE_COLOR := Color("ffb54e")
const BREAK_COLOR := Color("8be5ef")
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")

static func present(model) -> bool:
	return model.enemies.any(func(enemy): return enemy.get("boss",false))

## Center the boss body vertically; smaller bosses no longer sink toward the floor.
static func feet(battle, index: int) -> Vector2:
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var boss_side: float = battle._enemy_unit_side(0)
	var boss_y: float = battle.ARENA.get_center().y+boss_side*0.5
	var fanatic: bool = battle.model.enemies[0].role == Catalog.Role.FANATIC
	if fanatic: boss_y = 535 if portrait else 275
	if battle.model.enemies[index].get("boss",false):
		return Vector2(610 if fanatic else 530,boss_y) if portrait else Vector2(1240 if fanatic else 910,boss_y)
	if battle.model.enemies[index].get("summoned",false):
		if battle.model.enemies[index].role == Catalog.Role.BOUND_DEMON:
			return Vector2(315 if portrait else 590,590 if portrait else 270)
		var position: int = battle.model.enemies[index].get("summon_slot",0)
		return Vector2(415+(position%3)*140+(position/3)*10,680+(position/3)*150) if portrait else Vector2(620+(position%3)*190+(position/3)*70,365+(position/3)*145)
	var slot: int = index-1
	return Vector2(390+slot*300 if portrait else 630+slot*530,boss_y+boss_side*0.22)

## Zoom the entire world out only when a giant body cannot fit the available height.
static func rest_transform(battle, bounds: Rect2) -> Transform2D:
	if not present(battle.model): return Transform2D.IDENTITY
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	if portrait: return Transform2D.IDENTITY
	var full: Rect2 = bounds.merge(battle._player_world_sprite_rect())
	# Reserve the full charging HUD even while idle, so starting a charge never pans.
	var frame: Rect2 = Rect2(battle.ARENA.position+Vector2(28,150),battle.ARENA.size-Vector2(56,194))
	var factor: float = minf(1,minf(frame.size.x/full.size.x,frame.size.y/full.size.y))
	return Transform2D(0,Vector2.ONE*factor,0,frame.get_center()-full.get_center()*factor)

## Position all boss information above the head, leaving guard and player lanes free.
static func health_rect(battle, index: int) -> Rect2:
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var width: float = 270 if portrait else 220
	if battle.model.enemies[index].role == Catalog.Role.BOUND_DEMON: width = 220 if portrait else 190
	var head: Vector2 = battle._enemy_feet(index)-Vector2(0,battle._enemy_unit_side(index)*battle.battlefield_view.zoom)
	# Reserve the status row and its stack labels between the bar and the sprite.
	return Rect2(head-Vector2(width/2,62 if portrait else 54),Vector2(width,20))

static func marks_center(battle, index: int) -> Vector2:
	if battle.model.enemies[index].role == Catalog.Role.BOUND_DEMON:
		return health_rect(battle,index).get_center()+Vector2(35,-32)
	return health_rect(battle,index).get_center()-Vector2(0,32)

## Forecasting Charge alone does not reveal the marks; the first charge must land.
static func shows_marks(enemy: Dictionary) -> bool:
	return enemy.get("charging",false) and enemy.get("charge",0) > 0

## Give the move a normal square icon beside the boss name and phase.
static func intent_rect(battle, index: int) -> Rect2:
	var bar: Rect2 = health_rect(battle,index)
	var size: float = 40 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 30
	var offset: float = 110 if shows_marks(battle.model.enemies[index]) else size+10
	if battle.model.enemies[index].role == Catalog.Role.BOUND_DEMON and shows_marks(battle.model.enemies[index]): offset = 76
	return Rect2(bar.position-Vector2(0,offset),Vector2.ONE*size)

## Inspection includes the title and charging rows without enlarging the intent icon.
static func hud_rect(battle, index: int) -> Rect2:
	return health_rect(battle,index).merge(intent_rect(battle,index))

## Filled blue diamonds are the remaining casts needed to break the current charge.
static func paint(battle, index: int) -> void:
	var enemy: Dictionary = battle.model.enemies[index]
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var bar: Rect2 = health_rect(battle,index)
	var center: Vector2 = marks_center(battle,index)
	var font_size: int = 22 if portrait else 16
	var phase: String = "II" if enemy.get("boss_phase",1) == 2 else "I"
	var icon: Rect2 = intent_rect(battle,index)
	battle._center(Vector2(bar.get_center().x+icon.size.x*0.5,icon.get_center().y+font_size*0.35),GameText.text(enemy.name)+(" · "+phase if enemy.get("boss",false) else ""),font_size,data.color)
	battle._draw_enemy_intent(index)
	if not shows_marks(enemy): return
	var remaining: int = enemy.break_marks
	for i in range(data.break_casts):
		var at: Vector2 = center+Vector2((i-(data.break_casts-1)*0.5)*28,0)
		var lit: bool = i < remaining
		var diamond := PackedVector2Array([at+Vector2(0,-9),at+Vector2(8,0),at+Vector2(0,9),at+Vector2(-8,0)])
		battle.draw_colored_polygon(diamond,Color(BREAK_COLOR,0.85 if enemy.charging and lit else 0.3 if lit else 0.08))
		battle.draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),BREAK_COLOR if lit else Color("575f61"),2,true)
		if not lit:
			battle.draw_line(at+Vector2(-2,-6),at+Vector2(2,-1),Color("b6eff4"),2)
			battle.draw_line(at+Vector2(2,-1),at+Vector2(-3,6),Color("b6eff4"),2)
	for i in range(data.charge_turns):
		var at: Vector2 = center+Vector2((i-(data.charge_turns-1)*0.5)*38,-29)
		if enemy.role == Catalog.Role.BOUND_DEMON: at = Vector2(bar.position.x+18+i*30,center.y)
		var lit: bool = i < enemy.charge
		var pulse: float = 1 if battle.reduced else 0.82+0.18*sin(battle.clock_time*5)
		battle.draw_circle(at,12,Color(CHARGE_COLOR,0.22*pulse) if lit else Color(battle.INK,0.65))
		battle.draw_circle(at,7,CHARGE_COLOR if lit else Color("55534a"))
		if lit: battle.draw_circle(at,3,Color("fff5bd"))
