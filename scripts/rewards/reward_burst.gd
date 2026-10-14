extends RefCounted
## One rarity-colored explosion per landed reel, independent of pickup effects.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const DURATION := 1.1

static func create(at: Vector2, color: Color, born: float, rng: RandomNumberGenerator, scale: float = 1.0) -> Dictionary:
	var particles: Array = []
	for i in range(84):
		particles.append(Vector4(i*TAU/84+rng.randf_range(-0.04,0.04),rng.randf_range(260,560)*scale,rng.randf_range(5,11)*scale,rng.randf_range(0.8,1)))
	return {"at":at,"color":color,"born":born,"particles":particles,"scale":scale}

static func paint(canvas: CanvasItem, burst: Dictionary, elapsed: float, reduced: bool) -> void:
	var age: float = elapsed-burst.born
	if age < 0 or age >= DURATION: return
	var t: float = age/DURATION
	var color: Color = burst.color
	var fade: float = pow(1-t,1.5)
	var center: Vector2 = burst.at
	var scale: float = burst.scale
	if reduced:
		Pixel.circle(canvas,center,(24+t*70)*scale,Color(color,fade*0.8),4)
		return
	var launch: float = 1-pow(1-t,3)
	Pixel.circle(canvas,center,(24+launch*240)*scale,Color(color,fade),7*scale)
	Pixel.circle(canvas,center,(14+launch*170)*scale,Color(color.lightened(0.45),fade*0.7),4*scale)
	var flash: float = clampf(1-age/0.16,0,1)
	for layer in range(7,0,-1):
		canvas.draw_circle(center,(18+layer*9)*scale,Color(color,flash*0.07))
	canvas.draw_circle(center,(16+launch*45)*scale,Color(Color.WHITE,flash*0.75))
	for seed in burst.particles:
		var direction := Vector2.from_angle(seed.x)
		var at: Vector2 = center+direction*seed.y*launch*0.8+Vector2(0,t*t*65*scale)
		Pixel.line(canvas,at-direction*(14+30*(1-t))*scale,at,Color(color,fade*seed.w),seed.z)
		draw_spark(canvas,at,color,fade*seed.w,seed.z)

static func draw_spark(canvas: CanvasItem, at: Vector2, color: Color, alpha: float, radius: float) -> void:
	canvas.draw_circle(at,radius*2.8,Color(color,alpha*0.15))
	canvas.draw_rect(Rect2(at-Vector2.ONE*radius/2,Vector2.ONE*radius),Color(color.lightened(0.65),alpha))
	Pixel.line(canvas,at-Vector2(radius,0),at+Vector2(radius,0),Color(Color.WHITE,alpha*0.75),2)
	Pixel.line(canvas,at-Vector2(0,radius),at+Vector2(0,radius),Color(Color.WHITE,alpha*0.75),2)
