extends RefCounted
## Offline source for the confetti bake and its performance comparison; never used by gameplay.
const COLORS := [Color("ffd45c"),Color("ff8a42"),Color("ff5e97"),Color("b885ff"),Color("68dce5"),Color("fff1b9")]
const LIMIT := 1400
var particles: Array = []
var clock := 0.0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func clear() -> void:
	particles.clear()
	clock = 0.0

## Fire broad cannons from both sides and a crown of confetti across the upper screen.
func entrance(size: Vector2, reduced: bool) -> void:
	burst(size*Vector2(0.08,0.66),size,24 if reduced else 180,-0.95,0.6)
	burst(size*Vector2(0.92,0.66),size,24 if reduced else 180,-PI+0.95,0.6)
	burst(size*Vector2(0.5,0.28),size,18 if reduced else 120,-PI/2,PI)

## Every tap creates one bloom at a fresh screen position, independent of the pointer.
func bloom(size: Vector2, reduced: bool) -> void:
	var at := size*Vector2(rng.randf_range(0.14,0.86),rng.randf_range(0.22,0.68))
	burst(at,size,18 if reduced else 120,-PI/2,PI)

## Seed tumbling ribbons with varied sizes and lifetimes; cap rapid repeated taps.
func burst(at: Vector2, size: Vector2, count: int, direction: float, spread: float) -> void:
	var scale: float = 1.25 if size.y > size.x else 1.0
	for i in range(count):
		var velocity := Vector2.from_angle(direction+rng.randf_range(-spread,spread))*rng.randf_range(230,620)*scale
		particles.append({"at":at,"v":velocity,"born":clock,"life":rng.randf_range(2.8,4.4),"size":Vector2(rng.randf_range(6,12)*(2.2 if i%5 == 0 else 1.0),rng.randf_range(4,8))*scale,"angle":rng.randf()*TAU,"spin":rng.randf_range(-7,7),"flutter":rng.randf_range(5,11),"phase":rng.randf()*TAU,"color":COLORS[rng.randi_range(0,COLORS.size()-1)],"gravity":260*scale})
	if particles.size() > LIMIT: particles = particles.slice(particles.size()-LIMIT)

func advance(delta: float) -> void:
	clock += delta
	particles = particles.filter(func(p): return clock-p.born < p.life)

## Draw solid colored paper with tumbling faces, lateral flutter and a gentle fall.
func paint(canvas: CanvasItem) -> void:
	for p in particles:
		var t: float = clock-p.born
		var drift: float = (1-exp(-t*0.85))/0.85
		var at: Vector2 = p.at+p.v*drift+Vector2(sin(t*3+p.phase)*t*14,p.gravity*t*t*0.36)
		var extent: Vector2 = p.size*Vector2(maxf(0.16,absf(cos(t*p.flutter+p.phase))),1)
		var angle: float = p.angle+t*p.spin
		var points := PackedVector2Array()
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			points.append(at+(corner*extent*0.5).rotated(angle))
		var color: Color = p.color.lightened(maxf(0,sin(t*p.flutter+p.phase))*0.18)
		color.a = minf(1,(p.life-t)/0.7)
		canvas.draw_colored_polygon(points,color)
