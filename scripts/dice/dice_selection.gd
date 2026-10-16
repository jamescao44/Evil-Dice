extends Node2D
## Drag-to-connect presentation; the dice model owns locks, rolls and skill budgets.
const Beam = preload("res://scripts/dice/dice_connection_beam.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
var battle
var dragging: bool = false
var contact_die: int = -1
var pointer := Vector2.ZERO
var preview: MultiHitSkill = MultiHitSkill.new()
var caption: Dictionary = {}
var particles: Array = []
var emission_clock: float = 0
var clock_time: float = 0
var cosmetic := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 35
	cosmetic.randomize()

func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

func available() -> bool:
	return battle.view_phase == "ready" and battle.model.pending.is_empty() and not battle._menus_open() and not battle.tarot_ui.blocks_battle() and battle.inspecting_enemy < 0 and battle.model.outcome().is_empty()

## Keep the center hit area clear of all six dice.
func center_hit(point: Vector2) -> bool:
	return point.distance_to(battle.DICE_CENTER) <= (78 if portrait() else 48)

func die_rect(index: int) -> Rect2:
	var side: float = 114 if portrait() else 82
	return Rect2(battle.DICE_POSITIONS[index]-Vector2.ONE*side/2, Vector2.ONE*side)

## Start a connection at a die, or start/stop the Perfect timer at the center.
func click(point: Vector2) -> bool:
	if dragging: return true
	if battle.view_phase == "charging" and not battle._menus_open() and center_hit(point):
		battle._release_charge()
		return true
	if not available(): return false
	if center_hit(point):
		if battle.model.dice_turn.can_roll(): battle._start_charge()
		return true
	for index in range(battle.model.DiceTurn.COUNT):
		if die_rect(index).has_point(point):
			cancel_gesture()
			if battle.model.dice_turn.select(index):
				dragging = true
				pointer = point
				contact_die = index
				_selection_changed()
			return true
	return false

## Allow a complete trio to stretch before its final connection breaks.
func break_distance() -> float:
	return minf(die_rect(0).size.x*1.35,battle.DICE_POSITIONS[0].distance_to(battle.DICE_POSITIONS[1])*0.85)

## Sample the full pointer path so fast drags and backtracking behave alike.
func motion(point: Vector2) -> bool:
	if not dragging: return false
	if not available():
		cancel_gesture()
		return true
	var start: Vector2 = pointer
	var steps: int = clampi(ceili(start.distance_to(point)/(16 if portrait() else 10)),1,256)
	for step in range(1,steps+1): _visit_pointer(start.lerp(point,float(step)/steps))
	pointer = point
	return true

## Re-entering the endpoint undoes it; visiting an earlier die rewinds to it.
func _visit_pointer(point: Vector2) -> void:
	var pool = battle.model.dice_turn
	if contact_die >= 0 and not die_rect(contact_die).grow(10).has_point(point): contact_die = -1
	if contact_die < 0:
		for index in pool.unused():
			if not die_rect(index).has_point(point): continue
			contact_die = index
			var previous: int = pool.selected.find(index)
			if previous >= 0 and pool.selected.size() > 1:
				pool.selected.resize(previous if previous == pool.selected.size()-1 else previous+1)
				_selection_changed()
			elif previous < 0 and pool.select(index): _selection_changed()
			break
	if pool.selected.size() == 3 and point.distance_to(battle.DICE_POSITIONS[pool.selected[-1]]) > break_distance():
		pool.selected.pop_back()
		_selection_changed()
		# A new die may already be under the finger when the stretched link snaps.
		if contact_die >= 0 and contact_die not in pool.selected and die_rect(contact_die).has_point(point):
			if pool.select(contact_die): _selection_changed()

## Release commits exactly three connected dice; incomplete gestures spend nothing.
func release(point: Vector2) -> bool:
	if not dragging: return false
	motion(point)
	var complete: bool = dragging and available() and battle.model.dice_turn.selected.size() == 3
	dragging = false
	if complete: battle._form_selected_skill()
	else: battle.model.dice_turn.selected.clear()
	_clear_preview()
	return true

## Drop transient selection on focus loss, menus, rewards or a fresh turn.
func cancel_gesture() -> void:
	dragging = false
	contact_die = -1
	battle.model.dice_turn.selected.clear()
	_clear_preview()

func _clear_preview() -> void:
	preview = MultiHitSkill.new()
	caption.clear()
	particles.clear()
	emission_clock = 0
	for die in battle.dice:
		die.selection_emphasis = 0
		die.connection_glow = false
	queue_redraw()

## Cache the formed skill caption only when the selected trio changes.
func _selection_changed() -> void:
	preview = battle.model.classify(battle.model.dice_turn.selection_values())
	caption = {} if preview.is_empty() else battle._skill_caption(preview)
	if preview.is_empty(): particles.clear()
	battle._sound("ui/book",1.5,-24)
	queue_redraw()

func skill_color() -> Color:
	return battle.GOLD if preview.is_empty() else [battle.CREAM,battle.TEAL,battle.PURPLE,battle.GOLD][preview.kind]

## Animate a bounded stream of sparks while the complete trio is held.
func _process(delta: float) -> void:
	visible = not battle._menus_open() and not battle.tarot_ui.inventory_visible() and battle.view_phase in ["ready", "skill", "charging", "rolling", "forming", "targeting", "resolving", "frozen"]
	if dragging and not available(): cancel_gesture()
	clock_time += delta
	var pool = battle.model.dice_turn
	for index in range(battle.dice.size()):
		var die = battle.dice[index]
		die.selection_emphasis = move_toward(die.selection_emphasis,1.0 if dragging and index in pool.selected else 0.0,delta*12)
		die.connection_glow = dragging and not preview.is_empty() and index in pool.selected
		die.connection_color = skill_color()
	for spark in particles:
		spark.life -= delta
		spark.p += spark.v*delta
	particles = particles.filter(func(spark): return spark.life > 0)
	if dragging and not preview.is_empty():
		emission_clock -= delta
		if emission_clock <= 0:
			emission_clock = 0.14 if battle.reduced else 0.06
			for index in pool.selected:
				var direction := Vector2.from_angle(cosmetic.randf()*TAU)
				particles.append({"p":battle.DICE_POSITIONS[index]+direction*(52 if portrait() else 40),"v":direction*cosmetic.randf_range(15,35)+Vector2(0,-24),"life":0.65,"size":cosmetic.randf_range(3,6)})
	queue_redraw()

## Draw straight connections above dice and a small centered face/skill preview.
func _draw() -> void:
	var pool = battle.model.dice_turn
	var color: Color = skill_color()
	_draw_interactable_dice()
	if dragging:
		var points: Array = pool.selected.map(func(index): return battle.DICE_POSITIONS[index])
		points.append(pointer)
		for index in range(1,points.size()):
			var direction: Vector2 = (points[index]-points[index-1]).normalized()
			var edge: float = 48 if portrait() else 36
			var from: Vector2 = points[index-1]+direction*edge
			var to: Vector2 = points[index]-direction*(edge if index < pool.selected.size() else 0)
			if (to-from).dot(direction) > 0: Beam.paint(self,from,to,color,clock_time,1.0 if portrait() else 0.7,battle.reduced)
		var row: Vector2 = battle.DICE_CENTER-Vector2(0,300 if portrait() else 230)
		var spacing: float = 44 if portrait() else 30
		for index in range(pool.selected.size()):
			Pixel.mini_die(self,row+Vector2((index-(pool.selected.size()-1)*0.5)*spacing,0),pool.values[pool.selected[index]],16 if portrait() else 11)
		if not preview.is_empty():
			battle._center(row+Vector2(0,44 if portrait() else 38),caption.name,30 if portrait() else 23,color,self)
			var size: int = 24 if portrait() else 22
			var y: float = row.y+(70 if portrait() else 67)
			for line in GameText.lines(caption.description,battle.description_font,size,410 if portrait() else 340):
				var width: float = battle.description_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
				draw_string(battle.description_font,Vector2(row.x-width/2,y).round(),line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,battle.CREAM)
				y += size+4
	for spark in particles:
		var alpha: float = spark.life/0.65
		draw_circle(spark.p,spark.size*2,Color(color,alpha*0.1))
		draw_rect(Rect2(spark.p-Vector2.ONE*spark.size/2,Vector2.ONE*spark.size),Color(color.lightened(0.4),alpha))
	_draw_center()

## Bounce pixel rings around selectable dice; reduced effects keep them still.
func _draw_interactable_dice() -> void:
	var pool = battle.model.dice_turn
	if not available() or not pool.active or pool.rolls_left == pool.ROLLS or pool.has_pending_group(): return
	for index in pool.unused():
		var bounce: float = 0 if battle.reduced else sin(clock_time*TAU/1.5)*0.055
		var radius: float = (78 if portrait() else 62)*(1+bounce+battle.dice[index].selection_emphasis*0.12)
		Pixel.circle(self,battle.DICE_POSITIONS[index],radius,Color(battle.CREAM,0.26),4 if portrait() else 3)

## The center contains only glowing text, or a faint red skill-cancellation target.
func _draw_center() -> void:
	if dragging: return
	var at: Vector2 = battle.DICE_CENTER
	var size: int = 46 if portrait() else 32
	var cancelling: bool = battle._current_skill_selected()
	if cancelling:
		var over: bool = battle.skill_dragging and center_hit(battle.skill_pointer)
		draw_circle(at,78 if portrait() else 48,Color("db7474",0.15 if over else 0.06))
		draw_arc(at,78 if portrait() else 48,0,TAU,64,Color("db7474",0.65 if over else 0.28),2,true)
		battle._center(at+Vector2(0,60 if portrait() else 38),"CANCEL SKILL",24 if portrait() else 14,Color("db7474",0.9 if over else 0.65),self)
		return
	var charging: bool = battle.view_phase == "charging"
	var enabled: bool = charging or (available() and battle.model.dice_turn.can_roll())
	var label: String = GameText.text("STOP!" if charging else "ROLL")
	var color: Color = battle.GOLD if enabled else Color("505156")
	var base: Vector2 = at+Vector2(0,1)
	if enabled:
		var pulse: float = 0.7 if battle.reduced else 0.7+sin(clock_time*3.4)*0.3
		var width: float = battle.pixel_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		for outline in [8,4]: draw_string_outline(battle.pixel_font,base-Vector2(width/2,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,outline,Color(color,0.08*pulse))
	battle._center(base,label,size,color,self)
	battle._center(at+Vector2(0,35 if portrait() else 27),str(battle.model.dice_turn.rolls_left),26 if portrait() else 20,color,self)
