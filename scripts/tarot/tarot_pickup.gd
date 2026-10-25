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
var drops = preload("res://scripts/tarot/enemy_tarot_drop.gd").new()

func _ready() -> void:
	z_as_relative = false
	z_index = 125 # Above inventory, below choices, held items and settings.
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
	if cards.is_empty():
		var batch: Array = []
		for i in range(mini(3,pending.size())): batch.append({"item":pending.pop_front()})
		batch.append_array(drops.take_ready(3-batch.size()))
		for i in range(batch.size()):
			var card: Dictionary = batch[i]
			card.merge({"age":0.0 if card.has("from") else -i*0.12,"slot":i,"count":batch.size(),"landed":false})
			cards.append(card)
		if not batch.is_empty(): ui.battle._sound("item/card_draw",1,-5)
	for card in cards:
		card.age += delta
		if card.age >= LAND_TIME and not card.landed:
			card.landed = true
			ui.battle._sound("item/confirmation_002",1,-18)
	cards = cards.filter(func(card): return card.age < DURATION)

func pose(card: Dictionary) -> Dictionary:
	var portrait: bool = ui.portrait()
	var reduced: bool = ui.battle.reduced
	var target: Vector2 = ui.icon_rect().get_center()
	var origin := Vector2(ui.battle.fx.canvas_size.x/2+(card.slot-(card.count-1)/2.0)*(180 if portrait else 145),1050 if portrait else 405)
	var flight: float = smoothstep(REVEAL_END,LAND_TIME,card.age)
	var at: Vector2 = origin.lerp(target,flight)
	if not reduced: at.y -= sin(flight*PI)*65
	var appear: float = smoothstep(0,0.22,card.age)
	var size: Vector2 = Vector2(146,226) if portrait else Vector2(112,174)
	var angle: float = 0
	if card.has("from"):
		# Lift the original body drop into a readable upright card before inventory flight.
		appear = smoothstep(0,DROP_REVEAL_TIME,card.age)
		if flight == 0: at = card.from.lerp(origin,appear)
		size = card.from_size.lerp(size,appear)*lerpf(1,0.20,flight)
		angle = lerp_angle(card.from_angle,0,appear) if not reduced else 0.0
	else:
		size *= lerpf(1,0.20,flight)*(1 if reduced else lerpf(0.65,1,appear)+sin(appear*PI)*0.1)
	return {"at":at,"size":size,"angle":angle,"alpha":(1.0 if card.has("from") else appear)*(1-smoothstep(LAND_TIME-0.08,LAND_TIME,card.age)),"flight":flight,"reveal":appear}

## Keep each localized name beneath its card without overlapping adjacent receipts.
func name_rect(p: Dictionary) -> Rect2:
	var width: float = p.size.x+24
	return Rect2(p.at+Vector2(-width/2,p.size.y/2+12),Vector2(width,64))

func _process(delta: float) -> void:
	visible = not paused()
	if visible: advance(delta)
	queue_redraw()

func _draw() -> void:
	for card in cards:
		if card.age < 0: continue
		var p: Dictionary = pose(card)
		if not card.landed:
			Paint.card(self,card.item.id,p.at,p.size,p.angle,1,0.85,p.alpha)
			if p.flight == 0 and p.reveal >= 0.99:
				var label: Rect2 = name_rect(p)
				Paint.panel(self,label,Color(0.06,0.06,0.08,0.9*p.alpha))
				Paint.wrap(self,ui.battle.description_font,label.grow(-6),Paint.Catalog.ITEMS[card.item.id].name,22 if ui.portrait() else 18,Color(Paint.GOLD,p.alpha),true)
		else:
			var t: float = clampf((card.age-LAND_TIME)/(DURATION-LAND_TIME),0,1)
			draw_arc(ui.icon_rect().get_center(),ui.icon_rect().size.x*0.5+(0 if ui.battle.reduced else t*18),0,TAU,40,Color(Paint.GOLD,1-t),3)
