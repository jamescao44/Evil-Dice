extends Node2D
## Keep terrain draw commands between frames; actors and UI still animate separately.
var battle
var _snapshot: Array = []
var revision: int = 0

## Place the static scenery behind the battle actors and controls.
func _ready() -> void:
	z_index = -1

## Rebuild terrain only when growth, scrolling or layout changes its appearance.
func _process(_delta: float) -> void:
	refresh()

## Compare visual inputs so wave loads, restarts and transitions invalidate scenery.
func refresh() -> void:
	var state: Array = [battle.ARENA,battle.fx.canvas_size,battle.visual_stage,battle.background_offset,battle.background_vertical_offset,battle.model.is_city()]
	if state == _snapshot: return
	_snapshot = state
	revision += 1
	queue_redraw()

## Record the stone surround and arena scenery in the current screen layout.
func _draw() -> void:
	if battle.fx.canvas_size.y > battle.fx.canvas_size.x: _draw_portrait()
	else: _draw_landscape()

## Paint the landscape paving, horizon props and distant buildings.
func _draw_landscape() -> void:
	draw_rect(battle.ARENA, Color("a5a182"))
	var tile: int = roundi(battle._stage_size(battle.PAVING_SIZES))
	var tint: Color = Color("b6b8a0").lerp(Color("c3a889"), battle.visual_stage / float(battle.Run.WAVE_NAMES.size()-1))
	var scenery_stage: float = battle.visual_stage / float(battle.Run.WAVE_NAMES.size()-1) * 4
	var city_blend: float = clampf(scenery_stage - 3, 0, 1)
	var field_blend: float = clampf((scenery_stage-1)/2.0,0,1)
	_draw_extended_ground(tile,tint)
	_draw_paving(tile,tint,field_blend)
	var prop_side: float = battle._stage_size(battle.SCENERY_SIZES)
	var prop_space: float = prop_side * 2.25
	var prop_shift: float = fposmod(battle.background_offset * 0.65, prop_space)
	var horizon: float = 180
	for row in _scenery_rows(horizon,0.65):
		for i in range(-1, ceili(battle.ARENA.size.x / prop_space)+1):
			var x: float = 24 + i * prop_space - prop_shift
			_arena_art("arch", Rect2(x, row-prop_side*0.65, prop_side, prop_side), Color(tint, (1-city_blend)*0.8))
			_arena_art("column", Rect2(x + prop_side * 1.18, row-prop_side*0.3, prop_side * 0.66, prop_side * 0.66), Color(tint, (1-city_blend)*0.8))
	var tree_shift: float = fposmod(battle.background_offset * 0.4, 420)
	for row in _scenery_rows(horizon,0.4):
		for i in range(-1, 5):
			_arena_art("mangrove", Rect2(25 + i * 420 - tree_shift, row-prop_side*0.3, prop_side, prop_side), Color("939e79"))
	if city_blend > 0:
		for tree in [Vector2(476,184),Vector2(511,213),Vector2(474,230),Vector2(1160,430),Vector2(1210,390),Vector2(1134,451)]:
			_arena_art("mangrove", Rect2(tree,Vector2(24,24)), Color(0.67,0.74,0.55,city_blend))
	if battle.visual_stage >= 1 and not battle.model.is_city():
		var building_height: float = battle._stage_size([96.0,64.0,40.0,24.0,18.0])
		for row in _scenery_rows(horizon,0.2):
			for i in range(12):
				var x: float = 42 + i * 113 - fposmod(battle.background_offset * 0.2, 113)
				_draw_building(Rect2(x, row-building_height, building_height*0.7, building_height), Color(0.7, 0.7, 0.55, minf(0.8, battle.visual_stage * 0.35)), false)
	draw_rect(battle.ARENA.grow(maxf(512,battle.ARENA.size.x)), Color(0.84, 0.85, 0.67, 0.13))

