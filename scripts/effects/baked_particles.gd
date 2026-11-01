extends RefCounted
## Shared immutable flipbooks: one textured quad replaces an entire particle group.
const Library = preload("res://assets/art/fx/combat_particles/library.gd")

## Wrap without a duplicated endpoint; one-shot clips disappear after their last frame.
static func frame_index(clip: Dictionary, age: float) -> int:
	if age < 0 or (not clip.loop and age >= clip.duration): return -1
	var time: float = fposmod(age,clip.duration) if clip.loop else age
	return mini(clip.frames.size()-1,floori(time*Library.FPS))

## Keep the caller's transform and battlefield clip, including elliptical ring rotation.
static func paint(canvas: CanvasItem, name: String, age: float, at: Vector2 = Vector2.ZERO, scale: Vector2 = Vector2.ONE, tint: Color = Color.WHITE, rotation: float = 0.0) -> void:
	if tint.a <= 0.001: return
	var clip: Dictionary = Library.CLIPS[name]
	var index := frame_index(clip,age)
	if index < 0: return
	var frame: Array = clip.frames[index]
	var texture: Texture2D = Library.PAGES[frame[0]]
	var source: Rect2 = frame[1]
	var rect := Rect2(frame[2],source.size/clip.resolution)
	if is_zero_approx(rotation):
		canvas.draw_texture_rect_region(texture,Rect2(at+rect.position*scale,rect.size*scale),source,tint,false,true)
		return
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
		points.append(at+(rect.position+corner*rect.size).rotated(rotation)*scale)
		uvs.append((source.position+corner*source.size)/texture.get_size())
	canvas.draw_polygon(points,PackedColorArray([tint]),uvs,texture)

## Preserve the exact slow orbit continuously between baked shimmer frames.
static func ring(canvas: CanvasItem, rect: Rect2, age: float, tint: Color, reduced: bool) -> void:
	for layer in range(1 if reduced else 3):
		paint(canvas,"ring_orbit_%d" % layer,age,rect.get_center(),rect.size/128.0,tint,age*(0.18+layer*0.13))
	var outward_tint := tint
	if reduced: outward_tint.a *= 0.3
	paint(canvas,"ring_outward",age,rect.get_center(),rect.size/128.0,outward_tint,age*0.24)

## Reuse compact radial bursts at any damage scale without changing hit timing.
static func burst(canvas: CanvasItem, kind: String, at: Vector2, progress: float, scale: float, reduced: bool, alpha: float = 1.0) -> void:
	var name: String = ("light_" if reduced else "")+kind
	paint(canvas,name,progress*Library.CLIPS[name].duration,at,Vector2.ONE*scale,Color(1,1,1,alpha))
