extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func capture(g, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/commander-"+name+".png")
func run() -> void:
	GameText.set_language("zh_CN",false)
	for phone in [false,true]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process_input(false); g.speed = 20
		g._restart(10)
		check(not g.BossPresentation.shows_marks(g.model.enemies[0]),"Boss hides both mark rows before charging actually starts")
		g._update_battlefield_view(1)
		check(g._enemy_intent_rect(0).size.x == g._enemy_intent_rect(0).size.y,"Boss intention uses a compact square icon")
		check(g.ARENA.end.y-g._enemy_feet(0).y >= 60,"Boss feet leave visible space above the battlefield bottom")
		await capture(g,"portrait-idle" if phone else "landscape-idle")
		g.model.enemies[0].charging = true; g.model.enemies[0].charge = 2; g.model.enemies[0].break_marks = 4
		g.model.enemies[0].intent = g.model.choose_intent(0)
		g._update_battlefield_view(1)
		check(is_equal_approx(g._enemy_unit_side(0),g._enemy_side()*2),"Commander is twice regular-unit height and width")
		check(g.ARENA.encloses(g._enemy_sprite_rect(0)),"Two-times boss fits arena in both layouts")
		check(g.ARENA.encloses(g._enemy_intent_rect(0)),"Boss marks fit arena")
		check(g._target_rect(0).has_point(g._enemy_point(0)),"Giant targeting agrees with artwork")
		await capture(g,"portrait-phase1" if phone else "landscape-phase1")
		var card: Dictionary = g.model.grant_tarot("death")
		g.tarot_cast.request(card.instance_id,g._enemy_point(0),g.DICE_CENTER)
		check(g.tarot_cast.notice == "Death cannot affect bosses." and g.model.tarots.find_instance(card.instance_id) >= 0,"Dragging Death onto a boss rejects the cast without consuming it")
		g.model.tarot_effects.pending_repeat = {"id":"death","instance_id":-1}
		check(not g.tarot_cast._continue_repeat() and g.model.tarot_effects.pending_repeat.is_empty(),"A repeat dismisses cleanly when only a boss remains")
		g.model.base_max_hp = 1000; g.model.hp = 1000; g.model.phase = "enemy"
		await g._enemy_phase()
		check(g.model.hp == 1000-g.model.enemies[0].damage*3 and g.view_phase == "ready" and not g.model.enemies[0].charging,"Final Commander charge animates and hits exactly once before returning control")
		g._restart(10)
		g.model.hit_enemy(0,99999,true)
		g.reinforcement_started = g.clock_time-1
		g._update_battlefield_view(1)
		for i in range(3):
			check(g.ARENA.encloses(g._enemy_sprite_rect(i)),"Phase-two sprites fit")
			check(g.ARENA.grow(-6).encloses(g._enemy_health_rect(i)),"Phase-two health bars fit")
			for j in range(i): check(not g._enemy_health_rect(i).intersects(g._enemy_health_rect(j)),"Boss and guard health bars never overlap")
		await capture(g,"portrait-phase2" if phone else "landscape-phase2")
		# Exercise the actual animation loop from a sustained skill into fixed bonus Fireballs.
		g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1)]
		for e in g.model.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
		g.model.gain_souls(450)
		g.model.character_passive.charge = 2
		g.model.phase = "roll"; g.model.roll_pool(false,[1,2,3,4,5,6])
		g.model.dice_turn.selected = [0,1,2,3,4,5]; g.model.form_selected_skill()
		g._show_pending_skill(false); g.speed = 30
		g.skill_bubble.lock_cast_position(g._player_point())
		await g._resolve_player(0)
		check(g.model.phase != "executing" and g.model.character_passive.charge == 0,"Brimstone and two Fireballs finish without a stuck turn or recursive passive")
		g.queue_free(); await process_frame
	print("Commander scene: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