## Paint the portrait paving and compact skyline above the Horror.
func _draw_portrait() -> void:
	draw_rect(battle.ARENA, Color("a5a182"))
	var tile: int = roundi(battle._stage_size(battle.PAVING_SIZES))
	var progress: float = battle.visual_stage / float(battle.Run.WAVE_NAMES.size()-1)
	var tint: Color = Color("b6b8a0").lerp(Color("c3a889"), progress)
	var field: float = clampf((progress * 4 - 1) / 2.0, 0, 1)
	_draw_extended_ground(tile,tint)
	_draw_paving(tile,tint,field)
	var prop: float = battle._stage_size(battle.SCENERY_SIZES)
	var spacing: float = prop * 2.25
	var drift: float = fposmod(battle.background_offset * 0.65, spacing)
	for row in _scenery_rows(battle.ARENA.position.y+60,0.65):
		for i in range(-1, ceili(battle.ARENA.size.x / spacing) + 1):
			var x: float = 24 + i * spacing - drift
			_arena_art("mangrove" if battle.model.is_city() else "arch", Rect2(x, row - prop * 0.3, prop, prop), Color("939e79"))
	if battle.visual_stage >= 1 and not battle.model.is_city():
		var height: float = battle._stage_size([96.0, 64.0, 40.0, 24.0, 18.0])
		for row in _scenery_rows(battle.ARENA.position.y+104,0.2):
			for i in range(9):
				var x: float = 42 + i * 113 - fposmod(battle.background_offset * 0.2, 113)
				_draw_building(Rect2(x, row - height, height * 0.7, height), Color("a1a184"), false)
	draw_rect(battle.ARENA.grow(maxf(512,battle.ARENA.size.x)), Color(0.84, 0.85, 0.67, 0.13))

## Tile both axes so diagonal travel never exposes a blank strip or resets at arrival.
func _draw_paving(tile: int, tint: Color, field: float) -> void:
	var scroll := Vector2(battle.background_offset,battle.background_vertical_offset)
	var origin: Vector2 = battle.ARENA.position-Vector2(fposmod(scroll.x,tile),fposmod(scroll.y,tile))
	for row in range(ceili(battle.ARENA.size.y/tile)+1):
		for column in range(ceili(battle.ARENA.size.x/tile)+1):
			var at: Vector2 = origin+Vector2(column,row)*tile
			var variant: int = posmod(floori((at.x+scroll.x)/tile)+floori((at.y+scroll.y)/tile),4)
			if field < 1: _arena_art("floor%d" % variant,Rect2(at,Vector2.ONE*tile),tint)
			if field > 0: _arena_art("grass",Rect2(at,Vector2.ONE*tile),Color(0.76,0.83,0.66,field))

## Repeat bounded rows of props using each layer's existing parallax speed.
func _scenery_rows(anchor: float, parallax: float) -> Array:
	var span: float = battle.ARENA.size.y+256
	var shift: float = fposmod(battle.background_vertical_offset*parallax,span)
	return [-1,0,1,2].map(func(row): return anchor+row*span-shift)

## Clip a scenery texture to the inner battlefield without stretching it.
func _arena_art(key: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var clipped: Rect2 = rect.intersection(battle.ARENA.grow(256))
	if not clipped.has_area(): return
	var ratio: Vector2 = Vector2(battle.art[key].get_size()) / rect.size
	draw_texture_rect_region(battle.art[key], clipped, Rect2((clipped.position - rect.position) * ratio, clipped.size * ratio), tint)

## Draw a distant house with cropped roof tiles and windows.
func _draw_building(rect: Rect2, tint: Color, ruined: bool) -> void:
	if ruined:
		_arena_art("column", Rect2(rect.position.x, rect.end.y - 24, rect.size.x, 28), tint)
		return
	_arena_art("stone", rect, tint)
	var roof: Rect2 = Rect2(rect.position - Vector2(4, 12), Vector2(rect.size.x + 8, 20)).intersection(battle.ARENA.grow(256))
	if roof.has_area():
		draw_rect(roof, Color("785752") * tint)
		for x in range(int(roof.position.x), int(roof.end.x), 12):
			draw_rect(Rect2(x, roof.position.y, minf(6, roof.end.x - x), 6), Color("c09c79") * tint)
	for y in range(int(rect.position.y + 16), int(rect.end.y - 12), 24):
		for x in range(int(rect.position.x + 12), int(rect.end.x - 8), 22):
			var window := Rect2(x, y, 8, 12).intersection(battle.ARENA.grow(256))
			if window.has_area(): draw_rect(window, Color("e2ba69") * tint)


## Extend the paving under the camera pan with one repeated texture, avoiding blank edges.
func _draw_extended_ground(tile: float, tint: Color) -> void:
	var scale_factor: float = tile/32.0
	var bounds: Rect2 = battle.ARENA.grow(maxf(512,battle.ARENA.size.x))
	var origin: Vector2 = battle.ARENA.position-Vector2(fposmod(battle.background_offset,tile),fposmod(battle.background_vertical_offset,tile))
	var tiled := Rect2((bounds.position-origin)/scale_factor,bounds.size/scale_factor)
	var field: float = clampf((battle.visual_stage/float(battle.Run.WAVE_NAMES.size()-1)*4-1)/2,0,1)
	draw_set_transform(origin,0,Vector2.ONE*scale_factor)
	draw_texture_rect(battle.art.floor0,tiled,true,tint)
	if field > 0: draw_texture_rect(battle.art.grass,tiled,true,Color(0.76,0.83,0.66,field))
	draw_set_transform(Vector2.ZERO)
