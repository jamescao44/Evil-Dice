extends Node2D
## Drag-to-connect presentation; the dice model owns locks, rolls and skill budgets.
const Beam = preload("res://scripts/dice/dice_connection_beam.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const IdleFeedback = preload("res://scripts/dice/dice_idle_feedback.gd")
const Style = preload("res://scripts/dice/dice_pattern_style.gd")
const PromptPulse = preload("res://scripts/shared/prompt_pulse.gd")
var idle_feedback := IdleFeedback.new()
var battle
var dragging: bool = false
var moved: bool = false
var press_origin := Vector2.ZERO
var contact_die: int = -1
var pointer := Vector2.ZERO
var preview: MultiHitSkill = MultiHitSkill.new()
var caption: Dictionary = {}
var particles: Array = []
var emission_clock: float = 0
var clock_time: float = 0
var roll_prompt_age: float = 0
var end_turn_prompt_age: float = 0
var prompt_turn_id: int = -1
var cosmetic := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 35
	cosmetic.randomize()

func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

func available() -> bool:
	if is_instance_valid(battle.tarot_cast) and battle.tarot_cast.active(): return false
	return battle.view_phase == "ready" and battle.model.pending.is_empty() and not battle._menus_open() and not battle.tarot_ui.blocks_battle() and battle.inspecting_enemy < 0 and battle.model.outcome().is_empty()

## Keep the center hit area clear of all six dice.
func center_hit(point: Vector2) -> bool:
	return point.distance_to(battle.DICE_CENTER) <= (78 if portrait() else 48)

## A large text-only control clears tap selections without spending dice or rolls.
func cancel_rect() -> Rect2:
	var size := Vector2(208,52) if portrait() else Vector2(156,40)
	return Rect2(battle.DICE_CENTER+Vector2(0,56 if portrait() else 38)-size/2,size)

## A formed skill may be dropped anywhere below the dice area's midline.
func skill_cancel_rect() -> Rect2:
	return Rect2(0,battle.DICE_CENTER.y,battle.fx.canvas_size.x,battle.fx.canvas_size.y-battle.DICE_CENTER.y)

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
	if not battle.model.dice_turn.selected.is_empty() and cancel_rect().has_point(point):
		cancel_gesture()
		return true
	if center_hit(point):
		if not battle.model.dice_turn.selected.is_empty():
			if not preview.is_empty():
				battle._form_selected_skill()
				_clear_preview()
		elif battle.model.dice_turn.can_roll(): battle._start_charge()
		return true
	for index in range(battle.model.DiceTurn.COUNT):
		if die_rect(index).has_point(point):
			if battle.model.dice_turn.select(index):
				dragging = true
				moved = false
				press_origin = point
				pointer = point
				contact_die = index
				_selection_changed()
			else: battle.dice[index].reject_selection()
			return true
	return false

## A full six-die chain can stretch before the final connection breaks.
func break_distance() -> float:
	return minf(die_rect(0).size.x*1.35,battle.DICE_POSITIONS[0].distance_to(battle.DICE_POSITIONS[1])*0.85)

## Sample the full pointer path so fast drags and backtracking behave alike.
func motion(point: Vector2) -> bool:
	if not dragging: return false
	if not available():
		cancel_gesture()
		return true
	if point.distance_to(press_origin) > (14 if portrait() else 8): moved = true
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
				if pool.selected.size() == 1: pool.selected.clear()
				_selection_changed()
			elif previous < 0:
				if pool.select(index): _selection_changed()
				else: battle.dice[index].reject_selection()
			break
	if pool.selected.size() == pool.COUNT and point.distance_to(battle.DICE_POSITIONS[pool.selected[-1]]) > break_distance():
		pool.selected.pop_back()
		_selection_changed()
		# A new die may already be under the finger when the stretched link snaps.
		if contact_die >= 0 and contact_die not in pool.selected and die_rect(contact_die).has_point(point):
			if pool.select(contact_die): _selection_changed()

## Drag release summons a complete pattern; taps leave the selection for OK.
func release(point: Vector2) -> bool:
	if not dragging: return false
	motion(point)
	var complete: bool = moved and dragging and available() and not preview.is_empty()
	dragging = false
	contact_die = -1
	if complete:
		battle._form_selected_skill()
		_clear_preview()
	return true

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
		die.connection_fire = 0
	queue_redraw()

## Cache the formed skill caption only when the selected pattern changes.
func _selection_changed() -> void:
	preview = battle.model.relic_skills.preview_upgrade(battle.model,battle.model.Patterns.classify(battle.model.dice_turn.selection_values()))
	caption = {} if preview.is_empty() else battle._skill_caption(preview)
	if preview.is_empty(): particles.clear()
	battle._sound("ui/book",1.5,-24)
	queue_redraw()

func skill_color() -> Color:
	return Style.color(preview)

## Prompt the first throw, or a usable reroll when the remaining pool has no straight.
func should_prompt_roll() -> bool:
	var pool = battle.model.dice_turn
	return available() and pool.selected.is_empty() and pool.can_roll() and (not pool.has_rolled() or (not pool.skills_allowed() or not battle.model.Patterns.has_combination(pool.unused().map(func(i): return pool.values[i]))))

## Animate a bounded stream of sparks while the valid pattern is selected.
func _process(delta: float) -> void:
	visible = not battle._menus_open() and not battle.tarot_ui.inventory_visible() and battle.view_phase in ["ready", "skill", "charging", "rolling", "forming", "targeting", "resolving", "frozen"]
	if dragging and not available(): cancel_gesture()
	clock_time += delta
	var pool = battle.model.dice_turn
	if prompt_turn_id != pool.turn_id:
		prompt_turn_id = pool.turn_id
		roll_prompt_age = 0
	if should_prompt_roll(): roll_prompt_age += delta
	else: roll_prompt_age = 0
	if battle._can_end_turn() and pool.rolls_left == 0 and (not pool.skills_allowed() or not battle.model.Patterns.has_combination(pool.unused().map(func(i): return pool.values[i]))): end_turn_prompt_age += delta
	else: end_turn_prompt_age = 0
	idle_feedback.advance(delta,pool,available(),battle.reduced)
	for index in range(battle.dice.size()):
		var die = battle.dice[index]
		die.idle_hint = idle_feedback.hint_pose(index)
		die.selection_emphasis = move_toward(die.selection_emphasis,1.0 if index in pool.selected else 0.0,delta*12)
		die.connection_glow = index in pool.selected
		die.connection_color = skill_color()
		die.connection_fire = Style.fire_level(preview) if index in pool.selected else 0
	for spark in particles:
		spark.life -= delta
		spark.p += spark.v*delta
	particles = particles.filter(func(spark): return spark.life > 0)
	if not preview.is_empty():
		emission_clock -= delta
		if emission_clock <= 0:
			var level: int = Style.fire_level(preview)
			emission_clock = 0.2 if battle.reduced else [0.14,0.10,0.09,0.07,0.065][level]
			for index in pool.selected:
				for burst in range(1 if battle.reduced else [1,1,2,2,3][level]):
					if particles.size() >= 240: break
					var direction := Vector2.from_angle(cosmetic.randf()*TAU)
					particles.append({"p":battle.DICE_POSITIONS[index]+direction*(52 if portrait() else 40),"v":direction*cosmetic.randf_range(15,35)+Vector2(0,-24-level*18),"life":0.65,"size":cosmetic.randf_range(3,6)+level*0.4,"color":skill_color()})
	queue_redraw()

## Draw straight connections above dice and a small centered face/skill preview.
func _draw() -> void:
	var pool = battle.model.dice_turn
	var color: Color = skill_color()
	_draw_interactable_dice()
	if not pool.selected.is_empty():
		var points: Array = pool.selected.map(func(index): return battle.DICE_POSITIONS[index])
		if dragging and moved: points.append(pointer)
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
			for line in GameText.lines(caption.get("preview",caption.description),battle.description_font,size,410 if portrait() else 340):
				var width: float = battle.description_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
				draw_string(battle.description_font,Vector2(row.x-width/2,y).round(),line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,battle.CREAM)
				y += size+4
	for spark in particles:
		var alpha: float = spark.life/0.65
		draw_circle(spark.p,spark.size*2,Color(spark.color,alpha*0.1))
		draw_rect(Rect2(spark.p-Vector2.ONE*spark.size/2,Vector2.ONE*spark.size),Color(spark.color.lightened(0.4),alpha))
	_draw_center()

## Send a fading pixel wave outward every two seconds; reduced effects stay still.
func _draw_interactable_dice() -> void:
	var pool = battle.model.dice_turn
	if not available() or not pool.active or not pool.has_rolled() or pool.has_pending_group(): return
	for index in idle_feedback.ring_indices:
		var progress: float = 0 if battle.reduced else idle_feedback.wave_age/IdleFeedback.WAVE_PERIOD
		var radius: float = (65 if portrait() else 49)+(40 if portrait() else 30)*progress
		radius *= 1+battle.dice[index].selection_emphasis*0.12
		var alpha: float = 0.26 if battle.reduced else 0.34*sin(minf(progress/0.14,1.0)*PI/2)*pow(1-progress,1.2)
		Pixel.circle(self,battle.DICE_POSITIONS[index],radius,Color(battle.CREAM,alpha),4 if portrait() else 3)

## The center contains only glowing text, or a faint red skill-cancellation target.
func _draw_center() -> void:
	if is_instance_valid(battle.tarot_cast) and battle.tarot_cast.choice_type == "magician": return
	if (dragging and moved) or battle.view_phase == "rolling": return
	var at: Vector2 = battle.DICE_CENTER
	var size: int = 46 if portrait() else 32
	var cancelling: bool = battle._current_skill_selected()
	if cancelling:
		var zone: Rect2 = skill_cancel_rect()
		var skill_at: Vector2 = battle._source_bubble(battle.skill_source).display_center()
		var distance: float = maxf(0,zone.position.y-skill_at.y)
		var proximity: float = 1.0-smoothstep(0,260 if portrait() else 180,distance)
		draw_rect(zone,Color("db7474",lerpf(0.025,0.17,proximity)))
		draw_line(zone.position,Vector2(zone.end.x,zone.position.y),Color("db7474",lerpf(0.18,0.85,proximity)),2,true)
		battle._center(at+Vector2(0,68 if portrait() else 46),"CANCEL SKILL",38 if portrait() else 28,Color("ef9999",lerpf(0.28,1.0,proximity)),self)
		return
	var charging: bool = battle.view_phase == "charging"
	var selected: bool = not battle.model.dice_turn.selected.is_empty()
	var reroll: bool = battle.model.dice_turn.has_rolled()
	var enabled: bool = charging or (available() and (not preview.is_empty() if selected else battle.model.dice_turn.can_roll()))
	var label: String = GameText.text("STOP!" if charging else "OK" if selected else "REROLL" if reroll else "ROLL")
	var color: Color = battle.GOLD if enabled else Color("505156")
	var base: Vector2 = at+Vector2(0,1)
	# Rectified sine touches normal size briefly and eases around each crest.
	var pop: float = 1.0
	if should_prompt_roll() and not battle.reduced:
		pop = PromptPulse.scale_at(roll_prompt_age)
	var pivot: Vector2 = base+Vector2(0,(battle.pixel_font.get_descent(size)-battle.pixel_font.get_ascent(size))*0.5)
	draw_set_transform(pivot,0,Vector2.ONE*pop)
	base -= pivot
	if enabled:
		var pulse: float = 0.7 if battle.reduced else 0.7+sin(clock_time*3.4)*0.3
		var width: float = battle.pixel_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		for outline in [8,4]: draw_string_outline(battle.pixel_font,base-Vector2(width/2,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,outline,Color(color,0.08*pulse))
	battle._center(base,label,size,color,self)
	draw_set_transform(Vector2.ZERO)
	if reroll and not charging and not selected:
		battle._center(at+Vector2(0,35 if portrait() else 27),str(battle.model.dice_turn.rolls_left),26 if portrait() else 20,color,self)
	if selected and available(): battle._center(cancel_rect().get_center()+Vector2(0,8 if portrait() else 6),"Deselect",34 if portrait() else 24,Color("df9696"),self)
