extends SceneTree
const Rewards = preload("res://scripts/progression/wave_rewards.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Chest = preload("res://scripts/rewards/reward_chest.gd")
const BattlefieldReward = preload("res://scripts/rewards/battlefield_reward.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")

## Check economy, input and reward presentation contracts independently of animation randomness.
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func economy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 391
	for kind in [Rewards.BLOOD_GEMS,Rewards.SOULS]:
		var scale: int = 10 if kind == Rewards.BLOOD_GEMS else 1
		var tails := [0,0]
		var halves := [0,0]
		for i in range(100000):
			var amount: int = Rewards.amount(rng,kind)
			check(amount >= 10*scale and amount <= 40*scale,"Direct reward stays in its inclusive range")
			if amount >= 20*scale: tails[0] += 1
			if amount >= 30*scale: tails[1] += 1
			if amount < 20*scale: halves[0 if amount < 15*scale else 1] += 1
		check(abs(tails[0]-10000) < 600 and abs(tails[1]-1000) < 190,"Cumulative 10% and 1% tails hold")
		check(halves[0] > halves[1],"Larger payouts within a band are logarithmically rarer")
	var m = Run.new(14)
	m.acquire_relic("soul_vessel")
	m.gain_souls(20)
	m.gain_blood_gems(100)
	check(m.souls == 20 and m.blood_gems == 115,"Souls are separate from blood gems and their relic bonus")
	m.gain_souls(-5)
	check(m.souls == 20,"Negative grants cannot spend souls")
	for i in range(150):
		m._roll_chest(i%4)
		check(m.open_rewards.all(func(c): return c in [m.Rewards.Category.RELIC,m.Rewards.Category.CURSE]),"Every chest prize is a real relic")
		check(m.chest_tarots.is_empty(),"Chests do not reserve tarot draws")
		m.discard_unclaimed_rewards(); m.close_chest()
	m.reset_run()
	check(m.souls == 0 and m.blood_gems == 0,"Both currencies reset with the run")
	var counts := {Rewards.BLOOD_GEMS:0,Rewards.RELIC:0,Rewards.SOULS:0}
	for i in range(3000):
		m.reset_run()
		check(m.wave_kind in Rewards.BATTLE_TYPES and m.wave_kind != Rewards.SHOP,"First wave is always a battle with one of three reward types")
		counts[m.wave_kind] += 1
		check(m.route_history == [m.wave_kind],"First random reward is recorded for consecutive-route limits")
	for count in counts.values(): check(absi(count-1000) < 130,"Each first-wave reward appears equally often")

## Exercise complete runs so shop spacing and reward streaks include actual route visits.
func progression() -> void:
	for seed_value in range(80):
		var m = Run.new(seed_value)
		var last_shop := -100
		for stage in range(Run.PLAYABLE_WAVES):
			check(m.stage == stage,"Every destination, including shops, consumes one wave")
			if m.wave_kind == Rewards.SHOP:
				check(m.enemies.is_empty() and m.shop.open(m),"Shop wave has no enemies and opens directly")
				check(stage-last_shop >= 3,"Two battle waves separate shop visits")
				last_shop = stage
				check(not m.begin_wave_reward(),"Shop wave does not create a free reward chest")
				m.shop.close()
			else:
				for e in m.enemies: e.hp = 0
				check(m.begin_wave_reward(),"Each defeated battle creates one reward")
				if m.wave_kind == Rewards.RELIC:
					m.open_wave_chest(); m.discard_unclaimed_rewards(); m.close_chest()
				else:
					check(m.claim_wave_resource() > 0 and m.claim_wave_resource() == 0,"Direct reward is credited exactly once")
				check(m.finish_wave_reward() and not m.begin_wave_reward(),"Finished chest cannot reopen")
			if stage == Run.PLAYABLE_WAVES-1:
				check(m.outcome() == "victory" and m.offer_routes().is_empty(),"Final destination ends run without extra routes")
				continue
			var choices: Array = m.offer_routes()
			var rng_state: int = m.reward_rng.state
			check(choices.size() == 2 and choices[0] != choices[1],"Two distinct route choices")
			check(m.offer_routes() == choices and rng_state == m.reward_rng.state,"Repainting route choices cannot reroll them")
			if stage == 2: check(Rewards.SHOP in choices,"First shop is guaranteed in choices after wave three")
			if stage < last_shop+2: check(Rewards.SHOP not in choices,"Shop cannot return before two battles")
			if m.route_history.size() >= 2 and m.route_history[-1] == m.route_history[-2]: check(m.route_history[-1] not in choices,"No third consecutive reward of the same type")
			var index: int = choices.find(Rewards.SHOP) if Rewards.SHOP in choices else seed_value%2
			var hp_capacity: int = m.max_hp
			check(m.choose_route(index) and not m.choose_route(1-index),"Route selection commits once")
			check(m.advance_wave() and not m.advance_wave(),"Advance requires a fresh committed route")
			check(m.max_hp == hp_capacity,"Waves no longer grant maximum health")

## Automatic soul thresholds preserve leftovers, fill new HP capacity and scale only character base.
func leveling() -> void:
	var m = Run.new(83)
	var skill = m.Patterns.classify([1,2,3])
	var base: float = m.attack_base_with_bonus(skill,0)
	var events: Array = []
	m.character_leveled.connect(func(level): events.append(level))
	m.hp = 70
	m.gain_souls(29)
	check(m.character_level == 1 and m.level_cost() == 30,"Below threshold does not level")
	m.gain_souls(1)
	check(m.character_level == 2 and m.souls == 0 and m.max_hp == 150 and m.hp == 120,"First upgrade is automatic and fills only added capacity")
	check(is_equal_approx(m.attack_base_with_bonus(skill,7),base*1.5+7*3.6),"Leveling scales character base by 1.5 without scaling flat relic bonuses")
	m.gain_souls(55)
	check(m.character_level == 3 and m.souls == 5 and m.level_cost() == 0,"Final upgrade spends fifty and retains spare souls")
	check(m.max_hp == 225 and m.hp == 195 and is_equal_approx(m.attack_base_with_bonus(skill,0),base*2.25),"Two upgrades compound health and damage")
	check(events == [2,3],"Every evolution emits one ordered visual notification")
	m.gain_souls(500)
	check(m.character_level == 3 and m.souls == 505,"Maximum level keeps excess souls")
	m.reset_run()
	check(m.character_level == 1 and m.max_hp == 100 and m.souls == 0,"Run restart resets all leveling")

func presentation(portrait: bool) -> void:
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.set_process(false)
	g.view_phase = "wave_reward"
	for child in g.get_children(): child.set_process(false)
	var ui = BattlefieldReward.new()
	ui.battle = g
	g.add_child(ui)
	check(g.chest.scroll_symbols.all(func(i): return g.chest.symbols[i].has("relic_id")),"Cosmetic reels exclude tarot and summon shards")
	ui.present_routes([Rewards.BLOOD_GEMS,Rewards.SOULS])
	for i in range(2): check(g.ARENA.encloses(ui.route_rect(i)),"Route controls stay on the battlefield")
	check(not ui.route_rect(0).intersects(ui.route_rect(1)),"Route controls never overlap")
	var selected: Array = []
	ui.route_pressed.connect(func(i): selected.append(i))
	ui.click(ui.route_rect(0).get_center()); ui.click(ui.route_rect(1).get_center())
	check(selected == [0],"Double taps choose only one route")
	ui.present_chest(Rewards.SOULS)
	var opens: Array = []
	ui.chest_pressed.connect(func(): opens.append(true))
	ui.click(ui.chest_rect().get_center()); ui.click(ui.chest_rect().get_center())
	check(opens.size() == 1,"A battlefield chest opens once")
	ui.present_routes([Rewards.RELIC,Rewards.SHOP])
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://test-output/routes-"+("portrait" if portrait else "landscape")+".png")
	g.queue_free()
	await process_frame

func run() -> void:
	economy()
	progression()
	leveling()
	await presentation(false)
	await presentation(true)
	print("Wave rewards: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
