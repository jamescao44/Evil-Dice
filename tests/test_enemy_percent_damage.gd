extends SceneTree
## Percentage budgets exercise actual attacks, defenses, equipment and shared standalone combat.
const Run = preload("res://scripts/progression/run_rules.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
const Vitals = preload("res://scripts/combat/player_vitals.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func encounter(level: int, gap: int = 0, role: int = Enemy.Role.MAGE):
	var m = Run.new(123)
	m.gain_souls(5*level*(level-1))
	m.enemies = [Enemy.make(role,maxi(1,level+gap))]
	return m

## One intent is committed and executed through the same defenses as the GUI.
func attack(m, skill: String = "attack") -> int:
	var before: int = m.hp
	var enemy: Dictionary = m.enemies[0]
	enemy.acted = false; enemy.action_hit = 0
	enemy.intent = Actions.intent(m,0,skill)
	m.phase = "enemy"
	m.enemy_act(0)
	return before-m.hp

func _initialize() -> void:
	for row in [[Enemy.Role.PALADIN,150],[Enemy.Role.HIGH_PRIEST,200],[Enemy.Role.BOMBER,300],[Enemy.Role.MAGIC_CANNON,500]]:
		var normal = encounter(10,0,row[0])
		var elite = encounter(10,0,row[0])
		elite.enemies[0] = Enemy.make(row[0],10,true); elite.enemies[0].erase("modifier")
		check(attack(normal) == row[1],"Updated special-unit damage matches the document")
		check(attack(elite) == roundi(row[1]*1.25),"Special elites share the 1.25 damage factor")
	for level in [1,5,10,20]:
		for gap in [-2,0,1,3]:
			var m = encounter(level,gap)
			var expected: int = roundi(Vitals.base_health(level)*0.2*pow(1.1,maxi(1,level+gap)-level))
			check(attack(m) == expected,"Mage damage uses 20% reference health and the signed level gap")
			m = encounter(level,gap)
			m.acquire_relic("heart"); m.hp = m.max_hp
			check(m.max_hp > Vitals.base_health(level) and attack(m) == expected,"Health gear adds survivability without increasing incoming damage")
			m = encounter(level,gap)
			m.acquire_relic("reaper_scythe"); m.hp = m.max_hp
			check(attack(m) == mini(m.max_hp,expected),"Reduced-health gear keeps its risk instead of reducing the attack budget")
	var m = encounter(1)
	m.shield = 150
	check(attack(m) == 50 and m.shield == 0,"Percentage attacks still pass through shields")
	m = encounter(1); m.statuses[m.Status.IMMUNITY].count = 1
	check(attack(m) == 0,"Invulnerability still blocks percentage attacks")
	m = encounter(1); m.shield = 1000; m.apply_affliction(m.Status.CORROSION,1)
	check(attack(m) == 300 and m.shield == 1000,"Corrosion increases incoming damage and bypasses shields")
	m = encounter(1); m.apply_enemy_status(0,m.Status.DARKNESS,1,false)
	check(attack(m) == 100,"Enemy Darkness still halves outgoing damage")
	m = encounter(1); m.enemies[0].attack_boost = true
	check(attack(m) == 300,"Enemy empowerment applies after the percentage budget")
	m = encounter(1,0,Enemy.Role.ASSASSIN)
	check(attack(m,"flurry") == 240,"Assassin uses 8% per hit, three hits per action")
	m = encounter(1); m.enemies[0] = Enemy.make(Enemy.Role.ASSASSIN,1,true); m.enemies[0].modifier = "shielding"
	check(attack(m,"flurry") == 300,"Elite 1.25 damage factor applies once to every hit")
	m = encounter(1); m.enemies[0].modifier = "manic"
	var move: Dictionary = Actions.intent(m,0,"attack")
	check(move.amount == 400,"Manic doubles the same percentage budget")
	for level in [1,10,20]:
		m = encounter(level,0,Enemy.Role.SPELLSWORD); m.apply_affliction(m.Status.CORROSION,3)
		check(absf(float(attack(m,"dark_slash"))/m.max_hp-0.6) < 0.002,"Spellsword charged attack with Corrosion targets 60% at equal level")
		m = encounter(level,0,Enemy.Role.MAGIC_CANNON)
		check(absf(float(attack(m,"cannon_shot"))/m.max_hp-0.5) < 0.001,"Normal cannon targets 50% at equal level")
	var standalone = Rules.new(17)
	standalone.enemies = [Enemy.make(Enemy.Role.MAGE)]
	check(standalone.character_level == 1 and attack(standalone) == 200,"Standalone battle models resolve percentage damage without campaign state")
	print("Enemy percentage damage: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
