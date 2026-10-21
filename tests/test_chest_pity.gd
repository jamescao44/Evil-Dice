extends SceneTree
const Rules = preload("res://scripts/rewards/chest_rules.gd")
const Pity = preload("res://scripts/rewards/chest_pity.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Chest = preload("res://scripts/rewards/reward_chest.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func seed_for(outcomes: Array) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(10000):
		rng.seed = value
		var matches: bool = true
		for outcome in outcomes:
			if (rng.randf() < Rules.UPGRADE_CHANCE) != outcome: matches = false
		if matches: return value
	return -1

func run() -> void:
	var rng := RandomNumberGenerator.new()
	var fail_seed: int = seed_for([false,false,false])
	var partial_seed: int = seed_for([true,false])
	check(fail_seed >= 0 and partial_seed >= 0,"Deterministic random success/failure fixtures exist")
	var pity = Pity.new()
	# Even if every random chance fails, each fourth tier attempt must advance.
	for number in range(1,129):
		rng.seed = fail_seed
		var tier: int = pity.roll(rng)
		var expected: int = 3 if number%64 == 0 else 2 if number%16 == 0 else 1 if number%4 == 0 else 0
		check(tier == expected,"Worst-case chest %d follows the 4/16/64 bound" % number)
	check(pity.misses == [0,0,0],"Ultra resets all three successful tier counters")
	pity.misses = [2,1,2]
	rng.seed = partial_seed
	check(pity.roll(rng) == 1 and pity.misses == [0,2,2],"Natural success resets only its tier; one failure advances; unreached tier stays")
	check(pity.last_misses == [2,1,2],"Presentation keeps the counters from before the committed outcome")
	pity.misses = [3,3,3]
	var before_rng: int = rng.state
	check(pity.roll(rng) == 3 and rng.state == before_rng,"Ready pity guarantees the full chain without random rerolls")

	var model = Run.new(38)
	model.chest_pity.misses = [2,2,2]
	model.reset_run()
	check(model.chest_pity.misses == [2,2,2],"Restart keeps accumulated pity")
	model.load_debug_wave(20)
	check(model.chest_pity.misses == [2,2,2],"Debug wave changes also keep pity")
	model.chest_pity.misses = [3,3,3]
	model.open_debug_chest()
	check(model.opened_chest_tier == 3 and model.chest_pity.misses == [0,0,0],"Debug chest uses the real shared guarantee")
	before_rng = model.reward_rng.state
	check(model.open_debug_chest().is_empty() and model.chest_pity.misses == [0,0,0] and model.reward_rng.state == before_rng,"A pending chest cannot consume another pity attempt")
	model.discard_unclaimed_rewards()
	model.close_chest()
	model.chest_pity.misses = [2,1,2]
	model.reroll_progress = 3
	model.open_chest()
	check(model.chest_pity.misses == [2,1,2],"Fixed-tier Perfect treasure does not consume upgrade pity")
	model.discard_unclaimed_rewards()
	model.close_chest()
	model.reset_run()
	model.chest_pity.misses = [3,3,3]
	model.wave_kind = model.WaveRewards.RELIC
	for enemy in model.enemies: enemy.hp = 0
	check(model.begin_wave_reward() and model.wave_chest_tier == 3,"Wave chest uses all ready tier guarantees")
	check(model.chest_pity.misses == [0,0,0] and model.chest_pity.last_misses == [3,3,3],"Wave outcome commits counters before presentation")
	before_rng = model.reward_rng.state
	model.begin_wave_reward()
	model.open_wave_chest()
	model.release_chest_crystals()
	model.discard_unclaimed_rewards()
	model.close_chest()
	check(model.chest_pity.misses == [0,0,0] and model.reward_rng.state == before_rng,"Reentry, opening, crystal payout and skipping never advance pity twice")

	# Separate temporary save: never read or alter the player's real pity file.
	var path: String = "user://test_chest_pity_%d.cfg" % OS.get_process_id()
	pity.configure(path)
	pity.misses = [1,2,3]
	rng.seed = fail_seed
	pity.roll(rng)
	var reloaded = Pity.new()
	reloaded.configure(path)
	check(reloaded.misses == [2,2,3],"New instance reloads all three saved counters")
	rng.seed = partial_seed
	reloaded.roll(rng)
	pity.configure(path)
	check(pity.misses == [0,3,3],"Later sessions save successful resets and new failures")
	var invalid := ConfigFile.new()
	invalid.set_value("chest_upgrades","0",-5)
	invalid.set_value("chest_upgrades","1",99)
	invalid.set_value("chest_upgrades","2","invalid")
	invalid.save(path)
	pity.configure(path)
	check(pity.misses == [0,3,0],"Malformed counter entries are bounded or safely defaulted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for scene_path in ["res://scenes/battle.tscn","res://scenes/battle_portrait.tscn"]:
		var scene = load(scene_path).instantiate()
		check(scene.chest_pity_path == "user://chest_pity.cfg","Both shipped layouts use the same persistent save")
		scene.free()

	var chest = Chest.new()
	root.add_child(chest)
	chest.set_process(false)
	for canvas in [Vector2(1280,800),Vector2(804,1748)]:
		root.content_scale_size = Vector2i(canvas)
		root.size = Vector2i(canvas/2) if canvas.y > canvas.x else Vector2i(canvas)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for language in ["en","zh_CN"]:
			GameText.set_language(language,false)
			chest.start([6,6,6,6,6],canvas,GameText.description_font(),false,[],3,true,[1,3,2])
			check(chest.upgrade_hint() == GameText.text("25% CHANCE TO UPGRADE"),"Closed chest hides the attempt count")
			var hint_width: float = chest.font.get_string_size(chest.upgrade_hint(),HORIZONTAL_ALIGNMENT_LEFT,-1,24 if canvas.y > canvas.x else 18).x
			check(hint_width < canvas.x-64,"Attempt caption fits in both layouts and languages")
			await capture(chest,language+"-"+str(int(canvas.x))+"-attempt")
			chest.tier = 1
			check(chest.upgrade_hint() == GameText.text("25% CHANCE TO UPGRADE"),"Ready pity stays hidden")
			await capture(chest,language+"-"+str(int(canvas.x))+"-guaranteed")
			chest.tier = 2
			check(chest.upgrade_hint() == GameText.text("25% CHANCE TO UPGRADE"),"Reached tiers keep pity hidden")
			chest.tier = 3
			check(chest.upgrade_hint().is_empty(),"Ultra never advertises a further upgrade")
			chest.cancel()
	chest.free()
	print("Chest pity: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture(chest, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	chest.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/chest-pity-"+label+".png")
