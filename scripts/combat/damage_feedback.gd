extends Node2D
## Presentation-only damage recipe: regular base -> skill -> ordered modifiers -> hit.
## The model supplies the trace; this node never mutates combat or consumes RNG.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Orb = preload("res://scripts/combat/skill_orb_paint.gd")
const INTRO := 0.12
const STEP_TIME := 0.36
const FLIGHT_TIME := 0.25
const IMPACT_TIME := 0.38
const COMBINE_TIME := 0.28
const WAVE_TIME := 0.22
const WAVE_SPREAD := 0.14
const TREMBLE_THRESHOLD := 100.0
const TREMBLE_PER_DECADE := 2.0
const MAX_TREMBLE := 6.0
var battle
var active: bool = false
var building: bool = false
var value: float = 1.0
var base_value: float = 15.0
var steps: Array = []
var cursor: int = -1
var phase: String = ""
var age: float = 0
var result_age: float = 0
var tremble_age: float = 0
var impact_age: float = IMPACT_TIME
var impact_speed: float = 1.0
var impact_direction: int = 0
var base_direction: int = 0
var mult_direction: int = 0
var impact_color := Color.WHITE
var fade_age: float = -1
var flight_from := Vector2.ZERO
var landed: bool = false
var hit_damage: int = -1

func _ready() -> void:
	z_index = 115
	battle.model.relic_activated.connect(_relic_activated)
	hide()

func start(values: Array) -> void:
	clear()
	if values.is_empty(): return
	steps = values.duplicate(true)
	base_value = steps[0].base_before
	value = steps[0].before
	active = true
	building = true
	phase = "intro"
	visible = true

func clear() -> void:
	hit_damage = -1
	active = false
	building = false
	value = 1.0
	base_value = 15.0
	steps.clear()
	cursor = -1
	phase = ""
	age = 0
	result_age = 0
	tremble_age = 0
	impact_age = IMPACT_TIME
	impact_speed = 1.0
	impact_direction = 0
	base_direction = 0
	mult_direction = 0
	fade_age = -1
	landed = false
	hide()

func finish() -> void:
	building = false
	if active: fade_age = 0

static func number(amount: float, multiplier: bool = false) -> String:
	var text: String = "%.2f" % amount
	while text.ends_with("0"): text = text.left(-1)
	if text.ends_with("."): text = text + "0" if multiplier else text.left(-1)
	return text

func formula_label() -> String:
	return "DMG %s x %s" % [number(base_value),number(value,true)]

func combined_damage() -> int:
	return hit_damage if hit_damage >= 0 else floori(base_value * value + 0.000001)

func label() -> String:
	return "DMG %d" % combined_damage() if phase == "result" else formula_label()

func anchor() -> Vector2:
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	# Leave room above the baseline for the enlarged wave and maximum tremble.
	return battle.ARENA.position+Vector2(24 if portrait else 18,50 if portrait else 44)

func text_size() -> int:
	var size: int = 30 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 24
	var available: float = battle.ARENA.size.x - 64
	var width: float = battle.pixel_font.get_string_size(formula_label(),HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	return maxi(14,floori(size * minf(1.0,available/maxf(1,width*1.35))))

func _width(text: String) -> float:
	return battle.pixel_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size()).x

func impact_point(part: String = "") -> Vector2:
	if part.is_empty(): part = "base" if base_direction != 0 else "mult"
	var offset: float = _width("DMG ")
	if part == "base": offset += _width(number(base_value))*0.5
	else: offset += _width(number(base_value)+" x ")+_width(number(value,true))*0.5
	return anchor()+Vector2(offset,-text_size()*0.4)

func motion(direction: int = 2) -> Vector2:
	if direction == 2: direction = impact_direction
	if battle.reduced or impact_age >= IMPACT_TIME or direction == 0: return Vector2.ZERO
	var t: float = impact_age/IMPACT_TIME
	if direction < 0: return Vector2(sin(t*TAU*4)*5*(1-t),0)
	return Vector2(0,-sin(t*TAU)*9*(1-t))

func _impact(next_base: float, next_mult: float, color: Color) -> void:
	base_direction = 1 if next_base > base_value else -1 if next_base < base_value else 0
	mult_direction = 1 if next_mult > value else -1 if next_mult < value else 0
	impact_direction = base_direction if base_direction != 0 else mult_direction
	base_value = next_base
	value = next_mult
	impact_age = 0
	impact_speed = current_step_speed()
	impact_color = color
	if impact_direction != 0: battle._sound("player/drop_001",1.25 if impact_direction > 0 else 0.7,-22)

