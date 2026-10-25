extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var model = Run.new(823)
	model.load_debug_wave(10)
	return model
func act(model) -> void:
	model.enemies[0].acted = false
	model.enemies[0].action_hit = 0
	model.enemies[0].intent = model.choose_intent(0)
	model.phase = "enemy"
	model.enemy_act(0)
func cast(model, values: Array, uses: int = 1) -> Array:
	model.pending = Patterns.classify(values)
	model.pending.base_uses = uses
	model.phase = "player"
	var events: Array = model.apply_player(0)
	while model.phase == "player" and model.pending.cast_source != "manual": events.append_array(model.apply_player())
	return events
func _initialize() -> void:
	var m = fresh()
	var boss: Dictionary = m.enemies[0]
	check(boss.hp == 2142 and boss.damage == 23 and boss.shield == 0,"Wave ten uses the commander level for health and damage")
	check(Actions.options(m,0) == [["shield",3],["charge",5]],"No normal attack exists in boss pool")
	boss.shield = 200
	check(Actions.options(m,0) == [["charge",5]],"Capped shield excluded")
	for turn in range(2):
		act(m)
		check(boss.charge == turn+1 and m.hp == 100,"First two charges do not release the heavy attack")
	check(m.choose_intent(0).skill == "charge","Third action still presents its final charge")
	act(m)
	check(m.hp == 31 and m.status_count(m.Status.STUNNED) == 1,"Third charge immediately releases scaled triple damage and stuns once")
	check(boss.charge == 0 and not boss.charging and boss.break_marks == 5,"Release resets charge and five break marks")
	m = fresh(); boss = m.enemies[0]; boss.charging = true; boss.charge = 2
	cast(m,[1,2,3,4,5,6])
	check(boss.break_marks == 4,"Ten Brimstone damage ticks pop exactly one mark")
	cast(m,[1,2,3,4],3)
	check(boss.break_marks == 3,"Relic-added uses remain one committed cast")
	m.character_passive.charge = 2
	var events: Array = cast(m,[1,2,3])
	check(not boss.charging and boss.charge == 0 and boss.canceled,"Main Fireball and both bonus Fireballs pop last three marks")
	check(events.filter(func(e): return e.type == "bonus_skill").size() == 1,"Only one passive trigger per cast")
	var hp: int = m.hp
	check(m.enemy_status_count(0,m.Status.IMMOBILIZED) == 1,"Breaking the charge immobilizes the boss for one turn")
	m.phase = "enemy"; boss.acted = false; m.enemy_act(0)
	check(m.enemy_status_count(0,m.Status.IMMOBILIZED) == 0,"Immobile consumes exactly the next action")
	check(m.hp == hp,"Interrupted attack cannot resolve from stale intent")
	m = fresh(); boss = m.enemies[0]; boss.charging = true; boss.charge = 1; boss.shield = 200
	cast(m,[1,2,3])
	check(boss.break_marks == 4 and boss.hp == 2142,"Shield-blocked skills still pop a mark")
	m.hit_enemy(0,5); m.apply_enemy_status(0,m.Status.BURNING,2); m._tick_enemy_statuses()
	check(boss.break_marks == 4,"Item/direct damage and status ticks do not pop marks")
	m.roll_attacks = Patterns.automatic_groups([2,2,3,4,5,6],[0,1,2,3,4,5]); m.phase = "roll_attacks"
	while not m.roll_attacks.is_empty(): m.resolve_roll_attack_step()
	check(boss.break_marks == 4,"Rolled auto-attacks do not pop marks")
	m = fresh(); boss = m.enemies[0]; boss.charging = true; boss.charge = 2
	var gems: int = m.blood_gems
	m.hit_enemy(0,9999,true)
	check(boss.boss_phase == 2 and boss.hp == 3142 and boss.max_hp == 3142 and boss.damage == 23,"Second bar scales from its own base without rescaling damage")
	check(m.enemies.slice(1).all(func(e): return e.level == 2 and e.hp == 520 and e.damage == 19),"Reinforcements use their authored support level")
	check(m.enemies.size() == 3 and m.enemies.slice(1).all(func(e): return e.role == m.EnemyCatalog.Role.PALADIN and not e.elite and e.acted),"Exactly two normal Paladins arrive without immediate actions")
	check(m.blood_gems == gems and not boss.charging and boss.charge == 0,"Phase change grants no kill reward and clears charging")
	check(m.attack_targets() == [1,2] and m.area_damage_factor(0,m.taunting_enemies()) == 0.5,"Guard taunts and area protection apply to boss")
	check(Actions.intent(m,0,"shield").amount == 100,"Phase two raises 100 shield")
	m.hit_enemy(0,9999,true)
	check(m.enemies.size() == 3 and m.blood_gems == gems+21,"Final death grants one reward without summoning again")
	m.hit_enemy(0,999,true)
	check(m.blood_gems == gems+21,"Corpse cannot grant duplicate reward")
	m = fresh(); boss = m.enemies[0]; boss.hp = 1; boss.shield = 80
	m.apply_enemy_status(0,m.Status.BURNING,2); m._tick_enemy_statuses()
	check(boss.boss_phase == 2 and boss.shield == 0,"Burning can transition phases without restoring the old shield")
	for seed_value in range(100):
		m = Run.new(seed_value); m.load_debug_wave(9)
		for e in m.enemies: e.hp = 0
		m.wave_reward_resolved = true; m.battles_since_shop = 10
		check(m.WaveRewards.SHOP not in m.offer_routes(),"Shop cannot replace the boss milestone")
	print("Knight Commander: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
