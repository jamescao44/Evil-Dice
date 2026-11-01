extends Node2D
## Cosmetic receipts for already-owned cards. Hand-picked rewards use their ceremony.
const Paint = preload("res://scripts/tarot/tarot_paint.gd")
const REVEAL_END := 0.85
const LAND_TIME := 1.35
const DURATION := 1.55
const DROP_REVEAL_TIME := 0.28
var ui
var pending: Array = []
var cards: Array = []
var grid_key: Array = []
var grid_cache: Dictionary = {}
var drops = preload("res://scripts/tarot/enemy_tarot_drop.gd").new()

func _ready() -> void:
	z_as_relative = false
	z_index = BattleLayers.TAROT_PICKUP # Above inventory, below choices, held items and settings.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drops.ui = ui
	add_child(drops)

func enqueue(item: Dictionary) -> void:
	if item.has("enemy_index"):
		drops.enqueue(item)
		return
	pending.append(item.duplicate())

func reset() -> void:
	pending.clear()
	cards.clear()
	drops.reset()
	queue_redraw()

## Keep the wave-clear transition behind every queued receipt, including simultaneous kills.
func active() -> bool:
	return not pending.is_empty() or not cards.is_empty() or not drops.cards.is_empty()

func paused() -> bool:
	var b = ui.battle
	return ui.settings_open() or ui.ceremony.active() or ui.inspected >= 0 or ui.held or b.inspecting_enemy >= 0 or b.relic_ui.pickup.active or b.tarot_cast.active() or b.view_phase in ["reward","wave_reward","transition"]

func advance(delta: float) -> void:
	drops.advance(delta)
	var batch: Array = pending.map(func(item): return {"item":item})
	pending.clear()
	batch.append_array(drops.take_ready(drops.cards.size()))
	for card in batch:
		card.merge({"age":0.0,"landed":false})
		cards.append(card)
	if not batch.is_empty(): ui.battle._sound("item/card_draw",1,-5)
	var landed := false
	for card in cards:
		card.age += delta
		if card.age >= LAND_TIME and not card.landed:
			card.landed = true
			landed = true
	if landed: ui.battle._sound("item/confirmation_002",1,-18)
	cards = cards.filter(func(card): return card.age < DURATION)
	for i in range(cards.size()):
		cards[i].slot = i
		cards[i].count = cards.size()

## Fit the whole receipt into a centered grid instead of waiting through groups of three.
func grid(count: int) -> Dictionary:
	var key: Array = [count,ui.battle.fx.canvas_size]
	if key == grid_key: return grid_cache
	grid_key = key
	var portrait: bool = ui.portrait()
	var base := Vector2(146,226) if portrait else Vector2(112,174)
	var area := Rect2(44,360,ui.battle.fx.canvas_size.x-88,1000) if portrait else Rect2(100,100,ui.battle.fx.canvas_size.x-200,590)
	var step := base+Vector2(34,100)
	var columns := 1
	var best := 0.0
	for candidate in range(1,maxi(1,count)+1):
		var rows: int = ceili(float(count)/candidate)
		var extent := Vector2(candidate*step.x-34,rows*step.y-24)
		var scale: float = minf(1.0,minf(area.size.x/extent.x,area.size.y/extent.y))
		if scale > best:
			best = scale; columns = candidate
	grid_cache = {"area":area,"columns":columns,"rows":ceili(float(count)/columns),"scale":best,"step":step*best,"size":base*best}
	return grid_cache

func receipt_center(card: Dictionary, layout: Dictionary) -> Vector2:
	var row: int = card.slot/layout.columns
	var col: int = card.slot%layout.columns
	var in_row: int = mini(layout.columns,card.count-row*layout.columns)
	var extent: float = layout.rows*layout.step.y-24*layout.scale
	return Vector2(layout.area.get_center().x+(col-(in_row-1)*0.5)*layout.step.x,layout.area.get_center().y-extent/2+row*layout.step.y+layout.size.y/2)

func pose(card: Dictionary) -> Dictionary:
	var reduced: bool = ui.battle.reduced
	var target: Vector2 = ui.icon_rect().get_center()
	var layout: Dictionary = grid(card.count)
	var origin: Vector2 = receipt_center(card,layout)
	var flight: float = smoothstep(REVEAL_END,LAND_TIME,card.age)
	var at: Vector2 = origin.lerp(target,flight)
	if not reduced: at.y -= sin(flight*PI)*65
	var appear: float = smoothstep(0,0.22,card.age)
	var size: Vector2 = layout.size
	var angle: float = 0
	if card.has("from"):
		# Lift the original body drop into a readable upright card before inventory flight.
		appear = smoothstep(0,DROP_REVEAL_TIME,card.age)
		if flight == 0: at = card.from.lerp(origin,appear)
		size = card.from_size.lerp(size,appear)*lerpf(1,0.20,flight)
		angle = lerp_angle(card.from_angle,0,appear) if not reduced else 0.0
	else:
		size *= lerpf(1,0.20,flight)*(1 if reduced else lerpf(0.65,1,appear)+sin(appear*PI)*0.1)
	return {"at":at,"size":size,"angle":angle,"alpha":(1.0 if card.has("from") else appear)*(1-smoothstep(LAND_TIME-0.08,LAND_TIME,card.age)),"flight":flight,"reveal":appear,"layout_scale":layout.scale}

## Keep each localized name beneath its card without overlapping adjacent receipts.
func name_rect(p: Dictionary) -> Rect2:
	var width: float = p.size.x+24*p.layout_scale
	return Rect2(p.at+Vector2(-width/2,p.size.y/2+12*p.layout_scale),Vector2(width,64*p.layout_scale))

## Shrink long localized names just enough to retain every line in a dense receipt.
func name_size(item: Dictionary, p: Dictionary) -> int:
	var rect: Rect2 = name_rect(p).grow(-6*p.layout_scale)
	var size: int = maxi(8,roundi((22 if ui.portrait() else 18)*p.layout_scale))
	var value: String = GameText.text(Paint.Catalog.ITEMS[item.id].name)
	while size > 8 and GameText.lines(value,ui.battle.description_font,size,rect.size.x).size()*size*1.3 > rect.size.y: size -= 1
	return size

func _process(delta: float) -> void:
	visible = not paused()
	if visible: advance(delta)
	queue_redraw()

func _draw() -> void:
	var ring_time := -1.0
	for card in cards:
		if card.age < 0: continue
		var p: Dictionary = pose(card)
		if not card.landed:
			Paint.card(self,card.item.id,p.at,p.size,p.angle,1,0.85,p.alpha)
			if p.flight == 0 and p.reveal >= 0.99:
				var label: Rect2 = name_rect(p)
				Paint.panel(self,label,Color(0.06,0.06,0.08,0.9*p.alpha))
				Paint.wrap(self,ui.battle.description_font,label.grow(-6*p.layout_scale),Paint.Catalog.ITEMS[card.item.id].name,name_size(card.item,p),Color(Paint.GOLD,p.alpha),true)
		else:
			ring_time = maxf(ring_time,clampf((card.age-LAND_TIME)/(DURATION-LAND_TIME),0,1))
	if ring_time >= 0:
		draw_arc(ui.icon_rect().get_center(),ui.icon_rect().size.x*0.5+(0 if ui.battle.reduced else ring_time*18),0,TAU,40,Color(Paint.GOLD,1-ring_time),3)
