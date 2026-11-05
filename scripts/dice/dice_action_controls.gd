extends Node2D
## V3/V4 share dice selection and batch rerolls, with different action positions.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const REROLL_COLOR := Color("70b7ff")
const END_TURN_COLOR := Color("ed8189")
var battle

func _ready() -> void:
	z_index = BattleLayers.STATUS

func phone() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Both experiments allow arbitrary unused dice for rerolling, including invalid skills.
func shared_selection() -> bool:
	return battle.debug_control_version in [battle.ControlVersion.V3,battle.ControlVersion.V4]

func side_confirms(right: bool) -> bool:
	return right and battle.debug_split_controls

## Put side actions level with the top die, away from the selection circle.
func action_center(right: bool) -> Vector2:
	if not battle.debug_split_controls: return battle._saved_slot_center()
	var offset: float = battle.DICE_CENTER.x-96 if phone() else battle.DICE_RADIUS+84
	return Vector2(battle.DICE_CENTER.x+offset*(1 if right else -1),battle.DICE_POSITIONS[0].y)

func radius() -> float:
	if not battle.debug_split_controls: return battle._saved_slot_radius()
	return 56.0 if phone() else 42.0

func action_at(point: Vector2) -> int:
	for side in range(2):
		if side == 0 and not battle.debug_split_controls: continue
		if point.distance_to(action_center(side == 1)) <= radius()+10: return side
	return -1

func actions_shown() -> bool:
	return shared_selection() and not battle._menus_open() and not battle.tarot_ui.inventory_visible() and battle.view_phase not in ["over","reward","shop","wave_reward","advancing","transition"]

## The opening throw stays in the center; empty selections pass after it lands.
func left_label() -> String:
	return "END TURN" if battle.model.dice_turn.selected.is_empty() else "REROLL"

func enabled(right: bool) -> bool:
	if not actions_shown() or not battle.dice_selection.available(): return false
	if not right and not battle.debug_split_controls: return false
	var pool = battle.model.dice_turn
	if side_confirms(right): return not battle.dice_selection.dragging and not pool.selected.is_empty() and not battle.dice_selection.preview.is_empty() and pool.skills_allowed()
	if not pool.has_rolled(): return false
	if pool.selected.is_empty(): return battle._can_end_turn()
	# Connecting dice changes the batch, but never suspends its reroll availability.
	return pool.can_reroll_dice(pool.selected)

## Expanded tarot hands and inspection retain priority over the normal battle controls.
func input_available() -> bool:
	return actions_shown() and not battle.tarot_cast.active() and not battle.tarot_ui.blocks_battle() and not battle.tarot_quick.next_open and battle.tarot_quick.field_focus < 0 and not battle.tarot_quick.held and battle.inspecting_enemy < 0

func hit(point: Vector2) -> bool:
	var side: int = action_at(point)
	return input_available() and side >= 0 and enabled(side == 1)

## Side actions are atomic: a disabled OK never passes or spends the selected dice.
func click(point: Vector2) -> bool:
	if not input_available(): return false
	var side: int = action_at(point)
	if side < 0: return false
	if not enabled(side == 1): return true
	if side_confirms(side == 1):
		battle._form_selected_skill()
		battle.dice_selection._clear_preview()
	elif battle.model.dice_turn.selected.is_empty(): battle._end_dice_turn()
	else:
		var indices: Array = battle.model.dice_turn.selected.duplicate()
		indices.sort()
		battle._reroll_dice(indices)
		battle.dice_selection.cancel_gesture()
	return true

## The compact combo badge hugs the lower-right arena corner above the health baseline.
func combo_center() -> Vector2:
	return Vector2(battle.ARENA.end.x-(92 if phone() else 78),battle.player_health_rect().position.y-(44 if phone() else 36))

func combo_radius() -> float:
	return 36.0 if phone() else 28.0

func combo_bounds() -> Rect2:
	var half := Vector2(1.55,0.62)*(combo_radius()+20)
	return Rect2(combo_center()-half,half*2)

func combo_shown() -> bool:
	return battle.debug_split_controls and battle.model.perfect_combo > 0 and not battle._menus_open() and battle.view_phase not in ["over","reward","shop"]

func _process(_delta: float) -> void:
	visible = shared_selection()
	queue_redraw()

