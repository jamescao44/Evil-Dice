extends Node2D
## Presentation only. The battle owns targeting, consumption and combat time.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Orb = preload("res://scripts/combat/skill_orb_paint.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const DragFeedback = preload("res://scripts/shared/cast_drag_feedback.gd")
var drag_feedback = DragFeedback.new()
var battle
var stored: bool = false
var roll: MultiHitSkill = MultiHitSkill.new()
var age: float = 0
var formation: float = 0.45
var rotation_clock: float = 0
var aim_dock: float = 0
var entrance_speed: float = 1
var converge: float = 0.32
const RISE := 0.26
const HOLD := 0.26
const SETTLE := 0.28
const ENTRANCE_SCALE := 1.75
var caption: Dictionary = {}
var used: int:
	get: return roll.uses_spent
var pops: Array = []
var cast_age: float = 10
const DISSOLVE_TIME := 0.48
const CAST_OPACITY := 0.28
const SLAM_IMPACT_TIME := 0.28
const SLAM_DURATION := 0.46
var slam_age: float = SLAM_DURATION
var cast_position := Vector2.INF
var dissolving: bool = false
var dissolve_age: float = 0
var fragments: Array = []

func _ready() -> void:
	z_index = 40

func begin(value: MultiHitSkill) -> void:
	aim_dock = 0
	drag_feedback.reset()
	slam_age = SLAM_DURATION
	roll = value.duplicate(true)
	age = 0
	entrance_speed = battle._roll_speed()
	converge = 0.32 if roll.kind < Rules.Kind.SPECIAL else 0.38 if roll.kind == Rules.Kind.SPECIAL else 0.48
	formation = (converge + RISE + HOLD + SETTLE) / entrance_speed
	caption = battle._skill_caption(roll)
	pops.clear()
	cast_age = 10
	cast_position = Vector2.INF
	dissolving = false
	dissolve_age = 0
	fragments.clear()

func clear() -> void:
	aim_dock = 0
	drag_feedback.reset()
	slam_age = SLAM_DURATION
	roll = MultiHitSkill.new()
	caption.clear()
	pops.clear()
	age = 0
	cast_position = Vector2.INF
	dissolving = false
	dissolve_age = 0
	fragments.clear()
	self_modulate = Color.WHITE
	z_index = 40
	queue_redraw()

func lock_cast_position(at: Vector2) -> void:
	cast_position = at

func begin_slam() -> void:
	if cast_position == Vector2.INF: cast_position = display_center()
	slam_age = 0

func slam_lift() -> float:
	if battle.reduced or slam_age >= SLAM_IMPACT_TIME: return 0.0
	if slam_age < 0.12: return smoothstep(0, 0.12, slam_age)
	return 1.0 - pow((slam_age - 0.12) / (SLAM_IMPACT_TIME - 0.12), 3)

func slam_scale() -> float:
	if battle.reduced or slam_age >= SLAM_DURATION: return 1.0
	if slam_age < SLAM_IMPACT_TIME: return 1.0 + slam_lift() * 0.4
	return 1.0 - 0.22 * (1.0 - smoothstep(SLAM_IMPACT_TIME, SLAM_DURATION, slam_age))

func is_active_saved() -> bool:
	return stored and (battle.casting_source == "saved" or (battle.view_phase == "targeting" and battle.skill_source == "saved"))

func is_suspended() -> bool:
	return not stored and (battle.casting_source == "saved" or (battle.view_phase == "targeting" and battle.skill_source == "saved"))

func is_casting() -> bool:
	return battle.view_phase == "resolving" and battle.casting_source == ("saved" if stored else "current")

func display_radius() -> float:
	var preview_scale: float = drag_feedback.scale_factor() if is_dragging() else 1.0
	if stored: return (battle._skill_radius() if is_active_saved() else battle._saved_slot_radius()*0.84) * slam_scale()*preview_scale
	return battle._skill_radius()*radius_scale()*(0.7 if is_dragging() else 1.0)*slam_scale()*preview_scale

func is_dragging() -> bool:
	return battle.view_phase == "targeting" and battle.skill_dragging and battle.skill_source == ("saved" if stored else "current")

