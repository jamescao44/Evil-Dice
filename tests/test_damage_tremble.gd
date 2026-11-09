extends SceneTree
## The damage HUD pulses, shakes and scales against level-adjusted target HP, never raw magnitude.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Feedback = preload("res://scripts/combat/damage_feedback.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Capture fixed HUD moments without advancing combat or changing saved progress.
func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	g.queue_redraw(); g.arena_actors.queue_redraw(); g.damage_feedback.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/damage-pulse-"+label+".png")

func run() -> void:
	check(Feedback.damage_tremble_amplitude(10000,1000000) == 0,"A huge number doing one percent health damage stays steady")
	check(Feedback.damage_tremble_amplitude(90,100) > Feedback.damage_tremble_amplitude(10000,1000000),"A heavy small hit shakes more than a weak late-game hit")
	check(is_equal_approx(Feedback.damage_tremble_amplitude(180,200),Feedback.damage_tremble_amplitude(18000,20000)),"Equal health fractions shake identically at different levels")
	check(Feedback.damage_tremble_amplitude(80,100) == 0 and Feedback.damage_tremble_amplitude(80.01,100) < 0.01,"Tremble begins smoothly only above eighty percent health")
	check(Feedback.damage_tremble_amplitude(1000000,150) == Feedback.MAX_TREMBLE,"Overkill never exceeds the readability cap")
	check(Feedback.damage_tremble_amplitude(10000,0) == 0,"No target does not fall back to inflated absolute damage")
	check(Feedback.damage_pulse_frequency(1,100) > 0.4 and Feedback.damage_pulse_frequency(1,100) < 0.5,"Small hits have a slow breathing pulse")
	check(Feedback.damage_pulse_frequency(40,100) < Feedback.damage_pulse_frequency(80,100) and Feedback.damage_pulse_frequency(80,100) == 2,"Pulse accelerates up to exactly two cycles per second")
	check(Feedback.damage_pulse_frequency(81,100) == 0,"Trembling replaces the pulse above the threshold")
	check(Feedback.damage_pulse_frequency(0,100) == 0 and Feedback.damage_pulse_frequency(100,0) == 0,"Zero damage and unknown targets remain calm")
	check(is_equal_approx(Feedback.damage_pulse_frequency(40,100),Feedback.damage_pulse_frequency(40000,100000)),"Equal health fractions pulse identically across levels")
	check(Feedback.damage_result_scale(10,100) < Feedback.damage_result_scale(80,100) and Feedback.damage_result_scale(80,100) < Feedback.damage_result_scale(400,100),"Final number size grows through meaningful damage into overkill")
	check(Feedback.damage_result_scale(1000000,100) == Feedback.MAX_RESULT_SCALE,"Huge overkill has a bounded final font size")
	check(is_equal_approx(Feedback.damage_result_scale(80,100),Feedback.damage_result_scale(80000,100000)),"Same damage fraction keeps the same size as enemy levels grow")
	var low: Dictionary = Battle.Rules.make_enemy(0,1)
	var high: Dictionary = Battle.Rules.make_enemy(0,15)
	check(Feedback.damage_result_scale(100,low.max_hp) > Feedback.damage_result_scale(100,high.max_hp),"The same damage displays smaller against higher-level enemies")
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g)
		g.muted = true
		g.process_mode = Node.PROCESS_MODE_DISABLED
		g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1)]
		g.model.enemies[0].max_hp = 150
		g.model.enemies[1].max_hp = 100000
		for enemy in g.model.enemies: enemy.hp = enemy.max_hp
		var panel = g.damage_feedback
		var fireball: MultiHitSkill = g.model.make_straight_skill([3,4,5])
		fireball.target = 1
		g.model.pending = fireball
		var rng_before: int = g.model.rng.state
		panel.start(g.model.attack_damage_steps(fireball))
		check(panel.tremble_health == 100000,"Manual skill buildup captures its committed target")
		panel.hit_damage = 1000
		panel.tremble_age = 0.1
		panel.pulse_phase = 0.5
		check(panel.number_tremble(4) == Vector2.ZERO,"Actual HUD keeps weak four-digit damage still")
		check(panel.number_pulse_scale() > 1,"Actual HUD pulses instead of shaking for weak damage")
		panel.hit_damage = 90000
		check(panel.number_tremble(4) != Vector2.ZERO and panel.number_pulse_scale() == 1,"Actual HUD switches from pulse to tremble above eighty percent")
		var offset: Vector2 = panel.number_tremble(4)
		var held_size: float = panel.result_size_factor()
		g.model.enemies[1].hp = 0
		check(panel.number_tremble(4) == offset,"Killing the target cannot change the held result's reference")
		check(panel.result_size_factor() == held_size,"Killing the target cannot inflate the final number's size")
		panel.phase = "result"; panel.building = false; panel.result_age = 1
		panel.hit_damage = 80000; panel.pulse_phase = 0; g.speed = 2
		panel._process(0.25)
		check(is_equal_approx(panel.number_pulse_scale(),1.08),"Two-times combat speed still takes a quarter second to reach the pulse peak")
		g.menu_open = true; panel._process(0.1); g.menu_open = false
		check(is_equal_approx(panel.pulse_phase,0.5),"Menus pause the pulse clock")
		panel._process(0.25); g.speed = 1
		check(is_equal_approx(panel.number_pulse_scale(),1),"The fastest pulse completes in half a real second")
		for damage in [5000,80000,400000]:
			panel.hit_damage = damage; panel.pulse_phase = 0.5
			check(g.pixel_font.get_string_size(panel.label(),HORIZONTAL_ALIGNMENT_LEFT,-1,panel.text_size()).x*(panel.result_size_factor()+0.1)*panel.number_pulse_scale() <= g.ARENA.size.x-64,"Scaled result stays inside battlefield width")
			await capture(g,("phone-" if phone else "wide-")+str(damage))
		if "--capture" in OS.get_cmdline_user_args():
			panel.hit_damage = 80000
			for phase in ["result","attack"]:
				panel.phase = phase; panel.base_value = 2000; panel.value = 40; panel.impact_age = panel.IMPACT_TIME
				for pulse in [0.0,0.5]:
					panel.pulse_phase = pulse
					await capture(g,("phone-" if phone else "wide-")+phase+"-"+str(pulse))
			panel.phase = "result"
		panel.finish(); panel.fade_age = panel.RESULT_HOLD+panel.RETURN_TIME*0.5
		check(is_equal_approx(panel.result_glyph_scale(0,8),lerpf(panel.result_size_factor(),1,0.5)),"Health-scaled result shrinks smoothly back to standing size")
		panel.fade_age = -1
		g.model.enemies[1].hp = 1
		panel.show_attack(fireball,1)
		check(panel.tremble_health == 100000,"Low remaining HP does not inflate the shake")
		panel.show_attack(fireball,0)
		check(panel.tremble_health == 150,"Automatic attacks use their actual selected target")
		g.model.enemies[1].hp = 100000
		var storm: MultiHitSkill = g.model.make_straight_skill([1,2,3,4,5])
		panel.show_attack(storm,0)
		check(panel.tremble_health == 100000,"Area damage is not exaggerated by the weak member of a mixed-level group")
		g.model.enemies[1].boss = true
		panel.show_attack(fireball,1)
		check(panel.tremble_health == 20000,"Boss reference matches the twenty-percent health scale")
		panel.retain_result(10000)
		check(panel.tremble_health == 20000,"Bonus skills capture the same current target reference")
		g.reduced = true
		check(panel.number_tremble(4) == Vector2.ZERO and panel.number_pulse_scale() == 1,"Reduced motion disables shaking and pulsing")
		check(is_equal_approx(panel.result_glyph_scale(0,8),panel.result_size_factor()),"Reduced motion retains static damage-relative sizing")
		g.reduced = false
		g.model.enemies.clear()
		panel.clear()
		check(panel.tremble_health == 0,"Clearing the readout clears stale encounter context")
		check(panel.number_pulse_scale() == 1 and panel.pulse_phase == 0,"Standing stats remain still after clearing the cast")
		check(g.model.rng.state == rng_before,"Reading target strength never consumes targeting randomness")
		g.queue_free(); await process_frame
	print("Relative damage HUD: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
