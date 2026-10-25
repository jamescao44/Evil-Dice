extends SceneTree
## Enemy shield gains survive the full turn and report their actual result on screen.
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Lock a normal Vanguard's shield intent before any player-applied status changes.
func fresh():
	var m = Rules.new(2410)
	m.enemies = [Rules.make_enemy(0)]
	m.begin_round()
	m.enemies[0].intent = Actions.intent(m,0,"shield")
	return m

func model_checks() -> void:
	for initial in [0,17,20]:
		var m = fresh()
		m.enemies[0].shield = initial
		m.phase = "enemy"
		var events: Array = m.enemy_act(0)
		var gain: int = mini(5,20-initial)
		check(m.enemies[0].shield == initial+gain,"Vanguard gains five shield up to its cap")
		check(events.size() == 1 and events[0].type == "shield" and events[0].amount == gain,"Popup reports the actual shield gain instead of a generic boon")
		m.end_round(); m.begin_round()
		check(m.enemies[0].shield == initial+gain,"Shield remains for the next player turn")
	for status in [Status.FROZEN,Status.IMMOBILIZED,Status.CORROSION]:
		var m = fresh()
		m.apply_enemy_status(0,status,1,false)
		m.phase = "enemy"
		var events: Array = m.enemy_act(0)
		check(m.enemies[0].shield == 0,"Blocking statuses prevent the advertised shield action")
		check(events[0].type == ("immune" if status == Status.CORROSION else "skip"),"Blocked shield reports the status instead of implying a boon was gained")
		m.end_round(); m.begin_round()
		m.enemies[0].intent = Actions.intent(m,0,"shield"); m.phase = "enemy"
		check(m.enemy_act(0)[0].amount == 5 and m.enemies[0].shield == 5,"Shield works again after the blocking status expires")
	var m = fresh()
	m.enemies[0].shield = 5; m.hit_enemy(0,5)
	check(m.enemy_status_count(0,Status.IMMOBILIZED) == 1,"Breaking a normal Vanguard shield cancels its next action")
	m.phase = "enemy"
	check(m.enemy_act(0)[0].text == "IMMOBILIZED" and m.enemies[0].shield == 0,"A broken-shield skip does not silently restore the shield")

## Exercise the same End Turn animation and popup path used by players in both layouts.
func scene_checks(phone: bool, burning: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 20; g.set_process_input(false)
	g._restart(1)
	g.model.enemies = [Rules.make_enemy(0)]
	g.model.enemies[0].intent = Actions.intent(g.model,0,"shield")
	if burning: g.model.apply_enemy_status(0,Status.BURNING,2,false)
	check(g._enemy_intent_data(0).icon == "shield" and g._enemy_intent_data(0).detail == "+5","Visible intention advertises five shield")
	g.model.roll_pool(false,[1,2,3,4,5,6])
	g.fx.set_process(false); g.fx.floats.clear()
	await g._end_dice_turn()
	check(g.view_phase == "ready" and g.model.phase == "roll","End Turn returns control after the Vanguard acts")
	check(g.model.enemies[0].shield == 5,"Normal Vanguard retains its shield through the complete scene turn")
	check(g.model.enemies[0].hp == (65 if burning else 75),"Burning damages HP without erasing the newly raised shield")
	check(g.fx.floats.any(func(f): return f.text == GameText.format("+%d SHIELD",5)),"Both layouts display the localized shield amount")
	check(not g.fx.floats.any(func(f): return f.text == "+ BOON"),"Shield gain never displays as an unrelated boon")
	g.queue_free(); await process_frame

func run() -> void:
	GameText.set_language("zh_CN",false)
	model_checks()
	for phone in [false,true]:
		for burning in [false,true]: await scene_checks(phone,burning)
	print("Enemy shields: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
