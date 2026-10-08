extends RefCounted
## A whole fortified settlement, built from the existing public stone/grass tiles
## and pixel geometry. Map coordinates make the surrounding wall unambiguous.
const Pixel = preload("res://scripts/pixel_paint.gd")
const ORIGIN := Vector2(892, 182)
const U := Vector2(30, 11)
const V := Vector2(-33, 12)
const INK := Color("34372e")
const STONE := Color("aaa38b")
const LIGHT := Color("c7c0a1")
const SHADE := Color("737b6e")
const CENTER := Vector2(885, 300)
const RADIUS := Vector2(315, 112)
const GATE_SECTION := 12

static func point(u: float, v: float) -> Vector2:
	return (ORIGIN + U * u + V * v).snapped(Vector2.ONE * 2)

static func wall_point(section: float) -> Vector2:
	var angle: float = section * TAU / 32
	return (CENTER + Vector2(cos(angle),sin(angle)) * RADIUS).snapped(Vector2.ONE * 2)

static func gate_point() -> Vector2:
	return wall_point(GATE_SECTION + 0.5)

static func house_layout() -> Array:
	var houses: Array = []
	for row in range(10):
		for col in range(20):
			var foot := Vector2(600+col*29+(row%2)*14,214+row*19)
			if ((foot-CENTER)/Vector2(285,94)).length_squared() > 0.94: continue
			if foot.x > 750 and foot.x < 925 and foot.y < 299: continue # Castle hill.
			if absf(foot.x-895) < 25 and foot.y > 280: continue # Market street.
			if ((foot-Vector2(927,328))/Vector2(47,24)).length_squared() < 1: continue
			houses.append({"p": foot, "id": col * 17 + row * 31})
	houses.sort_custom(func(a, b): return a.p.y < b.p.y)
	return houses

static func house_ruined(id: int, remaining: float) -> bool:
	return remaining < 0.08 + (id % 23) * 0.037

static func paint(c: CanvasItem, art: Dictionary, remaining: float, clock: float, residents: Array = [], houses: Array = [], reduced: bool = false, layout_transform: Transform2D = Transform2D.IDENTITY) -> void:
	c.draw_set_transform_matrix(layout_transform)
	var corners := PackedVector2Array()
	var verge := PackedVector2Array()
	var moat := PackedVector2Array()
	for i in range(32):
		corners.append(wall_point(i))
		verge.append(CENTER + (wall_point(i) - CENTER) * 1.035)
		moat.append(CENTER + (wall_point(i) - CENTER) * Vector2(1.085,1.2))
	# A double verge and a pale road separate the city from the surrounding fields.
	c.draw_colored_polygon(moat, Color("698f89"))
	for i in range(32):
		Pixel.line(c, moat[i], moat[(i+1)%32], Color("a9b9a0"), 3)
	c.draw_colored_polygon(verge, Color("626e55"))
	c.draw_colored_polygon(corners, Color("a7aa83"))
	c.draw_colored_polygon(PackedVector2Array([gate_point()-Vector2(14,3), gate_point()+Vector2(14,3), Vector2(510,421), Vector2(450,421)]), Color("b9ab87"))
	_bridge(c, gate_point(), gate_point() + (gate_point()-CENTER).normalized()*52)
	_bridge(c, wall_point(0), wall_point(0)+Vector2(46,0))
	for lane in [4.5, 7.5]:
		Pixel.line(c, point(lane,0.5), point(lane,9.6), Color("c1b391"), 8)
		Pixel.line(c, point(0.5,lane), point(9.6,lane), Color("c1b391"), 8)
	# Back walls first; buildings occlude their lower sections.
	for i in range(16,32): _wall(c, wall_point(i), wall_point(i+1), remaining, i)
	for i in range(16,32,2):
		_tower(c, art, wall_point(i), remaining > 0.12 + (i % 5) * 0.08, clock)
	# Depth-ordered timber houses and terracotta roofs leave two crossing roads.
	var objects: Array = (house_layout() if houses.is_empty() else houses).duplicate()
	objects.append({"p": Vector2(836,278), "keep": true})
	for person in residents: objects.append({"p": person.p, "resident": person})
	objects.sort_custom(func(a,b): return a.p.y < b.p.y)
	for object in objects:
		if object.has("resident"): _resident(c, art, object.resident, clock, reduced, layout_transform)
		elif object.has("keep"): _keep(c, art, object.p, remaining, clock)
		else: _house(c, object.p, object.id, house_ruined(object.id, remaining))
	# The near curtain walls enclose the roofs, with a gate facing the Horror.
	for i in range(16):
		if i != GATE_SECTION: _wall(c, wall_point(i), wall_point(i+1), remaining, i)
	for i in range(0,16,2):
		if i != GATE_SECTION: _tower(c, art, wall_point(i), remaining > 0.1 + (i % 5) * 0.1, clock)
	_gate(c, art, gate_point(), remaining, clock)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _resident(c: CanvasItem, art: Dictionary, person: Dictionary, clock: float, reduced: bool, layout_transform: Transform2D) -> void:
	var alpha: float = clampf((person.life-person.age)/2.0,0,1)
	var stride: float = clock * 18 + person.phase
	var hop: float = 0 if reduced else snappedf(absf(sin(stride))*2,1)
	var lean: float = 0 if reduced else sin(stride)*0.18
	Pixel.disc(c, person.p, 4, Color(INK,0.28*alpha),2,0.3)
	c.draw_set_transform_matrix(layout_transform * Transform2D(lean, Vector2(person.facing,1), 0, (person.p-Vector2(0,hop)).round()))
	c.draw_texture_rect(art[person.art],Rect2(-8,-16,16,16),false,Color(1,1,1,alpha))
	c.draw_set_transform_matrix(layout_transform)
	# A brief pixel panic mark makes their reaction legible at city scale.
	if person.age < 2.0 or fposmod(person.age+person.phase,3.0) < 0.5:
		var at: Vector2 = (person.p-Vector2(0,22+hop)).round()
		c.draw_rect(Rect2(at-Vector2(2,1),Vector2(5,9)),Color(INK,alpha))
		c.draw_rect(Rect2(at,Vector2(2,4)),Color("f3d6a0")*Color(1,1,1,alpha))
		c.draw_rect(Rect2(at+Vector2(0,6),Vector2(2,2)),Color("f3d6a0")*Color(1,1,1,alpha))

