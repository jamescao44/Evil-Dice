extends Node2D
## Always-accessible menu shortcut and input barrier above gameplay pages.
var battle
var swallow_release := false
var paused_transition: Tween

## Only system pages pause an underlying reward or inventory page.
func active() -> bool:
	return battle.menu_open or battle.guide or battle.debug_open

## Route system controls first, preserving the current gameplay transaction.
func click(point: Vector2) -> bool:
	if active():
		battle._handle_menu_page_click(point)
	elif battle.MENU_RECT.has_point(point):
		battle._update_charge()
		battle.focus_mark.cancel()
		battle.inventory_page.cancel_drag()
		battle.shop_ui.cancel_drag()
		battle.relic_ui.cancel_hold()
		battle.tarot_ui.cancel_gesture()
		battle.tarot_ui.ceremony.cancel_gesture()
		battle.tarot_quick.cancel_gesture()
		battle._cancel_enemy_hold()
		if battle.dice_selection.dragging: battle.dice_selection.cancel_gesture()
		if battle.skill_pressed: battle._cancel_targeting()
		battle.menu_open = true
	else:
		return false
	swallow_release = true
	sync_pause()
	return true

## A close-button release must not click through into cards, dice or rewards.
func take_release() -> bool:
	var consumed := swallow_release or active()
	swallow_release = false
	return consumed

## Hold route movement and chest timing without discarding their progress.
func sync_pause() -> void:
	if active():
		var transition: Tween = battle.transition_tween
		if transition and transition.is_valid() and transition.is_running():
			transition.pause()
			paused_transition = transition
	elif paused_transition:
		if paused_transition.is_valid(): paused_transition.play()
		paused_transition = null
	battle.chest.paused = active() or battle.tarot_ui.ceremony.active()
	battle.chest._sync_audio()
	battle.menu_canvas.visible = active()
	battle.menu_canvas.queue_redraw()

## Keep the shortcut above inspection, inventory and reward screens.
func _process(_delta: float) -> void:
	sync_pause()
	visible = not active()
	queue_redraw()

func _draw() -> void:
	battle._button(battle.MENU_RECT,"",true,self)
	battle._draw_menu_icon(self)
