extends Node2D
## Cosmetic receipts for already-owned cards. Hand-picked rewards use their ceremony.
const Paint = preload("res://scripts/tarot_paint.gd")
const REVEAL_END := 0.85
const LAND_TIME := 1.35
const DURATION := 1.55
var ui
var pending: Array = []
var cards: Array = []

func _ready() -> void:
	z_as_relative = false
	z_index = 125 # Above inventory, below choices, held items and settings.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func enqueue(item: Dictionary) -> void:
	pending.append(item.duplicate())

func reset() -> void:
	pending.clear()
	cards.clear()
	queue_redraw()

func paused() -> bool:
	var b = ui.battle
	return ui.settings_open() or ui.ceremony.active() or ui.inspected >= 0 or ui.held or b.inspecting_enemy >= 0 or b.relic_ui.pickup.active or b.tarot_cast.active() or b.view_phase in ["reward","relic_reward","feeding","transition"]

func advance(delta: float) -> void:
	if cards.is_empty() and not pending.is_empty():
		var count: int = mini(3,pending.size())
		for i in range(count): cards.append({"item":pending.pop_front(),"age":-i*0.12,"slot":i,"count":count,"landed":false})
		ui.battle._sound("item/card_draw",1,-5)
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
	size *= lerpf(1,0.20,flight)*(1 if reduced else lerpf(0.65,1,appear)+sin(appear*PI)*0.1)
	return {"at":at,"size":size,"alpha":appear*(1-smoothstep(LAND_TIME-0.08,LAND_TIME,card.age)),"flight":flight}

func _process(delta: float) -> void:
	visible = not paused()
	if visible: advance(delta)
	queue_redraw()

func _draw() -> void:
	for card in cards:
		if card.age < 0: continue
		var p: Dictionary = pose(card)
		if not card.landed:
			Paint.card(self,card.item.id,p.at,p.size,0,1,0.85,p.alpha)
			if p.flight == 0:
				var label := Rect2(p.at+Vector2(-92,p.size.y/2+12),Vector2(184,64))
				Paint.panel(self,label,Color(0.06,0.06,0.08,0.9*p.alpha))
				Paint.wrap(self,ui.battle.description_font,label.grow(-6),Paint.Catalog.ITEMS[card.item.id].name,22 if ui.portrait() else 18,Color(Paint.GOLD,p.alpha),true)
		else:
			var t: float = clampf((card.age-LAND_TIME)/(DURATION-LAND_TIME),0,1)
			draw_arc(ui.icon_rect().get_center(),ui.icon_rect().size.x*0.5+(0 if ui.battle.reduced else t*18),0,TAU,40,Color(Paint.GOLD,1-t),3)
