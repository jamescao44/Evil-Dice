extends RefCounted
## Pixel geometry shared by status icons, ice shells and elite attribute auras.
const Pixel = preload("res://scripts/pixel_paint.gd")

static func star(node: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		points.append((at+Vector2.from_angle(-PI/2+i*PI/5)*radius*(1.0 if i%2==0 else 0.43)).snapped(Vector2.ONE*2))
	node.draw_colored_polygon(points,color)

static func icon(node: CanvasItem, at: Vector2, radius: float, type: String, color: Color) -> void:
	if type == "stars":
		star(node,at,radius,color)
	elif type == "ice":
		for i in range(6):
			var d := Vector2.from_angle(i*TAU/6)
			Pixel.line(node,at,at+d*radius,color,3)
			for flip in [-1,1]: Pixel.line(node,at+d*radius*0.65,at+d*radius*0.42+d.orthogonal()*radius*0.23*flip,color,2)
	else:
		var points := PackedVector2Array([at+Vector2(-radius*0.8,radius*0.4),at+Vector2(-radius*0.6,-radius*0.5),at+Vector2(-radius*0.2,-radius*0.15),at+Vector2(radius*0.3,-radius),at+Vector2(radius*0.8,radius*0.15),at+Vector2(radius*0.5,radius),at+Vector2(-radius*0.4,radius)])
		node.draw_colored_polygon(points,color)
		Pixel.disc(node,at+Vector2(0,radius*0.45),radius*0.32,Color("ffe7a3"),2)

static func intent_icon(node: CanvasItem, at: Vector2, radius: float, type: String, color: Color) -> void:
	if type == "sword":
		var tip := at+Vector2(radius*0.7,-radius*0.8)
		var hilt := at+Vector2(-radius*0.5,radius*0.5)
		Pixel.line(node,hilt,tip,color,maxf(3,radius*0.3))
		Pixel.line(node,at+Vector2(-radius*0.7,0),at+Vector2(0,radius*0.7),color,3)
		Pixel.line(node,hilt,at+Vector2(-radius*0.85,radius*0.85),color,3)
	elif type == "plus":
		Pixel.line(node,at-Vector2(radius*0.75,0),at+Vector2(radius*0.75,0),color,maxf(4,radius*0.4))
		Pixel.line(node,at-Vector2(0,radius*0.75),at+Vector2(0,radius*0.75),color,maxf(4,radius*0.4))
	elif type == "shield":
		var points := PackedVector2Array([at+Vector2(-radius*0.7,-radius*0.7),at+Vector2(radius*0.7,-radius*0.7),at+Vector2(radius*0.55,radius*0.35),at+Vector2(0,radius*0.9),at+Vector2(-radius*0.55,radius*0.35)])
		node.draw_colored_polygon(points,color)
		Pixel.line(node,at-Vector2(0,radius*0.4),at+Vector2(0,radius*0.45),Color("344639"),2)
	elif type == "boost":
		Pixel.line(node,at+Vector2(0,radius*0.8),at-Vector2(0,radius*0.8),color,4)
		Pixel.line(node,at-Vector2(0,radius*0.8),at+Vector2(-radius*0.65,0),color,3)
		Pixel.line(node,at-Vector2(0,radius*0.8),at+Vector2(radius*0.65,0),color,3)
	else:
		for flip in [-1,1]: Pixel.line(node,at+Vector2(-radius*0.6,radius*0.6*flip),at+Vector2(radius*0.6,-radius*0.6*flip),color,3)

static func ice(node: CanvasItem, rect: Rect2, strong: bool = false, cracks: int = 0) -> void:
	var a := rect.position
	var s := rect.size
	var points := PackedVector2Array([a+Vector2(s.x*0.13,0),a+Vector2(s.x*0.78,0),a+Vector2(s.x,s.y*0.18),a+Vector2(s.x*0.93,s.y),a+Vector2(s.x*0.1,s.y),a+Vector2(0,s.y*0.22)])
	node.draw_colored_polygon(points,Color(0.36,0.75,0.95,0.33 if strong else 0.23))
	for i in range(points.size()): Pixel.line(node,points[i],points[(i+1)%points.size()],Color("b9f2ff"),3)
	Pixel.line(node,points[0],a+Vector2(s.x*0.34,s.y*0.55),Color(0.85,0.98,1,0.8),3)
	Pixel.line(node,a+Vector2(s.x*0.34,s.y*0.55),points[3],Color(0.65,0.9,1,0.65),3)
	Pixel.line(node,points[1],a+Vector2(s.x*0.67,s.y*0.72),Color(0.85,0.98,1,0.65),3)
	Pixel.line(node,a+Vector2(s.x*0.07,s.y*0.7),a+Vector2(s.x*0.84,s.y*0.19),Color(0.87,0.99,1,0.4),maxf(4,s.x*0.045))
	for hit in range(cracks):
		var origin: Vector2 = a+s*Vector2(0.42+hit*0.18,0.42+hit*0.16)
		for ray in range(5):
			var direction := Vector2.from_angle(ray*TAU/5+hit*0.7)
			var bend: Vector2 = origin+direction*s.x*0.14
			Pixel.line(node,origin,bend,Color("e2fcff"),4)
			Pixel.line(node,bend,bend+direction.rotated(0.5)*s.x*0.19,Color("e2fcff"),3)

static func aura(node: CanvasItem, feet: Vector2, side: float, color: Color, clock: float, reduced: bool) -> void:
	var radius: float = maxf(22,side*0.53)
	var height: float = maxf(40,side*1.22)
	var pulse: float = 1.0 if reduced else 0.9+sin(clock*2.4)*0.1
	for layer in range(8):
		var y: float = float(layer)/8
		node.draw_rect(Rect2(feet-Vector2(radius,height*y+height/8),Vector2(radius*2,height/8)),Color(color,(1-y)*0.17*pulse))
	for i in range(9):
		var angle: float = i*PI/8
		var base := feet+Vector2(cos(angle)*radius,sin(angle)*radius*0.24)
		Pixel.line(node,base,base-Vector2(0,height),Color(color,0.28*pulse),maxf(2,side*0.035))
	for edge in [-1,1]:
		Pixel.line(node,feet+Vector2(radius*edge,0),feet+Vector2(radius*edge,-height),Color(color,0.62*pulse),2)
	for ring in range(2):
		ellipse(node,feet,radius+ring*4,Color(color,(0.9-ring*0.4)*pulse))
	ellipse(node,feet-Vector2(0,height),radius,Color(color,0.28*pulse))
	for i in range(5):
		var rise: float = 0.5 if reduced else fposmod(clock*0.45+i*0.21,1.0)
		var x: float = cos(i*2.4)*radius
		Pixel.line(node,feet+Vector2(x,-rise*height),feet+Vector2(x,-rise*height-8),Color(color,(1-rise)*0.75),2)

static func ellipse(node: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	for i in range(32):
		var a := Vector2.from_angle(i*TAU/32)*radius
		var b := Vector2.from_angle((i+1)*TAU/32)*radius
		a.y *= 0.24
		b.y *= 0.24
		Pixel.line(node,center+a,center+b,color,2)

static func orbiting_stars(node: CanvasItem, center: Vector2, side: float, clock: float, reduced: bool) -> void:
	for i in range(4):
		var angle: float = i*TAU/4+(0 if reduced else clock*2.2)
		var at := center+Vector2(cos(angle)*side*0.28,sin(angle)*side*0.065)
		star(node,at,maxf(5,side*0.045),Color("ffe388"))
