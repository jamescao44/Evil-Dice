extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
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
	root.get_texture().get_image().save_png("/tmp/spellsword-"+name+".png")

func run() -> void:
	GameText.set_language("zh_CN",false)
	for phone in [false,true]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process_input(false); g.speed = 20
		g._restart(20)
		check(not g.BossPresentation.shows_marks(g.model.enemies[0]),"Boss hides both mark rows before charging actually starts")
		g._update_battlefield_view(1)
		check(g._enemy_intent_rect(0).size.x == g._enemy_intent_rect(0).size.y,"Boss intention uses a compact square icon")
		check(g.ARENA.end.y-g._enemy_feet(0).y >= 60,"Boss feet leave visible space above the battlefield bottom")
		await capture(g,"portrait-idle" if phone else "landscape-idle")
		var e: Dictionary = g.model.enemies[0]
		e.charging = true; e.charge = 1; e.intent = g.model.choose_intent(0)
		g._update_battlefield_view(1)
		check(g.art.has("spellsword") and g.art.has("spellsword_glow"),"Boss sprite and silhouette loaded")
		check(is_equal_approx(g._enemy_unit_side(0),g._enemy_side()*2),"Spellsword is twice regular-unit height and width")
		check(g.ARENA.encloses(g._enemy_sprite_rect(0)) and g.ARENA.encloses(g._enemy_intent_rect(0)),"Boss and HUD fit the battlefield")
		check(g._target_rect(0).has_point(g._enemy_point(0)),"Target hitbox matches artwork")
		check(g._enemy_intent_data(0).description == "蓄力2/2，蓄满即攻击。命中3次技能可打断。","Charge description uses the correct short boss rule")
		await capture(g,"portrait-phase1" if phone else "landscape-phase1")
		g.model.base_max_hp = 1000; g.model.hp = 1000; g.model.phase = "enemy"
		await g._enemy_phase()
		check(g.model.hp == 1000-e.damage*2 and g.view_phase == "ready" and not e.charging,"Final Spellsword charge animates and hits in the same action")
		g._restart(20); e = g.model.enemies[0]
		for skill in ["frost_bind","spellsword_mend","dark_slash"]:
			e.intent = Actions.intent(g.model,0,skill)
			var info: Dictionary = g._enemy_intent_data(0)
			check(info.name == e.intent.name or info.name == "Heal","Each move has its own description")
			check(not info.description.contains("tarot") and not info.description.contains("auto-attack"),"Descriptions omit interaction exceptions")
		g.model.hit_enemy(0,99999,true)
		e.acted = false; e.intent = Actions.intent(g.model,0,"corrosive_heal")
		g._update_battlefield_view(1)
		check(g._enemy_intent_data(0).description == "Apply 3 Corrosion to both sides, then begin charging.","Corrosive Heal has its own short description")
		g.inspecting_enemy = 0
		await capture(g,"portrait-phase2" if phone else "landscape-phase2")
		g.inspecting_enemy = -1
		# Exercise the actual non-damage action presentation and next-round intent.
		g.model.phase = "enemy"
		await g._enemy_phase()
		check(g.view_phase == "ready" and g.model.enemies[0].intent.skill == "charge","Corrosive Heal animation returns control with forced charge visible")
		check(g.model.status_count(g.Status.CORROSION) == 3,"Presentation preserves all three Corrosion turns")
		# Run the real sustained animation plus two bonus Fireballs through a phase handoff.
		g._restart(20)
		g.model.gain_souls(450)
		g.model.character_passive.charge = 2
		g.model.enemies[0].hp = 1
		var handoffs: Array = []
		g.model.boss_changed.connect(func(_index, event_type):
			if event_type == "boss_phase": handoffs.append(g.model.pending.uses_left()))
		g.model.roll_pool(false,[1,2,3,4,5,6])
		g.model.dice_turn.selected = [0,1,2,3,4,5]; g.model.form_selected_skill()
		g._show_pending_skill(false)
		g.skill_bubble.lock_cast_position(g._player_point())
		await g._resolve_player(0)
		# Bonus Fireballs now have their own asynchronous casts after the original.
		var deadline: int = Time.get_ticks_msec()+8000
		while (g.view_phase != "ready" or g.model.phase != "roll") and Time.get_ticks_msec() < deadline: await process_frame
		e = g.model.enemies[0]
		check(handoffs == [0],"Phase presentation waits until the original spell and bonus Fireballs finish")
		check(e.boss_phase == 2 and e.hp == e.max_hp and not g.fallen.has(0),"Pending phase never draws or registers a corpse")
		check(g.view_phase == "ready" and g.model.phase == "roll","Completed six-die skill returns to a usable bonus turn")
		g.queue_free(); await process_frame
	print("Spellsword scene: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
