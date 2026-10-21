extends RefCounted
## Pixel flame vocabulary for Flamelings: embers, fireball, slash, storm and brimstone.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
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
	if tier == 2:
		for i in range(3): Pixel.line(canvas,at+Vector2(-side*0.3+i*5,side*0.3),at+Vector2(side*0.3,-side*0.3+i*5),color,5-i)
	else:
		ember(canvas,at,side*(0.22 if tier < 4 else 0.28),color,0.2,alpha)
		if tier >= 3:
			Pixel.circle(canvas,at,side*0.39,color,3)
			for i in range(tier+1):
				var d := Vector2.from_angle(i*TAU/(tier+1))
				Pixel.line(canvas,at+d*side*0.42,at+d*side*0.51,color,3)

## Spell progress reaches the target at 55%, matching the combat impact timing.
static func paint(canvas: CanvasItem, spell: Dictionary, reduced: bool) -> void:
	var t: float = clampf(1.0-spell.life/spell.duration,0,1)
	var tier: int = spell.flame_tier
	var color: Color = COLORS[tier]
	var travel: float = clampf(t/0.55,0,1)
	var fade: float = minf(1,(1-t)*4)
	for index in range(spell.targets.size()):
		# Scale around the impact point; both projectile endpoints stay camera-aligned.
		var size_scale: float = spell.get("scales",[])[index] if index < spell.get("scales",[]).size() else 1.0
		var target := Vector2.ZERO
		var origin: Vector2 = (spell.from-spell.targets[index])/size_scale
		canvas.draw_set_transform(spell.targets[index],0,Vector2.ONE*size_scale)
		if tier <= 1:
			var head: Vector2 = origin.lerp(target,travel)
			head.y -= sin(travel*PI)*(18 if tier == 0 else 42)
			for tail in range(5 if not reduced else 2,0,-1):
				var p: float = maxf(0,travel-tail*0.045)
				var point: Vector2 = origin.lerp(target,p)-Vector2(0,sin(p*PI)*(18 if tier == 0 else 42))
				Pixel.disc(canvas,point,(7 if tier == 0 else 16)*(1-tail*0.12),Color(color,fade*(0.65-tail*0.08)),3)
			ember(canvas,head,9 if tier == 0 else 22,color,t,fade)
		elif tier == 2:
			for layer in range(3):
				var points := PackedVector2Array()
				for i in range(17):
					var a: float = lerpf(-2.5,0.8,float(i)/16*travel)
					points.append(target+Vector2(cos(a)*82,sin(a)*58))
				canvas.draw_polyline(points,Color(color if layer == 0 else Color("ffd98a") if layer == 1 else Color("fff5dc"),fade),[18,10,4][layer])
		elif tier == 3:
			for i in range(3 if reduced else 7):
				var angle: float = i*TAU/7+t*8
				var radius: float = (1-travel)*100+18
				var point: Vector2 = target+Vector2(cos(angle)*radius,sin(angle)*radius*0.55-(1-travel)*85)
				ember(canvas,point,12+travel*6,color,t+i,fade)
			Pixel.circle(canvas,target,35+travel*55,Color(color,fade*0.6),4)
		else:
			var width: float = 15+sin(travel*PI/2)*42
			var top: Vector2 = target-Vector2(0,260)
			var bottom: Vector2 = top.lerp(target+Vector2(0,35),travel)
			Pixel.line(canvas,top,bottom,Color("d83d30",fade*0.45),width*1.5)
			Pixel.line(canvas,top,bottom,Color(color,fade),width)
			Pixel.line(canvas,top,bottom,Color("fff8d4",fade),width*0.36)
			Pixel.circle(canvas,target+Vector2(0,20),30+travel*66,Color(color,fade),5)
			for i in range(3 if reduced else 9):
				var angle: float = i*TAU/9
				ember(canvas,target+Vector2(cos(angle)*75,sin(angle)*28),9+travel*10,color,t+i,fade)
		if t >= 0.55:
			var blast: float = (t-0.55)/0.45
			Pixel.circle(canvas,target,8+blast*(25+tier*24),Color(color,(1-blast)*0.85),2+tier)
		canvas.draw_set_transform(Vector2.ZERO)
