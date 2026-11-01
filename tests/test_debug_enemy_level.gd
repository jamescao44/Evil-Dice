extends SceneTree
## Debug releveling preserves encounter state and tabbed controls share real hit geometry.
const Run = preload("res://scripts/progression/run_rules.gd")
const Adjust = preload("res://scripts/enemies/enemy_debug.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var m = Run.new(38)
	m.enemies = [m.EnemyCatalog.make(0,1,true),m.EnemyCatalog.make(1,2),m.EnemyCatalog.make(2,3)]
	m.begin_round()
	var e: Dictionary = m.enemies[0]
	e.hp = e.max_hp/2; e.shield = 7
	e.intent = preload("res://scripts/enemies/enemy_skill_catalog.gd").make("attack",e.damage*2)
	e.intent.target = 1; e.intent.friendly_fire = true
	m.apply_enemy_status(0,m.Status.BURNING,3,false)
	m.enemies[2].hp = 0
	var original: Dictionary = e.duplicate(true); var rng_state: int = m.rng.state
	check(Adjust.set_level(m,10),"Current encounter accepts a valid level")
	var expected: Dictionary = m.EnemyCatalog.make(0,10,true)
	check(e.level == 10 and e.damage == expected.damage and e.max_hp == expected.max_hp,"Normal and elite stats come from their catalog curve")
	check(absi(e.hp-roundi(float(original.hp)/original.max_hp*e.max_hp)) <= 1 and e.shield == 7,"Health percentage and shield remain intact")
	check(e.modifier == original.modifier and m.enemy_status_count(0,m.Status.BURNING) == 3 and m.rng.state == rng_state,"No rerolled trait, lost status or gameplay RNG consumption")
	check(e.intent.amount == m.EnemyCatalog.Damage.friendly_base_hit(e)*2 and e.intent.target == 1 and e.intent.friendly_fire,"Locked attack keeps its target and modifier while updating damage")
	check(m.enemies[2].hp == 0 and m.enemies[2].level == 3,"Dead enemies stay dead and unchanged")
	check(m.EnemyCatalog.soul_reward(e) == m.EnemyCatalog.soul_reward(expected),"Drops follow the updated level")
	check(not Adjust.set_level(m,0) and not Adjust.set_level(m,101),"Invalid levels are rejected")
	m.phase = "executing"; check(not Adjust.set_level(m,2),"An in-flight attack cannot change its encounter stats")
	for wave in [8,16,24]:
		m = Run.new(38); m.load_debug_wave(wave)
		m.hit_enemy(0,99999999,true); m.phase = "new"; m.begin_round()
		var boss: Dictionary = m.enemies[0]
		boss.charging = true; boss.charge = 1; boss.interrupt_straight = 4
		check(Adjust.set_level(m,12),"Boss encounter can be releveled after phase transition")
		check(boss.boss_phase == 2 and boss.max_hp == m.EnemyCatalog.phase_health(boss,2) and boss.charge == 1 and boss.interrupt_straight == 4,"Boss retains phase and charge challenge, using its separate health curve")
		for ally in m.enemies.slice(1):
			check(ally.level == 12,"Existing reinforcements receive the encounter level")
			if ally.get("summoned",false): check(m.EnemyCatalog.soul_reward(ally) == 0,"Summons stay non-farmable after releveling")

func scene(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g._open_debug()
	var ui = g.debug_page
	for tab in range(3):
		g._handle_menu_page_click(ui.tab_rect(tab).get_center())
		check(ui.page == tab,"Tab click selects its page")
		check(g.debug_wave_input.visible == (tab == 1) and ui.level_input.visible == (tab == 1),"Native fields only appear on Battle tab")
		var controls: Array = ui.buttons().map(func(row): return row[0])
		if tab == 0:
			for choice in [-1]+g.DEBUG_DICE_PRESETS.keys(): controls.append(ui.option_rect(choice))
		elif tab == 1: controls.append_array([g.DEBUG_WAVE_INPUT,ui.level_rect])
		for i in range(controls.size()):
			check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(controls[i]),"Every control fits the canvas")
			for j in range(i): check(not controls[i].intersects(controls[j]),"Controls on a tab never overlap")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			g.menu_canvas.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-output/debug-tabs-%s-%d.png" % [str(phone),tab])
	g._handle_menu_page_click(ui.tab_rect(1).get_center())
	ui.level_input.text = "7"
	g._handle_menu_page_click(ui.apply_rect.get_center())
	check(g.model.enemies.all(func(e): return e.level == 7),"Battle tab applies its input to the actual encounter")
	g._handle_menu_page_click(ui.tab_rect(2).get_center())
	var before: int = g.model.tarots.items.size()
	g._handle_menu_page_click(g.DEBUG_TAROTS.get_center())
	check(g.model.tarots.items.size() == before+22,"Existing reward shortcuts work on their own tab")
	g._close_debug(false)
	check(not ui.level_input.visible and not g.debug_wave_input.visible,"Closing Debug hides both native fields")
	g.queue_free(); await process_frame

func run() -> void:
	rules(); await scene(false); await scene(true)
	print("Debug enemy levels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
