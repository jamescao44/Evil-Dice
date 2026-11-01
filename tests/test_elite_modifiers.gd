extends SceneTree
## Shared elite traits, visible commitments and target protection use the real battle model.
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
const Traits = preload("res://scripts/enemies/enemy_modifiers.gd")
const Status = Rules.Status
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(modifier: String = ""):
	var m = Rules.new(812)
	m.enemies = [Enemy.make(Enemy.Role.ASSASSIN,1,true),Enemy.make(Enemy.Role.VANGUARD)]
	m.enemies[0].modifier = modifier
	m.hp = 10000; m.max_hp = 10000; m.round_number = 1
	return m

func act(m, index: int, skill: String) -> Array:
	m.phase = "enemy"; m.enemies[index].acted = false; m.enemies[index].action_hit = 0
	m.enemies[index].intent = Actions.intent(m,index,skill)
	return m.enemy_act(index)

func identities() -> void:
	for role in [Enemy.Role.VANGUARD,Enemy.Role.ARCHER,Enemy.Role.MAGE,Enemy.Role.CLERIC,Enemy.Role.ASSASSIN]:
		var unit: Dictionary = Enemy.make(role,1,true)
		check(unit.max_hp == roundi(Enemy.ITEMS[role].hp[0]*1.5),"Basic elites share x1.5 HP")
		check(unit.damage == roundi(Enemy.ITEMS[role].damage_percent*1.25*10.0),"Elite percentage budget is 1.25 times the normal budget")
		check(unit.shield == 0 and unit.modifier in Traits.ITEMS,"One trait replaces old automatic elite shield")
		check(Enemy.ITEMS[role].elite_skills.is_empty(),"Basic elites keep their class moves")
	check(Enemy.make(Enemy.Role.ASSASSIN).damage == 80,"Assassin five-base hit receives global damage increase")
	check(Enemy.make(Enemy.Role.VANGUARD,5).damage == 110,"Catalog cache describes the same-level 11% hit with fixed player health")
	var rng := RandomNumberGenerator.new(); rng.seed = 532
	var counts := {"shielding":0,"elemental":0,"manic":0,"thorns":0}
	for i in range(8000): counts[Enemy.make(0,1,true,rng).modifier] += 1
	check(counts.values().all(func(n): return n > 1800 and n < 2200),"Four elite categories are equally weighted")
	var m = fresh(); m.enemies[0] = Enemy.make(Enemy.Role.ARCHER)
	m.enemies[0].hp = 10; act(m,0,"heal")
	check(m.enemies[0].hp == 35,"Archer restores 50% max HP")
	m.enemies = [Enemy.make(Enemy.Role.CLERIC),Enemy.make(Enemy.Role.VANGUARD)]
	for e in m.enemies: e.hp -= 30
	act(m,0,"team_mend")
	check(m.enemies[0].hp == 35 and m.enemies[1].hp == 68,"Cleric heals the whole team, including self, by 30%")
	act(m,0,"team_shield")
	check(m.enemies[0].shield == 5 and m.enemies[1].shield == 8,"Cleric grants 10% max-HP shields")

func swift() -> void:
	var m = fresh()
	check(m.attack_targets() == [1],"Swift blocks individual targeting behind other classes")
	m.relics.add("challenger_badge"); m.RelicFocus.sync(m)
	check(not m.RelicFocus.select(m,0) and m.RelicFocus.targets(m) == [1],"Focus mark cannot violate Swift protection")
	m.enemies[1].hp = 0
	check(m.attack_targets() == [0],"Swift becomes targetable as soon as its protector dies")
	m.enemies = [Enemy.make(Enemy.Role.ASSASSIN),Enemy.make(Enemy.Role.ASSASSIN)]
	check(m.attack_targets() == [0,1],"An all-Assassin group remains targetable")

func shielding() -> void:
	var m = fresh("shielding")
	m.enemies[0].shield = 2; m.hit_enemy(0,5)
	check(m.enemies[0].shield == 0,"Shield-only hits do not activate Shielding")
	m.hit_enemy(0,1)
	check(m.enemies[0].shield == 12,"HP loss grants 20% max-HP shield")
	m.hit_enemy(0,12); m.hit_enemy(0,1)
	check(m.enemies[0].shield == 0,"Further hits in the same full turn cannot grant more shield")
	m.round_number += 1; m.apply_enemy_status(0,Status.CORROSION,1,false); m.hit_enemy(0,1)
	check(m.enemies[0].shield == 0,"Corrosion prevents the shield reaction")
	m.enemies[0].statuses.clear(); m.hit_enemy(0,99999)
	check(m.enemies[0].shield == 0,"Defeated enemies never gain reactive shields")