func display_center() -> Vector2:
	if cast_position != Vector2.INF: return cast_position - Vector2(0, battle._skill_radius() * slam_lift())
	if not battle.skill_dragging or battle.skill_source != ("saved" if stored else "current"): return center_at()
	var at: Vector2 = battle.skill_pointer-Vector2(0,78 if battle.fx.canvas_size.y > battle.fx.canvas_size.x and battle.active_touch >= 0 else 0)
	var radius: float = display_radius()
	at.x = clampf(at.x,radius+16,battle.fx.canvas_size.x-radius-16)
	return at

func dissolve() -> void:
	dissolving = true
	dissolve_age = 0
	var radius: float = display_radius()
	var count: int = 16 if battle.reduced else 64
	for i in range(count):
		var direction := Vector2.from_angle(i*TAU/count+rotation_clock*0.55)
		var offset: Vector2 = direction*radius*(1.0 if i%3 == 0 else 0.81 if i%3 == 1 else battle.fx.cosmetic.randf_range(0.05,0.4))
		fragments.append({"p":offset,"v":direction*battle.fx.cosmetic.randf_range(36,130)+Vector2(0,-70),"size":battle.fx.cosmetic.randf_range(3,7)})
	queue_redraw()

func _draw_dissolve(at: Vector2, radius: float, color: Color) -> void:
	var t: float = clampf(dissolve_age/DISSOLVE_TIME,0,1)
	var alpha: float = 1-t
	Pixel.circle(self,at,radius*(1+t*0.12),Color(color,alpha*alpha),3)
	_draw_icon(at,radius*0.66,Color(1,1,1,alpha*alpha))
	for fragment in fragments:
		var p: Vector2 = at+fragment.p+fragment.v*dissolve_age*(0.25 if battle.reduced else 1.0)
		var size: float = maxf(2,fragment.size*alpha)
		draw_rect(Rect2(p.snapped(Vector2.ONE*2),Vector2.ONE*size),Color(color.lightened(0.35),alpha))

func consume_use() -> void:
	roll.begin_cast(battle.model.skill_modifiers_for(roll))
	if roll.uses_left() == 0: return
	cast_age = 0
	if orb_count() > 1: pops.append({"index": used, "age": 0.0})
	roll.consume_use()

func uses_left() -> int:
	return roll.uses_left(battle.model.skill_modifiers_for(roll))

func orb_count() -> int:
	return battle.model.skill_use_count(roll) if battle.model.skill_use_count(roll) > 1 else 0

func center_at() -> Vector2:
	if cast_position != Vector2.INF: return cast_position
	if stored: return battle._saved_slot_center()
	var t: float = age*entrance_speed
	var start: Vector2 = battle.DICE_CENTER
	var reveal: Vector2 = battle._skill_reveal_point()
	var rest: Vector2 = battle._skill_rest_point()
	# Dock an aimed landscape skill below the arena so it cannot cover a target.
	rest = rest.lerp(Vector2(rest.x,battle.DICE_CENTER.y-40),smoothstep(0,1,aim_dock))
	if t < converge: return start
	if t < converge+RISE:
		return start.lerp(reveal, 1-pow(1-clampf((t-converge)/RISE,0,1),3))
	if t < converge+RISE+HOLD: return reveal
	if t < converge+RISE+HOLD+SETTLE:
		return reveal.lerp(rest, smoothstep(0,1,(t-converge-RISE-HOLD)/SETTLE))
	var bob: float = 0 if battle.reduced else sin((age-formation)*2.6)*(6 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 4)
	return rest+Vector2(0,bob)

func radius_scale() -> float:
	if stored: return 1.0
	var t: float = age*entrance_speed
	var appear: float = smoothstep(converge*0.2,converge,t)
	var flourish: float = ENTRANCE_SCALE if t < converge+RISE+HOLD else lerpf(ENTRANCE_SCALE,1.0,smoothstep(0,1,(t-converge-RISE-HOLD)/SETTLE))
	var cast_pulse: float = 0 if battle.reduced or cast_age >= 0.3 else sin(cast_age/0.3*PI)*0.08
	return lerpf(0.35,flourish,appear)+cast_pulse

