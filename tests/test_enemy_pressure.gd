extends SceneTree
## Check unmitigated threat against a combat-XP-only character, without player-adaptive scaling.
const Run = preload("res://scripts/progression/run_rules.gd")
const Moves = preload("res://scripts/enemies/enemy_skill_catalog.gd")
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Sum attacks if every living unit attacks; support turns and defenses can reduce actual loss.
func capacity(enemy: Dictionary) -> int:
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var maximum := 0
	for option in data.skills:
		var id: String = data.get("release",option[0]) if option[0] == "charge" else option[0]
		var move: Dictionary = Moves.make(id,enemy.damage)
		if move.type == "attack": maximum = maxi(maximum,move.amount*move.hits)
	return maximum

func _initialize() -> void:
	var xp := 0
	var rows: Array = []
	for stage in range(Run.PLAYABLE_WAVES):
		var m = Run.new(81)
		m.load_debug_wave(stage+1)
		m.gain_souls(xp)
		var attack := 0
		var units: Array = []
		for enemy in m.enemies:
			attack += capacity(enemy)
			units.append({"role":enemy.role,"name":enemy.name,"level":enemy.level,"elite":enemy.elite,"hp":enemy.max_hp,"damage":enemy.damage,"souls":Catalog.soul_reward(enemy),"phase_two_hp":Catalog.phase_health(enemy,2) if enemy.get("boss",false) else 0})
			if enemy.role in [Catalog.Role.MAGIC_CANNON,Catalog.Role.BOMBER]:
				check(enemy.damage >= m.max_hp*0.5,"Charged special threatens half reference HP at wave %d" % (stage+1))
			if not enemy.get("boss",false):
				check(Catalog.soul_reward(enemy) == Catalog.soul_reward(Catalog.make(enemy.role,enemy.level,enemy.elite)),"Chapter three adds no hidden XP multiplier")
			xp += Catalog.soul_reward(enemy)
		if not m.Waves.is_boss_stage(stage): check(attack >= m.max_hp*0.25,"Squad threatens one quarter of reference HP at wave %d" % (stage+1))
		rows.append({"wave":stage+1,"reference_hp":m.max_hp,"reference_level":m.character_level,"attack_capacity":attack,"units":units})
	check(Catalog.make(Catalog.Role.BOMBER).hp == 250,"Early Bomber has durability independent of excessive shot damage")
	check(Catalog.make(Catalog.Role.MAGIC_CANNON).damage == 500 and Catalog.make(Catalog.Role.MAGE).damage == 200 and Catalog.make(Catalog.Role.PALADIN).damage == 200,"Final level-one damage follows the edited document")
	check(Catalog.make(Catalog.Role.MAGIC_CANNON,2).damage == 570,"Fractional pre-global base is not truncated before level scaling")
	var file := FileAccess.open("res://test-output/pressure-profile-20261029.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	print("Enemy pressure targets: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
