extends SceneTree
## Shared shape challenges preserve cast progress and species-specific interruption rules.
const Run = preload("res://scripts/progression/run_rules.gd")
const Rules = preload("res://scripts/enemies/straight_interrupt.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(role: int):
	var m = Run.new(638)
	m.enemies = [m.EnemyCatalog.make(role,1)]
	m.phase = "new"; m.begin_round()
	return m

func rules() -> void:
	for role in [5,6,10,11]:
		var m = fresh(role); var e: Dictionary = m.enemies[0]
		e.charging = true; e.charge = 1
		var seen: Dictionary = {}
		for turn in range(1,61):
			m.round_number = turn; Rules.prepare_turn(m,0)
			check(e.interrupt_straight in [3,4,5],"Every charge challenge is a playable 3/4/5-straight")
			seen[e.interrupt_straight] = true
			var state: int = m.rng.state; var shape: int = e.interrupt_straight
			Rules.prepare_turn(m,0); m.choose_intent(0); m.choose_intent(0)
			check(e.interrupt_straight == shape and m.rng.state == state,"Repeated inspection/intent calls preserve the turn's challenge and RNG")
		check(seen.size() == 3,"Different turns can require each supported shape")
		for length in [3,4,5]:
			m = fresh(role); e = m.enemies[0]; e.charging = true; e.charge = 1; e.interrupt_straight = length
			var wrong = m.make_straight_skill([1,2,3,4] if length == 3 else [1,2,3])
			m.EnemyBehaviors.skill_cast(m,wrong)
			check(e.charge == 1 and e.charging,"A different straight tier does not interrupt")
			var correct = m.make_straight_skill(range(1,length+1))
			m.EnemyBehaviors.skill_cast(m,correct)
			if role == m.EnemyCatalog.Role.COMMANDER:
				check(e.charge == 1 and e.charging and Rules.remaining_casts(e) == 1,"Three-charge boss keeps charging after its first matching cast")
				m.round_number += 1; Rules.prepare_turn(m,0)
				check(Rules.remaining_casts(e) == 1,"New turn changes the shape without resetting partial interruption progress")
				correct = m.make_straight_skill(range(1,e.interrupt_straight+1))
				m.EnemyBehaviors.skill_cast(m,correct)
			var lock: int = 0 if role == m.EnemyCatalog.Role.MAGIC_CANNON else 1
			check(e.charge == 0 and not e.charging and e.interrupt_straight == 0 and m.enemy_status_count(0,m.Status.IMMOBILIZED) == lock,"Matching casts clear charge and apply only the species' intended action lock")
			m.EnemyBehaviors.skill_cast(m,correct)
			check(m.enemy_status_count(0,m.Status.IMMOBILIZED) == lock,"Repeat uses cannot stack skipped turns")
			m.phase = "enemy"; e.acted = false
			var events: Array = m.enemy_act(0)
			check(events.any(func(event): return event.type == ("charge" if lock == 0 else "skip")) and m.enemy_status_count(0,m.Status.IMMOBILIZED) == 0,"Boss loses one action; cannon charges immediately")
		m = fresh(role); e = m.enemies[0]; e.charging = true; e.charge = 1; e.interrupt_straight = 3
		var auto = m.make_straight_skill([1,2,3]); auto.pattern = "match_auto"
		m.EnemyBehaviors.skill_cast(m,auto)
		check(e.charging and e.charge == 1,"Matching-dice automatic attacks cannot satisfy a skill shape")
		if role != 11:
			m.apply_enemy_status(0,m.Status.FROZEN,1,false)
			check(e.charging and e.charge == 1,"Freeze preserves boss and Demon charge progress")
			m.round_number += 1; Rules.prepare_turn(m,0)
			check(e.interrupt_straight == 0,"A skipped frozen action has no active challenge")
		m = fresh(role); e = m.enemies[0]; e.charging = true; e.charge = 1; e.interrupt_straight = 3
		m.enemies.append(m.make_enemy(0)); m.enemies[1].hp = 9999; m.enemies[1].taunt = true
		m.pending = m.make_straight_skill([3,4,5]); m.pending.cast_source = "character_bonus"; m.phase = "player"
		check(m.begin_player_cast(1),"Bonus skill can target another enemy")
		check(Rules.remaining_casts(e) == 1 if role == 5 else not e.charging,"Bonus skill counts exactly once toward the charge requirement")
		if role in [5,6]:
			m = fresh(role); e = m.enemies[0]; e.interrupt_straight = 5; e.charging = true; e.charge = 1
			m.hit_enemy(0,e.hp,true)
			check(e.boss_phase == 2 and e.interrupt_straight == 0 and not e.has("interrupt_warning_round"),"Phase transition clears the old shape")
	# One multi-use skill is still one cast; its individual damage hits cannot remove both marks.
	var m = fresh(5); var boss: Dictionary = m.enemies[0]
	boss.charging = true; boss.charge = 1; boss.interrupt_straight = 3
	m.pending = m.make_straight_skill([3,4,5]); m.pending.cast_source = "manual"
	m.pending.base_uses = 3; m.phase = "player"
	check(m.begin_player_cast(0) and Rules.remaining_casts(boss) == 1,"One multi-use cast removes only one interruption mark")
	while m.phase == "executing": m.apply_player_step(0)
	check(boss.charging and Rules.remaining_casts(boss) == 1,"Damage ticks and extra uses do not satisfy the second mark")
	m.EnemyBehaviors.released(m,0)
	check(not boss.has("interrupt_remaining"),"Releasing an attack discards partial interruption progress")
	boss.charge = 1; boss.charging = true; Rules.prepare_turn(m,0)
	check(Rules.remaining_casts(boss) == 2,"A new charge sequence restores both interruption marks")

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false); g.set_process(false)
	for wave in [8,16,24]:
		g._restart(wave)
		var index := 0
		if wave == 24:
			g.model.hit_enemy(0,g.model.enemies[0].hp,true); index = g.model.enemies.size()-1
			g.clock_time += 1
		var e: Dictionary = g.model.enemies[index]
		e.charging = true; e.charge = 1; e.acted = false; e.interrupt_straight = 5
		e.interrupt_remaining = Rules.required_casts(e)
		e.intent = g.model.EnemyActions.intent(g.model,index,"charge")
		g._update_battlefield_view(1)
		var rect: Rect2 = g.BossPresentation.challenge_rect(g,index)
		check(g.ARENA.encloses(rect),"Boss challenge fits the battlefield in both layouts")
		check(not rect.intersects(g._enemy_health_rect(index)) and not rect.intersects(g._enemy_intent_rect(index)),"Linked-dice shape clears health and intent icons")
		check(g._enemy_intent_data(index).description.contains("5"),"Inspection exposes the current required shape")
		if wave == 8 and "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			g.queue_redraw(); g.arena_actors.queue_redraw()
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-output/interrupt-counter-%s.png" % ["portrait" if phone else "landscape"])
	g.queue_free(); await process_frame

func run() -> void:
	rules(); await scene(false); await scene(true)
	print("Straight interruption: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
