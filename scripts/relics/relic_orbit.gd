extends RefCounted
## Cosmetic relic satellites share inventory artwork and activation timing, never input or rules.
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Glow = preload("res://scripts/shared/item_glow.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const PERIOD := 24.0
const ICON_SCALE := 1.0
const BOB_PERIOD := 1.5

## Keep the orbit grounded on the resting form, with front/back depth around the actor.
static func poses(battle) -> Array:
	var result: Array = []
	var items: Array = battle.model.relics.items.duplicate()
	# A consumed Contract finishes its flash in its original place before disappearing.
	for id in battle.relic_ui.activations:
		var pulse: Dictionary = battle.relic_ui.activations[id]
		if not battle.model.relics.has(id) and pulse.has("item"):
			items.insert(clampi(pulse.slot,0,items.size()),pulse.item)
	if items.is_empty(): return result
	var radius: float = battle.relic_ui.battle_icon_radius()*ICON_SCALE
	# Preserve the orbital spacing when changing decorative icon size.
	var spacing: float = battle.relic_ui.battle_icon_radius()*2.0
	var sprite := Rect2(battle._player_world_feet()-Vector2(battle.monster_side*0.5,battle.monster_side),Vector2.ONE*battle.monster_side)
	var visible: Rect2 = battle.evolution.visible_rect(sprite)
	var center: Vector2 = visible.position+visible.size*Vector2(0.5,0.45)
	var edge_space: float = minf(center.x-battle.ARENA.position.x,battle.ARENA.end.x-center.x)-spacing-12
	var horizontal: float = minf(maxf(visible.size.x*0.65+spacing*0.8,spacing*2.25),maxf(spacing,edge_space))
	var vertical: float = maxf(visible.size.y*0.24,spacing*0.85)
	var time: float = battle.relic_ui.ready_clock
	for slot in range(items.size()):
		var item: Dictionary = items[slot]
		if battle.relic_ui.pickup.active and not battle.relic_ui.pickup.landed and battle.relic_ui.pickup.slot == battle.model.relics.index_of(item.id): continue
		var angle: float = -PI/2+TAU*slot/items.size()+(0.0 if battle.reduced else time*TAU/PERIOD)
		var depth: float = sin(angle)
		var strength: float = battle.relic_ui.activation_strength(item.id)
		var bounce: float = 0 if battle.reduced else strength*radius*0.40
		var float_y: float = 0 if battle.reduced else sin(time*TAU/BOB_PERIOD-slot*0.55)*(3.0 if battle.relic_ui.portrait() else 2.0)
		result.append({"item":item,"slot":slot,"depth":depth,"at":center+Vector2(cos(angle)*horizontal,depth*vertical+float_y-bounce),"radius":radius,"strength":strength})
	result.sort_custom(func(a,b): return a.slot < b.slot if is_equal_approx(a.depth,b.depth) else a.depth < b.depth)
	return result

## Draw the rear half before the character and the front half before character UI.
static func paint(canvas: CanvasItem, battle, entries: Array, front: bool) -> void:
	for pose in entries:
		if (pose.depth >= 0 or pose.strength > 0) != front: continue
		var item: Dictionary = pose.item
		var strength: float = pose.strength
		var radius: float = pose.radius*(1.0 if battle.reduced else 1.0+strength*0.14)
		var color: Color = Catalog.rarity_color(item.id).lightened(0.2)
		if strength > 0:
			Glow.paint(canvas,pose.at,radius*1.25,color,Rect2(),strength)
			canvas.draw_arc(pose.at,radius*(1.04+0.18*strength),0,TAU,32,Color(color,strength*0.8),2)
			for i in range(4):
				var spark: Vector2 = pose.at+Vector2.from_angle(i*TAU/4+PI/4)*(radius*(1.0+strength*0.4))
				canvas.draw_line(spark-Vector2(3,0),spark+Vector2(3,0),Color(1,0.96,0.82,strength),2)
				canvas.draw_line(spark-Vector2(0,3),spark+Vector2(0,3),Color(1,0.96,0.82,strength),2)
		canvas.draw_set_transform(pose.at,battle.relic_ui.activation_tilt(item.id))
		Paint.silhouette_glow(canvas,item.id,Vector2.ZERO,radius,Catalog.rarity_color(item.id),item,strength)
		Paint.paint(canvas,item.id,Vector2.ZERO,radius,false,item)
		canvas.draw_set_transform(Vector2.ZERO)
