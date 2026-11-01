extends RefCounted
## The required number of linked dice stays above the cannon; charge lamps sit beneath it.
const Panels = preload("res://scripts/tarot/tarot_paint.gd")
static func paint(battle, index: int, rect: Rect2, show_charge: bool = true) -> void:
	var enemy: Dictionary = battle.model.enemies[index]
	var count: int = enemy.get("interrupt_straight",3)
	var color := Color("d6a0ff")
	var pulse: float = 1.0 if battle.reduced else 0.8+0.2*sin(battle.clock_time*TAU)
	Panels.panel(battle,rect,Color("191525",0.95),Color(color,0.65*pulse),6)
	var side: float = minf(rect.size.y*0.32,rect.size.x/6.8)
	var gap: float = side*1.2
	var center: Vector2 = rect.get_center()-Vector2(0,rect.size.y*0.15 if show_charge else 0)
	for i in range(count):
		var at: Vector2 = center+Vector2((i-(count-1)*0.5)*gap,0)
		if i < count-1: battle.draw_line(at,at+Vector2(gap,0),color,2,true)
		battle.draw_rect(Rect2(at-Vector2.ONE*side/2,Vector2.ONE*side),Color("f1e7ce"))
		battle.draw_rect(Rect2(at-Vector2.ONE*(side/2-2),Vector2.ONE*(side-4)),Color("5f496e"))
	if not show_charge: return
	var charges: int = battle.model.EnemyCatalog.ITEMS[enemy.role].get("charge_turns",3)
	for i in range(charges):
		var at: Vector2 = rect.get_center()+Vector2((i-(charges-1)*0.5)*side*1.2,rect.size.y*0.3)
		battle.draw_circle(at,side*0.18,Color("ffbe65") if i < enemy.charge else Color("514750"))