func _process(delta: float) -> void:
	if not is_instance_valid(battle): return
	var selected: bool = battle.skill_source == ("saved" if stored else "current")
	z_index = battle.HELD_ITEM_Z if selected and battle.view_phase == "targeting" and (battle.skill_pressed or battle.skill_dragging) else 40
	# Once taken out, the saved skill still plays its cast and dissolve effects.
	var locked_saved: bool = stored and not is_casting() and not battle._can_use_saved()
	if not battle._menus_open():
		var docking: bool = not stored and selected and battle.view_phase == "targeting" and battle._skill_needs_target(roll) and battle.fx.canvas_size.x > battle.fx.canvas_size.y
		aim_dock = move_toward(aim_dock,1.0 if docking else 0.0,delta/0.24)
		drag_feedback.advance(delta,is_dragging(),battle.ARENA.has_point(battle.skill_pointer),battle.reduced)
		age += delta
		if not locked_saved: rotation_clock += delta * battle._world_time_scale()
		cast_age += delta
		slam_age = minf(SLAM_DURATION, slam_age + delta)
		if dissolving: dissolve_age += delta
		for pop in pops: pop.age += delta
		pops = pops.filter(func(pop): return pop.age < 0.4)
	self_modulate = Color(0.38,0.38,0.44,0.7) if is_suspended() or locked_saved else Color(1,1,1,CAST_OPACITY if is_casting() else 1.0)
	queue_redraw()

func _draw() -> void:
	if stored and not Rules.SAVED_SKILLS_ENABLED: return
	if is_instance_valid(battle) and is_instance_valid(battle.tarot_ui) and battle.tarot_ui.inventory_visible(): return
	if not is_instance_valid(battle) or battle._menus_open(): return
	if not stored and is_instance_valid(battle.dice_selection) and battle.dice_selection.dragging: return
	var source: String = "saved" if stored else "current"
	var selected: bool = battle.skill_source == source
	var casting: bool = is_casting()
	var aiming: bool = battle.view_phase == "targeting" and selected
	var held: bool = not roll.is_empty() and (stored or battle.view_phase in ["forming", "skill", "targeting", "resolving", "charging", "rolling"])
	if battle.view_phase in ["over", "reward"]: return
	if not held: return
	var at: Vector2 = display_center()
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var radius: float = display_radius()
	var color: Color = battle.PatternStyle.color(roll)
	if dissolving:
		_draw_dissolve(at,radius,color)
		return
	var progress: float = 1 if stored else clampf(age*entrance_speed/converge,0,1)
	var dragging: bool = battle.skill_dragging and selected
	if aiming and dragging and not battle._skill_needs_target(roll):
		draw_rect(battle.ARENA.grow(-8), Color(color,0.85 if battle._field_drop_valid(battle.skill_pointer) else 0.35),false,3)
	if progress < 1:
		var travel: float = 1.0 - pow(1.0 - progress, 3)
		for i in range(roll.dice.size()):
			var indices: Array = battle.model.skill_dice_indices
			var start: Vector2 = battle.DICE_POSITIONS[indices[i] if indices.size() == roll.dice.size() else i]
			var p: Vector2 = start.lerp(battle.DICE_CENTER, travel)
			Pixel.line(self, start.lerp(p, 0.65), p, Color(color, (1.0-progress)*0.7), 3)
			_mini_die(p, int(roll.dice[i]), lerpf(38 if portrait else 24, 8, travel), 1.0-progress)
	var appear: float = smoothstep(0.25, 0.85, progress)
	if appear <= 0: return
	# Fade only the sprite; target brackets, labels, and energy stay bright.
	if is_dragging(): appear *= drag_feedback.opacity()
	var pulse: float = 0.5 if battle.reduced else (sin(rotation_clock * 3.6) + 1) * 0.5
	for i in range(5, 0, -1):
		Pixel.circle(self, at, radius + i*4, Color(color, (0.035 + pulse*0.025)*appear), 4)
	if not casting: Pixel.disc(self, at, radius - 5, Color("151b25", appear * 0.96), 3)
	Pixel.disc(self, at, radius * 0.62, Color(color, (0.06+pulse*0.06)*appear), 3)
	Pixel.circle(self, at, radius, Color(color, appear), 3)
	Pixel.circle(self, at, radius * 0.81, Color(color, 0.65*appear), 2)
	var angle: float = 0 if battle.reduced else rotation_clock * 0.55
	for offset in [0.0, PI]:
		for i in range(3):
			var a: Vector2 = at + Vector2.from_angle(angle+offset+i*TAU/3)*radius*0.8
			var b: Vector2 = at + Vector2.from_angle(angle+offset+(i+1)*TAU/3)*radius*0.8
			Pixel.line(self, a, b, Color(color, 0.35*appear), 2)
	for i in range(8):
		var direction := Vector2.from_angle(-angle+i*TAU/8)
		var p := at + direction*radius*0.92
		Pixel.line(self, p-direction*5, p+direction*5, Color(color, appear), 3)
		if i % 2 == 0: Pixel.line(self, p-direction.orthogonal()*4, p+direction.orthogonal()*4, Color(color, appear), 2)
	_draw_icon(at, radius*0.66, Color(1,1,1,appear))
	if is_dragging(): drag_feedback.paint(self,at,Vector2.ONE*radius,color,battle.reduced)
	if aiming and battle._skill_needs_target(roll):
		for target in battle._skill_targets(): _draw_target(target, target == battle.hover_target, color)
	if progress >= 1:
		if orb_count() > 1: _draw_uses(at, radius, color)
		if not stored or aiming or casting: _draw_caption(at,radius,portrait,aiming,color)

