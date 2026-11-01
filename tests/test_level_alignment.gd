extends SceneTree
## Verify same-level damage budgets, increasing level gaps and non-adaptive spawn stats.
const Run = preload("res://scripts/progression/run_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
const Vitals = preload("res://scripts/combat/player_vitals.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	for level in [1,3,5,10,15,25]:
		var player = Run.new(61)
		player.gain_souls(5*level*(level-1))
		check(player.character_level == level and player.max_hp == Vitals.base_health(level),"XP levels use the shared reference health curve")
		player.enemies = [Enemy.make(Enemy.Role.MAGIC_CANNON,level)]
		player.phase = "enemy"
		var cannon: Dictionary = player.enemies[0]
		cannon.charge = 2; cannon.charging = true; cannon.intent = Actions.intent(player,0,"charge")
		player.enemy_act(0)
		check(absf(float(player.max_hp-player.hp)/player.max_hp-0.5) < 0.001,"Equal-level Cannon's real charged shot deals 50% reference HP")
		for role in [Enemy.Role.VANGUARD,Enemy.Role.MAGE,Enemy.Role.ARCHER,Enemy.Role.CLERIC,Enemy.Role.ASSASSIN,Enemy.Role.MAGIC_CANNON,Enemy.Role.BOMBER]:
			var base: Dictionary = Enemy.make(role)
			var same: Dictionary = Enemy.make(role,level)
			var near: Dictionary = Enemy.make(role,level+2)
			var high: Dictionary = Enemy.make(role,level+6)
			check(absf(float(same.damage)/Vitals.base_health(level)-float(base.damage)/1000) < 0.001,"Same-level attack ratio stays stable as player levels increase")
			check(absf(float(Enemy.Damage.base_hit(near,level))/Enemy.Damage.base_hit(same,level)-1.21) < 0.02,"Two-level damage lead remains moderate")
			check(Enemy.Damage.base_hit(high,level) > Enemy.Damage.base_hit(near,level)*1.4 and high.hp > near.hp*1.6,"Larger level gaps raise both punishment and time to defeat")
			player.acquire_relic("heart")
			check(Enemy.make(role,level).damage == same.damage and Enemy.make(role,level).max_hp == same.max_hp,"Obtaining health gear cannot rescale enemies")
	check(Enemy.make(Enemy.Role.MAGIC_CANNON,5).damage == 500,"Level-five cannon uses a single final rounding")
	check(Enemy.make(Enemy.Role.MAGIC_CANNON,10).damage == 500,"Level-ten cannon stays half of fixed 1000 reference HP")
	print("Level alignment: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
