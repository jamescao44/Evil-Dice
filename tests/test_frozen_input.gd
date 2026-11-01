extends SceneTree
## Exercise real stacked ice, input routing and the enemy-phase handoff in both layouts.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Status = preload("res://scripts/status/status_effect.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Match a physical touch and its synthesized mouse event without counting twice.
func tap(g, at: Vector2, touch: bool = false) -> void:
	if not touch:
		g._handle_click(at); g._handle_release(at)
		return
	var event := InputEventScreenTouch.new()
	event.index = 0; event.pressed = true
	event.position = g.get_global_transform_with_canvas()*at
	g._input(event)
	var synthetic := InputEventMouseButton.new()
	synthetic.device = -1; synthetic.button_index = MOUSE_BUTTON_LEFT
	synthetic.position = event.position; synthetic.pressed = true
	g._input(synthetic)
	event.pressed = false; g._input(event)

## Let presentation coroutines finish without hiding an input deadlock behind an infinite wait.
func await_next_round(g, round_before: int) -> bool:
	var deadline: int = Time.get_ticks_msec()+2000
	while g.model.round_number == round_before and Time.get_ticks_msec() < deadline:
		await process_frame
	return g.model.round_number == round_before+1

## Reproduce the High Priest's actual two-stack elemental ice and break both frozen turns.
func stacked_freeze(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 50; g.set_process_input(false)
	var m = g.model
	m.enemies = [m.make_enemy(m.EnemyCatalog.Role.HIGH_PRIEST)]
	var enemy: Dictionary = m.enemies[0]
	enemy.hp = 10000; enemy.max_hp = 10000
	for attempt in range(100):
		enemy.intent = m.EnemyActions.intent(m,0,"elemental")
		if enemy.intent.status == Status.FROZEN: break
	enemy.intent.amount = 1
	m.phase = "enemy"; m.enemy_act(0); m.end_round(); g._start_round()
	check(m.status_count(Status.FROZEN) == 2 and m.phase == "frozen" and g.view_phase == "frozen","High Priest starts a two-layer frozen turn")
	for remaining in [2,1]:
		var round_before: int = m.round_number
		enemy.intent = {"type":"attack","target":-1,"amount":0,"attribute":Status.Attribute.NONE}
		tap(g,g.MENU_RECT.get_center())
		check(g.menu_open,"Menu remains accessible while frozen")
		tap(g,g._ice_rect().end-Vector2(4,4))
		check(m.ice_hits_remaining == 3,"Menu-covered ice cannot be tapped")
		tap(g,g.MENU_RESUME.get_center())
		tap(g,g.inventory_page.button_rect().get_center())
		check(g.inventory_page.opened,"Backpack remains accessible while frozen")
		tap(g,g.DICE_CENTER)
		check(m.ice_hits_remaining == 3,"Backpack-covered ice cannot be tapped")
		tap(g,g.inventory_page.close_rect().get_center())
		for hit in range(2):
			tap(g,g.DICE_CENTER,phone)
			check(m.ice_hits_remaining == 2-hit and m.phase == "frozen","Each mouse or touch press cracks the ice once")
		tap(g,g._player_ice_rect().get_center(),phone)
		check(g.view_phase != "frozen" and m.phase != "frozen","Third crack advances even while another Freeze layer remains")
		var advanced: bool = await await_next_round(g,round_before)
		check(advanced,"Breaking a layer resolves exactly one enemy phase")
		if not advanced: break
		check(m.status_count(Status.FROZEN) == remaining-1,"Only one Freeze layer is spent per skipped turn")
		check(g.view_phase == ("frozen" if remaining == 2 else "ready"),"Remaining ice resets to three cracks; the final layer restores rolling")
		check(m.ice_hits_remaining == (3 if remaining == 2 else 0),"Each frozen turn has a fresh three-tap budget")
	g._restart(); g.queue_free(); await process_frame

## An open tarot view must not intercept taps on the visible frozen character.
func tarot_routing(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g.model.apply_affliction(Status.FROZEN,1)
	g.model.phase = "round_end"; g._start_round()
	g.model.tarots.add("hierophant")
	tap(g,g.tarot_ui.icon_rect().get_center())
	g.tarot_ui.expansion = 1.0
	check(g.tarot_ui.opened,"Frozen player can browse for a cure tarot")
	tap(g,g._player_ice_rect().get_center(),phone)
	check(g.model.ice_hits_remaining == 2,"Visible player ice receives taps through the non-modal tarot view")
	check(not g.tarot_ui.held and g.tarot_ui.inspected < 0,"Ice tap does not also start a tarot gesture")
	g.tarot_ui.inspected = 0
	tap(g,g._player_ice_rect().get_center(),phone)
	check(g.tarot_ui.inspected == -1 and g.model.ice_hits_remaining == 2,"Dismiss an inspected card before interacting with the dimmed battlefield")
	tap(g,g.tarot_ui.icon_rect().get_center())
	g.tarot_ui.expansion = 0
	tap(g,g.DICE_CENTER,phone)
	check(g.model.ice_hits_remaining == 1,"Closing tarot view restores dice-area ice taps")
	g._restart(); g.queue_free(); await process_frame

func run() -> void:
	await stacked_freeze(false); await stacked_freeze(true)
	await tarot_routing(false); await tarot_routing(true)
	print("Frozen input: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
