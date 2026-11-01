extends RefCounted
## Authored burn deaths, independent of damage, loot and normal corpse fragments.
const SHEET = preload("res://assets/art/enemies/deaths/dusted.png")
const CELL := 48
const FRAMES := 11
const HOLD := 0.5
const FPS := 12.0
const FIRST_BOUNDS := Rect2(8,4,28,41)
var bodies: Dictionary = {}
var source_bounds: Dictionary = {}

## Match the first silhouette's visible height and sole position to the defeated sprite.
func spawn(index: int, enemy: Dictionary, sprite: Rect2, texture: Texture2D) -> bool:
	if enemy.get("boss",false) or enemy.get("death_source","") not in ["burn","fire_storm","brimstone"]: return false
	if bodies.has(index): return true
	var key: int = texture.get_instance_id()
	if not source_bounds.has(key):
		var image: Image = texture.get_image()
		if image.is_compressed(): image.decompress()
		source_bounds[key] = Rect2(image.get_used_rect())
	var bounds: Rect2 = source_bounds[key]
	var ratio: Vector2 = sprite.size/Vector2(texture.get_size())
	var visible := Rect2(sprite.position+bounds.position*ratio,bounds.size*ratio)
	var scale_factor: float = visible.size.y/FIRST_BOUNDS.size.y
	var origin := Vector2(visible.get_center().x-FIRST_BOUNDS.get_center().x*scale_factor,visible.end.y-FIRST_BOUNDS.end.y*scale_factor)
	bodies[index] = {"rect":Rect2(origin,Vector2.ONE*CELL*scale_factor),"wait":HOLD,"age":0.0,"playing":false,"done":false}
	return true

## Hold until the attack sequence stops, then wait half a second before dissolving.
func advance(delta: float, attacking: bool) -> void:
	for body in bodies.values():
		if body.done: continue
		if not body.playing:
			if attacking: body.wait = HOLD; continue
			body.wait -= delta
			if body.wait > 0: continue
			body.playing = true
			body.age = -body.wait
		else: body.age += delta
		body.done = body.age >= (FRAMES-1)/FPS

## The first cell remains static; all following cells play once at twelve frames per second.
func frame(index: int) -> int:
	var body: Dictionary = bodies[index]
	return mini(FRAMES-1,1+floori(body.age*FPS)) if body.playing else 0

## Draw in the dead enemy's normal world layer with one fixed, foot-aligned rectangle.
func draw(canvas: CanvasItem, index: int) -> void:
	var body: Dictionary = bodies[index]
	if body.done: return
	canvas.draw_texture_rect_region(SHEET,body.rect,Rect2(frame(index)*CELL,0,CELL,CELL))

## Let the last death finish before replacing the battlefield with wave rewards.
func active() -> bool:
	return bodies.values().any(func(body): return not body.done)

## Restart and wave transitions remove every visual without touching saved progress.
func clear() -> void:
	bodies.clear()
