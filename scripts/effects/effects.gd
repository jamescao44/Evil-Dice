extends Node2D
## Small reusable pixel effects; this RNG is deliberately separate from combat.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
var particles: Array = []
var rings: Array = []
var floats: Array = []
var flashes: Array = []
var spell: Dictionary = {}
var enemy_spells: Array = []
var slashes: Array = []
var sigils: Array = []
var feeds: Array = []
var combo: Dictionary = {}
var skill: Dictionary = {}
var perfect: Dictionary = {}
var dice_power: Dictionary = {}
var font: Font
var cosmetic = RandomNumberGenerator.new()
var reduced: bool = false
var time_factor: float = 1.0
var canvas_size := Vector2(1280, 800)
var skill_anchor := Vector2(640, 280)
var skill_max_width: float = 1200
var combo_font_size: int = 64
const FLOAT_FONT_SIZE := 24
const PERFECT_FONT_SIZE := 80
const PAIR_FONT_SIZE := 52
var ultimate_center := Vector2(927, 286)
var ultimate_scale: float = 1.0

func _ready() -> void:
	cosmetic.randomize()

func burst(at: Vector2, color: Color, count: int = 24, strength: float = 160) -> void:
	for i in range(count):
		var angle := cosmetic.randf_range(0, TAU)
		var velocity := Vector2.from_angle(angle) * cosmetic.randf_range(strength * 0.25, strength)
		particles.append({"p": at, "v": velocity, "color": color, "life": cosmetic.randf_range(0.4, 0.9), "max": 1.0, "size": cosmetic.randi_range(3, 7)})

func ring(at: Vector2, color: Color, radius: float = 90.0, clip: Rect2 = Rect2()) -> void:
	rings.append({"p": at, "color": color, "life": 0.55, "radius": radius, "clip":clip})

static func damage_font_size(damage: int) -> int:
	return roundi(FLOAT_FONT_SIZE*maxf(1.0,log(maxi(1,damage))/log(10.0)))

func floating(at: Vector2, text: String, color: Color, size: int = FLOAT_FONT_SIZE) -> void:
	floats.append({"p": at, "text": text, "color": color, "life": 1.3,"size":size})

func reveal_combo(label: String, at: Vector2, color: Color) -> void:
	combo = {"label": label, "p": at, "color": color, "age": 0.0}

func reveal_skill(label: String, description: String, color: Color) -> void:
	skill = {"label": label, "description": description, "color": color, "age": 0.0}

func reveal_perfect(at: Vector2) -> void:
	perfect = {"p": at, "age": 0.0}

func channel_dice(values: Array, positions: Array, center: Vector2, target: Vector2, face: int, color: Color, duration: float) -> void:
	var sources: Array = []
	var total: int = 0
	for i in range(values.size()):
		total += values[i]
		if face == 0 or values[i] == face:
			sources.append({"p": positions[i], "value": values[i]})
	dice_power = {"sources": sources, "center": center, "target": target, "sum": total, "merge": face == 0, "face": face, "color": color, "age": 0.0, "duration": duration}

func flash(color: Color, amount: float = 0.12) -> void:
	if not reduced:
		flashes.append({"color": color, "life": 0.22, "amount": amount})

func cast(face: int, from: Vector2, targets: Array, duration: float) -> void:
	spell = {"face": face, "from": from, "targets": targets, "life": duration, "duration": duration}
	if face > 0:
		activate_circle(from + Vector2(0, 55), Color("efd394") if face == 6 else Color("c5a4de"), 106, duration)
		for target in targets:
			activate_circle(target + Vector2(0, 60), Color("efd394") if face == 6 else Color("c5a4de"), 70, duration)

func slash(at: Vector2, heavy: bool = false) -> void:
	slashes.append({"p": at, "life": 0.38, "heavy": heavy, "flip": cosmetic.randi_range(0, 1) * 2 - 1})
	burst(at, Color("efc1ab"), 22 if heavy else 10, 180)

func activate_circle(at: Vector2, color: Color, radius: float = 90, duration: float = 0.8) -> void:
	sigils.append({"p": at, "color": color, "radius": radius, "life": duration, "duration": duration})

