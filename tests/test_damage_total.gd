extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void:
	call_deferred("run")

## Render the same fixed damage chain in both real layout paths for a visual check.
func capture(game, phone: bool) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	game.queue_redraw(); game.damage_feedback.queue_redraw(); game.damage_total.queue_redraw()
	game.fx.combat_text_visible = true; game.fx._sync_damage_layer()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/evil-dice-damage-total-%s.png" % ["portrait" if phone else "landscape"])

## Verify event accounting, two-second renewal, per-hit digit waves and layout bounds together.
func run() -> void:
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
		g.view_phase = "ready"; g.fx.clear(); g.player_animation.reset()
		g.model.enemies = [g.Rules.make_enemy(0),g.Rules.make_enemy(1)]
		for enemy in g.model.enemies: enemy.hp = 1000; enemy.max_hp = 1000; enemy.shield = 0
		var total = g.damage_total
		check(not total.add_event(g.Rules.damage_event(0,5,5,"burn")) and total.total == 0,"Burning alone never starts a total")
		check(total.text_size() == 2*g.damage_feedback.base_text_size(),"Aggregate starts at twice the standing HUD font")
		check(total.get_parent() == g.fx.damage_canvas and g.fx.damage_layer.layer == BattleLayers.DAMAGE_CANVAS,"Total shares frontmost, arena-clipped damage canvas")
		var rng_state: int = g.model.rng.state
		g._show_events([g.Rules.damage_event(0,100,100),g.Rules.damage_event(1,200,200)])
		check(total.total == 300 and total.presented_total == 100 and total.pending_hits.size() == 1,"Two enemies contribute separate additions to one chain")
		check(g.fx.floats.is_empty(),"Outgoing damage no longer creates individual flying tick labels")
		check(total.caption_size() < total.text_size() and total.caption_origin(1).x > g.ARENA.end.x,"Smaller caption begins off the right edge")
		total._process(0.07)
		check(total.presented_total == 300 and total.additions == 2 and total.waves.size() == 2,"Each impact launches a wave without cancelling an earlier one")
		total._process(0.2)
		check(total.label() == "300" and total.size_factor > 1,"Counting settles exactly and gradually enlarges the number")
		g.damage_feedback.clear()
		check(total.total == 300,"Skill-calculation cleanup does not break the damage chain")
		g._show_events([g.Rules.damage_event(-1,30,30),g.Rules.damage_event(0,30,30,"damage",true),g.Rules.event(0,10,"heal","")])
		check(total.total == 300,"Incoming player damage, healing and executions do not inflate the total")
		check(g.fx.floats.any(func(f): return f.get("damage",false) and f.text == "-30"),"Player damage remains independently readable")
		g._show_events([g.Rules.damage_event(0,1,600),g.Rules.damage_event(1,5,5,"burn"),g.Rules.damage_event(1,20,20,"shield_hit")])
		check(total.total == 920,"Overkill and shield damage count while Burning is excluded")
		check(g.fx.floats.any(func(f): return f.get("damage",false) and f.text == "-5"),"Burning retains its own damage number at the enemy")
		check(not g.fx.floats.any(func(f): return f.text == "-20"),"Shield damage contributes once without a duplicate numeric label")
		total._process(0.3)
		check(total.presented_total == 920 and total.additions == 4,"A frame delay still settles every queued direct hit exactly once")
		for language in ["en","zh_CN"]:
			GameText.set_language(language,false)
			var caption: String = GameText.text("Total Damage")
			check(caption == ("Total Damage" if language == "en" else "总伤害"),"Caption follows the interface language")
			var caption_width: float = GameText.description_font().get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,total.caption_size()).x
			var number_width: float = g.pixel_font.get_string_size(total.label(),HORIZONTAL_ALIGNMENT_LEFT,-1,total.text_size()).x
			check(is_equal_approx(total.caption_origin(1).x+caption_width,total.anchor().x+number_width/2) and total.caption_origin(1).y > total.anchor().y,"Caption settles right-aligned beneath the number")
		check(g.model.rng.state == rng_state,"Readout effects never consume combat RNG")
		total.clear(); total.add_event(g.Rules.damage_event(0,1000,1000)); total._process(0.06)
		check(total.digit_wave(0,4) > 0 and total.digit_wave(3,4) == 0,"Increase wave starts on the leftmost digit")
		total._process(0.15)
		check(total.digit_wave(3,4) > 0,"Wave reaches the rightmost digit later")
		total.add_event(g.Rules.damage_event(0,10,10)); total._process(0.02)
		check(total.waves.size() == 2,"New damage retains the previous wave's trailing motion")
		g.reduced = true
		check(total.digit_wave(0,4) == 0,"Reduced effects suppress digit movement while retaining the tally")
		g.reduced = false; total._process(1.5)
		total.add_event(g.Rules.damage_event(1,20,20)); g.speed = 8; total._process(1.9)
		check(total.total == 1030 and total.opacity() > 0 and total.opacity() < 1,"New damage renews a two-real-second chain even at high battle speed")
		var elapsed: float = total.idle_age
		check(not total.add_event(g.Rules.damage_event(1,5,5,"burn")) and total.idle_age == elapsed and total.total == 1030,"Burning neither adds damage nor renews the shared number/caption fade")
		total._process(0.11)
		check(total.total == 0 and not total.visible,"Chain clears two seconds after the latest damage")
		total.add_event(g.Rules.damage_event(0,50,50)); total._process(0.1)
		g.menu_open = true; total._process(5)
		check(is_equal_approx(total.idle_age,0.1) and not total.visible,"Pause hides and preserves the remaining linger")
		g.menu_open = false; total._process(0)
		check(total.visible,"Returning from pause restores the same total")
		g.view_phase = "over"; total._process(0)
		check(not total.visible,"Totals never overlay the victory page")
		g.view_phase = "ready"
		total.clear(); total.add_event(g.Rules.damage_event(0,100,100))
		var small_scale: float = total.target_size_factor()
		total.clear(); g.model.enemies[0].max_hp = 10000; total.add_event(g.Rules.damage_event(0,1000,1000))
		check(is_equal_approx(small_scale,total.target_size_factor()),"Equivalent health chunks scale equally against higher-level enemies")
		total.clear(); g.model.enemies[0].max_hp = 1000; g.model.enemies[0].boss = true; total.add_event(g.Rules.damage_event(0,100,100))
		check(is_equal_approx(total.reference_health,200) and total.target_size_factor() > small_scale,"Boss sizing retains the twenty-percent health reference")
		total.clear(); g.model.enemies[0].boss = false; g.model.enemies[0].max_hp = 150
		total.add_event(g.Rules.damage_event(0,150,1280)); total._process(0.1)
		var width: float = g.pixel_font.get_string_size(total.label(),HORIZONTAL_ALIGNMENT_LEFT,-1,total.text_size()).x*total.fitted_scale(total.label(),1.3)
		check(total.anchor().x-width/2 >= g.ARENA.position.x and total.anchor().x+width/2 < g.ARENA.end.x,"Enlarged result stays inside portrait and desktop battlefield edges")
		await capture(g,phone)
		g._restart()
		check(total.total == 0 and total.pending_hits.is_empty() and total.waves.is_empty(),"Restart clears values, queued hits and digit waves")
		g.queue_free(); await process_frame
	print("Accumulated damage: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
