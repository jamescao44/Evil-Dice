extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Bound every asynchronous flow check so a deadlock fails instead of hanging the suite.
func until(predicate: Callable, label: String, seconds: float = 6.0) -> bool:
	var deadline := Time.get_ticks_msec()+roundi(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	var passed: bool = predicate.call()
	check(passed,label)
	return passed

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/"+name+".png")

## Reroll treasure temporarily covers field controls, then restores the same choice.
func claim_reroll(g) -> void:
	var field_phase: String = g.wave_chest.phase
	var routes: Array = g.model.route_choices.duplicate()
	g.model.reroll_progress = 10
	check(g._can_claim_chest(),"Ready reroll treasure can be claimed during field rewards and route selection")
	g._handle_click(g._chest_milestone_rect(1).get_center())
	check(g.view_phase == "reward" and g.chest.active and not g.wave_chest.visible,"Treasure tap reaches reels and hides underlying field controls")
	check(g.model.reroll_progress == 0 and g.model.next_route.is_empty(),"Claim consumes the meter without choosing a route")
	g._handle_click(g.wave_chest.route_rect(0).get_center())
	check(g.model.next_route.is_empty() and g.wave_chest.phase == field_phase,"Taps on reels cannot activate the hidden field layer")
	g.model.discard_unclaimed_rewards(); g.chest.skip_remaining(); g.crystal_pickup.reset()
	await until(func(): return g.view_phase == "wave_reward" and g.wave_chest.visible,"Treasure completion restores field controls")
	check(g.wave_chest.phase == field_phase and g.model.route_choices == routes,"Original unopened chest or route choices are preserved")

## Drive actual pointer handlers through field chest, auto-opening reels, shop and soul evolution.
func scene(portrait: bool) -> void:
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false); g.speed = 20
	g._restart(3)
	g.model.wave_kind = g.model.WaveRewards.RELIC
	for e in g.model.enemies: e.hp = 0
	g._check_over()
	if not await until(func(): return g.wave_chest.phase == "closed","Clear spawns a closed battlefield chest"): g.queue_free(); return
	var reserved_tier: int = g.model.wave_chest_tier
	await claim_reroll(g)
	check(not g.model.wave_chest_opened and g.model.wave_chest_tier == reserved_tier,"Reroll claim preserves unopened relic chest and its locked tier")
	await capture("field-chest-"+str(portrait))
	g._handle_click(g.wave_chest.chest_rect().get_center())
	check(g.wave_chest.phase == "opening" and not g.chest.active,"Chest shakes before entering relic reels")
	await until(func(): return g.wave_chest.phase == "lift","Relic chest enlarges from its battlefield position")
	if not await until(func(): return g.chest.active,"Relic chest reaches reels"): g.queue_free(); return
	check(g.chest.roll_phase != "closed","Reels open automatically without a second opening tap")
	g.model.discard_unclaimed_rewards(); g.chest.skip_remaining(); g.crystal_pickup.reset()
	if not await until(func(): return g.wave_chest.phase == "routes","Collected relic chest leads to route choice"): g.queue_free(); return
	await claim_reroll(g)
	var shop_index: int = g.model.route_choices.find(g.model.WaveRewards.SHOP)
	check(shop_index >= 0,"Shop is offered after third battle")
	await capture("field-routes-"+str(portrait))
	g._handle_click(g.wave_chest.route_rect(shop_index).get_center())
	if not await until(func(): return g.wave_chest.phase == "keeper","Keeper appears while traveling to shop"): g.queue_free(); return
	await capture("field-keeper-"+str(portrait))
	if not await until(func(): return g.shop_ui.visible,"Keeper transitions into storefront"): g.queue_free(); return
	check(g.model.stage == 3 and g.model.enemies.is_empty(),"Shop occupies wave four without enemies")
	await create_timer(0.3).timeout
	await capture("route-shop-"+str(portrait))
	g._handle_click(g.shop_ui.leave_rect().get_center())
	if not await until(func(): return g.wave_chest.phase == "routes","Leaving shop presents new routes"): g.queue_free(); return
	check(g.model.WaveRewards.SHOP not in g.model.route_choices,"Immediate repeat shop is excluded")
	g._handle_click(g.wave_chest.route_rect(0).get_center())
	if not await until(func(): return g.view_phase == "ready","Chosen next battle accepts input"): g.queue_free(); return
	check(g.model.stage == 4 and not g.model.enemies.is_empty(),"Battle resumes in wave five")
	# A controlled soul route tests the shared direct-resource path and automatic level transaction.
	g.model.wave_kind = g.model.WaveRewards.SOULS
	g.model.souls = 9
	for e in g.model.enemies: e.hp = 0
	g._check_over()
	if not await until(func(): return g.wave_chest.phase == "closed","Soul reward waits for its chest tap"): g.queue_free(); return
	await claim_reroll(g)
	g._handle_click(g.wave_chest.chest_rect().get_center())
	check(g.wave_chest.phase == "opening" and g.model.character_level == 1,"Soul chest shakes before paying its reward")
	await until(func(): return g.wave_chest.phase == "paid","Soul chest pays after its opening shake")
	await process_frame
	check(g.model.character_level >= 2 and g.evolution.active(),"Soul chest automatically triggers transformation")
	await until(func(): return g.soul_pickup.orbs.is_empty(),"Soul orbs arrive before the evolution reveal")
	await create_timer(1.05).timeout
	check(g.evolution.displayed_level >= 2 and g.evolution.form_index(g.evolution.displayed_level) == 0,"Ordinary levels retain the first form")
	await capture("evolution-"+str(portrait))
	if not await until(func(): return g.wave_chest.phase == "routes","Evolution completes before route selection"): g.queue_free(); return
	check(not g.chest.active and g.model.max_hp >= 110,"Soul chest bypasses reels and upgrades maximum health")
	g.model.gain_souls(150)
	if not await until(func(): return not g.evolution.active(),"Multiple upgrades finish their queued transformations"): g.queue_free(); return
	check(g.evolution.displayed_level >= 6 and g.evolution.form_index(g.evolution.displayed_level) == 1,"Level five milestone reveals the second form")
	await capture("final-form-"+str(portrait))
	g._restart()
	check(not g.evolution.active() and g.evolution.displayed_level == 1,"Restart restores starter form")
	g.queue_free(); await process_frame

func run() -> void:
	await scene(false)
	await scene(true)
	print("Route flow: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