func sync_value(next: float) -> void:
	# A kill can change a Reaper's modifier between hits of one skill.
	if active and not building and not is_equal_approx(value,next):
		_impact(base_value,next,Color("dfb866"))
		result_age = 0

## Show the current leftover die's base and rounded hit without replaying relics.
func sync_hit(next_base: float, actual: int) -> void:
	if not active: return
	if not is_equal_approx(base_value,next_base):
		_impact(next_base,value,Color("dfb866"))
		result_age = 0
	hit_damage = actual

func _relic_activated(id: String) -> void:
	var skill: MultiHitSkill = battle.model.pending
	if not active or fade_age >= 0 or skill.is_empty() or skill.uses_left() <= 1 or not battle.model.outcome().is_empty(): return
	var next: float = battle.model.cast_damage_multiplier(skill)
	if is_equal_approx(value,next): return
	if building:
		if cursor >= 0 and cursor < steps.size() and steps[cursor].id == id and not landed: steps[cursor].after = next
		return
	steps = [{"source":"relic","id":id,"slot":battle.model.relics.index_of(id),"speed":battle.model.relic_activation_speed,"before":value,"after":next,"base_before":base_value,"base_after":base_value,"note":""}]
	cursor = -1
	building = true
	_advance()

func step_color(step: Dictionary) -> Color:
	if not step.id.is_empty(): return Catalog.color(step.id)
	return Color("c18ce8") if step.source == "darkness" else Color("dfb866")

func current_step_speed() -> float:
	return steps[cursor].get("speed",1.0) if phase == "steps" and cursor >= 0 and cursor < steps.size() else 1.0

func _advance() -> void:
	cursor += 1
	age = 0
	landed = false
	if cursor >= steps.size():
		phase = "combine"
		return
	phase = "steps"
	var step: Dictionary = steps[cursor]
	flight_from = battle._perfect_combo_center() if step.source == "combo" else battle._player_point()
	if step.source == "skill": flight_from = battle._source_bubble(battle.casting_source).cast_position
	if step.slot >= 0:
		flight_from = battle.relic_ui.slot_rect(step.slot).get_center()
		for id in step.get("activators",[step.id]): battle.relic_ui.activate(id,step.get("speed",1.0))

func _process(delta: float) -> void:
	if not is_instance_valid(battle): return
	visible = active and not battle._menus_open() and battle.view_phase == "resolving"
	if battle._menus_open() or not active: return
	var elapsed: float = delta*clampf(battle._roll_speed(),1,2)
	impact_age += elapsed*impact_speed
	tremble_age += elapsed
	if phase == "result": result_age += elapsed
	if fade_age >= 0:
		fade_age += elapsed
		if fade_age >= 0.2: clear(); return
	if building:
		age += elapsed*current_step_speed()
		if phase == "intro":
			if age >= INTRO: _advance()
		elif phase == "combine":
			if age >= COMBINE_TIME:
				phase = "result"
				result_age = 0
				building = false
				battle._sound("player/drop_001",1.5,-20)
		elif phase == "steps":
			if not landed and age >= FLIGHT_TIME:
				landed = true
				_impact(steps[cursor].base_after,steps[cursor].after,step_color(steps[cursor]))
			if age >= STEP_TIME: _advance()
	queue_redraw()

func _wave_motion(index: int, count: int, time: float, height: float) -> Vector2:
	if battle.reduced: return Vector2.ZERO
	var local: float = time - index * WAVE_SPREAD/maxi(1,count-1)
	if local < 0 or local > WAVE_TIME: return Vector2.ZERO
	return Vector2(0,-sin(local/WAVE_TIME*PI)*height)

func formula_glyph_motion(index: int, count: int) -> Vector2:
	if base_direction <= 0 and mult_direction <= 0: return Vector2.ZERO
	return _wave_motion(index,count,impact_age,9)

func result_glyph_motion(index: int, count: int) -> Vector2:
	return _wave_motion(index,count,result_age,12)

func result_glyph_scale(index: int, count: int) -> float:
	if battle.reduced: return 1.2
	return 1.2 + absf(result_glyph_motion(index,count).y)/12.0*0.25

static func damage_tremble_amplitude(damage: float) -> float:
	if damage <= TREMBLE_THRESHOLD: return 0.0
	return minf(MAX_TREMBLE,log(damage/TREMBLE_THRESHOLD)/log(10.0)*TREMBLE_PER_DECADE)

