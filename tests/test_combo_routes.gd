extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Status = preload("res://scripts/status/status_effect.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Independent Perfect factors agree across previews, actual hits and animated damage steps.
func damage_checks() -> void:
	for combo in [0,1,2,3,5,20]:
		for dark in [false,true]:
			var m = Run.new(717)
			m.acquire_relic("hamburger")
			m.acquire_relic("bracelet")
			m.statuses[3].count = 2
			if dark: m.apply_affliction(Status.DARKNESS,1)
			var skill = m.Patterns.classify([3,4,5])
			var without_combo: float = m.damage_multiplier(skill)
			m.perfect_combo = combo
			var factor: float = 1.0 if combo == 0 else 1.2+combo*0.1
			check(is_equal_approx(m.combo_multiplier(),factor),"First Perfect gives x1.3, then adds 0.1 per combo")
			check(is_equal_approx(m.damage_multiplier(skill),without_combo*factor),"Combo independently multiplies buffs, relics and darkness")
			var steps: Array = m.attack_damage_steps(skill)
			var value := 1.0
			for step in steps:
				check(is_equal_approx(step.before,value),"Every animated multiplier step is continuous")
				value = step.after
			check(is_equal_approx(value,m.damage_multiplier(skill)),"Animated final multiplier equals combat")
			var bonus_steps: Array = steps.filter(func(s): return s.source == "combo")
			check(bonus_steps.size() == (0 if combo == 0 else 1),"Combo is applied once, with no additive duplicate")
			if combo > 0: check(is_equal_approx(bonus_steps[0].after,bonus_steps[0].before*factor),"Combo animation uses the independent factor")
			m.enemies[0].hp = 100000; m.enemies[0].max_hp = 100000; m.enemies[0].shield = 0
			m.pending = skill
			m.phase = "player"
			var expected := floori(m.attack_base(skill)*without_combo*factor+0.000001)
			check(m.attack_damage(skill,0) == expected,"Preview uses independently multiplied damage")
			var hits: Array = m.apply_player_step(0).filter(func(e): return e.type == "damage")
			check(not hits.is_empty() and hits[0].amount == expected,"Actual hit matches the same preview and trace")
	var m = Run.new(818)
	for i in range(3): m.record_perfect(true)
	check(m.perfect_combo == 3 and is_equal_approx(m.combo_multiplier(),1.5),"Third consecutive Perfect is x1.5")
	m.record_perfect(false)
	check(m.perfect_combo == 0 and m.combo_multiplier() == 1.0,"A miss removes the entire independent factor")

## Route choice keeps held relics visible and lets the ordinary inventory gestures work.
func presentation(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g.model.acquire_relic("fries"); g.model.acquire_relic("hamburger")
	g.view_phase = "wave_reward"
	g.wave_chest.present_routes([g.model.WaveRewards.SOULS,g.model.WaveRewards.BLOOD_GEMS])
	check(g.relic_ui.interactable(),"Route selection keeps inventory interactive")
	var first: Vector2 = g.relic_ui.slot_rect(0).get_center()
	var second: Vector2 = g.relic_ui.slot_rect(1).get_center()
	g._handle_click(first)
	check(g.relic_ui.pressed == 0 and g.wave_chest.phase == "routes","Route overlay no longer swallows relic inspection")
	g._handle_motion(second); g._handle_release(second)
	check(g.model.relics.items[1].id == "fries","Relic reordering works while choosing the next route")
	g.model.perfect_combo = 5
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://test-output/combo-routes-"+str(portrait)+".png")
	g.reduced = true
	await process_frame
	g.queue_free(); await process_frame

func run() -> void:
	damage_checks()
	await presentation(false)
	await presentation(true)
	print("Combo and routes: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
