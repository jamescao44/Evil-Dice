extends SceneTree
## Exercise real kills, duplicate-hit protection and wave-clear receipt ordering.
const Run = preload("res://scripts/progression/run_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Find deterministic successful and unsuccessful rolls without changing the production odds.
func seed_for_drop(wanted: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1000):
		rng.seed = seed_value
		if (rng.randi_range(1,8) == 1) == wanted: return seed_value
	return -1

func rules() -> void:
	for role in range(Enemy.ITEMS.size()):
		for elite in [false,true]:
			for drops in [false,true]:
				var m = Run.new(51)
				m.enemies = [Enemy.make(role,1,elite)]
				m.reward_rng.seed = seed_for_drop(drops)
				var state: int = m.reward_rng.state
				var notices: Array = []
				m.tarot_granted.connect(func(item): notices.append(item))
				m.enemies[0].shield = 10
				m.hit_enemy(0,9999)
				m.hit_enemy(0,1)
				check(m.tarots.items.is_empty() and m.reward_rng.state == state,"Shield and surviving hits never roll for tarot")
				m.hit_enemy(0,9999,true)
				if m.enemies[0].get("boss",false):
					check(m.enemies[0].boss_phase == 2 and m.tarots.items.is_empty() and m.reward_rng.state == state,"First boss bar never rolls for tarot")
					m.hit_enemy(0,9999,true)
				check(m.tarots.items.size() == int(drops) and notices.size() == int(drops),"Every enemy type shares the same independent drop roll")
				state = m.reward_rng.state
				m.hit_enemy(0,9999,true)
				check(m.tarots.items.size() == int(drops) and m.reward_rng.state == state,"Corpse hits neither reroll nor award a second card")
	var m = Run.new(52)
	m.reward_rng.seed = seed_for_drop(true)
	m.enemies[0].hp = 5
	m.apply_enemy_status(0,m.Status.BURNING,1)
	m._tick_enemy_statuses(); m._tick_enemy_statuses()
	check(m.tarots.items.size() == 1,"Burning deaths can drop a card exactly once")
	m = Run.new(53)
	m.tarot_effects.banned = m.Tarot.ITEMS.keys().filter(func(id): return id != "world")
	m.reward_rng.seed = seed_for_drop(true)
	m.hit_enemy(0,9999,true)
	check(m.tarots.items.size() == 1 and m.tarots.items[0].id == "world","Enemy drops respect the existing eligible card pool")
	m = Run.new(54)
	m.tarot_effects.banned = m.Tarot.ITEMS.keys()
	m.reward_rng.seed = seed_for_drop(true)
	m.hit_enemy(0,9999,true)
	check(m.tarots.items.is_empty(),"An exhausted pool cannot grant a banned card")
	m = Run.new(55)
	for i in range(16000): m._roll_enemy_tarot_drop()
	check(absf(m.tarots.items.size()/16000.0-0.125) < 0.01,"Seeded drop frequency stays near one in eight")
	m.reset_run(); m.troops = 1
	m.reward_rng.seed = seed_for_drop(true)
	m._crush_troops(1); m._crush_troops(1)
	check(m.tarots.items.size() == 1,"Legacy city troops also roll once per actual death")

func scene(portrait: bool, reduced: bool = false) -> void:
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
	g.reduced = reduced
	var p = g.tarot_ui.pickup
	p.set_process(false)
	for i in range(4):
		g.model.enemies = [Enemy.make(0)]
		g.model.reward_rng.seed = seed_for_drop(true)
		g.model.hit_enemy(0,9999,true)
	check(p.pending.is_empty() and p.drops.cards.size() == 4 and p.active(),"Simultaneous kills first spawn small body drops")
	var drop: Dictionary = p.drops.cards[0]
	check(p.drops.pose(drop).at.is_equal_approx(drop.origin),"Tarot starts at its enemy body")
	g.crystal_pickup.reset(); g.soul_pickup.reset(); g.evolution.reset()
	g._check_over()
	check(g.view_phase == "collecting" and not p.paused(),"Wave clear waits with card receipts able to animate")
	p.advance(0.7)
	await process_frame
	check(g.view_phase == "collecting" and p.drops.cards.size() == 4,"Reward chest waits while dropped cards settle")
	check(is_zero_approx(p.drops.pose(drop).angle) if reduced else absf(p.drops.pose(drop).angle) > 1,"Body card rotation respects reduced effects")
	p.drops.advance(0.16)
	p.advance(0)
	check(p.cards.size() == 3 and p.drops.cards.size() == 1,"Three drops reveal together while excess drops remain on the ground")
	var receipt: Dictionary = p.cards[0]
	var start: Dictionary = p.pose(receipt)
	check(start.at.is_equal_approx(drop.ground) and start.size.is_equal_approx(p.drops.pose(drop).size),"Readable reveal starts at the exact body-drop pose without a teleport")
	p.advance(0.4)
	var revealed: Dictionary = p.pose(receipt)
	check(revealed.flight == 0 and revealed.reveal == 1 and revealed.size.x >= 112,"Face-up card reaches readable size and holds before inventory flight")
	check(is_zero_approx(wrapf(revealed.angle,-PI,PI)),"Revealed tarot is upright")
	check(not p.name_rect(revealed).intersects(p.name_rect(p.pose(p.cards[1]))),"Names remain separate in multi-drop reveals")
	check(p.cards.map(func(card): return card.item.instance_id).all(func(id): return g.model.tarots.find_instance(id) >= 0),"Each reveal shows the actual already-granted tarot")
	g.menu_open = true; p._process(0.5)
	check(receipt.age == 0.4 and p.drops.cards.size() == 1,"Menus pause both revealing and queued body drops")
	g.menu_open = false; p.visible = true
	if "--capture" in OS.get_cmdline_user_args() and not reduced:
		p.queue_redraw(); await process_frame; RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/enemy-tarot-reveal-%s.png" % ("portrait" if portrait else "landscape"))
	p.advance(0.7)
	check(p.pose(receipt).flight > 0 and p.pose(receipt).at.distance_to(g.tarot_ui.icon_rect().get_center()) < revealed.at.distance_to(g.tarot_ui.icon_rect().get_center()),"Only revealed cards shrink and fly into inventory")
	p.advance(0.6); p.advance(0)
	check(p.cards.size() == 1 and p.drops.cards.is_empty() and p.pose(p.cards[0]).flight == 0,"Queued fourth drop receives its own full reveal")
	p.advance(1.7)
	await process_frame
	check(not p.active() and g.view_phase == "wave_reward","Chest appears only after every dropped card has landed")
	check(g.model.tarots.items.size() == 4,"Animation and wave transition never grant duplicates")
	g.model.grant_tarot("magician")
	check(p.pending.size() == 1 and p.drops.cards.is_empty(),"Non-enemy grants preserve the regular reveal receipt")
	g._restart()
	check(not p.active() and g.model.tarots.items.is_empty(),"Restart clears queued cards and collected run inventory")
	g.queue_free(); await process_frame

func run() -> void:
	rules()
	for portrait in [false,true]:
		for reduced in [false,true]: await scene(portrait,reduced)
	print("Enemy tarot drops: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