func _draw() -> void:
	if actions_shown():
		if battle.debug_split_controls: _draw_action(false)
		_draw_action(true)
	if combo_shown(): _draw_combo()

## V1 keeps Roll and Reroll gold; other versions distinguish Reroll in blue.
func action_color(label: String, active: bool = true) -> Color:
	if not active: return battle.MUTED
	if label == "REROLL" and battle.debug_control_version != battle.ControlVersion.V1: return REROLL_COLOR
	if label == "END TURN": return END_TURN_COLOR
	return battle.GOLD

## A fixed circle and fitted text keep both languages within the side touch targets.
func _draw_action(right: bool) -> void:
	var at: Vector2 = action_center(right)
	var active: bool = enabled(right)
	var confirms: bool = side_confirms(right)
	var label: String = "OK" if confirms else left_label()
	var color: Color = action_color(label,active)
	var age: float = battle.dice_selection.end_turn_prompt_age if label == "END TURN" else 0.0
	var pop: float = battle.dice_selection.PromptPulse.scale_at(age) if active and age > 0 and not battle.reduced else 1.0
	draw_set_transform(at,0,Vector2.ONE*pop)
	Pixel.disc(self,Vector2.ZERO,radius(),Color(battle.INK,0.9),2)
	Pixel.circle(self,Vector2.ZERO,radius(),Color(color,0.95 if active else 0.35),3)
	if active: Pixel.circle(self,Vector2.ZERO,radius()+4,Color(color,0.12),3)
	var size: int = (42 if phone() else 30) if confirms else (28 if phone() else 22)
	var text: String = GameText.text(label)
	while size > 12 and battle.pixel_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > radius()*1.8: size -= 1
	battle._center(Vector2(0,size*0.32),label,size,color,self)
	draw_set_transform(Vector2.ZERO)
	if confirms or not active: return
	var caption_direction: float = -1.0 if battle.debug_split_controls else 1.0
	if label == "REROLL":
		battle._center(at+Vector2(0,(radius()+(16 if battle.debug_split_controls else 24))*caption_direction),str(battle.model.dice_turn.rolls_left),26 if phone() else 18,color,self)
	elif label == "END TURN":
		var caption: String = GameText.format("TREASURE +%d",battle.model.dice_turn.rewardable_rolls())
		var caption_size: int = 24 if phone() else 18
		var width: float = 2*minf(at.x-16,battle.fx.canvas_size.x-16-at.x)
		while caption_size > 12 and battle.pixel_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size).x > width: caption_size -= 1
		battle._center(at+Vector2(0,(radius()+(18 if battle.debug_split_controls else 24))*caption_direction),caption,caption_size,battle.GOLD,self)
		var heal: int = battle.model.leftover_total_healing()
		if heal > 0: battle._center(at+Vector2(0,(radius()+(46 if battle.debug_split_controls else 52))*caption_direction),GameText.format("+%d HP",heal),20 if phone() else 14,battle.TEAL,self)

## Flatten the existing fire into a small halo and keep the multiplier upright and readable.
func _draw_combo() -> void:
	var at: Vector2 = combo_center()
	var r: float = combo_radius()
	var burning: bool = battle.model.perfect_combo >= 5
	var color: Color = Color("ffb653") if burning else battle.GOLD
	var flash: float = 0 if battle.reduced else clampf((battle.combo_flash_until-battle.clock_time)/0.45,0,1)
	draw_set_transform(at,0,Vector2(1.55,0.62))
	if burning: battle._draw_combo_flames(Vector2.ZERO,r,self)
	for i in range(3,0,-1): Pixel.circle(self,Vector2.ZERO,r+i*3,Color(color,0.08+flash*0.16),2)
	Pixel.disc(self,Vector2.ZERO,r,Color(battle.INK,0.9),2)
	Pixel.circle(self,Vector2.ZERO,r,Color(color,0.9),2)
	draw_set_transform(Vector2.ZERO)
	var text: String = "x%.1f" % battle.model.combo_multiplier()
	var size: int = 32 if phone() else 24
	while size > 12 and battle.pixel_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > r*2.7: size -= 1
	battle._center(at+Vector2(0,11 if phone() else 8),text,size,battle.CREAM,self)
	battle._center(at+Vector2(0,-r*0.62-9),"PERFECT",16 if phone() else 12,color,self)