func number_tremble(index: int) -> Vector2:
	if battle.reduced: return Vector2.ZERO
	var amplitude: float = damage_tremble_amplitude(combined_damage())
	# Match the dice's charging frequencies without consuming combat randomness.
	return Vector2(sin(tremble_age*71+index*2.1),cos(tremble_age*83+index*1.7))*amplitude

func _glyph(at: Vector2, character: String, scale_value: float, opacity: float) -> void:
	var width: float = _width(character)
	draw_set_transform(at+Vector2(width*0.5,0),0,Vector2.ONE*scale_value)
	draw_string(battle.pixel_font,Vector2(-width*0.5+2,2),character,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size(),Color(0.04,0.06,0.05,opacity))
	draw_string(battle.pixel_font,Vector2(-width*0.5,0),character,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size(),Color(1,1,1,opacity))
	draw_set_transform(Vector2.ZERO)

func _draw_formula(opacity: float) -> void:
	var x: float = 0
	var index: int = 0
	var count: int = formula_label().length()
	var merge: float = clampf(age/COMBINE_TIME,0,1) if phase == "combine" else 0.0
	var center: float = _width(formula_label())*0.5
	for part in [["DMG ",0,false],[number(base_value),base_direction,true],[" x ",0,false],[number(value,true),mult_direction,true]]:
		var direction: int = part[1]
		# Each numeric value trembles together so its digits remain readable.
		var tremble: Vector2 = number_tremble(index) if part[2] else Vector2.ZERO
		for character in part[0]:
			var wave: Vector2 = formula_glyph_motion(index,count)
			var bump: float = absf(wave.y)/9.0*0.16
			var at: Vector2 = anchor()+Vector2(lerpf(x,center,merge*0.55),0)+wave
			if direction < 0: at += motion(direction)
			at += tremble
			_glyph(at,character,1+bump,opacity*(1-merge))
			x += _width(character)
			index += 1

func _draw_result(opacity: float) -> void:
	var at: Vector2 = anchor()
	var text: String = label()
	for i in range(text.length()):
		var offset: Vector2 = result_glyph_motion(i,text.length())
		if i >= 4: offset += number_tremble(4)
		_glyph(at+offset,text[i],result_glyph_scale(i,text.length()),opacity)
		at.x += _width(text[i])*1.3

func _draw_flight(step: Dictionary, opacity: float) -> void:
	var color: Color = step_color(step)
	if not step.note.is_empty():
		var note: String = GameText.format(step.note,step.note_values) if not step.get("note_values",[]).is_empty() else GameText.text(step.note)
		draw_string(battle.pixel_font,flight_from+Vector2(-28,-30-age*16),note,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(color,opacity*(1-age/STEP_TIME)))
	if battle.reduced: return
	var parts: Array = []
	if not is_equal_approx(step.base_before,step.base_after): parts.append("base")
	if not is_equal_approx(step.before,step.after): parts.append("mult")
	var particle_scale: float = 1.4 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 1.0
	for part in parts:
		for i in range(3):
			var delay: float = i*0.035
			var t: float = clampf((age-delay)/(FLIGHT_TIME-delay),0,1)
			if t <= 0 or t >= 1: continue
			var from: Vector2 = flight_from+Vector2(sin(i*2.1),cos(i*1.7))*12
			var target: Vector2 = impact_point(part)
			var at: Vector2 = from.lerp(target,pow(t,1.6))+Vector2(sin(t*PI)*32,-sin(t*PI)*54)
			var prior: float = maxf(0,t-0.06)
			var trail: Vector2 = from.lerp(target,pow(prior,1.6))+Vector2(sin(prior*PI)*32,-sin(prior*PI)*54)
			draw_line(trail,at,Color(color,0.3*opacity),12*particle_scale)
			draw_line(trail,at,Color("fff2c8",0.7*opacity),3*particle_scale)
			Orb.paint(self,at,(16-i*2)*particle_scale,color,true)

func _draw() -> void:
	if not active: return
	var opacity: float = 1.0 if fade_age < 0 else clampf(1-fade_age/0.2,0,1)
	if phase == "result": _draw_result(opacity)
	else: _draw_formula(opacity)
	if phase == "steps" and cursor >= 0 and cursor < steps.size(): _draw_flight(steps[cursor],opacity)
	if not battle.reduced and impact_age < 0.2 and impact_direction != 0:
		var t: float = impact_age/0.2
		draw_arc(impact_point(),8+t*28,0,TAU,24,Color(impact_color,(1-t)*0.65*opacity),2)
		for i in range(8):
			var at: Vector2 = impact_point()+Vector2.from_angle(i*TAU/8)*(6+t*25)
			draw_circle(at,2,Color(impact_color,(1-t)*opacity))
