extends Node2D
## Pending tarot badges and consumption feedback; all effect state stays in TarotEffects.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const PURPLE := Color("bd75ff")
const LIGHT := Color("f1dfff")
const ICON = preload("res://assets/art/tarot/indicator.png")
var icon_region: Rect2
var inspection: Node2D
var battle
var effects
var pops: Array = []
var arrivals: Dictionary = {}
var queued_roll: Array = []
var held_roll: Array = []
var waves: Array = []
var star_roll := false
var age := 0.0

func _ready() -> void:
	z_index = BattleLayers.STATUS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_region = Rect2(ICON.get_image().get_used_rect())
	inspection = preload("res://scripts/status/effect_inspection.gd").new()
	inspection.feedback = self
	inspection.battle = battle
	add_child(inspection)
	bind_effects()

## Reconnect after a run reset without leaving listeners on the discarded rules object.
func bind_effects() -> void:
	if effects == battle.model.tarot_effects: return
	if effects != null and effects.effect_applied.is_connected(_applied): effects.effect_applied.disconnect(_applied)
	effects = battle.model.tarot_effects
	effects.effect_applied.connect(_applied)

func reset() -> void:
	arrivals.clear()
	pops.clear(); queued_roll.clear(); held_roll.clear(); waves.clear(); star_roll = false
	if is_instance_valid(inspection):
		inspection.close()
		inspection.swallow_release = false
	for die in battle.dice: die.tarot_glow = 0
	bind_effects()

func portrait() -> bool: return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Keep the centered card silhouettes above the roll label and away from the dice.
func roll_center(slot: int, count: int) -> Vector2:
	return battle.DICE_CENTER+Vector2((slot-(count-1)*0.5)*(42 if portrait() else 28),-82 if portrait() else -50)

func indicator_center(id: String, lane: String) -> Vector2:
	var items: Array = effects.active_indicators(lane)
	var slot: int = items.find_custom(func(item): return item.id == id)
	if lane == "skill": return battle._player_effect_center(battle._active_statuses().size()+maxi(0,slot),battle._active_statuses().size()+items.size())
	return roll_center(maxi(0,slot),maxi(1,items.size()))

## Throw badges pop on landing; skill badges pop when their strength is actually locked in.
func _applied(id: String, lane: String) -> void:
	arrivals.erase(id)
	var pop := {"id":id,"at":indicator_center(id,"skill" if lane == "skill" else "roll"),"age":0.0,"lane":lane,"count":1}
	if lane == "roll":
		if queued_roll.is_empty(): held_roll = effects.active_indicators("roll")
		if not held_roll.any(func(item): return item.id == id): held_roll.append({"id":id,"count":1})
		var slot: int = held_roll.find_custom(func(item): return item.id == id)
		pop.at = roll_center(slot,held_roll.size())
		pop.count = held_roll[slot].count
		queued_roll.append(pop)
	else:
		var items: Array = effects.active_indicators("skill" if lane == "skill" else "roll")
		for item in items:
			if item.id == id: pop.count = item.count
		pops.append(pop)

## Affected physical dice alone receive the traveling post-roll glow.
func roll_landed(indices: Array) -> void:
	if queued_roll.is_empty(): return
	pops.append_array(queued_roll)
	queued_roll.clear()
	held_roll.clear()
	waves.append({"age":0.0,"indices":indices.duplicate(),"touched":[]})

func shown() -> bool:
	# Stage changes never remove active effects; higher pages cover them naturally.
	return is_instance_valid(battle)

func _process(delta: float) -> void:
	bind_effects()
	# Victory/defeat is drawn on the battle canvas; its backdrop must cover these badges.
	z_index = BattleLayers.BACKDROP if battle.view_phase == "over" else BattleLayers.STATUS
	if battle.view_phase == "over" and inspection.opened: inspection.close()
	visible = shown()
	if not visible: return
	age += 0 if battle._menus_open() else delta
	if battle._menus_open(): queue_redraw(); return
	for pop in pops: pop.age += delta
	pops = pops.filter(func(pop): return pop.age < 0.48)
	for wave in waves:
		wave.age += delta
		var radius: float = battle.DICE_RADIUS*minf(1,wave.age/0.48)
		for index in wave.indices:
			if index in wave.touched or battle.dice[index].rolling: continue
			if battle.dice[index].position.distance_to(battle.DICE_CENTER) <= radius:
				battle.dice[index].tarot_glow = 1.0
				wave.touched.append(index)
	waves = waves.filter(func(wave): return wave.age < 0.65)
	queue_redraw()

## A small rounded backing is also shared by the Star meter outline.
static func glow_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(5)
	return box

