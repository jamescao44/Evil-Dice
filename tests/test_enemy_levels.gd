extends SceneTree
## Individual scaling, mixed-level payouts, onboarding gates and boss inheritance.
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Equal enemy identities and levels have equal stats anywhere in the campaign.
func scaling() -> void:
	for role in range(Enemy.ITEMS.size()):
		for elite in [false,true]:
			var base: Dictionary = Enemy.make(role,1,elite)
			check(base.hp == Enemy.ITEMS[role].hp[int(elite)] and base.damage == Enemy.ITEMS[role].damage[int(elite)],"Level one preserves catalog base stats")
			var previous := base
			for level in range(2,16):
				var current: Dictionary = Enemy.make(role,level,elite)
				check(current.level == level and current.hp > previous.hp and current.damage >= previous.damage,"HP increases and rounded damage never falls")
				check(Enemy.soul_reward(current) >= Enemy.soul_reward(previous) and Enemy.crystal_reward(current) >= Enemy.crystal_reward(previous),"Both drop currencies scale monotonically")
				check(float(current.hp)/base.hp > float(current.damage)/base.damage,"Health grows faster than unavoidable damage")
				previous = current
	var early: Dictionary = Enemy.make(Enemy.Role.VANGUARD,5)
	check(early.hp == 214 and early.damage == 8 and Enemy.soul_reward(early) == 7 and Enemy.crystal_reward(early) == 7,"Level-five Vanguard has independently verified stats and drops")
	var late: Dictionary = Enemy.make(Enemy.Role.VANGUARD,10)
	check(late.hp == 795 and late.damage == 10 and Enemy.soul_reward(late) == 10 and Enemy.crystal_reward(late) == 10,"Level-ten Vanguard uses one final rounding per value")
	check(Enemy.make(0,-5) == Enemy.make(0,1),"Invalid low levels normalize to the level-one baseline")
	check(Waves.create(-1,RandomNumberGenerator.new()).is_empty() and Waves.create(Waves.CITY_STAGE,RandomNumberGenerator.new()).is_empty(),"Out-of-range and dormant city encounters have no authored roster")

## A mixed roster grants each enemy's reward exactly once, independent of stage.
func payouts() -> void:
	for stage in [0,19]:
		var m = Run.new(50); m.stage = stage
		m.enemies = [Enemy.make(0,1),Enemy.make(0,5)]
		var gems: Array = []; var souls: Array = []
		m.enemy_crystals_dropped.connect(func(_index,amount): gems.append(amount))
		m.enemy_souls_dropped.connect(func(_index,amount): souls.append(amount))
		m.hit_enemy(0,99999,true); m.hit_enemy(1,99999,true)
		check(gems == [5,7] and souls == [5,7],"Mixed enemy levels pay their own gems and souls, not the stage's level")
		m.hit_enemy(0,99999,true); m.hit_enemy(1,99999,true)
		check(gems.size() == 2 and souls.size() == 2 and m.blood_gems == 12,"Re-hitting corpses cannot duplicate either reward")
	var m = Run.new(50); m.load_debug_wave(10)
	check(m.enemies[0].level == 5 and m.enemies[0].hp == 2142 and m.enemies[0].damage == 23,"First boss is level five")
	m.hit_enemy(0,99999,true)
	check(m.enemies[0].hp == 3142 and m.enemies[0].level == 5 and m.blood_gems == 0,"Phase two recomputes its own base HP once and pays no premature reward")
	check(m.enemies.slice(1).all(func(e): return e.level == 2 and e.hp == 520 and e.damage == 19 and Enemy.soul_reward(e) == 22 and Enemy.crystal_reward(e) == 11),"Boss summons use their explicit lower support level for stats and drops")
	m.hit_enemy(0,99999,true)
	check(m.blood_gems == 21,"Boss's final death grants level-scaled gems once")

## Introduce one new identity at a time, without shops skipping its learning encounter.
func rosters() -> void:
	var seen: Dictionary = {}
	var mixed := 0
	for stage in range(Run.PLAYABLE_WAVES):
		var row: Dictionary = Waves.SQUADS[stage]
		var new_types: Array = []
		var levels: Array = []
		for entry in row.units:
			var key := "%d:%s" % [entry.role,entry.get("elite",false)]
			if not seen.has(key) and key not in new_types: new_types.append(key)
			if entry.get("elite",false) and not Enemy.ITEMS[entry.role].get("boss",false):
				check(seen.has("%d:false" % entry.role),"An elite always follows an earlier normal version")
			if entry.level not in levels: levels.append(entry.level)
		check(new_types.size() <= 1,"No wave introduces two unfamiliar enemy identities")
		check(row.units.size() <= 4,"Authored squads stay small enough to read")
		if not new_types.is_empty():
			check(Waves.requires_combat(stage),"First appearance cannot be replaced by a shop")
			for key in new_types: seen[key] = true
		if levels.size() > 1: mixed += 1
		for seed_value in range(8):
			var rng := RandomNumberGenerator.new(); rng.seed = seed_value
			var actual: Array = Waves.create(stage,rng).map(func(e): return "%d:%d:%s" % [e.role,e.level,e.elite])
			var expected: Array = row.units.map(func(e): return "%d:%d:%s" % [e.role,e.level,e.get("elite",false)])
			actual.sort(); expected.sort()
			check(actual == expected,"Seeds can change positions, never authored identities or levels")
			if stage > 0 and stage % 10 != 0:
				var m = Run.new(seed_value); m.load_debug_wave(stage)
				for e in m.enemies: e.hp = 0
				m.wave_reward_resolved = true; m.battles_since_shop = 20
				var options: Array = m.offer_routes()
				if Waves.requires_combat(stage): check("shop" not in options,"Natural route choices preserve onboarding encounters")
	check(mixed >= 10,"Mixed-level waves are used throughout all three levels")
	check(seen.size() == 13,"All five normal/elite identities and all three bosses appear")
	var session = Session.new(50)
	session.model.enemies = [Enemy.make(0,1),Enemy.make(0,5)]
	var state: Dictionary = session.snapshot()
	check(state.enemies.map(func(e): return e.level) == [1,5] and state.enemies.map(func(e): return e.gem_reward) == [5,7],"CLI exposes individual levels and public rewards")
	for signal_info in session.model.get_signal_list():
		for connection in session.model.get_signal_connection_list(signal_info.name): session.model.disconnect(signal_info.name,connection.callable)

func _initialize() -> void:
	scaling(); payouts(); rosters()
	print("Enemy levels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
