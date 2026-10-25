extends RefCounted
## Procedural pixel-light rings and sustained beams, separate from targeting and damage.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")

## Paint broad additive-looking halos behind a crisp, pale laser core.
static func laser(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color, alpha: float, age: float, reduced: bool) -> void:
	var axis: Vector2 = (to-from).normalized()
	var normal := axis.orthogonal()
	for layer in range(4,0,-1):
		canvas.draw_line(from,to,Color(color,alpha*[0.0,0.82,0.3,0.10,0.04][layer]),width*[0.0,1.0,1.7,2.8,4.0][layer],false)
	canvas.draw_line(from,to,Color("fff8dc",alpha),maxf(2,width*0.36),false)
	if not reduced:
		for side in [-1,1]:
			var stream := PackedVector2Array()
			for i in range(19):
				var t: float = float(i)/18
				stream.append(from.lerp(to,t)+normal*(sin(t*TAU*2-age*9)*width*0.17+side*width*0.56))
			canvas.draw_polyline(stream,Color("fff3c2",alpha*0.65),2,false)
		for i in range(8):
			var t: float = fposmod(age*1.8+i/8.0,1)
			var p: Vector2 = from.lerp(to,t)
			canvas.draw_line(p-normal*width*0.55,p+normal*width*0.55,Color("fffbee",alpha*0.45),3,false)

## A hexagonal ritual emits one large light column with strands reaching all living targets.
static func wide_beam(r) -> void:
	if r.beam_targets.is_empty(): return
	var tint: Color = r.tint()
	var strength: float = r.beam_strength
	var aim := Vector2.ZERO
	for p in r.beam_targets: aim += p
	aim /= r.beam_targets.size()
	var axis: Vector2 = (aim-r.center).normalized()
	var normal := axis.orthogonal()
	var reach: float = 140
	for p in r.beam_targets: reach = maxf(reach,(p-r.center).dot(axis)+42)
	var low: float = -38
	var high: float = 38
	for p in r.beam_targets:
		var depth: float = maxf(0.2,(p-r.center).dot(axis)/reach)
		var lateral: float = (p-r.center).dot(normal)
		low = minf(low,(lateral-34)/depth)
		high = maxf(high,(lateral+34)/depth)
	var end: Vector2 = r.center+axis*reach
	# A single widening column aims at the enemy formation, including portrait layouts.
	for layer in range(4,0,-1):
		var padding: float = layer*8
		var polygon := PackedVector2Array([r.center-normal*(22+padding),end+normal*(low-padding),end+normal*(high+padding),r.center+normal*(22+padding)])
		beam_polygon(r,polygon,Color(tint,strength*(0.035 if layer > 1 else 0.32)))
	var core := PackedVector2Array([r.center-normal*15,end+normal*low*0.72,end+normal*high*0.72,r.center+normal*15])
	beam_polygon(r,core,Color("fff1bd",strength*0.32))
	laser(r,r.center,aim+axis*38,46,tint,strength*0.85,r.age,r.battle.reduced)
	# Faint longitudinal filaments make the wide beam read as one continuous flow.
	for i in range(7):
		var across: float = lerpf(low,high,float(i)/6)
		var tip: Vector2 = end+normal*across
		tip = tip.clamp(r.battle.ARENA.position+Vector2.ONE*8,r.battle.ARENA.end-Vector2.ONE*8)
		r.draw_line(r.center,tip,Color("fff8db",strength*0.22),2,false)
	for p in r.beam_targets:
		Pixel.circle(r,p,30+sin(r.age*5)*4,Color("fff4ce",0.9*strength),4)

## Keep the wide light wash inside the battlefield, clear of the top HUD and dice controls.
static func beam_polygon(r, polygon: PackedVector2Array, color: Color) -> void:
	var area: Rect2 = r.battle.ARENA.grow(-8)
	var clip := PackedVector2Array([area.position,area.position+Vector2(area.size.x,0),area.end,area.position+Vector2(0,area.size.y)])
	for piece in Geometry2D.intersect_polygons(polygon,clip): r.draw_colored_polygon(piece,color)

