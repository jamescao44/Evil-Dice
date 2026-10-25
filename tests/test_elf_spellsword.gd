extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(824)
	m.load_debug_wave(20)
	m.base_max_hp = 10000; m.hp = 10000
	return m

## Resolve a real enemy action and its following end-of-turn status decay.
func act(m, skill: String = "") -> Array:
	var e: Dictionary = m.enemies[0]
	e.acted = false; e.action_hit = 0
	e.intent = m.choose_intent(0) if skill.is_empty() else Actions.intent(m,0,skill)
	m.phase = "enemy"
	var events: Array = m.enemy_act(0)
	m.end_round()
	return events

func cast(m, values: Array, uses: int = 1) -> Array:
	m.pending = Patterns.classify(values); m.pending.base_uses = uses; m.phase = "player"
	var events: Array = m.apply_player(0)
	while m.phase == "player" and m.pending.cast_source != "manual": events.append_array(m.apply_player())
	return events

func _initialize() -> void:
	var m = fresh()
	var e: Dictionary = m.enemies[0]
	check(Run.PLAYABLE_WAVES == 30 and not m.is_city(),"Thirty playable waves, with city still disabled")
	check(e.hp == 13786 and e.damage == 30 and e.break_marks == 3,"Wave twenty applies the individual boss level")
	check(Actions.options(m,0) == [["charge",5],["frost_bind",2]],"Full health excludes healing; no ordinary attack")
	e.hp -= 2000
	check(Actions.options(m,0).has(["spellsword_mend",2]),"Injured boss can heal with weight two")
	act(m,"spellsword_mend")
	check(e.hp == 13165 and m.hp == 10000,"Healing restores ten percent of scaled maximum HP")
	act(m,"charge")
	check(e.charge == 1 and m.choose_intent(0).skill == "charge","First charge commits the next action")
	var events: Array = act(m)
	check(events.any(func(x): return x.type == "charge" and x.amount == 2),"Second action fills the final charge before its attack")
	check(m.hp == 9940 and m.status_count(m.Status.DARKNESS) == 1,"Second charge immediately deals double damage and applies two Darkness before decay")
	check(not e.charging and e.charge == 0 and e.break_marks == 3,"Release resets the three break marks")
	m = fresh(); e = m.enemies[0]
	act(m,"frost_bind")
	check(m.hp == 10000 and m.is_frozen(),"Freeze has no direct damage")
	check(not Actions.options(m,0).has(["frost_bind",2]),"Frozen player cannot be selected for another freeze")
	m.statuses[m.Status.FROZEN].count = 0
	check(not Actions.options(m,0).has(["frost_bind",2]),"No consecutive freeze even after thawing")
	act(m,"charge")
	check(m.choose_intent(0).skill == "charge","Freeze cannot interrupt a committed charge")
	m = fresh(); e = m.enemies[0]; e.charging = true; e.charge = 1
	cast(m,[1,2,3,4,5,6])
	check(e.break_marks == 2,"Ten Brimstone ticks consume one break mark")
	cast(m,[1,2,3,4],3)
	check(e.break_marks == 1,"Additional uses of one skill consume one break mark")
	cast(m,[1,2,3])
	check(not e.charging and m.enemy_status_count(0,m.Status.IMMOBILIZED) == 1,"Third separate cast interrupts and immobilizes")
	var hp: int = m.hp
	act(m)
	check(m.hp == hp and m.enemy_status_count(0,m.Status.IMMOBILIZED) == 0,"Interruption consumes exactly one enemy action")
	m.begin_round()
	check(not e.canceled and e.charge == 0,"Boss resumes fresh after the skipped action")
	m = fresh(); e = m.enemies[0]; e.charging = true; e.charge = 1
	m.character_passive.charge = 2
	cast(m,[3,4,5])
	check(not e.charging and m.enemy_status_count(0,m.Status.IMMOBILIZED) == 1,"Main Fireball and both bonus Fireballs break all three marks")
	m = fresh(); e = m.enemies[0]; e.charging = true; e.charge = 1
	m.hit_enemy(0,1); m.apply_enemy_status(0,m.Status.BURNING,1); m._tick_enemy_statuses()
	m.roll_attacks = Patterns.automatic_groups([1,1,2,3,4,5],[0,1,2,3,4,5]); m.phase = "roll_attacks"
	while not m.roll_attacks.is_empty(): m.resolve_roll_attack_step()
	check(e.break_marks == 3,"Direct damage, status ticks and auto-attacks cannot break marks")
	m.apply_enemy_status(0,m.Status.FROZEN,1,false)
	check(e.charging and e.charge == 1,"Freezing preserves boss charge progress")
	act(m)
	check(e.charging and e.charge == 1 and m.choose_intent(0).skill == "charge","Boss resumes charging after its frozen action")
	m = fresh(); e = m.enemies[0]
	var gems: int = m.blood_gems
	m.hit_enemy(0,99999,true)
	check(e.boss_phase == 2 and e.hp == 16543 and e.damage == 30 and m.enemies.size() == 1,"Second health bar has identical scaling and no reinforcements")
	check(m.blood_gems == gems and m.outcome().is_empty(),"First health bar cannot end the run or award drops")
	check(m.status_count(m.Status.DARKNESS) == 2 and m.enemy_status_count(0,m.Status.DARKNESS) == 2,"Phase entry applies two Darkness to both sides")
	check(Actions.options(m,0).has(["corrosive_heal",2]) and not Actions.options(m,0).has(["spellsword_mend",2]),"Corrosion replaces healing even at full health under Darkness")
	m.statuses[m.Status.DARKNESS].count = 0; e.statuses[m.Status.DARKNESS].count = 0
	act(m,"corrosive_heal")
	check(m.status_count(m.Status.CORROSION) == 3 and m.enemy_status_count(0,m.Status.CORROSION) == 3,"Both sides retain three full Corrosion turns after application")
	check(e.hp == 16543 and e.charge == 0 and m.choose_intent(0).skill == "charge","Corrosive Heal does not heal or grant a free charge")
	act(m)
	check(e.charge == 1 and m.status_count(m.Status.CORROSION) == 2,"First forced charge consumes the first Corrosion turn")
	hp = m.hp
	act(m)
	check(m.hp == hp-90 and m.status_count(m.Status.CORROSION) == 1 and not e.charging,"Second charge immediately hits with Corrosion still active")
	m.hit_enemy(0,99999,true)
	check(m.outcome() == "victory" and m.blood_gems == gems+30,"Only final boss death awards drops and completes the run")
	m.hit_enemy(0,99999,true)
	check(m.blood_gems == gems+30,"Final death cannot reward twice")
	for seed_value in range(100):
		m = Run.new(seed_value); m.load_debug_wave(19)
		for enemy in m.enemies: enemy.hp = 0
		m.wave_reward_resolved = true; m.battles_since_shop = 10
		check(m.outcome() == "wave_clear" and m.WaveRewards.SHOP not in m.offer_routes(),"Wave nineteen continues to a guaranteed boss battle")
		m.choose_route(0); check(m.advance_wave() and m.enemies[0].role == m.EnemyCatalog.Role.SPELLSWORD,"Route enters wave-twenty boss")
	print("Elf Spellsword: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
