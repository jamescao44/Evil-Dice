extends SceneTree
const Waves = preload("res://scripts/wave_catalog.gd")
const Run = preload("res://scripts/run_rules.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Status = preload("res://scripts/status_effect.gd")
const Driver = preload("res://tests/scene_driver.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func hit_display_checks() -> void:
	for sample in [[0,24],[1,24],[5,24],[10,24],[30,35],[100,48],[1000,72],[10000,96]]:
		check(Battle.Effects.damage_font_size(sample[0]) == sample[1],"Damage font follows log10 with a regular-size floor")
	for sample in [[0,0],[99,0],[100,0],[1000,2],[10000,4],[100000000,6]]:
		check(is_equal_approx(Battle.DamageFeedback.damage_tremble_amplitude(sample[0]),sample[1]),"Damage tremble has a silent threshold, logarithmic growth, and readable cap")
	check(Battle.DamageFeedback.damage_tremble_amplitude(101) > 0 and Battle.DamageFeedback.damage_tremble_amplitude(101) < 0.01,"Tremble starts smoothly just above 100 damage")
	for values in [[1,2,3],[1,1,2],[4,4,4],[5,5,5]]:
		var m = Run.new(13)
		m.begin_round()
		m.acquire_relic("bloodstone")
		m.hp = 50
		for enemy in m.enemies: enemy.hp = 1; enemy.shield = 0
		m.set_test_roll(values)
		var expected: int = m.attack_damage(m.pending,0)
		var hits: Array = m.apply_player_step(0).filter(func(e): return e.type == "damage")
		for hit in hits:
			check(hit.amount == 1 and hit.display_amount == expected,"Killing hits preserve full damage while removing only remaining HP")
			check(Battle._damage_popup(hit) == "-%d" % expected,"Killing hits render the full numeric damage")
		check(m.hp == 50,"Overkill display does not inflate lifesteal")
	for values in [[1,1,1],[6,6,6]]:
		var m = Run.new(14)
		m.begin_round()
		m.set_test_roll(values)
		for hit in m.apply_player_step(0).filter(func(e): return e.type == "damage"):
			check(hit.instant_kill and hit.amount > 0 and Battle._damage_popup(hit).is_empty(),"Squad executions kill without a damage number")
	var m = Run.new(15)
	m.begin_round()
	m.enemies[0].hp = 1
	m.enemies[0].shield = 10
	m.set_test_roll([1,1,2])
	var hit: Dictionary = m.apply_player_step(0)[0]
	check(hit.type == "shield_hit" and hit.amount == 10 and hit.display_amount == 25 and m.enemies[0].hp == 1,"Shield feedback shows the hit without causing HP spillover")
	m = Run.new(16)
	m.begin_round()
	m.enemies[0].hp = 1
	m.apply_enemy_status(0,Status.CORROSION,3)
	m.set_test_roll([1,1,2])
	hit = m.apply_player_step(0)[0]
	check(hit.amount == 1 and hit.display_amount == 37,"Lethal hit display includes target corrosion")
	m = Run.new(17)
	m.begin_round()
	m.enemies[0].hp = 1
	m.apply_enemy_status(0,Status.BURNING,3)
	hit = m._tick_enemy_statuses()[0]
	check(hit.amount == 1 and Battle._damage_popup(hit) == "-15","Lethal enemy burning shows the full tick")
	m.hp = 1
	hit = m.receive_damage(5,true)[0]
	check(hit.amount == 1 and Battle._damage_popup(hit) == "-5" and m.hp == 0,"Player burning is numeric on death without negative HP")
	m = Run.new(18)
	m.begin_round()
	m.hp = 1
	m.acquire_relic("armor")
	hit = m.receive_damage(10)[0]
	check(hit.amount == 1 and Battle._damage_popup(hit) == "-9","Player damage display includes defense before remaining-HP clamp")
	for values in [[1,1,1],[6,6,6]]:
		m = Run.new(19)
		m.load_debug_wave(Waves.COUNT)
		m.begin_round()
		m.city_hp = 1
		m.set_test_roll(values)
		var expected: int = 75 if values[0] == 1 else 2000
		check(m.damage_caption(m.pending) == "%d + 0 (x1)" % expected,"City previews retain full damage at one remaining HP")
		hit = m.apply_player_step()[0]
		check(hit.amount == 1 and hit.display_amount == expected and not hit.instant_kill and m.city_hp == 0,"City 111 and 666 remain numeric attacks on the killing blow")
	for city in [false,true]:
		m = Run.new(20)
		if city: m.load_debug_wave(Waves.COUNT)
		m.begin_round()
		if city: m.city_hp = 1
		else:
			for enemy in m.enemies: enemy.hp = 1; enemy.shield = 0
		m.acquire_relic("prismatic_stone")
		m.perfect_relic_ready = true
		hit = m.resolve_perfect_relic()[0]
		check(hit.amount == 1 and Battle._damage_popup(hit) == "-100","Prismatic lethal strikes show their full damage in both fight types")

func model_checks() -> void:
	for city in [false,true]:
		for order in [["codex_page","cursed_skull","magic_sword","cursed_bow"],["magic_sword","cursed_skull","codex_page","cursed_bow"],["bracelet","reaper_scythe","ancient_codex","mithril_blade","twin_scythes"]]:
			for dark in [false,true]:
				var m = Run.new(854)
				if city: m.stage = Waves.CITY_STAGE; m._load_wave()
				m.begin_round()
				for id in order: m.acquire_relic(id)
				for item in m.relics.items: item.kills = 3; item.waves = 2; item.charges = 1
				m.set_test_roll([5,5,5])
				m.reward_damage_multiplier = 0.5
				m.perfect_combo = 3
				m.statuses[3].count = 2; m.statuses[33].count = 2
				if dark: m.apply_affliction(Status.DARKNESS,3)
				m.begin_player_cast()
				var inventory: Array = m.relics.items.duplicate(true)
				var state: int = m.rng.state
				var steps: Array = m.attack_damage_steps(m.pending)
				var previous: float = 1.0
				var previous_base: float = m.regular_base_damage()
				var slots: Array = []
				for step in steps:
					check(is_equal_approx(step.before,previous),"Every animation step continues from the preceding value")
					check(is_equal_approx(step.base_before,previous_base),"Base contributions form a continuous trace")
					previous = step.after
					previous_base = step.base_after
					if step.slot >= 0: slots.append(step.slot)
				var sorted: Array = slots.duplicate(); sorted.sort()
				check(slots == sorted,"Relics activate in inventory order, including a stored critical")
				check(is_equal_approx(previous,m.cast_damage_multiplier(m.pending)),"Final animation value matches combat including critical and darkness")
				check(is_equal_approx(previous_base,m.attack_base(m.pending)) and floori(previous_base*previous+0.000001) == m.unmitigated_damage(m.pending),"Animated base and multiplier reproduce numeric impact damage")
				check(m.rng.state == state and m.relics.items == inventory,"Tracing does not roll effects or spend charges")
	for example in [[[1,2,3],false,9.0,19.0],[[1,1,2],false,25.5,40.5],[[4,4,2],false,13.0,59.0/3.0],[[5,5,2],false,18.0,28.0],[[4,4,4],false,30.0,50.0],[[5,5,5],false,15.0,25.0],[[1,1,1],true,75.0,125.0],[[6,6,6],true,2000.0,2010.0]]:
		var trace_model = Run.new(901)
		if example[1]: trace_model.load_debug_wave(Waves.COUNT)
		trace_model.begin_round()
		trace_model.acquire_relic("bracelet")
		trace_model.set_test_roll(example[0]); trace_model.begin_player_cast()
		var trace: Array = trace_model.attack_damage_steps(trace_model.pending)
		check(trace[0].base_before == 15 and is_equal_approx(trace[0].base_after,example[2]),"Skill changes the regular base before relics")
		check(trace[1].id == "bracelet" and is_equal_approx(trace[1].base_after,example[3]),"Flat relic reflects the skill's actual base scaling")
		check(is_equal_approx(trace_model.attack_base(trace_model.pending),example[3]),"Shared base calculation preserves existing attack balance")
	var executions = Run.new(902)
	executions.begin_round()
	for dice in [[1,1,1],[6,6,6],[2,2,2]]:
		executions.set_test_roll(dice)
		check(executions.attack_damage_steps(executions.pending).is_empty(),"Executions and support skills have no numeric damage recipe")
	var m = Run.new(900)
	m.begin_round()
	var activated: Array = []
	m.relic_activated.connect(func(id): activated.append(id))
	for id in ["bloodstone","orange_stone","magic_shield","contract"]: m.acquire_relic(id)
	m.hp = 40
	m._attack_relic_effects(0,20,Rules.classify([1,2,3]))
	check(activated == ["bloodstone","orange_stone"],"Actual heal and status procs emit activation notifications")
	activated.clear()
	m.apply_affliction(Status.FROZEN,1)
	check(activated == ["orange_stone"],"A stone glows when its immunity blocks an effect")
	activated.clear()
	m.relics.items[m.relics.index_of("magic_shield")].charges = 1
	m.receive_damage(5)
	check(activated == ["magic_shield"],"A blocking relic activates on use")
	activated.clear()
	m.receive_damage(1000)
	check(activated == ["contract"] and not m.relics.has("contract"),"Consumed revival activates before leaving inventory")

func capture(g, name: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	g.queue_redraw(); g.damage_feedback.queue_redraw(); g.relic_ui.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-output")
	root.get_texture().get_image().save_png("res://test-output/damage-feedback-%s-%s.png" % ["portrait" if g is Portrait else "landscape",name])

func motion_checks(g) -> void:
	var panel = g.damage_feedback
	g.reduced = false
	panel.active = true
	panel.show()
	panel.phase = "steps"
	panel._impact(100,1,Color.WHITE)
	panel.tremble_age = 0.1
	check(panel.number_tremble(4) == Vector2.ZERO,"Exactly 100 combined damage never trembles")
	panel._impact(100,100,Color.WHITE)
	panel.impact_age = 0.16
	var formula: String = panel.formula_label()
	check(panel.formula_glyph_motion(0,formula.length()).y < 0 and panel.formula_glyph_motion(formula.find("x"),formula.length()).y < 0,"DMG letters and multiplication sign join the formula wave")
	var tremble: Vector2 = panel.number_tremble(4)
	check(tremble != Vector2.ZERO and tremble.abs().x <= 4 and tremble.abs().y <= 4,"Combined damage drives the number tremble even when base alone is 100")
	await capture(g,"formula-wave-tremble")
	g.menu_open = true
	panel._process(1)
	check(panel.tremble_age == 0.1 and panel.number_tremble(4) == tremble,"Opening a menu freezes the tremble clock")
	g.menu_open = false
	panel.phase = "result"
	panel._process(0.16)
	check(panel.number_tremble(4) != tremble,"Tremble continues while final damage is displayed")
	await capture(g,"final-tremble")
	g.reduced = true
	check(panel.number_tremble(4) == Vector2.ZERO and panel.formula_glyph_motion(0,formula.length()) == Vector2.ZERO,"Reduced effects suppress formula waves and high-damage tremble")
	panel.clear()
	check(panel.tremble_age == 0,"New casts reset the tremble clock")

func scene_checks(portrait: bool) -> void:
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.set_process(false)
	g.damage_feedback.set_process(false)
	g.relic_ui.set_process(false)
	check(not g.damage_feedback.active and g._damage_multiplier_label().is_empty(),"Idle multiplier is hidden")
	for id in ["bracelet","codex_page","cursed_skull","cursed_bow"]: g.model.acquire_relic(id)
	g.model.set_test_roll([1,1,6])
	g.model.begin_player_cast()
	g.view_phase = "resolving"
	var panel = g.damage_feedback
	g._show_events([Rules.damage_event(0,1,1234)])
	check(g.fx.floats.back().text == "-1234" and g.fx.floats.back().size == 74,"Battle renderer uses full hit damage for both the number and its logarithmic size")
	if "--visual" in OS.get_cmdline_user_args():
		g.fx.floating(g._player_point()-Vector2(0,45),"-10",g.RED,g.fx.damage_font_size(10))
		await capture(g,"hit-sizes")
	g.fx.floats.clear()
	g._show_events([Rules.damage_event(0,35,35,"damage",true)])
	check(g.fx.floats.is_empty() and not g.fx.slashes.is_empty(),"Execution keeps impact feedback without a numeric popup")
	g._show_events([Rules.event(-1,100,"heal","HEAL")])
	check(g.fx.floats.back().size == 24,"Healing and other feedback retain their regular size")
	g.fx.clear()
	panel.start(g.model.attack_damage_steps(g.model.pending))
	check(panel.label() == "DMG 15 x 1.0" and panel.cursor == -1,"Every attack starts with the regular base and one multiplier")
	var rng: int = g.model.rng.state
	var reward_rng: int = g.model.reward_rng.state
	var hp: int = g.model.enemies[0].hp
	g.menu_open = true
	panel._process(1)
	check(panel.age == 0 and not panel.visible,"Menus pause and hide the buildup")
	g.menu_open = false
	panel._process(panel.INTRO)
	check(panel.steps[panel.cursor].source == "skill" and panel.base_value == 15,"Skill changes base before any relic activates")
	panel._process(0.27)
	check(panel.base_value == 31.5 and panel.value == 1,"Heavy skill supplies its own base while multiplier stays one")
	await capture(g,"skill-base")
	panel._process(0.1)
	check(panel.steps[panel.cursor].id == "bracelet","First relic starts only after the skill base lands")
	panel._process(0.27)
	check(panel.base_value == 46.5 and panel.value == 1 and panel.base_direction == 1,"Bracelet adds the heavy skill's scaled base contribution")
	await capture(g,"base-relic")
	panel._process(0.1)
	check(panel.steps[panel.cursor].id == "codex_page" and g.relic_ui.activations.has("codex_page"),"First relic glows at the start of its flight")
	panel._process(0.15); g.relic_ui._process(0.15)
	check(panel.value == 1 and absf(g.relic_ui.activation_tilt("codex_page")) > 0,"Number waits for the particle slam while the source tilts")
	await capture(g,"flight")
	panel._process(0.13)
	check(is_equal_approx(panel.value,1.2) and panel.impact_direction == 1,"First impact increases the multiplier")
	panel._process(0.02)
	check(panel.motion().y != 0 and panel.motion().x == 0,"Increase bobs in a vertical wave")
	await capture(g,"increase")
	panel._process(0.07)
	check(panel.steps[panel.cursor].id == "cursed_skull","Second source respects inventory order")
	panel._process(0.3)
	check(is_equal_approx(panel.value,2.4),"Skull multiplies the preceding page bonus")
	panel._process(0.07); panel._process(0.3)
	check(is_equal_approx(panel.value,2.28) and panel.impact_direction == -1,"Bow reduces the current multiplier")
	panel._process(0.02)
	check(panel.motion().x != 0 and panel.motion().y == 0,"Reduction shakes horizontally")
	await capture(g,"decrease")
	g.reduced = true
	check(panel.motion() == Vector2.ZERO and g.relic_ui.activation_tilt("codex_page") == 0,"Reduced effects suppress motion without changing values")
	panel._process(0.1)
	check(panel.building and panel.phase == "combine" and panel.label() == "DMG 46.5 x 2.28","Base and multiplier combine only after all relic steps")
	await capture(g,"combine")
	panel._process(panel.COMBINE_TIME)
	check(not panel.building and panel.label() == "DMG 106","Combined per-hit damage uses the combat rounding rule")
	g.reduced = false
	panel._process(0.075)
	var glyph_count: int = panel.label().length()
	check(panel.result_glyph_motion(0,glyph_count).y < 0 and panel.result_glyph_motion(glyph_count-1,glyph_count) == Vector2.ZERO,"Final wave starts at the D in DMG and reaches the final digit from left to right")
	check(panel.result_glyph_scale(0,glyph_count) > 1.2,"Final letters and numbers enlarge during their wave")
	await capture(g,"final-wave")
	g.reduced = true
	check(panel.result_glyph_motion(0,3) == Vector2.ZERO and panel.result_glyph_scale(0,3) == 1.2,"Reduced effects keep the enlarged result without bobbing")
	check(g.model.rng.state == rng and g.model.reward_rng.state == reward_rng and g.model.enemies[0].hp == hp,"Presentation never executes the attack or consumes RNG")
	panel.finish(); panel._process(0.21)
	check(not panel.active and g._damage_multiplier_label().is_empty(),"Multiplier fades away after the attack")
	await motion_checks(g)
	panel.start(g.model.attack_damage_steps(g.model.pending))
	g._restart()
	check(not panel.building and not panel.active and g.relic_ui.activations.is_empty(),"Restart clears the sequence, glow, and tilt")
	g.model.acquire_relic("reaper_scythe")
	g.model.enemies = [Rules.make_enemy(0),Rules.make_enemy(0),Rules.make_enemy(0)]
	g.model.enemies[0].hp = 1
	g.model.set_test_roll([5,5,5]); g.model.begin_player_cast()
	g.view_phase = "resolving"
	panel.start(g.model.attack_damage_steps(g.model.pending))
	while panel.building: panel._process(0.05)
	g.model.hit_enemy(0,5)
	check(panel.building and panel.steps[0].id == "reaper_scythe" and panel.value == 1,"A kill starts a new relic flight before the next combo hit")
	g.model.hit_enemy(1,100)
	panel._process(0.3)
	check(is_equal_approx(panel.value,1.21),"Multiple kills feed the in-flight Reaper update before the next hit")
	g._restart()
	g.set_process(true); panel.set_process(true); g.relic_ui.set_process(true)
	g.speed = 30
	g.reduced = false
	g.model.enemies = [Rules.make_enemy(0,100)]
	g.model.enemies[0].intent = {"type":"attack","target":-1,"amount":1}
	g.model.acquire_relic("codex_page")
	g.result = g.model.set_test_roll([1,1,6])
	g.skill_bubble.begin(g.result); g.skill_bubble.age = 1
	g.view_phase = "skill"
	check(not panel.active,"Holding an attack still hides DMG")
	hp = g.model.enemies[0].hp
	var expected: int = g.model.attack_damage(g.result,0)
	g._activate_skill(0)
	check(panel.building and panel.value == 1 and g.model.enemies[0].hp == hp,"Actual cast waits for buildup before damaging its target")
	await Driver.resolve_held(g)
	check(g.model.enemies[0].hp == hp-expected and not panel.active,"Attack deals its original damage once and hides the display")
	g._restart(Waves.COUNT)
	g.result = g.model.set_test_roll([2,2,2])
	g.skill_bubble.begin(g.result); g.skill_bubble.age = 1
	g.view_phase = "skill"
	g._activate_skill(-2)
	check(not panel.active,"Support casts do not show a damage multiplier")
	await Driver.resolve_held(g)
	if "--visual" in OS.get_cmdline_user_args():
		g.set_process(false)
		g.fx.set_process(false)
		await capture(g,"city")
		g._restart()
		var locale: String = GameText.language
		for language in GameText.LANGUAGES:
			GameText.set_language(language,false)
			g.fx.reveal_perfect(g.DICE_CENTER-Vector2(0,g.DICE_RADIUS*0.62))
			g.fx.perfect.age = 0.15
			g.fx.reveal_combo("PAIR",g.DICE_CENTER,g.TEAL)
			g.fx.combo.age = 0.28
			g.fx.queue_redraw()
			await capture(g,"callouts-"+language)
		GameText.set_language(locale,false)
	g.queue_free(); await process_frame

func retrigger_speed_checks() -> void:
	var g = Battle.new()
	root.add_child(g)
	g.muted = true
	g.set_process(false); g.relic_ui.set_process(false); g.damage_feedback.set_process(false)
	g.speed = 1
	g.view_phase = "resolving"
	for id in ["bracelet","disguise_mask","ancient_tentacle"]: g.model.acquire_relic(id)
	var panel = g.damage_feedback
	panel.start(g.model.attack_damage_steps(Rules.classify([1,2,3])))
	panel.cursor = 0; panel._advance() # Original Bracelet.
	panel._process(0.17)
	check(not panel.landed,"Original relic flight keeps its normal timing")
	panel.cursor = 1; panel._advance() # Mask copy.
	panel._process(0.17)
	check(panel.landed,"Retrigger flight lands in two-thirds of the original time")
	g.relic_ui._process(0.2)
	check(is_equal_approx(g.relic_ui.activations.disguise_mask.age,0.3),"Retrigger glow and tilt also run at 1.5x")
	panel._process(0.07)
	check(panel.cursor == 3,"Retrigger advances after 0.24 seconds rather than 0.36")
	g.model.stage = Waves.CITY_STAGE; g.model._load_wave()
	panel.cursor = 1; panel._advance()
	panel._process(0.085)
	check(panel.landed,"Retrigger pacing composes with the city's double playback speed")
	g.queue_free(); await process_frame

func run() -> void:
	hit_display_checks()
	model_checks()
	await scene_checks(false)
	await scene_checks(true)
	await retrigger_speed_checks()
	print("Cast damage feedback: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