func feed(from: Vector2, to: Vector2, duration: float = 1.2) -> void:
	for i in range(18):
		feeds.append({"from": from + Vector2(cos(i * 2.4) * 30, sin(i) * 10), "to": to, "life": duration + i * 0.025, "duration": duration + i * 0.025, "bend": sin(i * 2.1) * 65})

func enemy_cast(role: int, from: Vector2, target: Vector2, duration: float, attribute: int = 0) -> void:
	enemy_spells.append({"face": -1, "role": role, "attribute":attribute, "from": from, "targets": [target], "life": duration, "duration": duration})

func clear() -> void:
	particles.clear()
	rings.clear()
	floats.clear()
	flashes.clear()
	spell.clear()
	enemy_spells.clear()
	slashes.clear()
	sigils.clear()
	feeds.clear()
	combo.clear()
	skill.clear()
	perfect.clear()
	dice_power.clear()

func _process(delta: float) -> void:
	var real_delta: float = delta
	delta *= time_factor
	if not dice_power.is_empty():
		dice_power.age += delta
		if dice_power.age >= dice_power.duration: dice_power.clear()
	if not perfect.is_empty():
		perfect.age += delta
		if perfect.age >= 0.7: perfect.clear()
	for callout in [combo, skill]:
		if not callout.is_empty():
			callout.age += delta
			if callout.age >= (1.05 if callout == combo else 1.4): callout.clear()
	for group in [slashes, sigils, feeds, enemy_spells]:
		for item in group:
			item.life -= delta
	enemy_spells = enemy_spells.filter(func(s): return s.life > 0)
	slashes = slashes.filter(func(s): return s.life > 0)
	sigils = sigils.filter(func(s): return s.life > 0)
	feeds = feeds.filter(func(s): return s.life > 0)
	for p in particles:
		p.life -= delta
		p.p += p.v * delta
		p.v.y += 80 * delta
	particles = particles.filter(func(p): return p.life > 0)
	for r in rings:
		r.life -= delta
	rings = rings.filter(func(r): return r.life > 0)
	for f in floats:
		f.life -= delta
		f.p.y -= 25 * delta
	floats = floats.filter(func(f): return f.life > 0)
	for f in flashes:
		f.life -= real_delta
	flashes = flashes.filter(func(f): return f.life > 0)
	if not spell.is_empty():
		spell.life -= delta
		if spell.life <= 0:
			spell = {}
	queue_redraw()

