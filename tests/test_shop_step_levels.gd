extends SceneTree
## Fixed wave levels track sequential kill XP, not the live player's loot or equipment.
const Run = preload("res://scripts/progression/run_rules.gd")
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	var reference = Run.new(181)
	var boss_levels: Array = []
	for stage in range(Waves.SQUADS.size()):
		var gap: int = [0,0,-1,-1,-2,-2,2,1,1,0,0,-1,3,2,1,0,-1,-2,3,2,1,0,-1,-2][stage]
		var level: int = maxi(1,reference.character_level+gap)
		var rng := RandomNumberGenerator.new(); rng.seed = 181+stage
		var enemies: Array = Waves.create(stage,rng)
		check(enemies.all(func(e): return e.level == level),"Every enemy matches its fixed six-wave reference at wave %d" % (stage+1))
		check(Waves.reference_level_gap(stage) == gap,"Tuning metadata matches the requested continuous six-wave steps")
		var xp := 0
		for enemy in enemies:
			xp += Enemy.soul_reward(enemy)
			if enemy.get("boss",false):
				boss_levels.append(enemy.level)
				check(enemy.max_hp == Enemy.phase_health(enemy,1),"Boss keeps its independently scaled phase health")
			if enemy.role == Enemy.Role.COMMANDER:
				xp += 2*Enemy.soul_reward(Enemy.make(Enemy.Role.PALADIN,enemy.reinforcement_level))
		var boosted = Run.new(181)
		boosted.gain_souls(10000); boosted.acquire_relic("heart")
		boosted.load_debug_wave(stage+1)
		check(boosted.enemies.all(func(e): return e.level == level),"Extra XP and health gear never rescale an authored encounter")
		reference.gain_souls(xp)
	check(boss_levels == [5,10,13],"Sequential XP budgets produce the three fixed boss levels")
	check(reference.character_level == 16 and reference.souls == 56,"All updated kill rewards, including guards, produce the expected final reference XP")
	print("Six-wave level steps: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
