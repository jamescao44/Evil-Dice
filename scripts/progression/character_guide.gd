extends RefCounted
## Browse character forms in Help without changing the run's evolution or skill state.
var battle
var selected_form := 0
const FORM_LEVELS := [1,5,10]

## Open the guide on the currently earned form; later milestones reuse the final art.
func select_current() -> void:
	selected_form = clampi(battle.model.character_evolution_stage(),0,2)

func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Keep large form selectors separate from Help navigation and the skill list.
func option_rect(index: int) -> Rect2:
	return Rect2(282+index*158,548,144,62) if portrait() else Rect2(360+index*190,218,172,40)

func hit(point: Vector2) -> bool:
	for i in range(3):
		if option_rect(i).has_point(point): return true
	return false

## Consume only preview taps; no gameplay level, charge or damage is modified.
func click(point: Vector2) -> bool:
	for i in range(3):
		if option_rect(i).has_point(point):
			selected_form = i
			battle._sound("ui/book",1.2,-19)
			return true
	return false

func entries(straights: bool) -> Array:
	return battle.Rules.Patterns.help_entries(straights,selected_form)

func passive_text() -> String:
	return "Every 3 straight skills cast 2 bonus Fireballs at random enemies; each reusing the triggering skill’s total damage." if selected_form >= 2 else "Every 3 Fireballs cast 2 bonus Fireballs at random enemies; each reusing the triggering skill’s total damage."

## Paint a fitted sprite, three form choices and the selected form's passive rule.
func paint(canvas: CanvasItem) -> void:
	var phone := portrait()
	var frame := Rect2(62,536,180,220) if phone else Rect2(144,206,170,142)
	var texture: Texture2D = battle.evolution.forms[selected_form]
	var bounds: Rect2 = battle.evolution.visible_bounds[selected_form]
	var source := Rect2(bounds.position*Vector2(texture.get_size()),bounds.size*Vector2(texture.get_size()))
	var scale_factor: float = minf(frame.size.x/source.size.x,frame.size.y/source.size.y)
	var size: Vector2 = source.size*scale_factor
	canvas.draw_texture_rect_region(texture,Rect2(frame.get_center()-size/2,size),source)
	for i in range(3):
		var rect := option_rect(i)
		battle._button(rect,GameText.format("FORM %d",i+1),true,canvas)
		if i == selected_form: canvas.draw_rect(rect.grow(-3),battle.GOLD,false,3)
		battle._center(Vector2(rect.get_center().x,rect.end.y+(30 if phone else 24)),GameText.format("LV. %d",FORM_LEVELS[i]),24 if phone else 18,battle.GOLD if i == selected_form else battle.MUTED,canvas)
	battle._wrapped(Vector2(282,686) if phone else Vector2(360,312),passive_text(),476 if phone else 780,battle.CREAM,24 if phone else 18,canvas)
