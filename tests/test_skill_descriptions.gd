extends SceneTree
## Descriptions stay independent of enemy conditions while real combat retains them.
const Run = preload("res://scripts/progression/run_rules.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var m = Run.new(667)
	m.begin_round()
	m.enemies = [m.make_enemy(0),m.make_enemy(m.EnemyCatalog.Role.PALADIN)]
	for e in m.enemies: e.hp = 10000; e.max_hp = 10000; e.shield = 0
	for id in ["hellfire","nightmare_totem","corrupt_crystal"]: m.relics.add(id)
	for locale in ["en","zh_CN"]:
		GameText.set_language(locale,false)
		for length in range(3,7):
			var skill: MultiHitSkill = m.make_straight_skill(range(1,length+1))
			for e in m.enemies: e["statuses"] = {}
			var caption: String = m.damage_caption(skill)
			var selection: String = m.selection_damage_caption(skill)
			var plain: int = m.skill_damage_total(skill,0)
			for id in [m.Status.BURNING,m.Status.CORROSION,m.Status.DARKNESS]: m.apply_enemy_status(0,id,3)
			var state: int = m.rng.state
			check(m.damage_caption(skill,0) == caption and m.damage_caption(skill,1) == caption,"Targeted descriptions ignore Burning, Corrosion, vulnerability relics and taunt")
			check(m.selection_damage_caption(skill) == selection,"Connected-dice descriptions ignore enemy conditions in both languages")
			check(m.skill_damage_total(skill,0) > plain,"Actual damage still benefits from enemy statuses")
			check(m.rng.state == state and not skill.amplifier_locked,"Descriptions consume no randomness or skill charges")
			var enemies: Array = m.enemies
			m.enemies = []
			check(m.damage_caption(skill) == caption and m.selection_damage_caption(skill) == selection,"Descriptions stay useful with no living target")
			m.enemies = enemies
	GameText.set_language("en",false)
	m.relics.clear()
	m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for e in m.enemies: e.hp = 10000; e.max_hp = 10000; e.shield = 0
	var storm: MultiHitSkill = m.make_straight_skill([1,2,3,4,5])
	m.apply_enemy_status(1,m.Status.BURNING,2)
	m.set_skill_use_multiplier("test",2)
	check(m.damage_caption(storm) == "70 damage (10 hits)","Multiple uses do not forecast future Burning bonuses")
	check(m.selection_damage_caption(storm) == "35 damage (2 uses)","Dice preview retains the whole single-use total and separate use count")
	m.pending = storm; m.phase = "player"; m.apply_player(0)
	check(m.enemies[0].hp == 9890 and m.enemies[1].hp == 9850,"Real Storm uses retain all conditional Burning damage")
	print("Skill descriptions: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