func _draw() -> void:
	for s in sigils:
		var t: float = 1 - s.life / s.duration
		var color: Color = Color(s.color, minf(1, s.life * 5) * 0.85)
		var radius: float = s.radius * minf(1, t * 5 + 0.25)
		Pixel.circle(self, s.p, radius, color, 3)
		Pixel.circle(self, s.p, radius * 0.8, Color(color, color.a * 0.5), 2)
		for i in range(6):
			var angle: float = i * TAU / 6 + (0 if reduced else t * 0.7)
			var a: Vector2 = s.p + Vector2.from_angle(angle) * radius * 0.7
			var b: Vector2 = s.p + Vector2.from_angle(angle + TAU / 3) * radius * 0.7
			Pixel.line(self, a, b, color, 2)
			var p: Vector2 = s.p + Vector2.from_angle(angle) * radius
			Pixel.line(self, p - Vector2(0, 6), p + Vector2(0, 6), color, 3)
	for f in feeds:
		var t: float = clampf(1 - f.life / f.duration, 0, 1)
		var p: Vector2 = f.from.lerp(f.to, t * t)
		p.y -= sin(t * PI) * (75 + f.bend)
		draw_rect(Rect2(p.snapped(Vector2.ONE * 3), Vector2(6, 6)), Color("c86e79"))
		draw_rect(Rect2(p.snapped(Vector2.ONE * 3) + Vector2(0, 0), Vector2(3, 3)), Color("f4b8b4"))
	if not spell.is_empty():
		_draw_spell(spell)
	for effect in enemy_spells:
		_draw_spell(effect)
	for s in slashes:
		var t: float = 1 - s.life / 0.38
		for i in range(3 if s.heavy else 2):
			var a: Vector2 = s.p + Vector2(-45 * s.flip + i * 14, 38 - i * 8)
			var b: Vector2 = s.p + Vector2(45 * s.flip + i * 14, -48 - i * 8)
			var end: Vector2 = a.lerp(b, minf(1, t * 4))
			var start: Vector2 = a.lerp(b, maxf(0, (t - 0.25) * 1.33))
			Pixel.line(self, start + Vector2(4, 4), end + Vector2(4, 4), Color("9b5475"), 8)
			Pixel.line(self, start, end, Color("fff1c5"), 4)
	for r in rings:
		var progress: float = 1 - r.life / 0.55
		Pixel.circle(self, r.p, 10 + progress * r.radius, Color(r.color, (1 - progress) * 0.8), 3, r.clip)
	for p in particles:
		draw_rect(Rect2(p.p.snapped(Vector2(2, 2)), Vector2.ONE * p.size), Color(p.color, minf(1, p.life * 2)))
	for f in flashes:
		draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(f.color, f.life / 0.22 * f.amount))
	for f in floats:
		var alpha: float = minf(1, f.life * 3)
		var translated := GameText.text(f.text)
		var size: int = f.get("size",FLOAT_FONT_SIZE)
		var width := font.get_string_size(translated, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if width > canvas_size.x-32:
			size = maxi(1,floori(size*(canvas_size.x-32)/width))
			width = font.get_string_size(translated,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var point := Vector2(clampf(f.p.x-width/2,16,canvas_size.x-width-16),maxf(font.get_ascent(size)+8,f.p.y)).snapped(Vector2.ONE*2)
		draw_string(font, point + Vector2(2, 2), translated, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.02, 0.04, 0.07, alpha))
		draw_string(font, point, translated, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(f.color, alpha))
	_draw_callouts()
	_draw_dice_power()

func _draw_dice_power() -> void:
	if dice_power.is_empty(): return
	var flow: Dictionary = dice_power
	var progress: float = clampf(flow.age / flow.duration, 0, 1)
	var gather: Vector2 = flow.center - Vector2(0, 8)
	var lift := Vector2(0, -35)
	if flow.merge and progress < 0.35:
		var converge: float = smoothstep(0.08, 0.35, progress)
		for source in flow.sources:
			var at: Vector2 = (source.p + lift).lerp(gather, converge)
			_label(str(source.value), at, 38, flow.color, 4)
		return
	if flow.merge and progress < 0.55:
		var pulse: float = (progress - 0.35) / 0.2
		Pixel.circle(self, gather - Vector2(0, 18), 24 + pulse * 30, Color(flow.color, (1 - pulse) * 0.7), 3)
	# A combination travels as one emblem, never as separate numeric damage values.
	var begin: float = 0.43 if flow.merge else 0.18
	var t: float = clampf((progress - begin) / (0.92 - begin), 0, 1)
	var travel: float = t * t * (3 - 2 * t)
	var at: Vector2 = gather.lerp(flow.target, travel)
	at += Vector2(-sin(t * PI) * 24, -sin(t * PI) * 75)
	var alpha: float = minf(1, (1 - t) * 8)
	if t > 0 and t < 1:
		Pixel.line(self, at + Vector2(0, 8), at + (gather - flow.target).normalized() * 25 + Vector2(0, 8), Color(flow.color, alpha * 0.4), 4)
	if flow.merge:
		_label(str(flow.sum), at, roundi(lerpf(52, 28, t)), Color(flow.color, alpha), 4)
	else:
		var pop: float = lerpf(0.7, 1.0, smoothstep(0.0, 0.12, progress))
		_draw_power_dice(at, flow.face, flow.sources.size(), lerpf(1.0, 0.75, t) * pop, Color(flow.color, alpha))

func _draw_power_dice(at: Vector2, face: int, count: int, size_scale: float, color: Color) -> void:
	var layouts := [[4], [0,8], [0,4,8], [0,2,6,8], [0,2,4,6,8], [0,2,3,5,6,8]]
	var side: float = roundf(34 * size_scale)
	var spacing: float = side + 6
	var pip_size: float = maxf(3, roundf(5 * size_scale))
	for i in range(count):
		var center: Vector2 = (at + Vector2((i - (count - 1) * 0.5) * spacing, 0)).round()
		var rect := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		draw_rect(rect.grow(5), Color(color, color.a * 0.25))
		draw_rect(rect.grow(3), Color(Color("211c17"), color.a))
		draw_rect(rect, Color(Color("bca677"), color.a))
		draw_rect(rect.grow(-2), Color(Color("e5d5ac"), color.a))
		draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(side - 4, 3)), Color(Color("fff1c5"), color.a))
		for pip in layouts[face - 1]:
			var offset := Vector2(pip % 3 - 1, floori(pip / 3.0) - 1) * roundf(side * 0.26)
			draw_rect(Rect2((center + offset - Vector2.ONE * pip_size * 0.5).round(), Vector2.ONE * pip_size), Color(Color("30271e"), color.a))

