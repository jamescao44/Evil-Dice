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
	for role in Enemy.ITEMS:
		for elite in [false,true]:
			var base: Dictionary = Enemy.make(role,1,elite)
			var data: Dictionary = Enemy.ITEMS[role]
			var elite_factor: float = 1.5 if elite and data.get("standard_elite",false) else 1.0
			var boss_hp: float = Enemy.BossBalance.health_scale(data.name,1) if data.get("boss",false) else 1.0
			check(base.hp == roundi(data.hp[int(elite)]*elite_factor*boss_hp) and base.damage == roundi(10.0*base.damage_percent),"Level one applies explicit elite/percentage/boss budgets once")
			var previous := base
			for level in range(2,16):
				var current: Dictionary = Enemy.make(role,level,elite)
				check(current.level == level and current.hp > previous.hp and current.damage >= previous.damage,"HP increases and rounded damage never falls")
				check(Enemy.soul_reward(current) >= Enemy.soul_reward(previous) and Enemy.crystal_reward(current) >= Enemy.crystal_reward(previous),"Both drop currencies scale monotonically")
				check((current.hp+0.5)/base.hp > float(Enemy.Damage.base_hit(current,1))/base.damage,"Health grows faster than unavoidable damage, allowing half a point of HP rounding")
				previous = current
	var early: Dictionary = Enemy.make(Enemy.Role.VANGUARD,5)
	check(early.hp == 127 and early.damage == 110 and Enemy.soul_reward(early) == 7 and Enemy.crystal_reward(early) == 7,"Level-five Vanguard has independently verified stats and drops")
	var late: Dictionary = Enemy.make(Enemy.Role.VANGUARD,10)
	check(late.hp == 244 and late.damage == 110 and Enemy.soul_reward(late) == 9 and Enemy.crystal_reward(late) == 10,"Level-ten Vanguard uses one final rounding per value")
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
	var m = Run.new(50); m.load_debug_wave(8)
	var commander: Dictionary = m.enemies[0]
	check(commander.level == 9 and commander.hp == Enemy.phase_health(commander,1),"First boss has its independent health budget")
	m.hit_enemy(0,99999,true)
	check(commander.hp == Enemy.phase_health(commander,2) and m.blood_gems == 0,"Phase two restores its budget without premature loot")
	check(m.enemies.slice(1).all(func(e): return e.level == 1 and e.hp == 400),"Commander reinforcements use full level-one Paladin stats")
	m.hit_enemy(0,99999,true)
	check(m.blood_gems == Enemy.crystal_reward(commander),"Boss final death pays its level-scaled gems once")

## New specials anchor pressure steps; normal versions precede their elite variants.
func rosters() -> void:
	var seen: Dictionary = {}
	var first_specials: Dictionary = {}
	var expected_debuts := {Enemy.Role.PALADIN:3,Enemy.Role.HIGH_PRIEST:11,Enemy.Role.MAGIC_CANNON:11,Enemy.Role.BOMBER:19}
	for stage in range(Run.PLAYABLE_WAVES):
		var row: Dictionary = Waves.SQUADS[stage]
		var new_types: Array = []
		var levels: Array = []
		for entry in row.units:
			var special: bool = Enemy.ITEMS[entry.role].get("reward_class","") == "special" and not Enemy.ITEMS[entry.role].get("boss",false)
			if special and not first_specials.has(entry.role):
				first_specials[entry.role] = stage
				check(Waves.is_pressure_step(stage),"Every new special first appears on an actual pressure step")
				check(not entry.get("elite",false),"New specials debut without an unfamiliar elite modifier")
			var key := str(entry.role) if Enemy.ITEMS[entry.role].get("standard_elite",false) else "%d:%s" % [entry.role,entry.get("elite",false)]
			if not seen.has(key) and key not in new_types: new_types.append(key)
			if entry.get("elite",false) and not Enemy.ITEMS[entry.role].get("boss",false):
				check(seen.has(str(entry.role)) if Enemy.ITEMS[entry.role].get("standard_elite",false) else seen.has("%d:false" % entry.role),"An elite always follows an earlier normal version")
			if entry.level not in levels: levels.append(entry.level)
		check(new_types.size() <= (2 if Waves.is_pressure_step(stage) else 1),"Only a pressure step can introduce a pair of unfamiliar enemies")
		check(row.units.size() <= 4,"Authored squads stay small enough to read")
		if not new_types.is_empty():
			check(Waves.requires_combat(stage),"First appearance cannot be replaced by a shop")
			for key in new_types: seen[key] = true
		for seed_value in range(8):
			var rng := RandomNumberGenerator.new(); rng.seed = seed_value
			var actual: Array = Waves.create(stage,rng).map(func(e): return "%d:%d:%s" % [e.role,e.level,e.elite])
			var expected: Array = row.units.map(func(e): return "%d:%d:%s" % [e.role,e.level,e.get("elite",false)])
			actual.sort(); expected.sort()
			if row.units[0].has("random_roles"):
				check(actual.size() == 1 and row.units[0].random_roles.any(func(role): return actual[0] == "%d:%d:true" % [role,row.units[0].level]),"Random finales retain their authored level and boss pool")
			else: check(actual == expected,"Seeds can change positions, never authored identities or levels")
			if stage > 0 and stage % 8 != 0:
				var m = Run.new(seed_value); m.load_debug_wave(stage)
				for e in m.enemies: e.hp = 0
				m.wave_reward_resolved = true
				var options: Array = m.offer_routes()
				if not Waves.has_shop_after(m.stage): check("shop" not in options,"Shops appear only after scheduled checkpoints")
	check(seen.size() == 12,"Five basic classes, four specials and three bosses appear")
	check(first_specials == expected_debuts,"Specials debut on local wave 4: Paladin, High Priest/Cannon, Bomber")
	check(Waves.SQUADS[3].units.size() == 2 and Waves.SQUADS[3].units.any(func(e): return e.role == Enemy.Role.MAGE),"The first Paladin has only one familiar companion")
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
