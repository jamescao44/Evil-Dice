extends SceneTree
## Charge timing, public requirements, cast-based interruption and mixed-wave presentation.
const Run = preload("res://scripts/progression/run_rules.gd")
const Cannon = preload("res://scripts/enemies/magic_cannon.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var m = Run.new(101)
	m.enemies = [m.EnemyCatalog.make(m.EnemyCatalog.Role.MAGIC_CANNON,1),m.EnemyCatalog.make(0,1)]
	m.phase = "new"; m.begin_round()
	return m
func enemy_turn(m) -> Array:
	m.phase = "enemy"
	var events: Array = m.enemy_act(0)
	for e in m.enemies: e.acted = true
	m.end_round(); m.begin_round()
	return events
func rules() -> void:
	var m = fresh(); var cannon: Dictionary = m.enemies[0]
	check(cannon.hp == 500 and cannon.damage == 500,"Cannon uses documented level-one stats")
	check(m.EnemyCatalog.soul_reward(cannon) == 20 and m.EnemyCatalog.crystal_reward(cannon) == 10,"Cannon earns normal special-unit rewards")
	for turn in range(3):
		check(cannon.interrupt_straight in [3,4,5],"Requirement is an eligible straight length")
		var state: int = m.rng.state
		var requirement: int = cannon.interrupt_straight
		m.choose_intent(0); m.choose_intent(0)
		check(m.rng.state == state and cannon.interrupt_straight == requirement,"Inspection/intent rebuild never changes the requirement")
		var events: Array = enemy_turn(m)
		check(events.filter(func(e): return e.target == -1 and e.type == "damage").size() == (1 if turn == 2 else 0),"Shot occurs on the third charge, not a later fourth turn")
	check(m.hp == 500 and cannon.charge == 0,"A full charge fires exactly one 500-damage attack")
	for length in [3,4,5]:
		for source in ["manual","character_bonus","enchanted_missile","echo","chip"]:
			m = fresh(); cannon = m.enemies[0]; cannon.interrupt_straight = length; cannon.charge = 2
			m.pending = m.make_straight_skill(range(1,length+1)); m.pending.cast_source = source; m.phase = "player"
			check(m.begin_player_cast(1),"A matching skill can cast toward a different foe")
			check(cannon.charge == 0 and m.enemy_status_count(0,m.Status.IMMOBILIZED) == 1,"Every matching-length skill source interrupts once")
			m.pending = MultiHitSkill.new()
			var events: Array = enemy_turn(m)
			check(events.any(func(e): return e.type == "skip") and cannon.charge == 0,"Interrupted cannon misses the next action")
			check(m.enemy_status_count(0,m.Status.IMMOBILIZED) == 0,"Immobilization lasts exactly one action")
			enemy_turn(m); check(cannon.charge == 1,"Cannon starts its charge over afterward")
	m = fresh(); cannon = m.enemies[0]; cannon.interrupt_straight = 4; cannon.charge = 1
	var wrong = m.make_straight_skill([1,2,3]); m.EnemyBehaviors.skill_cast(m,wrong)
	check(cannon.charge == 1,"Shorter straights do not satisfy a larger requirement")
	wrong = m.make_straight_skill([1,2,3,4,5]); m.EnemyBehaviors.skill_cast(m,wrong)
	check(cannon.charge == 1,"Larger straights do not bypass the exact length")
	wrong.pattern = "match_auto"; wrong.dice = [4,4,4,4]; m.EnemyBehaviors.skill_cast(m,wrong)
	check(cannon.charge == 1,"Matching automatic attacks do not interrupt")
	m.apply_enemy_status(0,m.Status.FROZEN,1,false)
	check(cannon.charge == 0,"A non-boss cannon follows ordinary freeze charge reset")
	enemy_turn(m); check(cannon.charge == 0,"Freeze skips the next charge")
	var stages: Array = []
	for stage in range(m.PLAYABLE_WAVES):
		if m.Waves.SQUADS[stage].units.any(func(e): return e.role == m.EnemyCatalog.Role.MAGIC_CANNON): stages.append(stage+1)
	check(stages == [12,19,22],"Cannon appears gradually in three authored encounters")
	check(m.Waves.SQUADS[11].units.size() == 2 and m.Waves.requires_combat(11),"First cannon has one familiar supporter and cannot be skipped by a shop")
	var session = Session.new(3); session.model.enemies = m.enemies
	var snapshot: Dictionary = session.snapshot()
	check(snapshot.enemies[0].has("interrupt_straight"),"CLI exposes the same public counter as the GUI")
	for sig in session.model.get_signal_list():
		for c in session.model.get_signal_connection_list(sig.name): session.model.disconnect(sig.name,c.callable)

## Both layouts keep the cannon challenge above its sprite and away from other enemy HUDs.
func layout(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	for wave in [12,19,22]:
		g._restart(wave); g._update_battlefield_view(1); g.view_phase = "ready"
		for i in range(g.model.enemies.size()):
			if not Cannon.is_cannon(g.model.enemies[i]): continue
			g.model.enemies[i].charge = 2
			g.model.enemies[i].interrupt_straight = 5
			g._process(0.02)
			var rect: Rect2 = g._enemy_intent_rect(i)
			check(g.ARENA.encloses(rect),"Cannon requirement stays inside battlefield")
			check(not rect.intersects(g._enemy_health_rect(i)),"Requirement clears its health bar")
			for j in range(g.model.enemies.size()):
				if j == i: continue
				check(not rect.intersects(g._enemy_health_rect(j)) and not rect.intersects(g._enemy_intent_rect(j)),"Cannon requirement clears nearby enemy HUD")
			for locale in ["en","zh_CN"]:
				GameText.set_language(locale,false)
				check(not g._enemy_intent_data(i).description.is_empty(),"Requirement has bilingual inspection text")
			if "--capture" in OS.get_cmdline_user_args() and wave in [8,14]:
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-output/cannon-%s-wave%d.png" % ["portrait" if phone else "landscape",wave])
	g._restart(); g.queue_free(); await process_frame
func run() -> void:
	GameText.initialize(); rules(); await layout(false); await layout(true)
	print("Magic Cannon: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
