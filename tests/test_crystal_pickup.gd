extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func model_checks() -> void:
	for role in range(Enemy.ITEMS.size()):
		for elite in [false,true]:
			var m = Run.new(51)
			m.enemies = [Enemy.make(role,1,elite)]
			var drops: Array = []
			m.enemy_crystals_dropped.connect(func(target, amount): drops.append([target,amount]))
			var expected: int = (15 if elite else 10) if role in Enemy.SPECIAL else (8 if elite else 5)
			m.enemies[0].shield = 10
			m.hit_enemy(0,9999)
			check(m.rubies == 0 and drops.is_empty(),"Shield break grants no crystals")
			m.hit_enemy(0,9999)
			check(m.rubies == expected and drops == [[0,expected]],"Kill awards the correct role/elite amount exactly once")
			m.hit_enemy(0,9999,true)
			check(m.rubies == expected and drops.size() == 1,"Corpse hits cannot duplicate drops")
	var m = Run.new(52)
	m.enemies = [Enemy.make(0),Enemy.make(1)]
	m.acquire_relic("soul_vessel")
	m.hit_enemy(0,9999,true); m.hit_enemy(1,9999,true)
	check(m.rubies == 11 and is_equal_approx(m.soul_crystal_remainder,0.5),"Soul Vessel applies with fractional carry across kills")
	m = Run.new(53)
	m.enemies = [Enemy.make(0),Enemy.make(1,1,true),Enemy.make(3),Enemy.make(4,1,true)]
	m.begin_round(); m.set_test_roll([6,6,6]); m.apply_player()
	check(m.rubies == 38 and m.living().is_empty(),"666 grants each defeated enemy's reward including protected allies")
	m = Run.new(54)
	m.enemies[0].hp = 5
	m.apply_enemy_status(0,m.Status.BURNING,1)
	m._tick_enemy_statuses()
	check(m.rubies == 5,"Burning kills grant currency")
	m._tick_enemy_statuses()
	check(m.rubies == 5,"Later status ticks cannot repeat a kill reward")
	m = Run.new(55)
	m.begin_round()
	var card: Dictionary = m.tarots.add("death")
	m.tarot_effects.cast(m,card.instance_id,{"target":0})
	check(m.rubies == 5,"Tarot execution grants currency")
	m = Run.new(56)
	m.load_debug_wave(20); m.troops = 4
	var drops: Array = []
	m.enemy_crystals_dropped.connect(func(target, amount): drops.append([target,amount]))
	m.begin_round(); m.set_test_roll([4,4,4]); m.apply_player()
	check(m.rubies == 20 and m.troops == 0 and drops.size() == 4,"City area skills pay for every crushed troop")
	m.begin_round(); m.set_test_roll([4,4,4]); m.apply_player()
	check(m.rubies == 20,"City damage without troops creates no phantom drops")
	m.troops = 2; m.statuses[m.Status.MIGHT].apply(2)
	m.begin_round(); m.set_test_roll([3,3,1]); m.apply_player()
	check(m.rubies == 30 and m.troops == 0,"Reapplied attack buff pays for troops crushed by its shockwave")
	m.reset_run()
	check(m.rubies == 0 and m.soul_crystal_remainder == 0,"Restart clears earned currency")
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/evil-crystals-"+label+".png")
func run() -> void:
	model_checks()
	for portrait in [false,true]:
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g); g.muted = true; g.set_process(false)
		var p = g.crystal_pickup; p.set_process(false)
		g.model.hit_enemy(0,9999,true); g._sync_corpses()
		check(g.model.rubies == 5 and p.pending_total == 5 and p.gems.size() == 3,"One kill starts a few gems, holding only the displayed balance")
		var age: float = p.gems[0].age
		g.debug_open = true; p._process(0.5)
		check(not p.visible and p.gems[0].age == age,"Debug hides and pauses the pickup layer")
		g.debug_open = false; p._process(0.72)
		var gem: Dictionary = p.gems[0]
		check(p.visible and p.pose(gem).at == gem.ground and p.pose(gem).grounded,"Crystals rest visibly on the ground before pickup")
		await capture("portrait-ground" if portrait else "landscape-ground")
		p.advance(0.33)
		check(p.pose(gem).flight > 0 and p.pending_total == 5,"Flight begins after the ground pause")
		await capture("portrait-flight" if portrait else "landscape-flight")
		p.advance(0.23)
		check(p.pending_total < 5 and p.pending_total > 0,"Staggered arrivals count up instead of all landing at once")
		p.advance(0.4)
		check(p.pending_total == 0 and p.gems.is_empty() and g.model.rubies == 5,"Pickup only reveals committed rewards; never awards twice")
		g._restart(19); g.set_process(false)
		for i in range(g.model.enemies.size()): g.model.hit_enemy(i,9999,true)
		g._sync_corpses(); p.advance(0.57)
		check(p.gems.all(func(item): return g.ARENA.has_point(item.ground)),"Late-wave mass drops remain inside the field")
		await capture("portrait-group" if portrait else "landscape-group")
		g._check_over()
		check(g.view_phase == "collecting","Wave reward waits for the final enemy's receipt")
		g._check_over() # Must not start a second transition while collection is pending.
		p.advance(2)
		await process_frame
		check(g.view_phase == "reward" and g.model.wave_chest_stage == g.model.stage,"Wave chest begins after arrivals without blocking combat before victory")
		g._restart(); g.set_process(false)
		check(p.pending_total == 0 and p.gems.is_empty(),"Restart clears pending cosmetic balance")
		g.reduced = true
		g.model.hit_enemy(0,9999,true); p.advance(2)
		check(p.pending_total == 0 and g.model.rubies == 5,"Reduced effects keep the complete reward")
		g.queue_free(); await process_frame
	print("Crystal drops and pickups: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