static func _wall(c: CanvasItem, a: Vector2, b: Vector2, remaining: float, section: int) -> void:
	var rubble: bool = remaining < 0.12 + ((section * 3) % 9) * 0.075
	var height: float = 6 if rubble else 25
	var top := Vector2(0, height)
	c.draw_colored_polygon(PackedVector2Array([a,b,b-top,a-top]), SHADE if rubble else STONE)
	Pixel.line(c, a-top, b-top, LIGHT, 3)
	Pixel.line(c, a, b, INK, 2)
	for y in range(6, int(height), 6):
		Pixel.line(c, a-Vector2(0,y), b-Vector2(0,y), Color("8b8e79"), 2)
		var seam := a.lerp(b, 0.65 if y % 12 else 0.35) - Vector2(0,y)
		Pixel.line(c, seam, seam + Vector2(0,5), Color("8b8e79"), 2)
	for k in range(3):
		var merlon: Vector2 = a.lerp(b, (k + 0.2) / 3.0) - top
		c.draw_rect(Rect2(merlon + Vector2(-2,-5), Vector2(6,7)), LIGHT if not rubble else SHADE)

static func _tower(c: CanvasItem, art: Dictionary, foot: Vector2, intact: bool, clock: float, width: float = 22, height: float = 34) -> void:
	if not intact:
		c.draw_texture_rect(art.column, Rect2(foot - Vector2(width * 0.6,10), Vector2(width * 1.2,14)), false, Color("969582"))
		return
	var rect := Rect2(foot - Vector2(width / 2,height), Vector2(width,height))
	c.draw_rect(rect.grow(2), INK)
	c.draw_texture_rect(art.stone, rect, false, Color("c8c6a9"))
	c.draw_rect(rect, Color(0.82,0.71,0.49,0.27))
	c.draw_rect(Rect2(rect.position, Vector2(width * 0.3,height)), Color(0.3,0.38,0.32,0.4))
	c.draw_rect(Rect2(rect.position-Vector2(2,3), Vector2(width+4,6)), LIGHT)
	var tip := Vector2(foot.x, rect.position.y-width*0.75)
	c.draw_colored_polygon(PackedVector2Array([rect.position-Vector2(4,0),tip,rect.position+Vector2(width+4,0)]),Color("666275"))
	Pixel.line(c,rect.position-Vector2(4,0),tip,Color("a3a092"),2)
	Pixel.line(c,tip,rect.position+Vector2(width+4,0),Color("4d535d"),2)
	c.draw_rect(Rect2(rect.get_center().x-2, rect.position.y+12, 4,9), INK)
	if width > 25:
		Pixel.line(c, tip, tip-Vector2(0,15), INK, 2)
		c.draw_colored_polygon(PackedVector2Array([tip-Vector2(0,15), tip+Vector2(14,-13+snappedf(sin(clock*3+foot.x)*2,1)), tip+Vector2(0,-7)]), Color("a65f61"))

