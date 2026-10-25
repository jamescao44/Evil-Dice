extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
class TestBattle extends Battle:
	var test_values: Array = []
	func _debug_values() -> Array: return test_values.duplicate()
class TestPortrait extends Portrait:
	var test_values: Array = []
	func _debug_values() -> Array: return test_values.duplicate()
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func until(predicate: Callable, seconds: float = 10) -> bool:
	var deadline := Time.get_ticks_msec()+roundi(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	var passed: bool = predicate.call()
	return passed

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame; RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/flame-"+name+".png")

func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)

## Exercise actual roll, tap, cancel, cast and end-turn coroutines in both layouts.
func scene(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = TestPortrait.new() if portrait else TestBattle.new()
	root.add_child(g); g.muted = true; g.speed = 4; g.set_process_input(false)
	for enemy in g.model.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	if "--capture" in OS.get_cmdline_user_args():
		var language: String = GameText.language
		g.guide = true
		if portrait: g.guide_page = 1
		for locale in ["en","zh_CN"]:
			GameText.set_language(locale,false)
			await capture("guide-"+locale+"-"+str(portrait))
		g.guide = false
		GameText.set_language(language,false)
	var previous_phase: String = g.view_phase
	g.view_phase = "transition"
	g.travel_progress = 0.2
	var anchor: Vector2 = g._character_counter_center()
	g.travel_progress = 0.65
	check(g._character_counter_center().is_equal_approx(anchor),"Counter ignores advancing stretch and bounce")
	g.view_phase = previous_phase
	g.test_values = [1,1,2,2,4,4]
	g._roll()
	check(await until(func(): return g.dice[0].auto_attack_active),"Matching dice glow before the player attacks")
	check(g.fx.feeds.is_empty() and g.model.roll_attacks[0].skill.uses_spent == 0,"Brief matching bounce has no charging orbs or early damage")
	await capture("match-bounce-"+str(portrait))
	check(await until(func(): return g.fx.spell.has("flame_tier")),"Player launches auto attack after the matching bounce")
	check(g.fx.spell.from.distance_to(g._player_point()) < 1,"Auto attack launches from player instead of dice")
	check(g.combat_motion.attacks.has(-1),"Player bobs when firing")
	await capture("auto-"+str(portrait))
	check(await until(func(): return g.view_phase == "ready"),"Roll attacks finish and restore dice interaction")
	check(g.model.roll_attacks.is_empty() and g.model.dice_turn.locked.is_empty(),"All matching dice remain unlocked")
	tap(g,g.DICE_POSITIONS[0])
	check(g.model.dice_turn.selected.is_empty(),"Matching-only roll cannot be selected as a skill")
	# Begin a controlled straight roll after the automatic-only throw.
	g.test_values = [1,2,3,4,5,6]; g._roll()
	check(await until(func(): return g.view_phase == "ready"),"Straight roll returns to selection")
	tap(g,g.DICE_POSITIONS[0])
	tap(g,g.dice_selection.cancel_rect().get_center())
	check(g.model.dice_turn.selected.is_empty(),"Raised Deselect clears tapped dice")
	for face in [1,2,3]: tap(g,g.DICE_POSITIONS[g.model.dice_turn.values.find(face)])
	check(g.dice_selection.preview.dice.size() == 3,"Three connected dice preview Fireball")
	await capture("selection-"+str(portrait))
	tap(g,g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "skill"),"OK summons Fireball")
	check(g._skill_needs_target() and g.skill_bubble.caption.name == "Fireball","Fireball shows its name and asks for a target")
	var rolls_before: int = g.model.dice_turn.rolls_left
	var start: Vector2 = g.skill_bubble.display_center()
	var drop := Vector2(g.fx.canvas_size.x-12,g.DICE_CENTER.y+24)
	check(not g.dice_selection.center_hit(drop) and g.dice_selection.skill_cancel_rect().has_point(drop),"Cancel zone spans beyond the old center target")
	g._handle_click(start); g._handle_motion(drop); g._handle_release(drop)
	check(g.model.pending.is_empty() and g.model.dice_turn.locked.is_empty(),"Wide-zone drop cancels and unlocks skill dice")
	check(g.model.dice_turn.rolls_left == rolls_before,"Cancellation preserves remaining throws")
	for face in [1,2,3]: tap(g,g.DICE_POSITIONS[g.model.dice_turn.values.find(face)])
	tap(g,g.DICE_CENTER)
	check(await until(func(): return g.view_phase == "skill"),"Reformed Fireball is ready")
	g._activate_skill(0)
	check(await until(func(): return g.fx.spell.has("flame_tier")),"Fireball uses new flame visuals")
	check(is_equal_approx(g.fx.spell.scales[0],g.Effects.damage_scale(g.model.attack_damage(g.model.pending,0))),"Fireball visual scale follows its actual target damage")
	await capture("fireball-"+str(portrait))
	check(await until(func(): return g.view_phase == "ready"),"Fireball finishes without ending the turn")
	check(g.model.enemy_status_count(0,g.Status.BURNING) == 2,"Scene impact applies two Burning")
	g.model.hp = 20
	var health_before: int = g.model.hp
	g._end_dice_turn()
	check(await until(func(): return not g.leftover_volley.flights.is_empty()),"Leftovers visibly return toward the player")
	await capture("healing-"+str(portrait))
	check(await until(func(): return g.model.hp > health_before),"Healing occurs before enemy attacks")
	check(await until(func(): return g.view_phase == "ready"),"Healing proceeds through enemies into a new turn")
	# Capture each higher-tier effect, then test real multi-target execution.
	for length in [4,5,6]:
		g.model.pending = g.model.Patterns.classify(range(1,length+1)); g.model.phase = "player"
		g._show_pending_skill(false)
		g._activate_skill(-1)
		check(await until(func(): return g.fx.spell.has("flame_tier") and g.fx.spell.flame_tier == length-2),"Higher tier uses its distinct fire effect")
		while not g.fx.spell.is_empty() and 1-g.fx.spell.life/g.fx.spell.duration < 0.42: await process_frame
		await capture("tier-"+str(length)+"-"+str(portrait))
		var observed := {"life":float(g.fx.spell.get("life",0)),"hp":int(g.model.enemies[0].hp),"ticks":0,"restarted":false}
		check(await until(func():
			if length >= 5:
				var life: float = g.fx.spell.get("life",0)
				if life > observed.life+0.001: observed.restarted = true
				observed.life = life
				if g.model.enemies[0].hp < observed.hp:
					observed.ticks += 1
					observed.hp = g.model.enemies[0].hp
			return g.view_phase in ["ready","wave_reward","over"]),"Higher-tier cast completes")
		if length >= 5:
			check(not observed.restarted,"Sustained damage never restarts the spell visual")
			check(observed.ticks == (5 if length == 5 else 10),"Separate damage ticks land within one spell animation")
		if length == 6: check(g.model.pending.is_empty(),"Brimstone finishes its single-use damage pulses")
	# Exercise the actual casting coroutine after a Magician edit and an early death.
	g.model.begin_round(); g.model.roll_pool(false,[1,2,3,4,5,5])
	while not g.model.roll_attacks.is_empty(): g.model.resolve_roll_attack_step()
	var magician: Dictionary = g.model.tarots.add("magician")
	g.model.tarot_effects.cast(g.model,magician.instance_id,{"die":5,"face":6})
	g.model.enemies.append(g.model.make_enemy(1))
	g.model.enemies[-1].hp = 10000; g.model.enemies[-1].max_hp = 10000
	g.model.enemies[0].hp = 1
	for i in range(6): g.model.dice_turn.select(i)
	g.model.form_selected_skill(); g._show_pending_skill(false)
	g._activate_skill(0)
	check(await until(func(): return g.view_phase == "ready"),"Magician Brimstone returns to interactive dice after an early target death")
	check(g.model.pending.is_empty() and g.model.dice_turn.can_roll(),"Brimstone leaves no executing skill behind")
	g.home_enabled = true; g.menu_open = true
	var returned: Array = []
	g.home_requested.connect(func(): returned.append(true))
	var old_token: int = g.run_id
	g._handle_click(g.MENU_HOME.get_center())
	check(returned.size() == 1 and g.run_id > old_token and not g.menu_open,"Pause Home returns and invalidates running gameplay")
	check(not g.MENU_HOME.intersects(g.MENU_RESUME),"Home and Resume buttons do not overlap")
	g.queue_free(); await process_frame

func run() -> void:
	await scene(false)
	await scene(true)
	print("Flamelings scenes: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