func _draw_callouts() -> void:
	if not perfect.is_empty():
		var age: float = perfect.age
		var pop: float = 1.0 if reduced else lerpf(0.65, 1.0, minf(1, age / 0.08))
		_label("PERFECT", perfect.p - Vector2(0, age * 36), roundi(PERFECT_FONT_SIZE * pop), Color(Color("fff0a6"), minf(1, (0.7 - age) / 0.22)), 4)
	if not skill.is_empty():
		var age: float = skill.age
		var alpha: float = minf(1, age * 14) * clampf((1.4-age)/0.35,0,1)
		var center := skill_anchor - Vector2(0, minf(age * 8, 8))
		var size: int = 52 if reduced else roundi(lerpf(58,52,clampf(age/0.18,0,1)))
		while size > 24 and font.get_string_size(GameText.text(skill.label), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > skill_max_width:
			size -= 2
		_label(skill.label,center,size,Color(skill.color,alpha),4)
		if not skill.description.is_empty():
			var body: Font = GameText.description_font()
			var body_size: int = 30 if canvas_size.y > canvas_size.x else 24
			var lines := GameText.lines(skill.description,body,body_size,skill_max_width)
			for i in range(lines.size()):
				var width: float = body.get_string_size(lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,body_size).x
				var at: Vector2 = center+Vector2(-width/2,42+i*(body_size+8))
				draw_string_outline(body,at,lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,body_size,2,Color(0.06,0.08,0.07,alpha))
				draw_string(body,at,lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,body_size,Color(0.92,0.89,0.75,alpha))
	if not combo.is_empty():
		var age: float = combo.age
		var pop: float = lerpf(0.45,1.22,1-pow(1-clampf(age/0.12,0,1),3))
		if age > 0.12: pop = lerpf(1.22,1.0,clampf((age-0.12)/0.16,0,1))
		var rise: float = clampf((age-0.1)/0.95,0,1)
		var at: Vector2 = combo.p - Vector2(0,rise*84)
		var alpha: float = clampf((1.05-age)/0.6,0,1)
		var size: int = roundi((PAIR_FONT_SIZE if combo.label == "PAIR" else combo_font_size) * pop)
		if not reduced and age < 0.24:
			for i in range(8):
				var direction := Vector2.from_angle(i*TAU/8)
				Pixel.line(self,at+direction*(70+age*160),at+direction*(91+age*230),Color(combo.color,alpha*(1-age/0.24)),4)
		_label(combo.label,at+Vector2(0,size*0.34),size,Color(combo.color,alpha),4)

func _label(value: String, baseline: Vector2, size: int, color: Color, outline: int) -> void:
	value = GameText.text(value)
	var width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var at: Vector2 = (baseline - Vector2(width/2,0)).snapped(Vector2.ONE*2)
	for offset in [Vector2(-outline,0),Vector2(outline,0),Vector2(0,-outline),Vector2(0,outline),Vector2(outline,outline+2)]:
		draw_string(font,at+offset,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0.06,0.08,0.07,color.a))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw_spell(cast_info: Dictionary) -> void:
	var progress: float = 1 - cast_info.life / cast_info.duration
	var strength: float = sin(progress * PI)
	var color := Color("b395f0")
	if cast_info.face == -1:
		var attribute: int = cast_info.get("attribute",0)
		var tint: Color = [Color("eee0b9"), Color("82dfff"), Color("ff9955"), Color("ffe388"), Color("c18ce8"), Color("8ad26a"), Color("93899e")][attribute]
		var target: Vector2 = cast_info.targets[0]
		var head: Vector2 = cast_info.from.lerp(target, minf(1, progress * 1.6))
		if cast_info.role in [0,3]:
			Pixel.line(self, target + Vector2(-32, 46) * strength, target + Vector2(32, -46) * strength, tint, 6)
		elif cast_info.role == 1:
			Pixel.line(self, head, head + Vector2(42, -2), tint, 3)
			Pixel.line(self, head + Vector2(9, -9), head, tint.lightened(0.3), 3)
			Pixel.line(self, head + Vector2(9, 9), head, tint.lightened(0.3), 3)
		else:
			Pixel.disc(self, head, 12, tint if attribute else Color("c5a4de"), 4)
			Pixel.circle(self, head, 20, tint.lightened(0.3), 3)
		return
	if cast_info.face == 6:
		color = Color("efd394")
		# An abyssal seal opens over the squad; pale tendrils tear through it.
		var center := ultimate_center
		var radius: float = 164 * strength * ultimate_scale
		Pixel.disc(self, center, radius, Color("1d182c"), 5)
		Pixel.circle(self, center, radius + 8, Color(color, strength), 4)
		Pixel.circle(self, center, radius - 7, Color("c5a4de"), 3)
		for i in range(8):
			var direction := Vector2.from_angle(i * TAU / 8)
			Pixel.line(self, center + direction * (radius + 18), center + direction * (radius + 43), Color(color, strength), 4)
		for i in range(3):
			var a: Vector2 = center + Vector2.from_angle(-PI / 2 + i * TAU / 3) * radius * 0.8
			var b: Vector2 = center + Vector2.from_angle(-PI / 2 + (i + 1) * TAU / 3) * radius * 0.8
			Pixel.line(self, a, b, Color(color, strength * 0.6), 3)
		for i in range(7):
			var points := PackedVector2Array()
			for step in range(14):
				var t: float = step / 13.0
				points.append((center + Vector2(-237 + i * 78 + sin(t * TAU + i + progress * 4) * 38 * t, 135 - t * (135 + i * 37 % 120) * strength) * ultimate_scale).snapped(Vector2.ONE * 4))
			draw_polyline(points, Color("593c6c"), 20)
			draw_polyline(points, Color("c4a3c0"), 12)
			draw_polyline(points, Color("f0d8cb"), 4)
		return
	for target in cast_info.targets:
		if cast_info.face in [0, 1, 3]:
			var end: Vector2 = cast_info.from.lerp(target, minf(1, progress * 2))
			for strand in range(3 if cast_info.face == 1 else 1):
				var points := PackedVector2Array()
				for step in range(16):
					var t: float = step / 15.0
					var point: Vector2 = cast_info.from.lerp(end, t)
					point.y += sin(t * PI * 2 + progress * 8 + strand) * 20 * sin(t * PI) + strand * 9
					points.append(point.snapped(Vector2(3, 3)))
				draw_polyline(points, Color("745476"), 15 if cast_info.face else 7)
				draw_polyline(points, Color("f0d8cb"), 5 if cast_info.face else 3)
		elif cast_info.face == 4:
			for i in range(12):
				var p: Vector2 = target + Vector2(sin(i * 2.4 + progress * 5) * 58, cos(i * 1.7) * 55)
				draw_rect(Rect2(p, Vector2(18, 18) * strength), Color("997bc8"))
		else:
			for i in range(3):
				draw_arc(target, 25 + i * 14 + strength * 15, progress * TAU + i, progress * TAU + i + PI * 1.5, 24, Color(color, strength), 5)
