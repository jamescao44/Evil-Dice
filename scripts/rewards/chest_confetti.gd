extends RefCounted
## Each celebration is one baked sprite; cosmetic choices never touch reward randomness.
const Library = preload("res://assets/art/fx/chest_confetti/library.gd")
const LIMIT := 16
var bursts: Array[Dictionary] = []
var clock := 0.0
var rng := RandomNumberGenerator.new()
var last_variant: Dictionary = {}

func _init() -> void:
	rng.randomize()

## Remove every active sprite when the chest is replaced or closed.
func clear() -> void:
	bursts.clear()
	clock = 0.0

## Preserve the two side cannons and upper crown of the Ultra entrance.
func entrance(size: Vector2, reduced: bool) -> void:
	var scale: float = 1.25 if size.y > size.x else 1.0
	var cannon := "light_cannon" if reduced else "cannon"
	var bloom_clip := "light_bloom" if reduced else "bloom"
	_spawn(cannon,size*Vector2(0.08,0.66),scale,false,"entrance")
	_spawn(cannon,size*Vector2(0.92,0.66),scale,true,"entrance")
	_spawn(bloom_clip,size*Vector2(0.5,0.28),scale,rng.randf()<0.5,"entrance")

## Keep random-position tap blooms responsive without constructing individual particles.
func bloom(size: Vector2, reduced: bool) -> void:
	var at := size*Vector2(rng.randf_range(0.14,0.86),rng.randf_range(0.22,0.68))
	_spawn("light_bloom" if reduced else "bloom",at,1.25 if size.y>size.x else 1.0,rng.randf()<0.5,"tap")

## Celebrate each landed prize with a compact bloom scaled to its rarity.
func prize(at: Vector2, size: Vector2, reduced: bool, strength: float) -> void:
	var scale: float = (1.25 if size.y>size.x else 1.0)*lerpf(0.32,0.62,clampf(strength,0,1))
	_spawn("light_bloom" if reduced else "bloom",at,scale,rng.randf()<0.5,"prize",1.25)

## Pick a preloaded variant without repeating the previous one; bound rapid tap spam.
func _spawn(kind: String, at: Vector2, scale: float, mirror: bool, role: String, speed: float = 1.0) -> void:
	var variants: Array = Library.CLIPS[kind]
	var variant := rng.randi_range(0,variants.size()-1)
	if variants.size()>1 and variant == last_variant.get(kind,-1): variant = (variant+1)%variants.size()
	last_variant[kind] = variant
	if bursts.size() >= LIMIT: bursts.pop_front()
	bursts.append({"at":at,"born":clock,"scale":scale,"mirror":mirror,"speed":speed,"kind":kind,"variant":variant,"frames":variants[variant],"role":role})

## Advance only burst clocks and remove completed flipbooks without per-frame allocations.
func advance(delta: float) -> void:
	clock += delta
	for i in range(bursts.size()-1,-1,-1):
		if (clock-bursts[i].born)*bursts[i].speed >= Library.DURATION: bursts.remove_at(i)

## Draw one cropped atlas region per burst; shared gravity remains smooth at display FPS.
func paint(canvas: CanvasItem) -> void:
	for burst in bursts:
		var t: float = (clock-burst.born)*burst.speed
		var frame: Array = burst.frames[mini(int(t*Library.FPS),burst.frames.size()-1)]
		var region: Rect2 = frame[1]
		var origin: Vector2 = burst.at+Vector2(0,260*t*t*0.36)*burst.scale
		canvas.draw_set_transform(origin,0,Vector2(-burst.scale if burst.mirror else burst.scale,burst.scale))
		canvas.draw_texture_rect_region(Library.PAGES[frame[0]],Rect2(frame[2],region.size/Library.RESOLUTION),region)
	canvas.draw_set_transform(Vector2.ZERO)
