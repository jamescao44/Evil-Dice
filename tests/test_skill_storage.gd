extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Driver = preload("res://tests/scene_driver.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func next_round(m) -> void:
	for i in m.living(): m.enemy_act(i)
	m.end_round()
	m.begin_round()

func model_checks() -> void:
	var m := Run.new(810)
	m.begin_round()
	m.statuses[3].count = 2
	var bank: MultiHitSkill = m.set_test_roll([3,3,5]).duplicate(true)
	var rng: int = m.rng.state
	check(m.save_pending_skill(),"First skill fits in the empty slot")
	check(m.saved_skill.same_as(bank) and m.pending.is_empty() and m.phase == "enemy", "Saving stores the exact dice and passes the turn")
	check(m.statuses[3].count == 2 and m.rng.state == rng,"Saving preserves attack charges without granting the stored boon or drawing RNG")
	next_round(m)
	check(m.statuses[3].count == 2,"Saving and the enemy phase preserve attack charges")
	var current: MultiHitSkill = m.set_test_roll([1,2,3]).duplicate(true)
	check(not m.save_pending_skill() and m.pending.same_as(current) and m.saved_skill.same_as(bank),"Full slot cannot overwrite either skill")
	var turn: int = m.round_number
	check(m.begin_saved_cast(),"Stored boon can be used while a fresh roll is held")
	m.apply_player()
	check(m.pending.same_as(current) and m.phase == "player" and m.round_number == turn,"Bonus restores the waiting roll without spending a turn")
	check(m.statuses[3].count == 5 and m.saved_skill.is_empty() and m.bonus_resume.is_empty(),"Saved boon applies once and empties the slot")
	m.apply_player(0)
	check(m.statuses[3].count == 4,"The waiting attack spends one charge of the saved boon")
	next_round(m)
	check(m.statuses[3].count == 4,"Enemy actions do not spend a second attack charge")
	m.reset_run()
	m.begin_round()
	m.enemies[0].hp = 500
	m.enemies[0].max_hp = 500
	m.saved_skill = Rules.classify([5,5,5])
	current = m.set_test_roll([1,2,3]).duplicate(true)
	m.begin_saved_cast()
	m.apply_player()
	check(m.enemies[0].hp == 410 and m.pending.same_as(current) and m.phase == "player","Bonus combo stops after six hits and does not consume the waiting attack")
	m.saved_skill = Rules.classify([6,6,1])
	m.begin_saved_cast()
	m.apply_player()
	m.apply_player(0)
	check(m.statuses[6].count == 1,"A one-turn saved immunity protects the upcoming enemy phase")
	var hp: int = m.hp
	m.enemies[0].intent = {"type":"attack","amount":5,"target":-1}
	m.enemy_act(0)
	check(m.hp == hp,"Saved immunity actually blocks the enemy attack")
	m.end_round()
	m.begin_round()
	m.set_test_roll([1,2,3])
	m.apply_player(0)
	check(m.statuses[6].count == 0,"Saved immunity expires after its protected phase")
	m.saved_skill = Rules.classify([1,1,1])
	for enemy in m.enemies: enemy.hp = 0
	check(m.advance_wave() and m.saved_skill.face == 1,"Storage carries between waves")
	m.reset_run()
	check(m.saved_skill.is_empty() and m.bonus_resume.is_empty(),"New run clears stored skills and suspended state")
	m.stage = Waves.CITY_STAGE
	m._load_wave()
	m.begin_round()
	m.saved_skill = Rules.classify([1,1,1])
	current = m.set_test_roll([2,2,3]).duplicate(true)
	turn = m.round_number
	m.begin_saved_cast()
	m.apply_player()
	check(m.city_hp == Run.CITY_MAX_HP-75 and m.pending.same_as(current) and m.phase == "player","Stored 111 uses city damage and restores the current city roll")
	check(m.round_number == turn and m.statuses[2].count == 0,"City bonus does not execute the waiting support skill")
	m.saved_skill = Rules.classify([6,6,1])
	m.begin_saved_cast()
	m.apply_player()
	check(m.statuses[6].count == 1,"City saved immunity covers the live interval")
	m.apply_player()
	check(m.phase == "round_end" and m.statuses[6].count == 1,"Normal city roll does not consume timed immunity from a saved skill")
	for tick in range(40): m.tick_city(0.05)
	check(m.statuses[6].count == 0,"Saved city immunity expires after two seconds without another throw")
	m.saved_skill = Rules.classify([3,3,2])
	check(m.begin_saved_cast(),"A stored skill is available between city rolls")
	m.apply_player()
	check(m.phase == "round_end" and m.round_number == turn,"Between-roll bonus does not start a regeneration tick or new roll")
	m.reset_run()
	m.begin_round()
	m.saved_skill = Rules.classify([1,1,1])
	m.set_test_roll([3,3,4])
	m.begin_saved_cast()
	m.apply_player(0)
	check(m.outcome() == "wave_clear" and m.pending.is_empty() and m.bonus_resume.is_empty() and m.statuses[3].count == 0,"Bonus wave clear preserves the unused roll without executing it")
	check(m.saved_skill.dice == [3,3,4],"Bonus wave clear automatically banks the exact waiting dice")
	check(m.advance_wave(),"Bonus wave clear still advances normally")
	check(m.saved_skill.dice == [3,3,4],"Automatically banked skill survives the wave transition")

func force_roll(g, values: Array) -> void:
	g.result = g.model.set_test_roll(values)
	g.skill_bubble.begin(g.result)
	g.skill_bubble.age = g.skill_bubble.formation
	g.view_phase = "skill"

func drag(g, start: Vector2, end: Vector2) -> void:
	g._handle_click(start)
	g._handle_motion(end)
	g._handle_release(end)

func tap(g, at: Vector2) -> void:
	g._handle_click(at)
	g._handle_release(at)

func settle(g) -> void:
	var deadline: int = Time.get_ticks_msec()+7000
	while g.view_phase == "resolving" and Time.get_ticks_msec()<deadline: await process_frame
	check(Time.get_ticks_msec()<deadline,"Storage action finishes")

func layout_checks(g) -> void:
	root.add_child(g)
	g.muted = true
	g.speed = 20
	g.model.enemies[0].hp = 500
	g.model.enemies[0].max_hp = 500
	force_roll(g,[5,5,3])
	check(g.skill_bubble.value_text() == "19 + 0 (x3)","Held combo shows actual per-hit damage and three hits")
	check(g.skill_bubble.description_text() == "random attack +4.5" and g.skill_bubble.value_color().r > g.skill_bubble.value_color().g,"Attack descriptions remain separate from the red value line")
	g.model.statuses[3].count = 2
	check(g.skill_bubble.value_text() == "19 + 10 (x3)","Held preview updates immediately when attack buffs change")
	g.model.statuses[3].count = 0
	g.model.phase = "roll"
	force_roll(g,[1,1,6])
	tap(g,g._skill_center())
	g._handle_motion(g._enemy_point(0))
	check(g.skill_bubble.value_text() == "31 + 0 (x1)","Selected targeted skill shows a single-hit damage preview")
	check(not g._buff_drag_active(),"Attack selection does not dim enemies")
	g._cancel_targeting()
	g.model.phase = "roll"
	force_roll(g,[1,1,1])
	tap(g,g._skill_center())
	check(g.skill_bubble.value_text().is_empty() and g.skill_bubble.description_text() == "instant kill","Instant kill retains its description without a numeric damage value")
	g._cancel_targeting()
	for values in [[3,3,4],[6,6,4],[3,3,3]]:
		var caption: Dictionary = g._skill_caption(Rules.classify(values))
		check(" for " in caption.description and "," not in caption.description,"Buff captions say for N turns without a comma")
	g.model.phase = "roll"
	force_roll(g,[2,2,4])
	check(g.skill_bubble.value_text().is_empty() and "Freeze all: 1 stack" in g.skill_bubble.description_text(),"Freeze shows its effect without a misleading healing or damage value")
	g._handle_click(g._skill_center())
	g._handle_motion(g.ARENA.get_center())
	check(g._buff_drag_active(),"Dragging support dims enemies")
	g._cancel_targeting()
	check(not g._buff_drag_active(),"Canceling support drag restores enemy brightness")
	g.model.phase = "roll"
	force_roll(g,[2,2,2])
	var before_hp: int = g.model.hp
	g.model.hp = g.model.max_hp-37
	check(g.skill_bubble.value_text() == "+37 HP","Full heal shows actual missing health")
	g.model.hp = g.model.max_hp
	check(g.skill_bubble.value_text() == "+0 HP","Full heal cannot advertise overhealing")
	g.model.hp = before_hp
	g.model.phase = "roll"
	force_roll(g,[3,3,2])
	var turn: int = g.model.round_number
	drag(g,g._skill_center(),g._saved_slot_center())
	check(g.view_phase == "resolving" and g.model.saved_skill.dice == [3,3,2] and g.skill_bubble.roll.is_empty(),"Dropping into SAVE banks the skill and passes to enemies")
	await settle(g)
	check(g.view_phase == "ready" and g.model.round_number == turn+1 and g._can_use_saved(),"Saving permits the next roll after one enemy turn")
	check(not g.saved_bubble.roll.is_empty() and g.saved_bubble.center_at() == g._saved_slot_center(),"Stored skill occupies the upper-right seal")
	force_roll(g,[4,4,1])
	var pending: MultiHitSkill = g.model.pending.duplicate(true)
	var rng: int = g.model.rng.state
	drag(g,g._skill_center(),g._saved_slot_center())
	check(g.view_phase == "skill" and g.model.pending.same_as(pending) and g.model.saved_skill.face == 3,"Full slot rejects a new skill without losing either")
	drag(g,g._skill_center(),Vector2(20,20))
	check(g.view_phase == "skill" and g.model.pending.same_as(pending) and g.model.rng.state == rng,"Invalid field drop preserves the roll and RNG")
	tap(g,g._saved_slot_center())
	check(g.view_phase == "skill" and not g.model.saved_skill.is_empty() and g.model.statuses[3].count == 0,"Tapping a stored support skill does not cast it")
	turn = g.model.round_number
	g._handle_click(g._saved_slot_center())
	check(g.skill_bubble.is_suspended() and g.saved_bubble.display_radius() == g._skill_radius(),"Selecting storage dims the waiting skill and restores the saved seal to full size")
	g.saved_bubble._process(0)
	check(g.saved_bubble.self_modulate == Color.WHITE,"Selected saved skill is fully visible before casting")
	g._handle_click(g._skill_center())
	check(g.skill_source == "saved" and g.view_phase == "targeting","Suspended current bubble cannot interrupt saved-skill targeting")
	g._handle_motion(g.ARENA.get_center())
	check(g._buff_drag_active(),"Saved support also dims enemies while dragging")
	g._cancel_targeting()
	drag(g,g._saved_slot_center(),g.ARENA.get_center())
	check(not g._buff_drag_active(),"Casting restores enemies to full brightness")
	check(g.casting_source == "saved" and g.view_phase == "resolving" and g.model.saved_skill.is_empty(),"Field drop consumes the saved skill exactly once")
	check(g.saved_bubble.center_at() == g.ARENA.get_center() and not g.skill_bubble.roll.is_empty() and g.skill_bubble.is_suspended(),"Saved cast stays at its drop location and keeps the dimmed waiting skill present")
	g.saved_bubble._process(0)
	check(g.saved_bubble.self_modulate.a < 0.35 and g.saved_bubble.self_modulate.r == 1,"Saved cast becomes transparent without darkening its colors")
	while not g.saved_bubble.dissolving and g.view_phase == "resolving": await process_frame
	check(g.saved_bubble.dissolving and not g.saved_bubble.fragments.is_empty(),"Cast skill dissolves into pixel fragments")
	check(g.saved_bubble.center_at() == g.ARENA.get_center(),"Dissolving never snaps back to the summon point")
	check(g.saved_bubble.self_modulate.a < 0.35,"Dissolve retains cast transparency")
	await settle(g)
	check(g.view_phase == "skill" and g.result.same_as(pending) and g.model.pending.same_as(pending) and g.model.round_number == turn,"Bonus restores the displayed and model versions of the waiting skill")
	check(g.model.statuses[3].count == 2 and g.saved_bubble.roll.is_empty(),"Bonus boon retains its duration and the slot empties")
	check(g.skill_bubble.value_text() == "11 + 6 (x1)","Waiting skill preview reflects the just-cast saved power boon")
	g.skill_bubble._process(0)
	check(not g.skill_bubble.is_suspended() and g.skill_bubble.self_modulate == Color.WHITE,"Bonus completion restores waiting skill interaction and opacity")
	Driver.cast_pending(g)
	g.skill_bubble._process(0)
	check(g.skill_bubble.self_modulate.a < 0.35,"Ordinary cast also becomes transparent")
	await settle(g)
	check(g.view_phase == "ready" and g.model.round_number == turn+1 and g.model.statuses[3].count == 1,"Waiting skill then uses the bonus and advances exactly one turn")
	force_roll(g,[5,5,3])
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = g.get_global_transform_with_canvas()*g._skill_center()
	g._input(press)
	var motion := InputEventScreenDrag.new()
	motion.index = 0
	motion.position = g.get_global_transform_with_canvas()*g._saved_slot_center()
	g._input(motion)
	press.pressed = false
	press.position = motion.position
	g._input(press)
	await settle(g)
	check(g.model.saved_skill.face == 5 and g.active_touch == -1,"Touch drag can bank a multi-hit skill")
	turn = g.model.round_number
	drag(g,g._saved_slot_center(),g.ARENA.get_center())
	await settle(g)
	check(g.view_phase == "ready" and g.model.round_number == turn and g.model.phase == "roll","Saved combo is a bonus between rolls with no extra turn")
	g.model.saved_skill = Rules.classify([1,1,1])
	g._sync_saved_bubble()
	tap(g,g._saved_slot_center())
	check(g.view_phase == "targeting" and g.skill_source == "saved","Stored targeted skill supports tap then choose a foe")
	g.saved_bubble._process(0)
	check(g.saved_bubble.self_modulate == Color.WHITE,"Selecting the next stored skill restores full opacity")
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(g.view_phase == "ready" and not g.model.saved_skill.is_empty(),"Focus loss returns a saved skill without consuming it")
	g.guide = true
	check(not g._can_use_saved(),"Menu blocks stored casts")
	g.guide = false
	g.model.saved_skill = Rules.classify([5,5,5])
	g._sync_saved_bubble()
	drag(g,g._saved_slot_center(),g.ARENA.get_center())
	g._restart()
	await create_timer(0.25).timeout
	check(g.model.saved_skill.is_empty() and g.model.bonus_resume.is_empty() and g.model.hp == 100 and g.view_phase == "ready","Restart cancels the bonus chain and clears storage")
	g.model.enemies = [Rules.make_enemy(0),Rules.make_enemy(0),Rules.make_enemy(0)]
	g.model.enemies[1].shield = 10
	force_roll(g,[2,2,4])
	pending = g.model.pending.duplicate(true)
	g.model.saved_skill = Rules.classify([1,1,1])
	g._sync_saved_bubble()
	tap(g,g._saved_slot_center())
	tap(g,g._enemy_point(1))
	await settle(g)
	check(g.view_phase == "skill" and g.model.enemies[1].hp == 0 and g.model.enemies[0].hp == 75 and g.model.pending.same_as(pending),"Saved tap-aim executes the chosen foe through shield and preserves the new skill")
	g._restart()
	force_roll(g,[6,6,4])
	g.model.saved_skill = Rules.classify([1,1,1])
	g._sync_saved_bubble()
	drag(g,g._saved_slot_center(),g._enemy_point(0))
	var wave_deadline: int = Time.get_ticks_msec()+7000
	while (g.model.stage == 0 or g.view_phase != "ready") and Time.get_ticks_msec()<wave_deadline:
		preload("res://tests/scene_driver.gd").cast_pending(g)
		await process_frame
	check(g.model.stage == 1 and g.view_phase == "ready" and g.model.saved_skill.dice == [6,6,4],"Bonus wave victory automatically carries the unused summoned skill to the next wave")
	check(g.saved_bubble.roll.dice == [6,6,4] and g.skill_bubble.roll.is_empty() and g.model.statuses[6].count == 0,"Auto-save updates the slot visual without activating the unused boon")
	g._restart()
	g.model.stage = Waves.CITY_STAGE
	g.model._load_wave()
	g._start_round()
	g.model.hp = 1000
	g.model.city_hp = 100000 # Exercise resuming the waiting skill after a nonlethal bonus cast.
	force_roll(g,[1,2,3])
	pending = g.model.pending.duplicate(true)
	g.model.saved_skill = Rules.classify([6,6,6])
	g._sync_saved_bubble()
	turn = g.model.round_number
	drag(g,g._saved_slot_center(),g.ARENA.get_center())
	await settle(g)
	check(g.model.city_hp == 100000-2000 and g.model.pending.same_as(pending) and g.view_phase == "skill" and g.model.round_number == turn,"City bonus Annihilation leaves the current skill and round intact")
	g.queue_free()
	await process_frame

func run() -> void:
	# These assertions verify the English wording; Chinese is covered by test_localization.
	GameText.set_language("en",false)
	model_checks()
	await layout_checks(Battle.new())
	await layout_checks(Portrait.new())
	print("Skill storage: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
