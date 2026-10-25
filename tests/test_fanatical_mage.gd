extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Boss = preload("res://scripts/enemies/boss_rules.gd")
const Fanatic = preload("res://scripts/enemies/fanatical_mage.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh(level: int = 1):
	var m = Run.new(82)
	m.stage = 29; m.wave_kind = "relic"
	m.enemies = [m.EnemyCatalog.make(m.EnemyCatalog.Role.FANATIC,level,true)]
	m.phase = "player"
	return m
func _initialize() -> void:
	var m = fresh()
	check(m.enemies[0].hp == 1500,"Mage uses authored phase-one base health")
	check(not m.EnemyActions.options(m,0).any(func(o): return o[0] == "split_minions"),"Splitting requires two octopuses")
	Fanatic.summon(m,0)
	check(Fanatic.servants(m,0).size() == 2 and m.enemies[1].acted,"Two servants spawn and wait until the next turn")
	var before: int = m.enemies[1].hp+m.enemies[2].hp
	check(m.hit_enemy(0,100) == 0 and m.enemies[0].hp == 1500,"Servant absorbs the mage's damage")
	check(before-m.enemies[1].hp-m.enemies[2].hp == 50,"Overkill does not spill through a servant")
	check(m.souls == 0 and m.blood_gems == 0,"Summons cannot farm leveling or treasure")
	m = fresh(); Fanatic.summon(m,0); m.tarot_effects._tower(m)
	check(m.enemies[0].hp == 1450 and Fanatic.servants(m,0).is_empty(),"Tower keeps its exact HP loss on every target despite servants")
	m = fresh(); Fanatic.summon(m,0); Fanatic.split(m,0)
	check(Fanatic.servants(m,0).size() == 6 and Fanatic.servants(m,0,true).is_empty(),"Two octopuses split into six tentacles")
	check(not m.EnemyActions.options(m,0).any(func(o): return o[0] in ["split_minions","summon_minions"]),"Full tentacle formation cannot split or grow again")
	check(m.souls == 0 and m.enemies[1].dismissed,"Splitting removes old bodies without rewards")
	for i in Fanatic.servants(m,0): Fanatic.dismiss(m,i)
	m.phase = "executing"; m.hit_enemy(0,9999,true)
	check(m.enemies[0].phase_transition_pending and m.enemies.size() == 9,"Phase two waits for the attack sequence")
	Boss.finish_attack_sequence(m)
	check(m.enemies[0].boss_phase == 2 and m.enemies[0].hp == 1500,"Second phase restores its authored bar")
	var demon: int = m.enemies.size()-1
	check(m.enemies[demon].hp == 10000 and m.taunting_enemies() == [demon],"Demon has its own HP and taunt")
	m.phase = "enemy"; m.enemies[demon].acted = false; m.enemies[demon].intent = m.EnemyActions.intent(m,demon,"charge")
	m.enemy_act(demon)
	check(m.enemies[demon].charge == 1,"Demon begins its two-step charge")
	for i in range(3): m.boss_cast_contacts.clear(); Boss.skill_contact(m,demon)
	check(m.enemies[demon].charge == 0 and m.enemy_status_count(demon,m.Status.IMMOBILIZED) == 1,"Three separate skill casts interrupt and immobilize the demon")
	m.hp = 100; m.enemies[demon].erase("statuses"); m.enemies[demon].canceled = false
	for i in range(2):
		m.enemies[demon].acted = false; m.enemies[demon].intent = m.EnemyActions.intent(m,demon,"charge"); m.enemy_act(demon)
	check(m.hp == 40 and m.enemies[demon].charge == 0,"Second charge releases the 60-damage attack immediately")
	m.enemies[demon].charging = true; m.enemies[demon].charge = 1
	m.apply_enemy_status(demon,m.Status.FROZEN,1,false)
	check(m.enemies[demon].charging and m.enemies[demon].charge == 1,"Frozen demon preserves committed charging")
	for level in [1,12,14,18]:
		m = fresh(level); m.hit_enemy(0,m.enemies[0].hp,true)
		m.shield = 1000
		for turn in range(5): Fanatic.end_turn(m)
		check(m.enemies[0].hp == 0 and not m.has_living_enemies(),"Five level-scaled sacrifices dismiss the demon at level %d" % level)
		check(m.souls+5*m.character_level*(m.character_level-1) == m.EnemyCatalog.soul_reward(m.enemies[0]),"Only final mage death awards boss XP")
	print("Fanatical Mage: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
