extends SceneTree
## Compare repeated terrain against the former per-tile renderer, including diagonal travel.
const Backdrop = preload("res://scripts/combat/battle_backdrop.gd")
class Terrain extends RefCounted:
	var ARENA := Rect2(13,17,280,210)
	var background_offset := 0.0
	var background_vertical_offset := 0.0
	var art: Dictionary = {}
class Batched extends Backdrop:
	var tile := 16
	var field := 0.0
	func _process(_delta: float) -> void: pass
	func _draw() -> void: _draw_paving(tile,Color("b6b8a0"),field)
class Original extends Batched:
	func _draw_paving(cell: int, tint: Color, grass: float) -> void:
		var scroll := Vector2(battle.background_offset,battle.background_vertical_offset)
		var origin: Vector2 = battle.ARENA.position-Vector2(fposmod(scroll.x,cell),fposmod(scroll.y,cell))
		for row in range(ceili(battle.ARENA.size.y/cell)+1):
			for column in range(ceili(battle.ARENA.size.x/cell)+1):
				var at: Vector2 = origin+Vector2(column,row)*cell
				var variant: int = posmod(floori((at.x+scroll.x)/cell)+floori((at.y+scroll.y)/cell),4)
				if grass < 1: _arena_art("floor%d" % variant,Rect2(at,Vector2.ONE*cell),tint)
				if grass > 0: _arena_art("grass",Rect2(at,Vector2.ONE*cell),Color(0.76,0.83,0.66,grass))
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func viewport_for(node: Node2D) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(320,256)
	view.transparent_bg = true
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view); view.add_child(node)
	return view

## Separate quads can choose opposite texels exactly at a nearest-sampling boundary.
func same_tiles(before: Image, after: Image, origin: Vector2, tile: int) -> bool:
	if before.get_data() == after.get_data(): return true
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if a == b: continue
			var source: Vector2 = (Vector2(x+0.5,y+0.5)-origin)*32.0/tile
			var boundary: bool = absf(source.x-roundf(source.x)) < 0.0001 or absf(source.y-roundf(source.y)) < 0.0001
			if a.a != b.a or not boundary: return false
	return true
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Terrain comparison requires rendering"); quit(1); return
	var terrain := Terrain.new()
	for key in ["floor0","floor1","floor2","floor3","grass"]:
		terrain.art[key] = load("res://assets/art/fantasy/"+key+".png")
	var original := Original.new(); original.battle = terrain
	var batched := Batched.new(); batched.battle = terrain
	var old_view := viewport_for(original); var new_view := viewport_for(batched)
	var pattern: Texture2D
	for cell in [16,31,96]:
		for scroll in [Vector2.ZERO,Vector2(57.5,-33.25),Vector2(511,713)]:
			terrain.background_offset = scroll.x; terrain.background_vertical_offset = scroll.y
			for blend in [0.0,0.7,1.0]:
				original.tile = cell; batched.tile = cell
				original.field = blend; batched.field = blend
				original.queue_redraw(); batched.queue_redraw()
				await process_frame; await RenderingServer.frame_post_draw
				var before: Image = old_view.get_texture().get_image()
				var after: Image = new_view.get_texture().get_image()
				var origin: Vector2 = terrain.ARENA.position-Vector2(fposmod(scroll.x,cell),fposmod(scroll.y,cell))
				var equal: bool = same_tiles(before,after,origin,cell)
				check(equal,"Terrain preserves tile artwork and alignment: tile=%d scroll=%s blend=%.1f" % [cell,scroll,blend])
				if cell == 16: check(before.get_data() == after.get_data(),"Late-wave paving remains pixel-identical")
				if not equal:
					before.save_png("/tmp/terrain-original.png"); after.save_png("/tmp/terrain-batched.png")
					quit(1); return
				if pattern == null: pattern = batched._paving_pattern()
				check(pattern == batched._paving_pattern(),"Growth and scroll reuse the same small texture")
	old_view.queue_free(); new_view.queue_free(); await process_frame
	print("Terrain batching: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
