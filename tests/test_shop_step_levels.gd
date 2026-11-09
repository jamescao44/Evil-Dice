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
	var previous_level := 1
	for stage in range(24): # Preserve the established first three levels exactly.
		if stage%8 == 0: previous_level = 1
		var gap: int = Waves.reference_level_gap(stage)
		var level: int = maxi(previous_level,reference.character_level+gap)
		var rng := RandomNumberGenerator.new(); rng.seed = 181+stage
		var enemies: Array = Waves.create(stage,rng)
		check(enemies.all(func(e): return e.level == level),"Every enemy matches its fixed monotonic reference at wave %d" % (stage+1))
		var authored_levels := [1,1,1,4,5,5,7,9,8,8,8,11,11,11,14,15,14,14,14,16,16,16,19,21]
		check(level == authored_levels[stage],"Only the requested boss gaps and later-level +1 increase change the roster")
		check(level >= previous_level,"Enemy levels never fall within a level")
		previous_level = level
		var xp := 0
		for enemy in enemies:
			xp += Enemy.soul_reward(enemy)
			if enemy.get("boss",false):
				boss_levels.append(enemy.level)
				check(enemy.level-reference.character_level == 5,"Every boss is five levels above expected entry level")
				check(enemy.max_hp == Enemy.phase_health(enemy,1),"Boss keeps its independently scaled phase health")
			if enemy.role == Enemy.Role.COMMANDER:
				xp += 2*Enemy.soul_reward(Enemy.make(Enemy.Role.PALADIN,enemy.reinforcement_level))
		var boosted = Run.new(181)
		boosted.gain_souls(10000); boosted.acquire_relic("heart")
		boosted.load_debug_wave(stage+1)
		check(boosted.enemies.all(func(e): return e.level == level),"Extra XP and health gear never rescale an authored encounter")
		reference.gain_souls(xp)
	check(boss_levels == [9,15,21],"Sequential XP budgets produce the three fixed boss levels")
	check(reference.character_level == 17 and reference.souls == 31,"All updated kill rewards, including guards, produce the expected final reference XP")
	var commander = Run.new(181)
	commander.load_debug_wave(8)
	commander.hit_enemy(0,999999,true)
	var paladin: Dictionary = Enemy.make(Enemy.Role.PALADIN,1)
	check(commander.enemies.size() == 3,"Commander phase two summons exactly two guards")
	for guard in commander.enemies.slice(1):
		check(guard.role == Enemy.Role.PALADIN and guard.level == 1 and not guard.elite,"Guards are ordinary LV.1 Paladins")
		check(guard.hp == 280 and guard.hp == paladin.hp and guard.max_hp == paladin.max_hp,"Guards retain full catalog health without a hidden summon penalty")
		check(guard.damage_percent == paladin.damage_percent and guard.shield_cap == paladin.shield_cap,"Guard damage and shield capacity use normal LV.1 rules")
		check(Enemy.soul_reward(guard) == Enemy.soul_reward(paladin) and Enemy.crystal_reward(guard) == Enemy.crystal_reward(paladin),"Guard drops agree with their actual level")
		check(guard.acted,"Guards still wait until the next enemy phase to act")
	print("Eight-wave level steps: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
