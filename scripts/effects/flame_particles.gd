extends RefCounted
## Shared cosmetic embers sampled from effect time, never from gameplay randomness.

## Ragged, tapered cinders keep fire hot and directional without white sparkle centers.
static func cinder(canvas: CanvasItem, point: Vector2, velocity: Vector2, size: float, color: Color, alpha: float = 1.0) -> void:
	if alpha <= 0.001: return
	var direction := velocity.normalized()
	var normal := direction.orthogonal()
	var at := point.snapped(Vector2.ONE*2)
	var shape := PackedVector2Array([direction*size*0.8,normal*size*0.55-direction*size*0.25,-direction*size*2.4-normal*size*0.2,-normal*size*0.65])
	var glow := PackedVector2Array()
	var body := PackedVector2Array()
	for corner in shape:
		glow.append(at+corner*1.65)
		body.append(at+corner)
	canvas.draw_colored_polygon(glow,Color(color,alpha*0.17))
	canvas.draw_colored_polygon(body,Color(color,alpha))
	var core := PackedVector2Array([at+direction*size*0.5,at+normal*size*0.22,at-direction*size*0.9])
	canvas.draw_colored_polygon(core,Color(color.lerp(Color("ffb52d"),0.35),alpha*0.9))

## A colored halo, bright pixel core and occasional white glint keep dense sparks readable.
static func spark(canvas: CanvasItem, point: Vector2, size: float, color: Color, alpha: float = 1.0) -> void:
	if alpha <= 0.001: return
	var at := point.snapped(Vector2.ONE)
	canvas.draw_rect(Rect2(at-Vector2.ONE*size*1.5,Vector2.ONE*size*3),Color(color,alpha*0.16))
	canvas.draw_rect(Rect2(at-Vector2.ONE*size*0.5,Vector2.ONE*size),Color(color.lerp(Color("fff2b0"),0.35),alpha))
	if size >= 3.5: canvas.draw_rect(Rect2(at-Vector2.ONE,Vector2.ONE*2),Color("fff9dc",alpha))

## Scatter a dense wake from earlier positions on the projectile's curved path.
static func trail(canvas: CanvasItem, from: Vector2, to: Vector2, progress: float, age: float, lift: float, width: float, count: int, color: Color, alpha: float = 1.0, fierce: bool = false) -> void:
	for i in range(count):
		var phase: float = fposmod(age*2.3+i*0.618034,1.0)
		var along: float = maxf(0,progress-phase*0.34)
		var at: Vector2 = from.lerp(to,along)-Vector2(0,sin(along*PI)*lift)
		at += Vector2(sin(i*4.13)*width*phase,cos(i*2.71)*width*phase-phase*phase*28)
		var opacity: float = alpha*(1-phase)*smoothstep(0,0.08,progress)
		if fierce:
			var velocity: Vector2 = from-to+Vector2(sin(i*4.13)*width,-cos(along*PI)*PI*lift-50)
			cinder(canvas,at,velocity,3.0+i%4,Color("ff480a").lerp(color,float(i%5)/5.0),opacity)
		else: spark(canvas,at,2.0+i%4,color,opacity)

## One impact throws varied radial embers outward without extending the attack timeline.
static func explosion(canvas: CanvasItem, at: Vector2, progress: float, count: int, reach: float, color: Color, alpha: float = 1.0, fierce: bool = false) -> void:
	var t: float = clampf(progress,0,1)
	for i in range(count):
		var direction := Vector2.from_angle(i*2.399963)
		var distance: float = reach*(0.3+fposmod(i*0.754877,1.0)*0.7)*(1-pow(1-t,2))
		var point: Vector2 = at+direction*distance-Vector2(0,reach*0.25*t*t)
		var opacity: float = alpha*(1-t)*smoothstep(0,0.04,t)
		if fierce: cinder(canvas,point,direction-Vector2(0,0.25*t),3.0+i%4,Color("ff480a").lerp(color,float(i%5)/5.0),opacity)
		else: spark(canvas,point,2.0+i%4,color,opacity)

## Continuously lift scattered embers through a column with staggered lifetimes.
static func fountain(canvas: CanvasItem, at: Vector2, age: float, width: float, height: float, count: int, color: Color, alpha: float = 1.0) -> void:
	for i in range(count):
		var phase: float = fposmod(age*(0.8+fposmod(i*0.37,0.7))+i*0.618034,1.0)
		var point := at+Vector2(sin(i*2.4)*width+sin(age*3+i)*width*0.16*phase,-phase*height)
		spark(canvas,point,2.0+i%4,color,alpha*sin(phase*PI)*(1-phase*0.4))
