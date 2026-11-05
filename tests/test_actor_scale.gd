extends SceneTree
## Fixed form sizes and encounter framing, including bosses after their phase transition.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 30: push_error(label)

func _initialize() -> void: call_deferred("run")

func framing(g, context: String) -> void:
	g._update_battlefield_view(1)
	for index in g.model.living():
		for rect in [g._enemy_sprite_rect(index),g._enemy_health_rect(index),g._enemy_intent_rect(index)]:
			check(g.ARENA.encloses(rect),context+" enemy %d outside arena: %s" % [index,rect])
		for other in g.model.living():
			if other >= index: continue
			check(not g._enemy_health_rect(index).intersects(g._enemy_health_rect(other)),context+" health bars overlap")

func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.arena_actors.queue_redraw(); g.backdrop.refresh()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/form-size-"+label+".png")

func run() -> void:
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
		for form in range(3):
			for wave in range(1,41):
				g._restart(wave)
				g.model.character_level = [1,5,10][form]; g.evolution.reset()
				var expected: float = 224+64*(4.0 if form == 2 else 11.0)/19
				check(is_equal_approx(g.monster_side,expected),"Actor uses its form size on every wave")
				check(is_equal_approx(g._enemy_side(),g.ActorScale.enemy_size(form)),"Enemies use the revealed evolution")
				var context: String = "%s form%d wave%d" % [phone,form,wave]
				for enemy in g.model.enemies:
					if enemy.get("boss",false): enemy.charging = true; enemy.charge = 1; enemy.interrupt_straight = 4
				framing(g,context)
				if wave == 8:
					g.model.hit_enemy(0,999999999,true); g.model.finish_attack_sequence()
					for enemy in g.model.enemies: enemy.arrival_started = g.clock_time-2
					framing(g,context+" guards")
					await capture(g,"%s-form%d-guards" % [phone,form])
				if wave == 3: await capture(g,"%s-form%d-squad" % [phone,form])
			g.model.enemies = []
			for i in range(6): g.model.enemies.append(g.model.make_enemy(i%3))
			framing(g,"%s form%d six enemies" % [phone,form])
		g.model.character_level = 4; g.evolution.reset(); g.soul_pickup.reset()
		var old_size: float = g._enemy_side()
		g.model.character_level = 5; g.soul_pickup.reset(); g.evolution.enqueue(5)
		check(g._enemy_side() == old_size,"Enemy sizes wait for the visible transformation")
		g.evolution._process(0.9)
		check(g._enemy_side() == g.ActorScale.enemy_size(1),"Enemy sizes switch on the evolution reveal")
		g.model.character_level = 6; g.soul_pickup.reset(); g.evolution.reset()
		check(g._enemy_side() == g.ActorScale.enemy_size(1),"Ordinary level gains do not resize enemies")
		g.queue_free(); await process_frame
	print("Actor form sizes: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
