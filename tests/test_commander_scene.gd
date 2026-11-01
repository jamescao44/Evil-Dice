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
		g._restart(8)
		check(not g.BossPresentation.shows_marks(g.model.enemies[0]),"Boss hides both mark rows before charging actually starts")
		g._update_battlefield_view(1)
		check(g._enemy_intent_rect(0).size.x == g._enemy_intent_rect(0).size.y,"Boss intention uses a compact square icon")
		check(g.ARENA.end.y-g._enemy_feet(0).y >= 50,"Boss feet leave visible space above the battlefield bottom")
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
		g.model.base_max_hp = 10000; g.model.hp = 10000; g.model.phase = "enemy"
		await g._enemy_phase()
		check(g.model.hp == 10000-g.model.enemies[0].damage*3 and g.view_phase == "ready" and not g.model.enemies[0].charging,"Final Commander charge animates and hits exactly once before returning control")
		g._restart(8)
		g.model.hit_enemy(0,99999,true)
		g.BattlefieldRender.register_arrivals(g)
		g._update_battlefield_view(1)
		for age in [0.0,0.2,0.5]:
			for unit in g.model.enemies.slice(1): unit.arrival_started = g.clock_time-age
			check(g.BattlefieldRender.labels_visible(g,0),"Commander HUD stays visible while guards arrive")
			for guard in [1,2]: check(not g.BattlefieldRender.labels_visible(g,guard),"Arriving guards cannot sweep health or intent labels across the boss")
		for unit in g.model.enemies.slice(1): unit.arrival_started = g.clock_time-1
		g._update_battlefield_view(1)
		for i in range(3):
			check(g.BattlefieldRender.labels_visible(g,i),"Settled reinforcements regain health, intent and status labels")
			check(g.ARENA.encloses(g._enemy_sprite_rect(i)),"Phase-two sprites fit")
			check(g.ARENA.grow(-6).encloses(g._enemy_health_rect(i)),"Phase-two health bars fit")
			for j in range(i): check(not g._enemy_health_rect(i).intersects(g._enemy_health_rect(j)),"Boss and guard health bars never overlap")
			if i > 0:
				check(not g._enemy_intent_rect(i).intersects(g._enemy_sprite_rect(0)),"Guard intent icons leave the Commander body clear")
				check(g.ARENA.encloses(g._enemy_intent_rect(i)),"Shifted guard intent remains within the battlefield")
		var owned: Array = g.model.relics.items.duplicate(true)
		g.model.relics.items = range(10).map(func(_i): return g.model.relics._new_item("bracelet"))
		var overlap := false
		var saved_level: int = g.evolution.displayed_level
		for level in [1,5,10]:
			g.evolution.displayed_level = level
			for step in range(48):
				g.relic_ui.ready_clock = step*0.5
				for pose in preload("res://scripts/relics/relic_orbit.gd").poses(g):
					var orbit := Rect2(pose.at-Vector2.ONE*pose.radius,Vector2.ONE*pose.radius*2)
					for guard in [1,2]: overlap = overlap or g._enemy_world_sprite_rect(guard).intersects(orbit)
		check(not overlap,"Raised Paladins leave the full relic orbit clear in all three player forms")
		g.evolution.displayed_level = saved_level
		await capture(g,"portrait-phase2" if phone else "landscape-phase2")
		g.model.relics.items = owned
		# Boss ground placement deliberately ignores its overhead health bar.
		g.fx.flame_cast(4,g._player_point(),[g._enemy_point(0)],1.0,[20],[g._enemy_feet(0)],[g._enemy_effect_ground(0)])
		g.fx.spell.hold_damage = true; g.fx.begin_flame_damage(); g.fx.spell.brimstone.age = 0.3
		var cast: Dictionary = g.fx.projected_spell(g.fx.spell)
		check(cast.brimstone_anchor.y > g._enemy_feet(0).y+20,"Brimstone grounds beneath the boss instead of its overhead HP bar")
		check(g.Effects.Brimstone.visual_rect(cast).position.y < g.ARENA.position.y,"Full beam continues above the battlefield crop")
		await capture(g,"portrait-beam" if phone else "landscape-beam")
		g.fx.clear()
		# Exercise the actual animation loop from a sustained skill into fixed bonus Fireballs.
		g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1)]
		for e in g.model.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
		g.model.gain_souls(450)
		g.model.character_passive.charge = 2
		g.model.phase = "roll"; g.model.roll_pool(false,[1,2,3,4,5,6])
		g.model.dice_turn.selected = [0,1,2,3,4,5]; g.model.form_selected_skill()
		g.result = g.model.pending.duplicate(true); g.skill_bubble.begin(g.result); g.speed = 30
		g.skill_bubble.lock_cast_position(g._player_point())
		await g._resolve_player(0)
		check(g.model.phase != "executing" and g.model.character_passive.charge == 0,"Brimstone and two Fireballs finish without a stuck turn or recursive passive")
		g.queue_free(); await process_frame
	print("Commander scene: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
