extends Node2D
## Read-only active-effect details, shared by tarot badges and player statuses.
const Cards = preload("res://scripts/tarot/tarot_paint.gd")
const Statuses = preload("res://scripts/status/status_catalog.gd")
const StatusPaint = preload("res://scripts/status/status_paint.gd")
const TAROT_REMAINING := {
	"strength":"%d stacks · next skill",
	"high_priestess":"%d stacks · this turn",
	"lovers":"%d throw remaining",
	"devil":"%d stacks · next throw",
	"star":"%d throws remaining",
	"temperance":"%d rolls · next turn",
}
var battle
var feedback
var opened := false
var swallow_release := false
var status_id := -1
var selected_card := ""

func _ready() -> void:
	z_as_relative = false
	z_index = BattleLayers.EFFECT_INSPECTION
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Cards.soften(self)

## Full-page interfaces own their own taps; exposed battlefield stages keep inspection.
func available() -> bool:
	return not battle._menus_open() and battle.inspecting_enemy < 0 and battle.view_phase not in ["shop","reward","over"] and not battle.tarot_cast.active() and battle.tarot_ui.inspected < 0 and not battle.skill_pressed and not battle.dice_selection.dragging and not battle.focus_mark.dragging

func hit(point: Vector2) -> bool:
	if opened: return true
	if not available(): return false
	if not feedback.badge_at(point).is_empty(): return true
	return battle._active_statuses().any(func(item): return battle._status_rect(item.id).has_point(point))

## Read live pending effects, retaining committed throw badges only until landing.
func rows() -> Array:
	if status_id >= 0:
		return battle._active_statuses().filter(func(item): return item.id == status_id)
	var items: Array = feedback.displayed_indicators("skill")+feedback.displayed_indicators("roll")
	return items

func portrait() -> bool: return feedback.portrait()

func panel_rect() -> Rect2:
	var width: float = 644 if portrait() else 520
	var height: float = (132 if portrait() else 106)+rows().size()*(110 if portrait() else 78)
	if status_id >= 0:
		var detail: String = battle._status_description(status_id,battle.model.status_count(status_id))
		height += GameText.lines(detail,battle.description_font,26 if portrait() else 20,width-48).size()*(34 if portrait() else 26)+26
	var size := Vector2(width,height)
	return Rect2((battle.fx.canvas_size-size)/2,size)

func close_rect() -> Rect2:
	var panel := panel_rect()
	var side: float = 52 if portrait() else 38
	return Rect2(panel.end.x-side-12,panel.position.y+12,side,side)

## Mark already committed throw effects without claiming they still await the next roll.
func remaining_text(item: Dictionary) -> String:
	if feedback.queued_roll.any(func(pop): return pop.id == item.id): return GameText.text("Applying this throw")
	return GameText.format(TAROT_REMAINING[item.id],item.count)

## Consume opening/closing presses before reward controls, frozen input, or dice gestures.
func click(point: Vector2) -> bool:
	if opened:
		swallow_release = true
		if not panel_rect().has_point(point) or close_rect().has_point(point): close()
		return true
	if not hit(point): return false
	var badge: Dictionary = feedback.badge_at(point)
	selected_card = badge.get("id","")
	status_id = -1
	if badge.is_empty():
		for item in battle._active_statuses():
			if battle._status_rect(item.id).has_point(point): status_id = item.id; break
	opened = true
	swallow_release = true
	battle._cancel_enemy_hold()
	battle.relic_ui.cancel_hold()
	battle.tarot_ui.cancel_gesture()
	battle._sound("ui/book",1,-20)
	queue_redraw()
	return true

func close() -> void:
	opened = false
	status_id = -1
	selected_card = ""
	queue_redraw()

## The touch release that opened or closed details must never reach the controls below.
func release() -> bool:
	if swallow_release:
		swallow_release = false
		return true
	return opened

func _process(_delta: float) -> void:
	if opened and rows().is_empty(): close()
	queue_redraw()

func _draw() -> void:
	if not opened: return
	var panel := panel_rect()
	var font: Font = battle.description_font
	var size: int = 28 if portrait() else 22
	var inset: float = 24
	var step: float = 110 if portrait() else 78
	draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color(0.02,0.015,0.04,0.78))
	Cards.panel(self,panel,Color("24212f"),Color("ad79d6"),16)
	Cards.text(self,font,panel.position+Vector2(inset,48 if portrait() else 38),"ACTIVE TAROT" if status_id < 0 else "STATUS EFFECT",size,battle.CREAM,false)
	var close := close_rect().get_center()
	draw_line(close-Vector2(8,8),close+Vector2(8,8),battle.CREAM,3)
	draw_line(close+Vector2(-8,8),close+Vector2(8,-8),battle.CREAM,3)
	var y: float = panel.position.y+(106 if portrait() else 84)
	for item in rows():
		var center := Vector2(panel.position.x+56,y+10)
		if status_id < 0:
			if item.id == selected_card: Cards.panel(self,Rect2(panel.position.x+12,y-step*0.38,panel.size.x-24,step-8),Color("393044"))
			# Reuse the normal card art and desaturation while keeping text independent.
			var card_size := Vector2(39,60) if portrait() else Vector2(29,45)
			draw_texture_rect(Cards.texture(item.id),Rect2(center-card_size/2,card_size),false)
			Cards.text(self,font,Vector2(panel.position.x+104,y),Cards.Catalog.ITEMS[item.id].name,size,battle.CREAM,false)
			Cards.text(self,font,Vector2(panel.position.x+104,y+(36 if portrait() else 28)),remaining_text(item),size-4,Color("d4b8ed"),false)
		else:
			StatusPaint.icon(self,center,22 if portrait() else 16,item.icon,item.color)
			Cards.text(self,font,Vector2(panel.position.x+104,y),item.name,size,item.color,false)
			var remaining: String = GameText.remaining(item.turns,"throw") if item.id == battle.Status.STUNNED else Statuses.counter_text(item)
			Cards.text(self,font,Vector2(panel.position.x+104,y+(36 if portrait() else 28)),remaining,size-4,battle.CREAM,false)
		y += step
	if status_id >= 0:
		Cards.wrap(self,font,Rect2(panel.position.x+inset,y-24,panel.size.x-inset*2,panel.end.y-y),battle._status_description(status_id,battle.model.status_count(status_id)),26 if portrait() else 20,battle.CREAM)
