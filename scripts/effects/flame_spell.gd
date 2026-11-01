extends RefCounted
## Pixel flame vocabulary for Flamelings: embers, fireball, slash, storm and brimstone.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Embers = preload("res://scripts/effects/flame_particles.gd")
const Particles = preload("res://scripts/effects/baked_particles.gd")
const FireStorm = preload("res://scripts/effects/fire_storm.gd")
const FierySlash = preload("res://scripts/effects/fiery_slash.gd")
const Brimstone = preload("res://scripts/effects/brimstone.gd")
const COLORS := [Color("ffb057"),Color("ff9c42"),Color("ff7440"),Color("ff5250"),Color("ffda72")]

## Layer offset flame lobes around a white-hot core without sprite stretching.
static func ember(canvas: CanvasItem, at: Vector2, radius: float, color: Color, age: float, alpha: float = 1.0) -> void:
	Pixel.disc(canvas,at,radius*1.7,Color(color,alpha*0.12),3)
	for i in range(4):
		var offset := Vector2(sin(i*2.4+age*15)*radius*0.45,-radius*(0.4+fmod(age*3+i*0.22,1.0)))
		Pixel.disc(canvas,at+offset,radius*(0.55-i*0.08),Color(color,alpha*0.7),3)
	Pixel.disc(canvas,at,radius,Color(color,alpha),3)
	Pixel.disc(canvas,at+Vector2(0,2),radius*0.55,Color("fff1bf",alpha),2)

## Draw a compact tier-specific fire sigil inside the summoned skill.
static func icon(canvas: CanvasItem, at: Vector2, side: float, tier: int, alpha: float) -> void:
	var color: Color = Color(COLORS[clampi(tier,0,4)],alpha)
	if tier == 4:
		Brimstone.paint_frame(canvas,Brimstone.LOOP_FIRST,Rect2(at-Vector2.ONE*side*0.6,Vector2.ONE*side*1.2),Color(1,1,1,alpha))
		return
	if tier == 3:
		FireStorm.paint_frame(canvas,FireStorm.LOOP_FIRST,Rect2(at-Vector2.ONE*side*0.6,Vector2.ONE*side*1.2),Color(1,1,1,alpha))
		return
	if tier == 2:
		FierySlash.paint_frame(canvas,FierySlash.IMPACT_FRAME,Rect2(at-Vector2.ONE*side*0.6,Vector2.ONE*side*1.2),Color(1,1,1,alpha))
	else:
		ember(canvas,at,side*(0.22 if tier < 4 else 0.28),color,0.2,alpha)
		if tier >= 3:
			Pixel.circle(canvas,at,side*0.39,color,3)
			for i in range(tier+1):
				var d := Vector2.from_angle(i*TAU/(tier+1))
				Pixel.line(canvas,at+d*side*0.42,at+d*side*0.51,color,3)

## Track projectiles to their impact points and delegate authored sheets to their own clocks.
static func paint(canvas: CanvasItem, spell: Dictionary, reduced: bool) -> void:
	var t: float = clampf(1.0-spell.life/spell.duration,0,1)
	var tier: int = spell.flame_tier
	if tier == 4:
		Brimstone.paint(canvas,spell,reduced)
		return
	var color: Color = COLORS[tier]
	var travel: float = clampf(t/0.55,0,1)
	var fade: float = minf(1,(1-t)*4)
	for index in range(spell.targets.size()):
		# Scale around the impact point; both projectile endpoints stay camera-aligned.
		var size_scale: float = spell.get("scales",[])[index] if index < spell.get("scales",[]).size() else 1.0
		var target := Vector2.ZERO
		var origin: Vector2 = (spell.from-spell.targets[index])/size_scale
		var visual_scale: float = FireStorm.VISUAL_SCALE if tier == 3 else 1.0
		# Enlarge storms around their ground contact so the bottom does not slide over HP bars.
		var offset := Vector2(0,FireStorm.SIDE*0.4*size_scale*(1-visual_scale))
		if tier == 3 and index < spell.get("feet",[]).size():
			offset = spell.feet[index]-spell.targets[index]-Vector2(0,FireStorm.SIDE*0.4*size_scale*visual_scale)
		canvas.draw_set_transform(spell.targets[index]+offset,0,Vector2.ONE*size_scale*visual_scale)
		if tier <= 1:
			var head: Vector2 = origin.lerp(target,travel)
			head.y -= sin(travel*PI)*(18 if tier == 0 else 42)
			for tail in range(5 if not reduced else 2,0,-1):
				var p: float = maxf(0,travel-tail*0.045)
				var point: Vector2 = origin.lerp(target,p)-Vector2(0,sin(p*PI)*(18 if tier == 0 else 42))
				Pixel.disc(canvas,point,(7 if tier == 0 else 16)*(1-tail*0.12),Color(color,fade*(0.65-tail*0.08)),3)
			ember(canvas,head,9 if tier == 0 else 22,color,t,fade)
			if tier == 1:
				Embers.trail(canvas,origin,target,travel,t,42,30,12 if reduced else 64,color,fade,true)
		elif tier == 2:
			FierySlash.paint(canvas,spell,reduced)
		elif tier == 3:
			FireStorm.paint(canvas,spell,index,reduced)
		if tier <= 1 and t >= 0.55:
			var blast: float = (t-0.55)/0.45
			Pixel.circle(canvas,target,8+blast*(25+tier*24),Color(color,(1-blast)*0.85),2+tier)
			if tier == 1: Particles.burst(canvas,"fire_burst",target,blast,1.0,reduced)
		canvas.draw_set_transform(Vector2.ZERO)