func _draw_uses(at: Vector2, radius: float, color: Color) -> void:
	var total: int = orb_count()
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var side: float = 12 if portrait else 9
	var orbit: float = radius+(18 if portrait else 16)
	if stored and not is_active_saved():
		side = 7 if portrait else 5
		orbit = radius+11
	# Shrink markers with angular spacing so twelve uses fit even in the saved slot.
	side = minf(side, maxf(2, orbit*sin(PI/total)*0.55))
	for i in range(total):
		var p := at+Vector2.from_angle(-PI/2+i*TAU/total)*orbit
		if i >= used:
			Orb.paint(self,p,side,color)
		else: Pixel.circle(self,p,side*0.6,Color(color,0.18),2)
	for pop in pops:
		var p := at+Vector2.from_angle(-PI/2+pop.index*TAU/total)*orbit
		var q: float = pop.age/0.4
		Pixel.circle(self,p,side+q*22,Color(color,1-q),2)
		if not battle.reduced:
			for ray in range(6):
				var direction := Vector2.from_angle(ray*TAU/6)
				Pixel.line(self,p+direction*(8+q*20),p+direction*(14+q*30),Color(color,1-q),2)

func description_text() -> String:
	return battle._skill_caption(roll).description if not roll.is_empty() else ""

func value_text() -> String:
	if roll.is_empty() or age < formation or is_suspended(): return ""
	var selected: bool = battle.view_phase == "targeting" and battle.skill_source == ("saved" if stored else "current")
	var held: bool = battle.view_phase == "skill" and not stored
	if not selected and not (held and not battle._skill_needs_target(roll)): return ""
	if Rules.is_attack(roll): return battle.model.damage_caption(roll, battle.hover_target if selected else -1)
	if roll.face == 2 and roll.kind == Rules.Kind.SPECIAL:
		if battle.model.status_count(battle.Status.DARKNESS) > 0: return "+0 HP"
		return "+%d HP" % maxi(0, battle.model.max_hp-battle.model.hp)
	return ""

func value_color() -> Color:
	return Color("ff827c") if Rules.is_attack(roll) else Color("94eb9c")

func _draw_value(at: Vector2, radius: float, portrait: bool) -> void:
	var value: String = value_text()
	if value.is_empty(): return
	var size: int = 30 if portrait else 20
	var width: float = battle.pixel_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var baseline := Vector2(clampf(at.x,width/2+16,battle.fx.canvas_size.x-width/2-16),maxf(size+16,at.y-radius-(32 if portrait else 24)))
	# Keep the larger resting skill's value below the treasure meter, inside its rim.
	if not stored and not is_dragging() and not is_casting(): baseline.y = at.y-radius+(28 if portrait else 22)
	_center(baseline,value,size,value_color(),true)

