extends Node2D
## Battlefield-only drag handle for Challenger's Badge; the model owns the selected foe.
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Feedback = preload("res://scripts/shared/cast_drag_feedback.gd")
const ID := "challenger_badge"
const COLOR := Color("ffc775")
var battle
var dragging := false
var moved := false
var pointer := Vector2.ZERO
var origin := Vector2.ZERO
var hover := -1
var clock := 0.0
var flash := 0.0

func _ready() -> void:
	z_index = BattleLayers.STATUS

## Keep rewards, inspection, tarot choices and menu pages above and free of the mark.
func available() -> bool:
	return not battle.model.is_city() and battle.model.relics.has(ID) and not battle._menus_open() and battle.inspecting_enemy < 0 and not battle.tarot_cast.active() and not battle.tarot_ui.blocks_battle() and battle.view_phase in ["ready","charging","rolling","forming","resolving","frozen"] and battle.model.outcome().is_empty()

## Target visible bodies even if a separate health label is clipped by the arena edge.
func settled(index: int) -> bool:
	return battle.BattlefieldRender.arrival_progress(battle,index) >= 1.0 and battle.ARENA.intersects(battle._target_rect(index))

func radius() -> float:
	return 26.0 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 18.0

## Reserve space above the intent; try adjacent positions when a boss HUD occupies it.
func mark_rect(index: int) -> Rect2:
	var intent: Rect2 = battle._enemy_intent_rect(index)
	var side: float = radius()*2
	var head := Vector2(battle._enemy_point(index).x,intent.position.y-side/2-10)
	var candidates: Array = [head,Vector2(intent.position.x-side/2-10,intent.get_center().y),Vector2(intent.end.x+side/2+10,intent.get_center().y)]
	var best := Rect2()
	var best_overlap := INF
	for point in candidates:
		var rect := Rect2(point-Vector2.ONE*side/2,Vector2.ONE*side)
		rect.position = rect.position.clamp(battle.ARENA.position+Vector2.ONE*8,battle.ARENA.end-rect.size-Vector2.ONE*8)
		var overlap := 0.0
		for enemy in battle.model.living():
			var obstacles: Array = [battle._enemy_intent_rect(enemy).grow(5),battle._enemy_health_rect(enemy).grow(10)]
			if battle.model.enemies[enemy].get("boss",false): obstacles.append(battle.BossPresentation.hud_rect(battle,enemy).grow(4))
			for obstacle in obstacles: overlap += rect.intersection(obstacle).get_area()
		if overlap < best_overlap:
			best = rect
			best_overlap = overlap
	return best

## Give the small badge a generous touch area without replacing enemy-body inspection.
func hit(point: Vector2) -> bool:
	var target: int = battle.model.RelicFocus.current(battle.model)
	if not available() or target < 0 or not settled(target): return false
	return mark_rect(target).grow(16 if radius() > 20 else 8).has_point(point)

func click(point: Vector2) -> bool:
	if not hit(point): return false
	dragging = true
	moved = false
	pointer = point
	origin = point
	hover = battle.model.RelicFocus.current(battle.model)
	battle._cancel_enemy_hold()
	return true

## Highlight eligible living foes; the badge bypasses taunt but respects Swift.
func target_at(point: Vector2) -> int:
	if not battle.ARENA.has_point(point): return -1
	var selected := -1
	var nearest := INF
	for index in battle.model.living():
		if not settled(index) or not battle.Rules.EnemyCatalog.targetable(battle.model.enemies,index): continue
		var rect: Rect2 = battle._target_rect(index)
		var distance: float = rect.get_center().distance_squared_to(point)
		if rect.has_point(point) and distance < nearest:
			selected = index
			nearest = distance
	return selected

func motion(point: Vector2) -> bool:
	if not dragging: return false
	if not available(): cancel(); return true
	pointer = point
	moved = moved or origin.distance_to(point) > (12 if radius() > 20 else 8)
	hover = target_at(point) if moved else battle.model.RelicFocus.current(battle.model)
	return true

## Commit only a valid drop; an off-field drop or a tap leaves the original focus alone.
func release(point: Vector2) -> bool:
	if not dragging: return false
	motion(point)
	if dragging and moved and hover >= 0 and battle.model.RelicFocus.select(battle.model,hover):
		flash = 0.35
		battle._sound("ui/book",1.0,-18)
	cancel()
	return true

func cancel() -> void:
	dragging = false
	moved = false
	hover = -1

func _process(delta: float) -> void:
	clock += delta
	flash = maxf(0,flash-delta)
	if dragging and not available(): cancel()
	visible = available()
	z_index = BattleLayers.HELD_ITEM if dragging else BattleLayers.STATUS
	queue_redraw()

## The same icon is used for loot and targeting, with unobtrusive glow and a drop highlight.
func _draw() -> void:
	if not available(): return
	var target: int = battle.model.RelicFocus.current(battle.model)
	if target < 0 or not settled(target): return
	var at: Vector2 = mark_rect(target).get_center()
	if dragging and moved:
		for index in battle.model.living():
			if not settled(index) or not battle.Rules.EnemyCatalog.targetable(battle.model.enemies,index): continue
			Feedback.paint_target(self,battle._target_rect(index),index == hover,COLOR,radius() > 20)
		if hover >= 0:
			var next: Vector2 = mark_rect(hover).get_center()
			Paint.paint(self,ID,next,radius(),true,{},battle.ARENA,Color(1,1,1,0.65))
		Paint.paint(self,ID,pointer,radius()*1.15,true,{},battle.ARENA,Color(1,1,1,0.45 if hover >= 0 else 0.85))
	else:
		at.y += 0.0 if battle.reduced else sin(clock*TAU/1.5)*2
		Paint.paint(self,ID,at,radius()*(1+flash*0.3),true,{},battle.ARENA)
