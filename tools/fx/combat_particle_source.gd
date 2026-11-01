extends RefCounted
## Offline-only particle recipes. Bake these; never simulate them in the battle renderer.
const Embers = preload("res://scripts/effects/flame_particles.gd")
const FPS := 60.0
const COLORS := [Color("ff3d08"),Color("ff640a"),Color("ff8d16"),Color("ffb82c")]
var particles: Array = []
var recipe: Dictionary = {}

## Small emission packets retain natural births and dying tails when a spell stops.
static func recipes() -> Array:
	var result: Array = []
	for layer in range(3):
		result.append({"name":"ring_orbit_%d" % layer,"kind":"orbit","layer":layer,"duration":4.0,"bounds":Rect2(-64,-64,128,128),"resolution":0.5,"loop":true,"count":24})
	result.append({"name":"ring_outward","kind":"outward","duration":2.0,"bounds":Rect2(-80,-80,160,160),"resolution":0.5,"loop":true,"count":8})
	for light in [false,true]:
		var prefix: String = "light_" if light else ""
		for variant in range(3 if not light else 1):
			result.append({"name":prefix+"storm_%d" % variant,"kind":"storm","duration":1.05,"interval":0.35,"bounds":Rect2(-190,-190,380,285),"resolution":0.5,"loop":false,"count":3 if light else 84,"seed":501+variant*117})
		for variant in range(2 if not light else 1):
			result.append({"name":prefix+"beam_%d" % variant,"kind":"beam","duration":1.55,"interval":0.4,"bounds":Rect2(-310,-340,620,380),"resolution":0.4,"loop":false,"count":4 if light else 80,"seed":803+variant*193})
		for kind in ["fire_burst","match_burst"]:
			result.append({"name":prefix+kind,"kind":kind,"duration":0.6,"bounds":Rect2(-140,-175,280,315),"resolution":0.5,"loop":false,"count":16 if light else (80 if kind == "fire_burst" else 112)})
		result.append({"name":prefix+"fountain","kind":"fountain","duration":2.0,"bounds":Rect2(-72,-210,144,230),"resolution":0.5,"loop":true,"count":10 if light else 72})
	return result

## Freeze cosmetic seeds once for reproducible atlases and comparisons.
func prepare(spec: Dictionary) -> void:
	recipe = spec
	particles.clear()
	if spec.kind not in ["storm","beam"]: return
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.seed
	for i in range(spec.count):
		var p := {"born":i*spec.interval/spec.count}
		if spec.kind == "storm":
			p.life = rng.randf_range(0.35,0.7)
			p.at = Vector2(rng.randf_range(-66,66),rng.randf_range(-90,58))
			p.v = Vector2((-1 if p.at.x < 0 else 1)*rng.randf_range(85,145),rng.randf_range(-80,-35))
			p.size = rng.randi_range(2,4)
			p.color = Color("ff480a").lerp(Color("ffb82c"),rng.randf())
		else:
			p.life = rng.randf_range(0.65,1.15)
			p.at = Vector2(rng.randf_range(-270,270),rng.randf_range(-6,2))
			p.v = Vector2(rng.randf_range(-18,18),rng.randf_range(-220,-110))
			p.size = rng.randi_range(6,12)
			p.color = [Color("ff4b0b"),Color("ff7012"),Color("ff9b20"),Color("ffd350")][rng.randi_range(0,3)]
		particles.append(p)

## Sample periodic fields analytically, so the wrap has the same motion as any frame.
func paint(canvas: CanvasItem, age: float) -> void:
	match recipe.kind:
		"orbit":
			for i in range(recipe.count):
				var id: int = i*3+recipe.layer
				var angle: float = id*2.399963
				var radius: float = 128*(0.38+fposmod(id*0.017,0.08))
				var at := Vector2.from_angle(angle)*radius
				var size: float = 128*(0.009+0.006*(id%3))
				var alpha: float = 0.45+0.20*sin(age*TAU/recipe.duration+id*1.7)
				var color: Color = COLORS[id%4]
				canvas.draw_rect(Rect2(at-Vector2.ONE*size,Vector2.ONE*size*2),Color(color,alpha*0.18))
				canvas.draw_rect(Rect2(at-Vector2.ONE*size*0.5,Vector2.ONE*size),Color(color,alpha))
		"outward":
			for i in range(recipe.count):
				# Integer cycles and transparent birth/death remove the restart seam.
				var phase: float = fposmod(age*3.0/recipe.duration+i*0.618034,1)
				var dir := Vector2.from_angle(i*2.399963)
				var velocity := dir*12.8-Vector2(0,7.68)
				Embers.cinder(canvas,dir*54+velocity*phase,velocity,1.2+0.8*(i%3),COLORS[i%4],0.65*sin(phase*PI))
		"storm", "beam":
			for p in particles:
				var t: float = age-p.born
				if t < 0 or t >= p.life: continue
				var acceleration := Vector2(0,-32 if recipe.kind == "storm" else -50)
				var at: Vector2 = p.at+p.v*t+acceleration*t*t*0.5
				var velocity: Vector2 = p.v+acceleration*t
				var alpha: float = minf(1,(p.life-t)*4)*minf(1,t*24)
				if recipe.kind == "storm":
					Embers.cinder(canvas,at,velocity,p.size,p.color,alpha)
				else:
					canvas.draw_line(at-velocity.normalized()*p.size*1.4,at,Color(p.color,alpha*0.3),p.size*0.6,false)
					canvas.draw_rect(Rect2(at-Vector2.ONE*p.size,Vector2.ONE*p.size*2),Color(p.color,alpha*0.15))
					canvas.draw_rect(Rect2(at-Vector2.ONE*p.size*0.5,Vector2.ONE*p.size),Color(p.color,alpha))
		"fire_burst", "match_burst":
			Embers.explosion(canvas,Vector2.ZERO,age/recipe.duration,recipe.count,100 if recipe.kind == "fire_burst" else 120,Color("ff9e40"),1,recipe.kind == "fire_burst")
		"fountain":
			for i in range(recipe.count):
				var phase: float = fposmod(age*(2+i%2)/recipe.duration+i*0.618034,1)
				var at := Vector2(sin(i*2.4)*50+sin(age*TAU/recipe.duration+i)*8*phase,-phase*190)
				Embers.spark(canvas,at,2.0+i%4,Color("ffd275"),sin(phase*PI)*(1-phase*0.4))
