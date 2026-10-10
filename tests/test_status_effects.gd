extends SceneTree
const Rules = preload("res://scripts/battle_rules.gd")
const Run = preload("res://scripts/run_rules.gd")
const Status = preload("res://scripts/status_effect.gd")
const Meter = preload("res://scripts/throw_meter.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fresh(role: int = 2, elite: bool = true):
	var m = Rules.new(928)
	m.enemies = [Rules.make_enemy(role,1,elite)]
	m.enemies[0].weight = 100
	m.enemies[0].shield = 20
	m.begin_round()
	return m

func enemy_turn(m, attribute: int = Status.Attribute.NONE, damage: int = 0) -> Array:
	m.phase = "enemy"
	for e in m.enemies:
		e.acted = false
		e.intent = {"type":"attack","target":-1,"amount":damage,"attribute":attribute}
	return m.enemy_act(0)

func model_checks() -> void:
	var m = fresh()
	check(m.statuses.values().all(func(s):return s is StatusEffect),"Boons and afflictions use the same status class")
	for role in range(3):
		m = fresh(role)
		var procs := 0
		for i in range(4000):
			var intent: Dictionary = m.choose_intent(0)
			procs += int(intent.attribute != Status.Attribute.NONE)
			check(intent.type == "attack" and intent.attribute in [Status.Attribute.NONE,m.enemies[0].attribute],"Elite attributes only match their own attack type")
		check(procs == 4000 if role == 2 else procs > 1850 and procs < 2150,"Mage attacks always burn; archer and vanguard control attacks occur 50% of the time")
		m = fresh(role,false)
		for i in range(40): check(m.choose_intent(0).attribute == Status.Attribute.NONE,"Normal enemies have no attributes")
	m = fresh()
	var effects: Array = enemy_turn(m,Status.Attribute.FIRE,15)
	check(m.hp == 85 and m.status_count(Status.BURNING) == 2 and effects[-1].text == "BURN +2","Fire damage applies two burning stacks")
	var burn: Array = m.end_round_step()
	check(m.hp == 84 and burn.size() == 1 and burn[0].amount == 1 and m.phase == "turn_end","Burning resolves one HP at a time after enemies finish")
	burn = m.end_round_step()
	check(m.hp == 83 and burn[0].type == "burn" and m.status_count(Status.BURNING) == 1 and m.phase == "round_end","Two stacks deal two ticks then lose one stack")
	check(m.end_round().is_empty() and m.hp == 83,"Completed burning cannot tick twice")
	m.begin_round()
	m.set_test_roll([2,2,4])
	m.apply_player()
	enemy_turn(m)
	m.end_round()
	check(m.hp == 82 and m.status_count(Status.BURNING) == 0,"One remaining stack ticks once and expires")
	m = fresh()
	m.apply_affliction(Status.BURNING,2)
	m.apply_affliction(Status.BURNING,2)
	check(m.status_count(Status.BURNING) == 4,"Burning stacks add")
	enemy_turn(m)
	m.enemies.append(Rules.make_enemy(0))
	check(m.end_round_step().is_empty() and m.hp == 100,"Burning waits until every surviving enemy has acted")
	m.enemies[1].acted = true
	m.statuses[6].apply(1)
	m.buff_ticks[6] = true
	m.end_round()
	check(m.hp == 100 and m.status_count(Status.BURNING) == 3 and m.status_count(6) == 0,"Last-turn immunity protects every burn tick before expiring")
	m = fresh()
	m.apply_affliction(Status.BURNING,9)
	var capped: Array = m.apply_affliction(Status.BURNING,2)
	check(m.status_count(Status.BURNING) == 10 and capped[0].amount == 1 and capped[0].text == "BURN +1","Burning caps at ten and reports only the added stack")
	check(m.apply_affliction(Status.BURNING,2).is_empty() and m.status_count(Status.BURNING) == 10,"Repeated fire at the cap does not add stacks or false popups")
	m.statuses[Status.BURNING].count = 100
	check(m.status_count(Status.BURNING) == 10,"Direct status assignment also respects the burn cap")
	enemy_turn(m)
	check(m.end_round().size() == 10 and m.hp == 90 and m.status_count(Status.BURNING) == 9,"Maximum burning produces ten one-HP ticks then decays")
	m.set_status_counts({Status.BURNING:50})
	check(m.status_count(Status.BURNING) == 10,"Restoring statuses cannot bypass the burn cap")
	m = fresh(1)
	m.enemies.append(Rules.make_enemy(1,1,true))
	m.enemies.append(Rules.make_enemy(1,1,true))
	m.apply_affliction(Status.FROZEN,1)
	m.phase = "round_end"
	m.begin_round()
	check(m.phase == "frozen" and m.enemies.all(func(e):return e.intent.type == "attack" and e.intent.attribute == Status.Attribute.NONE),"Every archer schedules an ordinary arrow while the player is frozen")
	for i in range(3): m.break_ice()
	for i in m.living(): m.enemy_act(i)
	m.end_round()
	m.begin_round()
	check(m.phase == "roll" and not m.is_frozen(),"Breaking free guarantees a playable next turn even against multiple elite archers")
	var can_freeze_again: bool = false
	for i in range(100):
		if m.choose_intent(0).get("attribute",Status.Attribute.NONE) == Status.Attribute.ICE: can_freeze_again = true
	check(can_freeze_again,"Archers can assign ice arrows again once the player has a playable turn")
	m = fresh()
	m.shield = 30
	enemy_turn(m,Status.Attribute.FIRE,15)
	check(m.hp == 100 and m.status_count(Status.BURNING) == 0,"Fully shielded hits do not apply afflictions")
	m.statuses[6].apply(1)
	for attr in [Status.Attribute.ICE,Status.Attribute.FIRE,Status.Attribute.SHOCK]:
		enemy_turn(m,attr,15)
	check(not m.is_frozen() and not m.is_stunned() and m.status_count(Status.BURNING) == 0,"Invincibility blocks elite on-hit effects")
	m = fresh()
	m.apply_affliction(Status.FROZEN,1)
	m.apply_affliction(Status.FROZEN,1)
	m.apply_affliction(Status.STUNNED,1)
	enemy_turn(m)
	m.end_round()
	m.begin_round()
	var turn: int = m.round_number
	var rng: int = m.rng.state
	check(m.phase == "frozen" and m.roll().is_empty() and m.set_test_roll([6,6,6]).is_empty(),"Freeze prevents natural and debug rolls")
	m.saved_skill = Rules.classify([6,6,6])
	check(not m.begin_saved_cast() and m.rng.state == rng,"Freeze blocks stored skills without spending them or dice RNG")
	check(m.ice_hits_remaining == 3 and m.skip_frozen_turn().is_empty(),"Freeze cannot finish without three ice hits")
	for hit in range(2):
		check(m.break_ice()[0].type == "ice_crack" and m.phase == "frozen" and m.ice_hits_remaining == 2-hit,"First two taps crack the ice without ending the turn")
	check(m.break_ice().size() == 1 and m.phase == "enemy" and not m.is_frozen(),"Third tap breaks free and ends exactly one player turn")
	check(m.skip_frozen_turn().is_empty() and m.is_stunned(),"Skipping cannot repeat or consume a stun without a throw")
	enemy_turn(m)
	m.end_round()
	m.begin_round()
	check(m.round_number == turn+1 and m.phase == "roll","Skipped action includes exactly one enemy phase")
	m.set_test_roll([1,2,3])
	check(not m.is_stunned(),"Stun expires when the next valid throw is accepted")
	m = fresh()
	m.hp = 2
	m.apply_affliction(Status.BURNING,10)
	enemy_turn(m)
	check(m.end_round().size() == 2 and m.hp == 0 and m.phase == "finished","Lethal burning stops immediately and never produces negative HP")
	var city = Run.new(4)
	city.stage = 9
	city._load_wave()
	city.begin_round()
	city.apply_affliction(Status.BURNING,3)
	city.saved_skill = Rules.classify([3,3,4])
	city.begin_saved_cast()
	city.apply_player()
	check(city.hp == 100 and city.status_count(Status.BURNING) == 3,"Saved bonus skills do not advance burning")
	city.set_test_roll([2,2,4])
	city.apply_player()
	check(city.phase == "turn_end","City carries burning into its completed roll interval")
	city.end_round()
	check(city.hp == 97 and city.status_count(Status.BURNING) == 2,"City roll ends tick carried burning once")
	city.reset_run()
	check(city.status_counts().values().all(func(v):return v == 0),"Restart clears boons and every affliction")

func meter_checks() -> void:
	var meter = Meter.new()
	meter.reset(true)
	var saw_left := false
	var saw_right := false
	var last: float = meter.position_ratio()
	for i in range(1000):
		meter.advance(0.01)
		var p: float = meter.position_ratio()
		check(p >= 0 and p <= 1,"Stunned marker stays on the track")
		saw_left = saw_left or p < last
		saw_right = saw_right or p > last
		check(meter.sample() == meter.sample(),"Drawing and sampling the marker cannot reroll its position")
		last = p
	check(saw_left and saw_right,"Stunned marker reverses direction")
	var a = Meter.new()
	var b = Meter.new()
	for m in [a,b]:
		m.reset(true)
		m.motion_rng.seed = 67
		m.segment_age = 0
		m.segment_from = 0.2
		m._next_segment()
	for i in range(100): a.advance(0.01)
	for i in range(10): b.advance(0.1)
	check(is_equal_approx(a.position_ratio(),b.position_ratio()),"Random movement is independent of frame rate")
	meter.reset()
	meter.elapsed = Meter.PERIOD/4
	check(not meter.erratic and meter.sample().perfect,"Normal movement and Perfect window restore after stun")

func layout_checks(g) -> void:
	root.add_child(g)
	g.muted = true
	g.speed = 20
	for stage in range(9):
		g._restart()
		g.model.stage = stage
		g.model._load_wave()
		g.visual_stage = stage
		g.monster_side = g.HORROR_SIZES[stage]
		g.model.set_status_counts({2:3,3:3,33:3,6:3,Status.FROZEN:1,Status.BURNING:4,Status.STUNNED:1})
		for i in range(g.model.enemies.size()):
			var badge: Rect2 = g._enemy_intent_rect(i).grow(2)
			var health: Rect2 = g._enemy_health_rect(i).grow(3)
			var location: String = " (%s stage %d enemy %d)" % [g.get_script().resource_path,stage,i]
			check(g.ARENA.encloses(badge) and g.ARENA.encloses(health),"Move badges and health bars stay inside every wave's battlefield"+location+str(badge)+str(health))
			for j in range(g.model.enemies.size()):
				check(not badge.intersects(g._enemy_health_rect(j).grow(3)),"Move badges never overlap health bars"+location+" bar "+str(j))
				if j != i:
					check(not badge.intersects(g._enemy_intent_rect(j).grow(2)),"Enemy move badges never overlap each other")
					check(not health.intersects(g._enemy_health_rect(j).grow(3)),"Enemy health bars never overlap each other")
			for item in g._active_statuses():
				var icon: Rect2 = g._status_rect(item.id)
				check(not badge.intersects(icon) and not health.intersects(icon) and not g._target_rect(i).intersects(icon),"All seven statuses fit clear of enemy targets, moves and health"+location+" status "+str(item.id))
	g._restart()
	g.model.enemies = [Rules.make_enemy(0),Rules.make_enemy(1,1,true),Rules.make_enemy(2,1,true)]
	for e in g.model.enemies: e.damage = 0
	g.model.phase = "new"
	g._start_round()
	for i in range(g.model.enemies.size()):
		check(not g._enemy_intent_data(i).is_empty(),"Next move is visible for every living enemy")
	var rng: int = g.model.rng.state
	for i in range(10): g._enemy_intent_data(1)
	check(g.model.rng.state == rng,"Intent previews never consume combat RNG")
	var archer: Dictionary = g.model.enemies[1]
	archer.intent = {"type":"attack","target":-1,"amount":10,"attribute":Status.Attribute.ICE}
	check(g._enemy_intent_data(1).label == "ICE 10" and g._enemy_intent_data(1).detail == "SKIP TURN","Chosen ice move shows its damage and turn skip")
	g.model.phase = "enemy"
	g.model.enemy_act(1)
	check(g.model.is_frozen() and g._enemy_intent_data(1).is_empty(),"The telegraphed move applies its advertised status and clears after acting")
	g.model.statuses[Status.FROZEN].count = 0
	g.model.phase = "roll"
	archer.intent = {"type":"attack","target":-1,"amount":0,"attribute":Status.Attribute.NONE}
	g.model.apply_affliction(Status.STUNNED,1)
	g._start_charge()
	check(g.throw_meter.erratic and g.model.is_stunned(),"Stun randomizes the charging meter and stays visible until a throw")
	g._cancel_charge()
	check(g.model.is_stunned() and not g.throw_meter.erratic,"Canceled charging preserves stun without leaving erratic motion active")
	g.model.saved_skill = Rules.classify([5,5,5])
	g._sync_saved_bubble()
	g.model.apply_affliction(Status.FROZEN,1)
	g.model.phase = "round_end"
	g._start_round()
	var frozen_turn: int = g.model.round_number
	check(g.view_phase == "frozen" and not g._can_use_saved(),"Frozen presentation locks dice and saved skills")
	g._start_charge()
	check(g.view_phase == "frozen","Clicking dice cannot bypass the frozen turn")
	g.debug_open = true
	g._handle_click(g.DICE_CENTER)
	await create_timer(0.15).timeout
	check(g.model.is_frozen() and g.model.round_number == frozen_turn and g.model.ice_hits_remaining == 3,"Menus block ice hits")
	g.debug_open = false
	await create_timer(1.15).timeout
	check(g.view_phase == "frozen" and g.model.ice_hits_remaining == 3,"Freeze waits for manual taps instead of expiring automatically")
	g._handle_click(Vector2.ZERO)
	check(g.model.ice_hits_remaining == 3,"Taps outside the ice do not count")
	for hit in range(2):
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = g.get_global_transform_with_canvas()*g.DICE_CENTER
		touch.pressed = true
		g._input(touch)
		var synthesized := InputEventMouseButton.new()
		synthesized.device = -1
		synthesized.button_index = MOUSE_BUTTON_LEFT
		synthesized.position = touch.position
		synthesized.pressed = true
		g._input(synthesized)
		touch.pressed = false
		g._input(touch)
		check(g.model.ice_hits_remaining == 2-hit and g.view_phase == "frozen" and g.model.round_number == frozen_turn,"Each press cracks once; release never adds a hit")
	g._handle_click(g._player_ice_rect().get_center())
	g._handle_release(g._player_ice_rect().get_center())
	var deadline: int = Time.get_ticks_msec()+5000
	while g.view_phase != "ready" and Time.get_ticks_msec()<deadline: await process_frame
	check(g.view_phase == "ready" and g.model.round_number == frozen_turn+1 and g.model.is_stunned(),"Breaking ice completes one enemy phase, preserving the pending stun")
	g.model.apply_affliction(Status.FROZEN,1)
	g.model.phase = "round_end"
	g._start_round()
	g._restart()
	await create_timer(1.1).timeout
	check(g.model.round_number == 1 and g.view_phase == "ready" and not g.model.is_frozen(),"Restart cancels a queued frozen skip")
	g.speed = 1
	g.model.apply_affliction(Status.BURNING,3)
	g.model.phase = "enemy"
	for e in g.model.enemies: e.acted = true
	g.view_phase = "resolving"
	g._resolve_turn_end(g.run_id)
	check(g.model.hp == 99 and g.model.phase == "turn_end","Burn animation starts with a single one-HP tick")
	g.guide = true
	await create_timer(0.25).timeout
	check(g.model.hp == 99,"Opening a menu pauses the burn tick sequence")
	g.guide = false
	var hp_steps: Array = [99]
	deadline = Time.get_ticks_msec()+2000
	while g.model.phase == "turn_end" and Time.get_ticks_msec()<deadline:
		await process_frame
		if g.model.hp != hp_steps[-1]: hp_steps.append(g.model.hp)
	check(hp_steps == [99,98,97] and g.model.status_count(Status.BURNING) == 2,"Scene presents consecutive one-HP losses and decays one stack after the sequence")
	g._restart()
	g.view_phase = "resolving"
	g.model.phase = "enemy"
	check(not await g._resolve_turn_end(g.run_id),"An unfinished enemy phase cannot spin or prematurely end the turn")
	g.queue_free()
	await process_frame

func run() -> void:
	model_checks()
	meter_checks()
	await layout_checks(Battle.new())
	await layout_checks(Portrait.new())
	print("Attributes and statuses: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
