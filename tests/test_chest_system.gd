extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Chests = preload("res://scripts/rewards/chest_rules.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Drops = preload("res://scripts/relics/relic_drop_table.gd")
const Rewards = preload("res://scripts/rewards/reward_catalog.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frequency(actual: int, samples: int, expected: float, message: String) -> void:
	check(absf(actual-samples*expected) < 6*sqrt(samples*expected*(1-expected))+5,message)

func resolve(model) -> void:
	model.discard_unclaimed_rewards()
	check(model.close_chest(),"Resolved chest closes")

func model_checks() -> void:
	var model = Run.new(201)
	for n in range(2): model.record_perfect(true)
	model.record_perfect(false)
	check(model.perfect_progress == 0,"Early miss loses incomplete first streak")
	for tier in range(1,4):
		while model.perfect_progress < Chests.THRESHOLDS[tier]: model.record_perfect(true)
		check(model.chest_tier() == tier,"Checkpoint grants tier %d" % tier)
		if tier < 3:
			for n in range(2): model.record_perfect(true)
		model.record_perfect(false)
		check(model.perfect_progress == Chests.THRESHOLDS[tier],"Miss preserves highest earned tier")
	check(model.open_chest().size() == 5 and model.perfect_progress == 0,"Claim empties whole bank")
	resolve(model)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14312
	var tiers := [0,0,0,0]
	var categories := [0,0,0,0,0,0,0,0]
	for n in range(50000):
		tiers[Chests.roll_wave_tier(rng)] += 1
		categories[Rewards.draw_category(rng)] += 1
	for tier in range(4): frequency(tiers[tier],50000,[0.75,0.1875,0.046875,0.015625][tier],"Chained upgrade probability")
	frequency(categories[1],50000,0.7,"70 percent relics")
	frequency(categories[6],50000,0.1,"10 percent shards")
	frequency(categories[7],50000,0.2,"20 percent tarot")
	check(categories[0] == 0 and categories[2] == 0,"No crystals or independent curse category in reward slots")
	for tier in range(4):
		model = Run.new(190+tier)
		var slots := [0,0,0,0,0]
		for n in range(500):
			var combat_state: int = model.rng.state
			model._roll_chest(tier)
			check(model.rng.state == combat_state and model.open_rewards.size() == Chests.COUNTS[tier],"Locked chest preserves combat RNG and count")
			if tier > 0:
				slots[model.guaranteed_slot] += 1
				check(model.chest_relics.has(model.guaranteed_slot),"Guarantee is a real relic")
				check(Catalog.ITEMS[model.chest_relics[model.guaranteed_slot]].rarity >= Chests.MIN_RARITY[tier],"Guaranteed rarity floor")
			var funds: int = model.rubies
			check(model.release_chest_crystals() == Chests.CRYSTALS[tier],"Correct crystal payout")
			check(model.release_chest_crystals() == 0 and model.rubies == funds+Chests.CRYSTALS[tier],"Payout is idempotent")
			var state: int = model.reward_rng.state
			var outcome: Array = model.open_rewards.duplicate()
			check(model.open_chest() == outcome and model.reward_rng.state == state,"Reopening never rerolls")
			resolve(model)
			check(model.reward_rng.state == state,"Skipping leaves outcome RNG unchanged")
		if tier > 1:
			for slot in range(Chests.COUNTS[tier]): frequency(slots[slot],500,1.0/Chests.COUNTS[tier],"Guarantee slot uniform")
	# Reveal currency in tier increments without leaking future upgrades or losing fractions.
	for vessel in [false,true]:
		model = Run.new(512)
		if vessel: model.acquire_relic("soul_vessel")
		model._roll_chest(3)
		for tier in range(4):
			model.release_chest_crystals(tier)
			var expected: int = floori(Chests.CRYSTALS[tier]*(1.15 if vessel else 1)+0.0001)
			check(model.rubies == expected and model.chest_crystals == expected,"Only revealed tier pays crystals, including carried bonus fractions")
			check(model.release_chest_crystals(tier) == 0 and model.release_chest_crystals(0) == 0,"Repeated or stale tier cannot pay twice")
		check(model.chest_crystals_claimed and model.release_chest_crystals() == 0,"Final upgrade fully settles crystal payout")
	# Floor promotion preserves the 1% legendary weight instead of conditioning on high rarity.
	for floor_rarity in [1,2]:
		var counts := [0,0,0,0,0]
		for n in range(20000): counts[Catalog.ITEMS[Drops.draw(rng,Catalog.ITEMS.keys(),Catalog.RARITY_WEIGHTS,floor_rarity)].rarity] += 1
		frequency(counts[3],20000,0.01,"Guarantee keeps legendary probability at 1 percent")
		frequency(counts[4],20000,0.01,"Guarantee keeps cursed probability at 1 percent")
		check(counts[0] == 0 and (floor_rarity == 1 or counts[1] == 0),"Low tiers promoted to floor")
	var early = Run.new(170)
	var late = Run.new(170)
	late.stage = 18
	check(late.relic_drop_weights() == Catalog.RARITY_WEIGHTS,"Run sources use fixed rarity weights")
	check(Drops.weights_for_wave(20)[3] > 17,"Future shop curve remains available")
	for tier in range(4):
		check(early._roll_chest(tier) == late._roll_chest(tier) and early.chest_relics == late.chest_relics,"Identical chest odds at every wave")
		resolve(early); resolve(late)
	model = Run.new(91)
	for enemy in model.enemies: enemy.hp = 0
	check(model.begin_wave_reward() and not model.advance_wave(),"Pending wave chest blocks progression")
	var locked: Array = model.open_rewards.duplicate()
	var state: int = model.reward_rng.state
	check(model.begin_wave_reward() and model.open_rewards == locked and model.reward_rng.state == state,"Repeated wave entry cannot reroll")
	check(not model.finish_wave_reward() and model.begin_tarot_reward("wave").is_empty(),"Cannot skip chest or buy before opening")
	model.open_wave_chest()
	resolve(model)
	model.rubies = 29
	check(not model.can_buy_wave_tarot() and model.begin_tarot_reward("wave").is_empty() and model.rubies == 29,"Cannot overspend")
	model.rubies = 30
	var cards: Array = model.begin_tarot_reward("wave")
	check(cards.size() == 3 and model.rubies == 0 and model.wave_tarot_bought,"One paid tarot draw deducts 30")
	check(not model.finish_wave_reward() and model.begin_tarot_reward("wave").is_empty(),"Draw cannot be bought twice or abandoned")
	check(not model.choose_tarot(1).is_empty() and model.tarots.items.size() == 1,"Buy draw keeps chosen card")
	model.rubies = 500
	check(not model.can_buy_wave_tarot() and model.finish_wave_reward() and model.advance_wave(),"One draw per wave, then continue")
	model.reset_run()
	check(model.wave_chest_stage == -1 and model.rubies == 0 and model.open_rewards.is_empty(),"Reset clears chest transaction")

func frame_until(predicate: Callable, seconds: float = 8) -> bool:
	var deadline: int = Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	check(predicate.call(),"Scene reaches expected state within deadline")
	return predicate.call()

func tap(game, at: Vector2) -> void:
	game._handle_click(at)
	game._handle_release(at)

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/new-chests-"+label+".png")

func scene_checks(script, portrait: bool) -> void:
	var game = script.new()
	root.add_child(game)
	game.muted = true
	game.speed = 3
	await process_frame
	var label: String = "portrait" if portrait else "landscape"
	game.model.perfect_progress = 15
	game.chest.playback_speed = 1
	game._reward_sequence(3)
	if not await frame_until(func(): return game.chest.visible): game.free(); return
	var state: int = game.model.reward_rng.state
	var outcomes: Array = game.model.open_rewards.duplicate()
	check(game.chest.roll_phase == "closed" and game.model.rubies == 0,"Banked chest waits for a click without paying early")
	tap(game,game.chest.closed_rect().get_center())
	check(game.chest.audio.ultra_started and game.chest.audio.payout.playing,"Opening a banked Ultra starts its finale immediately")
	check(game.chest.active and game.chest.roll_phase == "settling" and game.model.open_rewards == outcomes and game.model.reward_rng.state == state,"Ultra automatically starts its locked reveal without changing prizes")
	await frame_until(func(): return game.chest.did_open)
	check(game.model.rubies == 100 and game.crystal_pickup.pending_total == 100 and game.crystal_pickup.gems.size() >= 30,"Skipping still gives one dramatic crystal burst")
	check(game.crystal_pickup.z_index > game.chest.z_index,"Chest gems render above reward overlay")
	for i in range(5):
		var rect: Rect2 = game.chest.reel_rect(i)
		check(Rect2(Vector2.ZERO,game.fx.canvas_size).encloses(rect),"Reels fit viewport")
		check(rect.size.y > rect.size.x,"Tall scrolling window")
		check(is_equal_approx(rect.get_center().y,game.chest.reel_rect(0).get_center().y),"All rewards share one horizontal row")
		if i > 0: check(not rect.intersects(game.chest.reel_rect(i-1)),"Reward slots never overlap")
	await create_timer(0.2).timeout
	await capture(label+"-burst")
	if not await frame_until(func(): return game.crystal_pickup.pending_total == 0): game.free(); return
	if not await frame_until(func(): return not game.chest.active): game.free(); return
	await capture(label+"-rewards")
	var slot: int = game.model.guaranteed_slot
	tap(game,game.chest.reel_rect(slot).get_center())
	check(game.relic_ui.pickup.active,"Relic pickup still animates into inventory")
	await frame_until(func(): return not game.relic_ui.pickup.active)
	tap(game,game.chest.skip_rect().get_center())
	await frame_until(func(): return game.view_phase == "ready")
	check(game.model.rubies == 100 and game.model.reward_history.size() == 1,"Partial pickup retains crystals and only claimed item")
	# Real wave flow with three successful upgrades and no timing-dependent rewards.
	game._restart()
	var rng := RandomNumberGenerator.new()
	for seed_value in range(10000):
		rng.seed = seed_value
		if Chests.roll_wave_tier(rng) == 3:
			game.model.reward_rng.seed = seed_value
			break
	for enemy in game.model.enemies: enemy.hp = 0
	game._check_over()
	if not await frame_until(func(): return game.chest.visible): game.free(); return
	state = game.model.reward_rng.state
	outcomes = game.model.open_rewards.duplicate()
	check(game.model.wave_chest_tier == 3 and game.model.open_rewards.size() == 5,"Upgrade chain and rewards locked together")
	check(game.chest.upgrade_mode and game.chest.tier == 0 and game.chest.roll_phase == "closed" and not game.wave_chest.visible,"Wave starts with a closed Normal Chest")
	await capture(label+"-closed")
	tap(game,game.chest.closed_rect().get_center())
	await frame_until(func(): return game.chest.did_open)
	check(game.model.rubies == 30,"Opening Normal does not leak the locked Ultra payout")
	game.chest._process(8)
	check(game.chest.active and game.chest.announced == 0,"Wave rewards keep rolling until the player stops them")
	await capture(label+"-normal-rolling")
	for tier in range(1,4):
		tap(game,Vector2(10,10))
		check(game.chest.tier == tier and game.chest.roll_phase == ("settling" if tier == 3 else "upgrading") and game.chest.active,"Any screen tap reveals one upgrade while rewards keep rolling")
		tap(game,game.fx.canvas_size-Vector2(10,10))
		check(game.chest.tier == tier,"Rapid second tap cannot skip an upgrade impact")
		await frame_until(func(): return game.chest.upgrade_age >= game.chest.UPGRADE_BEAT)
		check(game.chest.visible_reel_count() == Chests.COUNTS[tier] and game.model.rubies == Chests.CRYSTALS[tier],"Upgrade adds reward reels and only its crystal difference")
		check(game.model.reward_rng.state == state and game.model.open_rewards == outcomes,"Stop timing leaves committed prizes and RNG untouched")
		for i in range(game.chest.visible_reel_count()):
			check(Rect2(Vector2.ZERO,game.fx.canvas_size).encloses(game.chest.reel_rect(i)),"Expanded reels remain inside viewport")
			if i > 0: check(not game.chest.reel_rect(i).intersects(game.chest.reel_rect(i-1)),"Expanded horizontal reels do not overlap")
		await capture(label+"-upgrade-"+str(tier))
	check(game.chest.roll_phase == "settling" and game.chest.audio.payout.playing,"Ultra automatically plays level 3 and settles without another tap")
	await frame_until(func(): return not game.chest.active)
	for i in range(outcomes.size()): check(game.chest._symbol_at(i,roundi(game.chest.travel(i))) == game.chest.rewards[i],"Each stopped reel shows its locked prize")
	tap(game,game.chest.skip_rect().get_center())
	await frame_until(func(): return game.wave_chest.phase == "after")
	check(game.model.rubies == 100 and not game.model.wave_reward_resolved,"Wave chest leaves optional purchase screen")
	await capture(label+"-purchase")
	tap(game,game.wave_chest.tarot_rect().get_center())
	check(game.model.rubies == 70 and game.tarot_ui.ceremony.active(),"Purchase opens existing tarot ceremony")
	# Complete through the model + ceremony signal adapter, retaining the existing ceremony tests.
	game.tarot_ui._collect(0)
	game.tarot_ui.ceremony.reset()
	check(game.model.tarots.items.size() == 1 and not game.model.can_buy_wave_tarot(),"Paid tarot is kept, second purchase blocked")
	tap(game,game.wave_chest.action_rect().get_center())
	await frame_until(func(): return game.model.stage == 1,12)
	check(game.model.rubies == 70 and not game.wave_chest.visible,"Continue advances once with balance preserved")
	game._restart()
	check(not game.wave_chest.visible and game.crystal_pickup.pending_total == 0,"Restart clears presentation")
	game.chest.set_process(false)
	for target in [0,1,2]:
		game.model._roll_chest(target)
		game.view_phase = "reward"
		game.chest.start(game.model.open_rewards,game.fx.canvas_size,game.description_font,false,[],target,true)
		game.chest.open_chest()
		var reward_state: int = game.model.reward_rng.state
		for attempt in range(target+1):
			game.chest._process(4)
			check(game.chest.active,"No automatic stop before another tap")
			tap(game,Vector2(10,10))
		game.chest._process(3)
		check(not game.chest.active and game.chest.roll_phase == "complete" and game.chest.tier == target,"First failed upgrade settles the reward reels at the locked tier")
		check(game.model.reward_rng.state == reward_state,"Stop never consumes reward RNG")
		check(game.model.rubies == Chests.CRYSTALS[target],"Failed upgrade keeps the correct total payout")
		game._restart()
	game._restart()
	game.free()
	await process_frame

func run() -> void:
	GameText.set_language("zh_CN",false)
	model_checks()
	await scene_checks(Battle,false)
	await scene_checks(Portrait,true)
	await create_timer(0.15).timeout
	print("Chest system: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
