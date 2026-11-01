extends SceneTree
## Shops are mandatory intermissions: all 24 battles, rewards and level checkpoints survive.
const Run = preload("res://scripts/progression/run_rules.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")

## Collect every offered relic, replacing slot one when necessary; never skip prizes.
func clear_reward(m) -> void:
	for enemy in m.enemies: enemy.hp = 0
	check(m.begin_wave_reward(),"A defeated battle grants exactly one reward chest")
	check(m.offer_routes().is_empty(),"Reward must be collected before any shop or route")
	if m.wave_kind == m.WaveRewards.RELIC:
		m.open_wave_chest()
		for slot in range(m.open_rewards.size()):
			check(not m.claim_reward(slot,0 if m.relics.items.size() >= 10 else -1).is_empty(),"Every relic prize can be claimed")
		m.close_chest()
	else: m.claim_wave_resource()
	check(m.finish_wave_reward(),"Collected reward closes normally")

func progression() -> void:
	for seed_value in range(8):
		var m = Run.new(seed_value); var shops := 0
		var campaign = Run.Campaign.new()
		for stage in range(Run.PLAYABLE_WAVES):
			check(m.stage == stage and not m.at_shop and not m.enemies.is_empty(),"Every authored battle is encountered in order")
			clear_reward(m)
			if m.Waves.has_shop_after(stage):
				var before: Array = [m.stage,m.wave_kind,m.character_level,m.souls,m.reroll_progress,m.relic_reward_stage,m.route_history.duplicate()]
				var rng_state: int = m.reward_rng.state
				check(m.offer_routes() == [m.WaveRewards.SHOP] and m.offer_routes() == [m.WaveRewards.SHOP] and m.reward_rng.state == rng_state,"Shop is the sole fixed route, without rerolling reward randomness")
				check(not m.choose_route(1) and m.choose_route(0) and m.advance_wave(),"Only the shop entrance is selectable")
				check(m.at_shop and m.enemies.is_empty() and m.stage == stage and m.wave_kind == before[1],"Shop never consumes a wave or changes its reward identity")
				check(m.offer_routes().is_empty() and not m.advance_wave() and not m.begin_wave_reward(),"Unvisited shop cannot be bypassed or issue another chest")
				check(m.shop.open(m) and not m.shop.open(m),"Shop stock opens exactly once")
				check(m.offer_routes().is_empty(),"Battle route choices wait until leaving the shop")
				m.shop.close(); shops += 1
				check([m.stage,m.wave_kind,m.character_level,m.souls,m.reroll_progress,m.relic_reward_stage,m.route_history] == before,"A free shop visit preserves progression and reward streaks")
				check(not m.shop.open(m) and not m.begin_wave_reward(),"Closed stop cannot reopen or duplicate rewards")
			if m.outcome() == "victory":
				check((stage+1)%8 == 0,"Boss completion still ends each eight-battle level")
				if m.has_next_level():
					check(campaign.complete(m),"Level completion saves the collected build")
					campaign.start(m)
				continue
			var routes: Array = m.offer_routes()
			check(routes.size() == 2 and routes[0] != routes[1] and m.WaveRewards.SHOP not in routes,"Two battle rewards appear after leaving a shop or an ordinary wave")
			if m.route_history.size() >= 2 and m.route_history[-1] == m.route_history[-2]: check(m.route_history[-1] not in routes,"Shop stops do not break the two-reward streak limit")
			check(m.choose_route(seed_value%2) and m.advance_wave() and m.stage == stage+1,"Next reward route advances exactly one battle")
		check(shops == 6,"Each of three levels contains exactly two shop stops")

func cli() -> void:
	var s = Session.new(83)
	s.model.load_debug_wave(3); s.model.wave_kind = s.model.WaveRewards.BLOOD_GEMS
	for enemy in s.model.enemies: enemy.hp = 0
	s._settle()
	check(s.command({"action":"open"}).ok,"CLI claims the checkpoint battle reward")
	var state: Dictionary = s.snapshot()
	check(state.phase == "routes" and state.routes == ["shop"],"CLI presents the sole shop route")
	check(s.command({"action":"route","slot":1}).ok and s.snapshot().phase == "shop" and s.model.stage == 2,"CLI shop entry preserves the current battle number")
	check(s.command({"action":"leave"}).ok and s.snapshot().phase == "routes","CLI returns to reward routes after shop")
	check(s.command({"action":"route","slot":1}).ok and s.model.stage == 3 and not s.model.enemies.is_empty(),"CLI proceeds to the previously unskipped fourth battle")

	for signal_info in s.model.get_signal_list():
		for connection in s.model.get_signal_connection_list(signal_info.name): s.model.disconnect(signal_info.name,connection.callable)

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+10000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func scene(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 30; g.set_process_input(false)
	g.model.load_debug_wave(3); g.model.wave_kind = g.model.WaveRewards.BLOOD_GEMS
	clear_reward(g.model)
	g._advance_wave()
	check(await until(func(): return g.wave_chest.phase == "routes"),"Scene displays shop-only route")
	check(g.wave_chest.options == ["shop"],"No alternative path can skip the scheduled shop")
	g._handle_click(g.wave_chest.route_rect(0).get_center())
	check(await until(func(): return g.shop_ui.visible and g.shop_ui.modulate.a >= 0.99),"Keeper transition reaches the shop page")
	check(g.model.stage == 2 and g.model.at_shop,"Visual transition keeps the completed battle index")
	g._handle_click(g.shop_ui.leave_rect().get_center())
	check(await until(func(): return g.wave_chest.phase == "routes"),"Leaving shop displays battle choices")
	check(g.wave_chest.options.size() == 2 and "shop" not in g.wave_chest.options,"Next battle reward is chosen after shopping")
	g._handle_click(g.wave_chest.route_rect(0).get_center())
	check(await until(func(): return g.model.stage == 3 and g.view_phase == "ready"),"Fourth battle starts after one further transition")
	g.queue_free(); await process_frame

func run() -> void:
	progression(); cli()
	await scene(false); await scene(true)
	print("Shop checkpoints: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