func _draw_caption(at: Vector2, radius: float, portrait: bool, aiming: bool, color: Color) -> void:
	_draw_value(at, radius, portrait)
	if not aiming and not is_casting():
		_center(at+Vector2(0,radius+30),GameText.text(caption.name),26 if portrait else 18,color)
		return
	var description: String = GameText.text(description_text())
	var title: String = GameText.text(caption.name)
	var title_size: int = 32 if portrait else 24
	var body_size: int = 30 if portrait else 24
	var width: float = 700 if portrait else 500
	while title_size > 16 and battle.pixel_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x > width: title_size -= 2
	var baseline: Vector2 = at+Vector2(0,radius+(64 if portrait else 48))
	var lines := GameText.lines(description,battle.description_font,body_size,width)
	var bonus: String = battle._skill_reapply_bonus(roll)
	var bonus_size: int = 30 if portrait else 20
	var bonus_lines := GameText.lines(bonus,battle.description_font,bonus_size,width if portrait else 340)
	var caption_width: float = battle.pixel_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
	for line in lines: caption_width = maxf(caption_width,battle.description_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,body_size).x)
	for line in bonus_lines: caption_width = maxf(caption_width,battle.description_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,bonus_size).x)
	baseline.x = clampf(baseline.x,caption_width/2+16,battle.fx.canvas_size.x-caption_width/2-16)
	_center(baseline,title,title_size,color,true)
	var next: float = 40 if portrait else 32
	if not description.is_empty():
		for line in lines:
			_center(baseline+Vector2(0,next),line,body_size,Color("eee0b9"),true,battle.description_font)
			next += body_size+6
	if not bonus.is_empty():
		for line in bonus_lines:
			_center(baseline+Vector2(0,next),line,bonus_size,battle.GOLD,true,battle.description_font)
			next += bonus_size+6
	if age < formation or battle.view_phase == "resolving" or battle.skill_dragging or is_suspended() or battle._current_skill_selected(): return
	var hint: String = "CHOOSE A FOE" if aiming and battle._skill_needs_target(roll) else "TAP / DRAG TO AIM" if battle._skill_needs_target(roll) else "DRAG TO FIELD"
	_center(baseline+Vector2(0,next),hint,24 if portrait else 20,Color("d2d1c9"),true,battle.description_font)

func _draw_target(target: int, selected: bool, color: Color) -> void:
	battle._draw_target_indicator(self,target,selected,color)

func _draw_icon(at: Vector2, side: float, tint: Color) -> void:
	if roll.pattern == "straight":
		preload("res://scripts/effects/flame_spell.gd").icon(self,at,side,roll.dice.size()-2,tint.a)
		return
	if roll.is_freeze():
		preload("res://scripts/status/status_paint.gd").icon(self,at,side*0.43,"ice",Color("82dfff",tint.a))
		return
	var kind: int = roll.kind
	var face: int = roll.face
	var key: String = "attack"
	if not roll.pattern.is_empty():
		key = "shield" if roll.pattern == "straight" else "crown" if roll.pattern == "annihilation" else "attack"
	elif kind != Rules.Kind.NORMAL:
		key = "heal" if face == 2 else "book" if face == 3 else "shield" if face == 6 and kind == Rules.Kind.PAIR else "feast" if face == 1 and kind == Rules.Kind.SPECIAL else "crown" if kind == Rules.Kind.ULTIMATE else "attack"
	if battle.art.has(key): draw_texture_rect(battle.art[key], Rect2(at-Vector2.ONE*side/2, Vector2.ONE*side),false,tint)
	if Rules.hits_all(roll):
		for i in range(4):
			var d := Vector2.from_angle(i*PI/2)
			Pixel.line(self,at+d*side*0.57,at+d*side*0.76,Color("eee0b9",tint.a),3)

func _mini_die(at: Vector2, face: int, half: float, alpha: float) -> void:
	Pixel.mini_die(self,at,face,half,alpha)

func _center(at: Vector2, value: String, size: int, color: Color, outline: bool = false, font: Font = null) -> void:
	value = GameText.text(value)
	if font == null: font = battle.pixel_font
	var width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	if outline: draw_string_outline(font,(at-Vector2(width/2,0)).round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,4 if font == battle.pixel_font else 2,Color("15151b"))
	draw_string(font,(at-Vector2(width/2,0)).round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
