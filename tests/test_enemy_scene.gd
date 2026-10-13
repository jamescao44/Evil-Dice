extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Home = preload("res://scripts/home.gd")
const Waves = preload("res://scripts/wave_catalog.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/evil-enemies-"+label+".png")
func run() -> void:
	GameText.set_language("zh_CN",false)
	for portrait in [false,true]:
		var layout: String = "portrait" if portrait else "landscape"
		var h = Home.new(); h.portrait = portrait; h.muted = true
		root.add_child(h)
		await capture(layout+"-home")
		h.queue_free(); await process_frame
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g); g.muted = true
		for key in ["paladin","high_priest"]: check(g.art.has(key) and g.art[key].get_width() == 32,"New enemy sprite is loaded: "+key)
		for wave in range(1,Waves.COUNT+1):
			g._restart(wave)
			check(g.model.stage == wave-1 and g.monster_side == Waves.player_size(wave-1),"Wave load matches player growth")
			if wave != 20:
				for i in g.model.living():
					var e: Dictionary = g.model.enemies[i]
					var sprite := Rect2(g._enemy_feet(i)-Vector2(g._enemy_side()/2,g._enemy_side()),Vector2.ONE*g._enemy_side())
					check(g.ARENA.encloses(sprite),"Enemy sprite fits fully inside battlefield: "+layout+" wave "+str(wave))
					if e.role in [3,4]:
						e.charging = true; e.charge = 1
						e.intent = g.model.choose_intent(i)
						check(g._enemy_intent_data(i).icon == "charge","Charge uses the clock intention icon")
					var plate: Rect2 = g._enemy_health_rect(i).grow(3)
					var badge: Rect2 = g._enemy_intent_rect(i).grow(2)
					check(g.ARENA.encloses(plate) and g.ARENA.encloses(badge),"Health and intent remain inside arena")
					for j in g.model.living(): check(not badge.intersects(g._enemy_health_rect(j).grow(3)),"Intent is clear of all health bars")
			if wave in [4,6,10,14,18,19,20]: await capture(layout+"-wave"+str(wave))
			if wave == 19:
				g.inspecting_enemy = g.model.enemies.find_custom(func(e): return e.role == 3)
				await capture(layout+"-inspection")
				g.inspecting_enemy = -1
			if wave == Waves.COUNT and "--capture" in OS.get_cmdline_user_args():
				g.view_phase = "transition"
				for progress in [0.18,0.36,0.65,1.0]:
					g.travel_progress = progress
					await capture(layout+"-growth"+str(roundi(progress*100)))
		# Exercise the actual feeding/transition coroutine through the whole route.
		g._restart(); g.speed = 20
		for wave in range(2,Waves.COUNT+1):
			for e in g.model.enemies: e.hp = 0
			g._advance_wave()
			var deadline: int = Time.get_ticks_msec()+4000
			while g.view_phase != "ready" and Time.get_ticks_msec() < deadline:
				if g.view_phase == "relic_reward": g.model.skip_relic()
				await process_frame
			check(g.view_phase == "ready" and g.model.stage == wave-1,"Feeding reaches the next wave exactly once")
			check(is_equal_approx(g.monster_side,Waves.player_size(wave-1)) and g._player_growth_scale() == Vector2.ONE,"Growth settles at the configured size after each transition")
		for role in [3,4]:
			g._restart(14)
			g.model.enemies = [g.Rules.make_enemy(role,1,true)]
			g.model.enemies[0].charging = true
			g.model.enemies[0].charge = g.Rules.EnemyCatalog.ITEMS[role].charge_turns
			g.model.phase = "new"; g.model.begin_round()
			g.model.phase = "enemy"; g.view_phase = "resolving"; g.speed = 30
			g.model.hp = g.model.max_hp
			var before: int = g.model.hp
			var round_before: int = g.model.round_number
			await g._enemy_phase()
			check(g.model.hp == before-g.model.enemies[0].damage*(2 if role == 3 else 6),"Scene resolves each charged strike exactly once")
			check(g.view_phase == "ready" and g.model.round_number == round_before+1,"Charged burst advances exactly one round")
		g.queue_free(); await process_frame
	print("Enemy presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