## Single stacks need only the icon; larger counts use white digits over a dark outline.
func paint_card(at: Vector2, alpha: float = 1.0, scale_factor: float = 1.0, count: int = 1, tint: Color = Color.WHITE) -> void:
	var height: float = (40 if portrait() else 28)*scale_factor
	var size := Vector2(height*icon_region.size.x/icon_region.size.y,height)
	var rect := Rect2(at-size/2,size)
	var pulse: float = 1 if battle.reduced else 0.86+sin(age*4)*0.14
	for layer in range(6,0,-1):
		draw_texture_rect_region(ICON,rect.grow(layer*2.2),icon_region,Color(PURPLE,(0.065+0.025*(6-layer))*alpha*pulse)*tint)
	draw_texture_rect_region(ICON,rect,icon_region,Color(Color.WHITE,alpha)*tint)
	if count <= 1: return
	var font: Font = battle.fx.font
	var point_size: int = roundi((22 if portrait() else 16)*scale_factor)
	var value := str(count)
	while point_size > 9 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x > size.x-4: point_size -= 1
	var width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x
	var baseline := at+Vector2(-width/2,(font.get_ascent(point_size)-font.get_descent(point_size))/2)
	draw_string_outline(font,baseline.round()+Vector2(0,1),value,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,4,Color(Color.BLACK,alpha*0.95)*tint)
	draw_string(font,baseline.round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,Color(Color.WHITE,alpha)*tint)

## Tiny deterministic sparks avoid allocating particles or touching gameplay randomness.
func paint_sparks(at: Vector2, seed: float, tint: Color) -> void:
	if battle.reduced: return
	for index in range(5):
		var t: float = fposmod(age*0.7+index*0.2+seed,1.0)
		var x: float = sin(index*5.7+seed)*22+sin(t*4+index)*5
		var point := at+Vector2(x,22-t*62)*(1.0 if portrait() else 0.7)
		var alpha: float = sin(t*PI)*0.8
		draw_rect(Rect2(point.round()-Vector2.ONE*3,Vector2.ONE*6),Color(PURPLE,alpha*0.3)*tint)
		draw_rect(Rect2(point.round()-Vector2.ONE,Vector2.ONE*2),Color(LIGHT,alpha)*tint)

## Use the same unavailable-state tint as the dice, without dimming battlefield badges.
func roll_tint() -> Color:
	return battle._dice_area_tint()

## Hide only the arriving addition; existing stacks remain visible until delivery.
func begin_arrival(id: String, previous: Dictionary) -> String:
	for lane in ["skill","roll"]:
		for item in effects.active_indicators(lane):
			if item.id == id:
				arrivals[id] = int(previous.get(id,0))
				return lane
	return ""

## Reveal the current live count, never restoring an already consumed effect.
func finish_arrival(id: String, lane: String) -> void:
	if not arrivals.has(id): return
	arrivals.erase(id)
	for item in effects.active_indicators(lane):
		if item.id == id:
			pops.append({"id":id,"at":indicator_center(id,lane),"age":0.0,"lane":lane,"count":item.count})

## Hold a committed roll's badges until its dice land, including their tap targets.
func displayed_indicators(lane: String) -> Array:
	var items: Array = (held_roll if lane == "roll" and not held_roll.is_empty() else effects.active_indicators(lane)).duplicate(true)
	for item in items:
		if arrivals.has(item.id): item.count = mini(item.count,arrivals[item.id])
	return items.filter(func(item): return item.count > 0)

## Keep hit testing and drawing on the same centered, generously tappable rectangles.
func badge_at(point: Vector2) -> Dictionary:
	for lane in ["skill","roll"]:
		if lane == "roll" and battle.tarot_ui.inventory_visible(): continue
		var items: Array = displayed_indicators(lane)
		for index in range(items.size()):
			var at: Vector2 = roll_center(index,items.size()) if lane == "roll" else indicator_center(items[index].id,lane)
			var size := Vector2(40,58) if portrait() else Vector2(27,40)
			if Rect2(at-size/2,size).has_point(point): return items[index].merged({"lane":lane})
	return {}

func _draw() -> void:
	if effects == null or not shown(): return
	battle._draw_statuses(self)
	var roll_visible: bool = not battle.tarot_ui.inventory_visible()
	for lane in ["skill","roll"]:
		if lane == "roll" and not roll_visible: continue
		var items: Array = displayed_indicators(lane)
		for index in range(items.size()):
			var item: Dictionary = items[index]
			var at: Vector2 = roll_center(index,items.size()) if lane == "roll" else indicator_center(item.id,lane)
			var tint: Color = roll_tint() if lane == "roll" else Color.WHITE
			paint_sparks(at,float(item.id.hash()%100)/100,tint)
			paint_card(at,1.0,1.0,item.count,tint)
	for pop in pops:
		if pop.lane != "skill" and not roll_visible: continue
		var t: float = pop.age/0.48
		paint_card(pop.at,1-t,1+sin(t*PI)*0.45,pop.get("count",1),roll_tint() if pop.lane != "skill" else Color.WHITE)
		if not battle.reduced:
			for i in range(8):
				var point: Vector2 = pop.at+Vector2.from_angle(i*TAU/8)*(12+40*t)
				draw_rect(Rect2(point-Vector2.ONE*2,Vector2.ONE*4),Color(LIGHT,1-t))
	if not roll_visible: return
	for wave in waves:
		var progress: float = minf(1,wave.age/0.48)
		var alpha: float = clampf((0.65-wave.age)/0.25,0,1)
		var radius: float = battle.DICE_RADIUS*progress
		for layer in range(3,0,-1): Pixel.circle(self,battle.DICE_CENTER,maxf(2,radius-layer*5),Color(PURPLE,alpha*0.12),4)
		Pixel.circle(self,battle.DICE_CENTER,maxf(2,radius),Color(LIGHT,alpha*0.6),3)
