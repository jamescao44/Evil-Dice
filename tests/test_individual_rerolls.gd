extends SceneTree
## Initial matching attacks, untimed single-die corrections and real pointer mode transitions.
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var m = Run.new(917)
	m.begin_round(); m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
	for enemy in m.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	return m
func settle(m) -> Array:
	var events: Array = []
	for i in range(24):
		if m.roll_attacks.is_empty(): break
		events.append_array(m.resolve_roll_attack_step())
	check(m.roll_attacks.is_empty(),"Matching attacks terminate")
	return events.filter(func(e): return e.type == "damage")
func rules() -> void:
	var die = preload("res://scripts/dice/die.gd").new()
	for rate in [1.0,2.0]:
		die.reroll_to(4,rate)
		var motion = die.roll_motion
		check(is_equal_approx(motion.seconds*motion.frames_per_second,14.0),"Correction completes exactly two seven-frame loops")
		check(is_equal_approx(motion.seconds/die.duration,rate*1.15),"Correction plays 15% faster at each selected game speed")
		for step in range(14):
			var frame: int = motion.frame_at((step+0.5)/14.0)
			check(frame == 6+posmod(motion.start_frame+step*motion.frame_direction,7),"Two loops retain random start and playback direction")
		die.motion_tween = null
	die.free()
	var m = fresh()
	check(m.reroll_die(0).is_empty() and m.dice_turn.rolls_left == 5,"Individual correction requires an opening throw")
	m.roll_pool(true,[1,2,3,4,5,6])
	var combo: int = m.perfect_combo
	var before: Array = m.dice_turn.values.duplicate()
	check(m.reroll_die(4,[6]) == [4],"Correction returns exactly the tapped physical die")
	check(m.dice_turn.values == [1,2,3,4,6,6] and m.dice_turn.rolls_left == 3,"One die changes for one ordinary roll")
	check(m.perfect_combo == combo and m.roll_attacks.is_empty() and m.phase == "roll","A new match never attacks on a reroll; combo survives")
	m.tarot_effects.star_throws = 3
	m.reroll_die(3,[6])
	check(m.roll_attacks.is_empty() and m.perfect_combo == combo and m.tarot_effects.star_throws == 3,"Untimed corrections preserve combo and reserve Star for timed throws")
	m.reroll_die(3,[5]); m.reroll_die(3,[6])
	var rng_state: int = m.rng.state
	before = m.dice_turn.values.duplicate()
	check(m.reroll_die(0).is_empty() and m.rng.state == rng_state and m.dice_turn.values == before,"Exhausted correction is atomic")
	m.roll_pool(false,[6,6,6,6,6,6],true)
	check(m.roll_attacks.is_empty(),"Free full-pool tarot rerolls do not retrigger six alike")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6])
	for i in [0,1,2]: m.dice_turn.select(i)
	m.form_selected_skill()
	check(m.reroll_die(4).is_empty(),"Pending skills block corrections")
	m.apply_player(0)
	before = m.dice_turn.values.duplicate(); rng_state = m.rng.state
	for index in [-1,0,1,2,6]: check(m.reroll_die(index).is_empty(),"Spent and out-of-range dice cannot be rerolled")
	check(m.rng.state == rng_state and m.dice_turn.values == before and m.dice_turn.rolls_left == 4,"Invalid corrections spend nothing")
	m.tarot_effects.lovers = true
	m.reroll_die(5,[4])
	check(m.tarot_effects.lovers and m.dice_turn.values.slice(0,5) == before.slice(0,5),"Four-die guarantees wait instead of rewriting untouched dice")
	m = fresh(); m.dice_turn.ticket_rolls_left = 1; m.dice_turn.reset()
	m.roll_pool(false,[1,2,3,4,5,6])
	for i in range(Run.DiceTurn.REROLLS): m.reroll_die(0,[3])
	check(m.dice_turn.rolls_left == 1 and m.dice_turn.rewardable_rolls() == 0,"Ticket's remaining correction gives no treasure")
	m.reroll_die(0,[4]); check(m.dice_turn.rolls_left == 0 and m.dice_turn.ticket_rolls_left == 0,"Correction spends Ticket after ordinary rolls")
	for count in [3,4]:
		m = fresh(); m.tarot_effects.strength = 2; m.tarot_effects.extra_uses = 3
		m.acquire_relic("twin_scythes")
		m.roll_pool(false,[4,4,4,1,2,6] if count == 3 else [4,4,4,4,1,2])
		var hits: Array = settle(m)
		check(hits.size() == (1 if count == 3 else 3),"Triple concentrates one hit; quadruple hits every enemy once")
		check(hits.all(func(hit): return hit.display_amount == (21 if count == 3 else 28)),"Triple/quadruple use their stronger pip coefficient before final damage rounding")
		check(m.enemies.reduce(func(total,e): return total+m.enemy_status_count(m.enemies.find(e),m.Status.BURNING),0) == (2 if count == 3 else 0),"Triple applies Burning after impact; quadruple adds no status")
		check(m.shield == 0 and m.tarot_effects.strength == 2 and m.tarot_effects.extra_uses == 3 and m.character_passive.charge == 0,"Matches add no shield, spend no skill tarot and charge no skill counter")
		m = fresh()
		for e in m.enemies: e.hp = 1
		m.enemies = [m.enemies[0]] if count == 3 else m.enemies
		m.roll_pool(false,[4,4,4,1,2,6] if count == 3 else [4,4,4,4,1,2]); settle(m)
		check(m.phase == "finished" and not m.outcome().is_empty(),"Match clear ends the wave without corpse hits or a stranded phase")
	m = fresh(); m.roll_pool(false,[1,2,3,1,2,3]); settle(m)
	for i in [0,1,2]: m.dice_turn.select(i)
	m.form_selected_skill(); m.apply_player(0)
	check(m.phase == "enemy" and m.bonus_turn_count == 0,"One manual skill hands off to enemies")
	for e in m.enemies: e.acted = true
	m.end_round(); m.begin_round()
	check(not m.dice_turn.has_rolled(),"Only a real next turn starts a fresh opening throw")
	m.roll_pool(false,[4,4,4,1,2,6]); check(settle(m).size() == 1,"Next turn may trigger its initial matching attack")