static func _house(c: CanvasItem, foot: Vector2, id: int, ruined: bool) -> void:
	var width: float = 10 + id % 3 * 2
	var height: float = 11 + id % 4 * 2
	if ruined:
		for i in range(4):
			c.draw_rect(Rect2(foot+Vector2(-10+i*5,(i%2)*3-4), Vector2(6,4)), SHADE if i % 2 else Color("947365"))
		return
	var a := foot + Vector2(-width,-5)
	var b := foot + Vector2(2,2)
	var d := foot + Vector2(width+4,-5)
	var lift := Vector2(0,height)
	c.draw_colored_polygon(PackedVector2Array([a,b,b-lift,a-lift]), Color("dbc7a0"))
	c.draw_colored_polygon(PackedVector2Array([b,d,d-lift,b-lift]), Color("a19679"))
	for edge in [[a,b],[b,d],[a,a-lift],[b,b-lift],[d,d-lift],[a-Vector2(0,6),b-Vector2(0,6)]]:
		Pixel.line(c, edge[0], edge[1], Color("62594a"), 2)
	c.draw_rect(Rect2(b-Vector2(1,9),Vector2(4,9)), INK)
	c.draw_rect(Rect2(a+Vector2(4,-7),Vector2(3,4)), Color("f1d796"))
	var roof: Color = [Color("965d50"), Color("a97352"), Color("757f78"), Color("b48a5f")][id % 4]
	var peak := foot + Vector2(-3,-height-15)
	var far := peak + Vector2(width+6,-5)
	var right := d-lift+Vector2(4,1)
	var left := a-lift-Vector2(3,0)
	c.draw_colored_polygon(PackedVector2Array([left,peak,far,right,b-lift+Vector2(1,2)]), roof)
	Pixel.line(c, peak, far, roof.lightened(0.35), 2)
	Pixel.line(c, peak, left, roof.lightened(0.2), 2)
	Pixel.line(c, b-lift+Vector2(1,2), right, roof.darkened(0.35), 2)
	for i in range(1,4):
		Pixel.line(c, peak.lerp(b-lift, i/4.0), far.lerp(right, i/4.0), roof.darkened(0.14), 2)
	if id % 4 == 0:
		c.draw_rect(Rect2(far+Vector2(-6,-8),Vector2(4,11)), STONE)

static func _keep(c: CanvasItem, art: Dictionary, foot: Vector2, remaining: float, clock: float) -> void:
	Pixel.disc(c, foot+Vector2(0,10), 92, Color("7e8d62"), 4, 0.4)
	Pixel.disc(c, foot+Vector2(0,5), 79, Color("b6b38d"), 4, 0.35)
	if remaining <= 0.12:
		for x in [-26,0,26]: _tower(c,art,foot+Vector2(x,0),false,clock,28,52)
		return
	_tower(c,art,foot+Vector2(-12,-16),remaining>0.2,clock,30,84)
	var rect := Rect2(foot-Vector2(32,60),Vector2(64,60))
	c.draw_rect(rect.grow(2), INK)
	c.draw_texture_rect(art.stone,rect,false,Color("cacbb7"))
	c.draw_rect(rect, Color(0.86,0.75,0.53,0.3))
	c.draw_colored_polygon(PackedVector2Array([rect.position-Vector2(5,0),rect.position+Vector2(32,-24),rect.position+Vector2(69,0)]),Color("665c6b"))
	for x in [-14,0,14]:
		c.draw_rect(Rect2(foot+Vector2(x-2,-42),Vector2(4,10)),Color("e4c68b"))
	_tower(c,art,foot+Vector2(-43,2),remaining>0.23,clock,28,62)
	_tower(c,art,foot+Vector2(40,4),remaining>0.36,clock,28,68)
	_wall(c,foot+Vector2(-57,16),foot+Vector2(55,22),remaining,7)
	_tower(c,art,foot+Vector2(-52,19),remaining>0.26,clock,24,38)
	_tower(c,art,foot+Vector2(47,24),remaining>0.16,clock,24,38)
	c.draw_rect(Rect2(foot-Vector2(5,17),Vector2(10,18)),INK)

static func _bridge(c: CanvasItem, start: Vector2, end: Vector2) -> void:
	var normal: Vector2 = (end-start).orthogonal().normalized()*11
	c.draw_colored_polygon(PackedVector2Array([start-normal,start+normal,end+normal,end-normal]),LIGHT)
	for side in [-1,1]:
		Pixel.line(c,start+normal*side,end+normal*side,SHADE,4)
		for i in range(4):
			c.draw_rect(Rect2(start.lerp(end,i/3.0)+normal*side-Vector2(2,6),Vector2(4,8)),STONE)

static func _gate(c: CanvasItem, art: Dictionary, foot: Vector2, remaining: float, clock: float) -> void:
	if remaining <= 0.05: return
	var lintel := Rect2(foot-Vector2(19,27),Vector2(38,9))
	c.draw_rect(lintel, LIGHT)
	c.draw_rect(Rect2(foot-Vector2(14,18),Vector2(28,20)),INK)
	for x in range(-12,15,6):
		c.draw_rect(Rect2(foot+Vector2(x,-17),Vector2(2,9)),Color("61564a"))
	_tower(c,art,foot+Vector2(-23,-6),remaining>0.18,clock,26,39)
	_tower(c,art,foot+Vector2(23,8),remaining>0.3,clock,26,39)
