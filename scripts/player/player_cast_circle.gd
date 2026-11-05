extends RefCounted
## Flattened rotating sigils attach to the hand and overhead channel in world coordinates.
const GOLD := Color("ffd46a")
const HOT := Color("fff1b1")

## Project every point onto an ellipse; rotation happens within that tilted plane.
static func point(center: Vector2, radius: float, angle: float) -> Vector2:
	return center+Vector2(cos(angle),sin(angle)*0.32)*radius

## Bounded geometry gives the circle an orange halo, gold runes and a bright inner seal.
static func ring(canvas: CanvasItem, center: Vector2, radius: float, angle: float, alpha: float, reduced: bool) -> void:
	var points := PackedVector2Array()
	for i in range(49): points.append(point(center,radius,i*TAU/48))
	for width in [10.0,5.0,1.7]: canvas.draw_polyline(points,Color(GOLD,alpha*(0.09 if width > 5 else 0.22 if width > 2 else 0.95)),width,true)
	for inset in [0.72,0.86]:
		var inner := PackedVector2Array()
		for i in range(33): inner.append(point(center,radius*inset,i*TAU/32))
		canvas.draw_polyline(inner,Color(GOLD,alpha*0.65),1.2,true)
	for i in range(6):
		var a: float = angle+i*TAU/6
		canvas.draw_line(point(center,radius*0.7,a),point(center,radius*0.7,a+TAU/3),Color(HOT,alpha*0.7),1.4,true)
		canvas.draw_line(point(center,radius*0.89,a),point(center,radius*1.04,a+0.06),Color(HOT,alpha),2,true)
	if not reduced:
		for i in range(8):
			var p: Vector2 = point(center,radius*(0.95+0.13*sin(angle*3+i)),angle*1.4+i*TAU/8)
			canvas.draw_rect(Rect2(p-Vector2.ONE*1.5,Vector2.ONE*3),Color(HOT,alpha*0.85))

## Recovery shrinks the hand seal; ultimate channel grows, trembles, then flashes open.
static func paint(canvas: CanvasItem, rect: Rect2, animation, reduced: bool, tint: Color) -> void:
	if animation.action.is_empty() or animation.action == "pair" or animation.emoting(): return
	var active: bool = animation.phase in ["build","damage"]
	var strength: float = 1.0 if active else clampf(animation.age*8,0,1) if animation.phase == "windup" else 1-clampf(animation.age*animation.FPS/6,0,1)
	var alpha: float = strength*tint.a
	var angle: float = 0.0 if reduced else animation.total_age*1.8
	var at: Vector2 = rect.position+animation.hand_uv()*rect.size
	var radius: float = rect.size.x*0.22*lerpf(0.55,1,strength)
	# Raised hands channel into one overhead seal; the hand seal opens on release.
	var clip: Dictionary = animation.clip_data()
	if not clip.has("channel_end") or animation.frame_number() >= clip.release:
		ring(canvas,at,radius,angle,alpha,reduced)
	if not clip.has("channel_end"): return
	var charging: bool = animation.phase in ["windup","build"]
	var charge: float = clampf(animation.total_age/2.5,0,1)
	var expansion: float = 1.0 if charging else 1.0+minf(animation.age*3,0.35)
	# Leave the fixed charge/status UI a gap between the horn tips and the overhead seal.
	var overhead: Vector2 = rect.position+Vector2(rect.size.x*0.49,-rect.size.y*0.20)
	if not reduced and charging: overhead += Vector2(sin(animation.total_age*57),cos(animation.total_age*49))*rect.size.x*(0.003+charge*0.006)
	ring(canvas,overhead,rect.size.x*lerpf(0.26,0.40,charge)*expansion,-angle*0.7,alpha,reduced)
	if animation.phase == "damage" and animation.age < 0.22:
		var burst: float = 1-animation.age/0.22
		ring(canvas,overhead,rect.size.x*(0.40+0.25*(1-burst)),angle,burst*tint.a,reduced)
