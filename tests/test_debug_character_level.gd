extends SceneTree
## Character debug controls synchronize stats, evolution and HUD without replacing the run.
const Run = preload("res://scripts/progression/run_rules.gd")
const Adjust = preload("res://scripts/player/character_debug.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Retain the encounter and ownership while refreshing level-dependent stats in both directions.
func rules() -> void:
	var m = Run.new(71)
	m.enemies = [m.make_enemy(0,3),m.make_enemy(1,4)]
	m.begin_round()
	m.enemies[0].modifier = "manic"
	m.enemies[0].intent = Adjust.Skills.make("attack",Adjust.Damage.base_hit(m.enemies[0],1)*2)
	m.enemies[1].intent = Adjust.Skills.make("attack",80)
	m.enemies[1].intent.friendly_fire = true; m.enemies[1].intent.target = 0
	m.relics.add("codex_page"); m.tarots.add("strength")
	check(not m.relics.items.is_empty() and not m.tarots.items.is_empty(),"Preservation fixture owns a real relic and tarot")
	var items: Array = m.relics.items.duplicate(true)
	var tarot_count: int = m.tarots.items.size()
	var rng: int = m.rng.state
	var hp: int = m.enemies[0].hp
	var initial_hit: int = m.enemies[0].intent.amount
	for level in [5,10,100,1]:
		m.souls = 7; m.hp = 1
		check(Adjust.set_level(m,level),"Valid debug character level applies")
		check(m.character_level == level and m.souls == 0 and m.hp == m.max_hp,"Level, XP and full healing agree")
		check(is_equal_approx(m.character_damage_factor(),m.LevelCurve.damage_scale_at(level)),"Base damage follows the existing level curve")
		check(m.character_evolution_stage() == floori(level/5.0),"Skill evolution follows level")
		check(m.enemies[0].level == 3 and m.enemies[0].hp == hp and m.enemies[1].intent.amount == 80,"Enemy stats and friendly-fire damage stay intact")
		check(m.enemies[0].intent.amount == Adjust.Damage.base_hit(m.enemies[0],level)*2,"Locked player-targeted attack keeps its modifier at the new level gap")
	check(m.enemies[0].intent.amount == initial_hit,"Returning from a high level restores enemy damage without rounding drift")
	check(m.relics.items == items and m.tarots.items.size() == tarot_count and m.rng.state == rng,"Inventory and gameplay RNG are preserved")
	check(not Adjust.set_level(m,0) and not Adjust.set_level(m,101),"Out-of-range levels do not apply")
	m.phase = "executing"; check(not Adjust.set_level(m,5),"In-flight casts cannot be releveled")
	m.phase = "shop"; check(Adjust.set_level(m,5),"The shop also supports character level changes")

## Use real tab clicks, numeric submission and rendered controls in both layouts.
func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g._open_debug()
	var ui = g.debug_page
	g._handle_menu_page_click(ui.tab_rect(ui.Page.BATTLE).get_center())
	check(ui.character_input.visible and ui.character_input.text == str(g.model.character_level),"Opening Battle tab shows the current character level")
	g.evolution.queued = [2,3,4]; g.soul_pickup.pending_total = 20
	for level in [5,10,1]:
		ui.character_input.text = str(level)
		g._handle_menu_page_click(ui.character_apply_rect.get_center())
		var form: int = mini(2,floori(level/5.0))
		check(g.model.character_level == level and g.evolution.displayed_level == level and g.player_animation.form == form,"Apply changes both level and visible form immediately")
		check(not g.evolution.active() and g.soul_pickup.counter_state().level == level,"Stale XP receipts and queued transformations cannot restore an old form")
		check(g.player_animation.Sprite.has_divine_ring(form) == (level >= 10),"Divine ring follows evolution")
		check(is_equal_approx(g.damage_feedback.base_value,g.model.standing_damage_values().x),"Damage readout updates with the level")
	ui.character_input.text = "10"; ui.character_input.text_submitted.emit("10")
	check(g.model.character_level == 10,"Enter submits the character level")
	ui.apply_character_level("abc"); ui.apply_character_level("0")
	check(g.model.character_level == 10 and not g.debug_wave_error.is_empty(),"Invalid input reports an error without changing the level")
	g.view_phase = "rolling"; ui.apply_character_level("5")
	check(g.model.character_level == 10 and not ui.can_apply_character_level(),"Rolling temporarily disables the control")
	g.view_phase = "ready"; ui.apply_character_level("10")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		g.menu_canvas.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/debug-character-"+str(phone)+".png")
	g._handle_menu_page_click(ui.tab_rect(ui.Page.DICE).get_center())
	check(not ui.character_input.visible,"Changing tabs hides the new field")
	ui.apply_character_level("1"); check(g.model.character_level == 10,"Hidden field cannot submit")
	g._close_debug(false); g.queue_free(); await process_frame

func run() -> void:
	rules(); await scene(false); await scene(true)
	print("Debug character levels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