## One continuously energized beam slews toward each of five random targets.
static func targeted_beam(r) -> void:
	if r.beam_targets.is_empty(): return
	var target: Vector2 = r.beam_targets[0]
	if not r.previous_targets.is_empty(): target = r.previous_targets[0].lerp(target,smoothstep(0,0.09,r.shot_age))
	laser(r,r.center,target,17,r.tint(),r.beam_strength,r.age,r.battle.reduced)
	Pixel.disc(r,target,22,Color(r.tint(),0.22*r.beam_strength),4)
	Pixel.circle(r,target,20,Color("fff4d8",r.beam_strength),3)

## Draw counter-rotating rune bands without changing the upright dice faces.
static func sigil(r) -> void:
	var s: float = r.FORMATION_SCALE
	var a: float = r.aura
	var tint: Color = r.tint()
	var ready: bool = r.phase in ["charge","fire","hold","return"]
	var radius: float = r.radius
	if ready:
		for i in range(5,0,-1): Pixel.circle(r,r.center,radius*(0.72+i*0.07),Color(tint,a*0.07),5)
		Pixel.circle(r,r.center,radius*0.88,Color(tint,a*0.85),3)
		Pixel.circle(r,r.center,radius*0.70,Color("fff2bd",a*0.72),2)
		Pixel.disc(r,r.center,radius*0.60,Color(tint,a*0.08),4)
		for i in range(24):
			var angle: float = i*TAU/24+r.rotation_angle
			var d := Vector2.from_angle(angle)
			var p: Vector2 = r.center+d*radius*0.79
			var n: Vector2 = d.orthogonal()
			Pixel.line(r,p-d*4*s,p+d*4*s,Color("fff1be",a*0.9),2)
			if i%2 == 0: Pixel.line(r,p-(n*3+d*2)*s,p+(n*3+d*2)*s,Color(tint,a),2)
		for i in range(6):
			var angle: float = i*TAU/6-r.rotation_angle*1.4
			var a1: Vector2 = r.center+Vector2.from_angle(angle)*radius*1.14
			var a2: Vector2 = r.center+Vector2.from_angle(angle+0.23)*radius*1.14
			r.draw_line(a1,a2,Color(tint,a*0.65),4,false)
	# Draw the outside polygon and the pentagram / two interlocked triangles.
	for i in range(r.points.size()):
		var p: Vector2 = r.points[i]
		var next: Vector2 = r.points[(i+1)%r.count]
		var diagonal: Vector2 = r.points[(i+2)%r.count]
		for width in [15,7,2]:
			var alpha: float = 0.05 if width == 15 else 0.2 if width == 7 else 0.95
			r.draw_line(p,next,Color(tint,a*alpha),width*s,false)
			r.draw_line(p,diagonal,Color("fff0bb",a*alpha*0.7),width*s,false)
		Pixel.disc(r,p,(22 if ready else 32)*s,Color(tint,a*0.16),4)
		Pixel.circle(r,p,(27 if ready else 38)*s,Color(tint,a*0.7),2)
	if ready:
		var power: float = 1.0 if r.phase == "fire" else 0.6+r.progress*0.3 if r.phase == "charge" else 0.5
		for i in range(4,0,-1): Pixel.disc(r,r.center,(7+i*7*power)*s,Color(tint,a*0.06*(5-i)),3)
		Pixel.disc(r,r.center,(7+power*7)*s,Color("fff8d9",a*0.92),3)
		if r.phase == "charge" and not r.battle.reduced:
			for i in range(12):
				var t: float = fposmod(r.age*1.5+i/12.0,1)
				var d := Vector2.from_angle(i*TAU/12+r.rotation_angle)
				Pixel.line(r,r.center+d*radius*(1-t),r.center+d*radius*maxf(0,0.8-t),Color("fff4d7",a*t),3)

## Layer sparks, the sustained beam, then the summoning seal beneath the real dice.
static func draw(r) -> void:
	if r.beam_strength > 0:
		if r.count == 6: wide_beam(r)
		else: targeted_beam(r)
	sigil(r)
	for p in r.particles:
		var a: float = clampf(p.life/p.max,0,1)*r.aura
		r.draw_rect(Rect2(p.p-Vector2.ONE*p.size,Vector2.ONE*p.size*2),Color(r.tint(),a*0.14))
		r.draw_rect(Rect2(p.p-Vector2.ONE*p.size*0.5,Vector2.ONE*p.size),Color("fff0c7",a))