func elemental() -> void:
	var m = fresh("elemental"); m.enemies[0].element = Status.BURNING; m.enemies[0].attribute = Status.Attribute.FIRE
	var triggered := 0
	for i in range(1000):
		if Actions.intent(m,0,"flurry").get("status_once",false): triggered += 1
	check(triggered > 420 and triggered < 580,"Elemental proc rate is 50% per committed attack")
	var move: Dictionary = Actions.intent(m,0,"flurry")
	while not move.get("status_once",false): move = Actions.intent(m,0,"flurry")
	m.phase = "enemy"; m.enemies[0].intent = move
	m.enemy_act(0)
	check(m.status_count(Status.BURNING) == 1,"Three-hit attack applies its elemental status only once")
	m.enemies[0].element = Status.FROZEN; m.apply_affliction(Status.FROZEN,1)
	for i in range(30): check(Actions.intent(m,0,"flurry").status == -1,"Already-frozen players are not assigned another freeze attack")
	for element in Traits.ELEMENTS:
		m = fresh("elemental"); m.enemies[0].element = element; m.enemies[0].attribute = Traits.ATTRIBUTES[element]
		move = Actions.intent(m,0,"flurry")
		while not move.get("status_once",false): move = Actions.intent(m,0,"flurry")
		m.phase = "enemy"; m.enemies[0].intent = move
		m.enemy_act(0)
		check(m.status_count(element) == 1,"Each elemental type applies once across the whole three-hit action")
		m = fresh("elemental"); m.enemies[0].element = element; m.enemies[0].attribute = Traits.ATTRIBUTES[element]
		move = Actions.intent(m,0,"flurry")
		while not move.get("status_once",false): move = Actions.intent(m,0,"flurry")
		m.shield = 1000; m.phase = "enemy"; m.enemies[0].intent = move
		m.enemy_act(0)
		check(m.status_count(element) == 0,"Fully shielded attacks do not inflict their element")

func manic() -> void:
	var m = fresh("manic")
	var move: Dictionary = Actions.intent(m,0,"flurry")
	while not move.get("friendly_fire",false): move = Actions.intent(m,0,"flurry")
	check(move.target == 1 and move.amount == m.enemies[0].damage*2,"Manic intent locks ally target and doubled damage")
	m.phase = "enemy"; m.enemies[0].intent = move; var hp: int = m.hp
	m.enemy_act(0)
	check(m.hp == hp and m.enemies[1].hp < 75,"Friendly flurry attacks its locked ally, not the player")
	m.enemies[1].hp = 0
	move = Actions.intent(m,0,"flurry")
	while not move.get("friendly_fire",false): move = Actions.intent(m,0,"flurry")
	check(move.target == 0,"A lone Manic enemy targets itself on friendly fire")
	m = fresh("manic"); m.enemies[0] = Enemy.make(Enemy.Role.CLERIC,1,true); m.enemies[0].modifier = "manic"
	move = Actions.intent(m,0,"team_mend")
	while not move.get("inverted",false): move = Actions.intent(m,0,"team_mend")
	m.phase = "enemy"; m.enemies[0].intent = move; m.enemy_act(0)
	check(m.enemies[0].hp == 30 and m.enemies[1].hp == 30,"Inverted team healing damages allies by doubled healing amount")

func thorns() -> void:
	var m = fresh("thorns"); m.phase = "executing"; var hp: int = m.hp
	m.hit_enemy(0,1); m.hit_enemy(0,1)
	check(m.hp == hp and m.enemies[0].counter_pending,"Thorns waits until the current attack sequence ends")
	m.finish_attack_sequence()
	check(m.hp == hp-m.enemies[0].damage,"Only one counter resolves after the sequence")
	m.hit_enemy(0,1); m.finish_attack_sequence()
	check(m.hp == hp-m.enemies[0].damage,"Additional casts in the same turn cannot retrigger Thorns")
	m.round_number += 1; m.hit_enemy(0,1); m.hit_enemy(0,99999); m.finish_attack_sequence()
	check(m.hp == hp-m.enemies[0].damage,"Killing a queued counterattacker cancels its retaliation")
	m = fresh("thorns"); hp = m.hp
	m.hit_enemy(0,1); m.apply_enemy_status(0,Status.FROZEN,1,false); m.finish_attack_sequence()
	check(m.hp == hp,"Freezing the counterattacker before the sequence finishes cancels its counter")
	m.enemies[0].statuses.clear(); m.round_number += 1
	m.hit_enemy(0,1,true,"burn"); m.finish_attack_sequence()
	check(m.hp == hp,"Burning damage cannot trigger a Thorns counter")
	m.hit_enemy(0,1); m.finish_attack_sequence()
	check(m.hp == hp-m.enemies[0].damage,"An eligible hit can still counter after a burn tick")

func campaign() -> void:
	check(Run.PLAYABLE_WAVES == 24 and Run.Campaign.WAVES_PER_LEVEL == 8,"Three eight-wave levels")
	for stage in range(24):
		check(Run.Waves.is_boss_stage(stage) == (stage%8 == 7),"Each eighth wave is a boss")
	for stage in range(7):
		check(Run.Waves.SQUADS[stage].units.all(func(e): return Enemy.ITEMS[e.role].get("standard_elite",false)),"First level regular waves contain only basic classes")
	check(Enemy.BossBalance.damage_percent("Elf Spellsword") == 20.0,"Boss attack percentage is independently authored")

func _initialize() -> void:
	identities(); swift(); shielding(); elemental(); manic(); thorns(); campaign()
	print("Elite redesign: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