func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)
func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+6000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/individual-reroll-"+label+".png")
func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	g.model = fresh(); g.model.roll_pool(true,[1,2,3,4,5,6]); g._show_pending_skill(false)
	for i in range(6): g.dice[i].face = i+1
	await process_frame
	var ui = g.dice_selection
	tap(g,g.DICE_CENTER); await process_frame
	check(ui.reroll_mode and g.view_phase == "ready" and g.dice.all(func(d): return d.reroll_hint),"Center enables pulsing corrections without a Perfect meter")
	await capture("mode-"+str(phone))
	tap(g,g.DICE_CENTER)
	check(not ui.reroll_mode and g.model.dice_turn.rolls_left == 4,"Center exits freely")
	tap(g,g.DICE_CENTER); tap(g,g.DICE_POSITIONS[4])
	check(g.view_phase == "rolling" and g.dice[4].rolling and g.dice.filter(func(d): return d.rolling).size() == 1,"Only chosen die tumbles immediately")
	check(await until(func(): return g.view_phase == "ready"),"Correction returns control promptly")
	check(ui.reroll_mode and g.model.perfect_combo == 1 and g.model.dice_turn.rolls_left == 3,"Reroll mode stays active and combo is unchanged")
	for i in range(Run.DiceTurn.REROLLS-1):
		tap(g,g.DICE_POSITIONS[5]); await until(func(): return g.view_phase == "ready"); await process_frame
	check(not ui.reroll_mode and g.dice.all(func(d): return not d.reroll_hint),"Last correction automatically exits reroll mode")
	for count in [3,4]:
		g.model = fresh(); g.model.roll_pool(false,[4,4,4,1,2,6] if count == 3 else [4,4,4,4,1,2]); g.view_phase = "rolling"
		g._resolve_roll_triggers(g.run_id)
		check(await until(func(): return g.fx.spell.get("match_count",0) == count),"Concentrated matching effect starts")
		await until(func(): return g.fx.spell.get("life",0.0) < g.fx.spell.get("duration",0.0)*0.35)
		await capture("burst-%d-%s" % [count,str(phone)])
		check(await until(func(): return g.model.roll_attacks.is_empty()),"New effect commits damage")
		await create_timer(0.6).timeout
		check(g.model.phase == "roll" and g.dice.all(func(d): return not d.auto_attack_active),"Special attack restores dice without a skill-use orb")
	g._restart(); g.queue_free(); await process_frame
func run() -> void:
	rules(); await scene(false); await scene(true)
	print("Individual rerolls: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
