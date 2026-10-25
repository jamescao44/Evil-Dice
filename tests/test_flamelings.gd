extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Status = preload("res://scripts/status/status_effect.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(778)
	m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
	for e in m.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
	m.begin_round()
	return m

func automatic(m) -> Array:
	var events: Array = []
	var guard := 0
	while not m.roll_attacks.is_empty() and guard < 100:
		events.append_array(m.resolve_roll_attack_step()); guard += 1
	check(guard < 100,"Automatic queue terminates")
	return events.filter(func(e): return e.type == "damage")

func form(m, indices: Array) -> MultiHitSkill:
	for i in indices: check(m.dice_turn.select(i),"A straight can be selected")
	return m.form_selected_skill()

func _initialize() -> void:
	# All matching sizes use count for hits, face for damage, and leave dice unspent.
	for count in range(2,7):
		for face in range(1,7):
			var values: Array = []; values.resize(count); values.fill(face)
			check(Patterns.classify(values).is_empty(),"Matching faces cannot be summoned, including six alike")
			var groups: Array = Patterns.automatic_groups(values,range(count))
			check(groups.size() == 1 and groups[0].skill.base_uses == count,"One automatic hit per matching die")
			var m = fresh()
			check(is_equal_approx(m.attack_base(groups[0].skill),5*(0.5+face*0.05)*(8 if count == 6 else 4 if count == 5 else 1)),"Automatic base follows pip coefficient")
	for length in range(3,7):
		for first in range(1,8-length):
			var values: Array = range(first,first+length); values.reverse()
			var skill = Patterns.classify(values)
			check(skill.pattern == "straight" and skill.is_attack(),"Every unique consecutive set attacks")
			check(skill.hits_all() == (length >= 4),"Only Fireball needs a single target")
			check(skill.use_count() == 1 and skill.damage_ticks == (10 if length == 6 else 5 if length == 5 else 1) and skill.duplicate().same_as(skill),"Straights copy separate damage ticks without extra uses")
	check(not Patterns.has_combination([1,1,2,4,4,6]),"Pairs do not suppress End Turn's no-combination hint")
	check(not Patterns.can_extend([2,2],[1,2,2,3,4,5]),"Repeated faces rejected during selection")
	check(Patterns.can_extend([4,2],[1,2,3,4,5,6]),"Out-of-order selection can complete a straight")
	var m = fresh()
	m.tarot_effects.strength = 2; m.tarot_effects.extra_uses = 3
	m.roll_pool(false,[1,1,4,4,6,6])
	check(m.phase == "roll_attacks" and m.roll_pool().is_empty(),"Roll/selection waits for automatic attacks")
	check(m.form_selected_skill().is_empty(),"Cannot form a skill while automatic attacks resolve")
	var hits: Array = automatic(m)
	check(hits.size() == 6,"All three matching groups attack")
	check(hits.map(func(e): return e.display_amount) == [4,4,3,3,2,2],"Highest-to-lowest automatic queue uses pip-weighted damage")
	check(m.dice_turn.locked.is_empty() and m.dice_turn.rolls_left == 2 and m.phase == "roll","Automatic attacks never spend dice or extra rolls")
	check(m.tarot_effects.strength == 2 and m.tarot_effects.extra_uses == 3,"Automatic hits preserve next-skill tarot")
	check(m.resolve_roll_attack_step().is_empty(),"Resolving the queue twice cannot repeat hits")
	m = fresh(); m.roll_pool(false,[1,2,3,4,4,6]); automatic(m)
	form(m,[0,1,2]); m.apply_player(0)
	check(m.roll_pool(false,[6,6,2]) == [3,4,5],"Rerolls only unused physical dice")
	check(automatic(m).size() == 2,"Only newly rerolled matching dice fire")
	# Burning doubles read the status before the hit, and new stacks follow damage.
	for length in [3,4,5,6]:
		m = fresh(); m.pending = Patterns.classify(range(1,length+1)); m.phase = "player"
		m.apply_enemy_status(0,Status.BURNING,1,false)
		var base: float = [18.0,15.0,7.5,10.0][length-3]
		check(m.attack_damage(m.pending,0) == floori(base*2 if length >= 4 else base),"Burning doubles Slash, Storm and Brimstone")
		check(m.attack_damage(m.pending,1) == floori(base),"Unburned preview is not doubled")
		var events: Array = m.apply_player_step(0)
		var damage: Array = events.filter(func(e): return e.type == "damage")
		check(damage.size() == (1 if length == 3 else 3),"Correct single/area target count")
		check(m.enemy_status_count(0,Status.BURNING) == (3 if length == 3 else 1),"Fireball ignites on hit; Storm waits for all pulses")
		if length == 5:
			check(damage[1].display_amount == floori(base) and m.enemy_status_count(1,Status.BURNING) == 0,"Storm has not ignited enemies after the first pulse")
	m = fresh(); m.enemies[0] = m.make_enemy(3); m.enemies[0].hp = 100000; m.enemies[0].shield = 0
	m.pending = Patterns.classify([1,2,3,4]); m.phase = "player"
	var taunt_hits: Array = m.apply_player_step(0).filter(func(e): return e.type == "damage")
	check(taunt_hits[0].display_amount == 15 and taunt_hits[1].display_amount == 7,"Area fire respects Paladin protection")
	# Native repeated attacks retain normal damage, shields, Burning and relic scaling.
	for length in [5,6]:
		m = fresh(); m.pending = Patterns.classify(range(1,length+1)); m.phase = "player"
		m.apply_enemy_status(0,Status.BURNING,1,false)
		var hits_per_enemy: int = 5 if length == 5 else 10
		var repeated: Array = m.apply_player(0).filter(func(e): return e.type == "damage")
		check(repeated.size() == hits_per_enemy*3,"Every native hit reaches all three enemies")
		check(repeated.all(func(e): return not e.instant_kill and not e.text.is_empty()),"Brimstone and Storm show real damage, never execute")
		check(repeated.filter(func(e): return e.target == 0).all(func(e): return e.display_amount == (15 if length == 5 else 20)),"Each hit doubles on already Burning targets")
		check(m.enemies[1].hp == 100000-(35 if length == 5 else 100),"An unburned enemy takes normal damage for every pulse")
		check(m.enemy_status_count(1,Status.BURNING) == (2 if length == 5 else 0),"Storm ignites once after all five pulses; Brimstone never ignites")
		m = fresh(); m.acquire_relic("twin_scythes")
		check(m.skill_use_count(Patterns.classify(range(1,length+1))) == 1,"Multi-hit relics do not affect damage pulses")
	m = fresh(); m.enemies[0].shield = 9999
	m.pending = Patterns.classify([1,2,3,4,5,6]); m.phase = "player"
	var shielded: Array = m.apply_player(0)
	check(m.enemies[0].hp == 100000 and m.enemies[0].shield == 9899,"Brimstone respects shields across ten impacts")
	for length in [5,6]:
		m = fresh(); m.acquire_relic("pet_bat"); m.hp = 20; m.statuses[3].count = 2
		m.pending = Patterns.classify(range(1,length+1)); m.phase = "player"
		m.apply_player(0)
		check(m.hp == 21 and m.statuses[3].count == 1,"Damage pulses trigger one 1%-HP bat heal and spend boon charges only once")
		m = fresh()
		for enemy in m.enemies: enemy.hp = 1
		m.pending = Patterns.classify(range(1,length+1)); m.phase = "player"
		var clearing: Array = m.apply_player(0).filter(func(e): return e.type == "damage")
		check(clearing.size() == 3 and clearing.all(func(e): return not e.get("corpse_hit",false)),"Damage pulses stop on wave clear without corpse hits")
		check(m.pending.is_empty() and m.phase == "finished" and m.apply_player_step(0).is_empty(),"Early clear finalizes the cast and cannot emit more pulses")
	# Reproduce Magician -> 1–6 -> early target death, keeping another enemy alive.
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,5]); automatic(m)
	var magician: Dictionary = m.tarots.add("magician")
	check(not m.tarot_effects.cast(m,magician.instance_id,{"die":5,"face":6}).has("error"),"Magician completes a six-die straight")
	m.enemies[0].hp = 1
	var brimstone: MultiHitSkill = form(m,[0,1,2,3,4,5])
	check(brimstone.use_count() == 1 and brimstone.damage_ticks == 10 and not brimstone.has_use_orbs() and not brimstone.is_combo_attack(),"Brimstone is one use with no combo orbs")
	var pulse_events: Array = m.apply_player(0)
	check(m.enemies[0].hp <= 0 and m.has_living_enemies(),"First target dies but other enemies remain")
	check(m.pending.is_empty() and m.phase == "roll" and m.bonus_turn_count == 1,"All pulses finish and six spent dice grant a playable bonus turn")
	check(m.dice_turn.can_roll(),"Next throw remains available after Magician Brimstone")
	# Leftovers heal once as a percentage, without consuming any attack modifier.
	m = fresh(); m.hp = 20; m.max_hp = 150
	m.roll_pool(false,[1,2,3,4,5,6]); m.tarot_effects.strength = 3; m.tarot_effects.extra_uses = 2; m.statuses[3].count = 2
	check(m.leftover_total_healing() == 32,"21 pips heal 21% of 150 maximum HP, rounded once")
	check(m.end_dice_turn(),"End Turn commits healing")
	var healing: Array = m.apply_player().filter(func(e): return e.type == "heal")
	check(healing.size() == 1 and healing[0].amount == 32 and m.hp == 52,"Leftover healing resolves once before enemies act")
	check(m.phase == "enemy" and m.bonus_turn_count == 0,"Healing does not grant a bonus turn")
	check(m.tarot_effects.strength == 3 and m.tarot_effects.extra_uses == 2 and m.statuses[3].count == 2,"Healing preserves offensive charges")
	m = fresh(); m.hp = 99; m.roll_pool(false,[1,2,3,4,5,6])
	check(m.leftover_total_healing() == 1,"Healing preview clamps to missing health")
	m.apply_affliction(Status.DARKNESS,1); check(m.leftover_total_healing() == 0,"Darkness preview blocks healing")
	m.end_dice_turn(); m.apply_player(); check(m.hp == 99,"Darkness blocks actual leftover healing")
	m = fresh(); m.roll_pool(false,[1,2,3,1,2,3]); automatic(m)
	form(m,[0,1,2]); m.apply_player(0); form(m,[3,4,5]); m.apply_player(0)
	check(m.bonus_turn_count == 1 and m.dice_turn.rolls_left == 3 and m.phase == "roll","Two straights using all dice still grant a bonus turn")
	m = fresh(); m.acquire_relic("twin_scythes"); m.roll_pool(false,[2,2,3,4,5,6])
	check(automatic(m).size() == 2,"Auto-attacks do not receive multi-hit relic bonuses")
	m = fresh(); m.enemies = [m.make_enemy(0)]; m.enemies[0].hp = 1
	m.roll_pool(false,[6,6,6,6,6,6]); check(automatic(m).size() == 1,"Automatic attacks stop when no living target remains")
	check(m.roll_attacks.is_empty() and not m.outcome().is_empty(),"Last automatic kill safely clears its queue")
	check(m.reroll_progress == 2,"Automatic wave clear banks remaining rolls exactly once")
	storm_burning_timing()
	print("Flamelings rules: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

## Follow individual ticks to catch premature ignition, per-target ordering and repeated stacks.
func storm_burning_timing() -> void:
	for evolved in [false,true]:
		for runestone in [false,true]:
			var m = fresh()
			m.character_level = 5 if evolved else 1
			if runestone: m.acquire_relic("runestone")
			m.pending = Patterns.classify([1,2,3,4,5]); m.phase = "player"
			m.apply_enemy_status(0,Status.BURNING,1,false)
			var skill: MultiHitSkill = m.pending.duplicate()
			var normal: int = m.attack_damage(skill,1)
			var doubled: int = m.attack_damage(skill,0)
			var total: int = m.skill_damage_total(skill,1)
			check(total == normal*5,"Storm preview assumes no self-ignition during its damage")
			for tick in range(5):
				var events: Array = m.apply_player_step(0)
				var damage: Array = events.filter(func(e): return e.type == "damage")
				check(damage.size() == 3 and damage[0].display_amount == doubled and damage[1].display_amount == normal and damage[2].display_amount == normal,"Every pulse respects existing Burning without igniting its own later damage")
				var stacks: int = (3 if evolved else 2)+(1 if runestone else 0)
				check(m.enemy_status_count(0,Status.BURNING) == (1+stacks if tick == 4 else 1) and m.enemy_status_count(1,Status.BURNING) == (stacks if tick == 4 else 0),"Evolved and Runestone Burning are applied once at the end")
				if tick == 4:
					var status_events: Array = events.filter(func(e): return e.type == "status" and e.get("status",-1) == Status.BURNING)
					check(status_events.size() == 3 and events.find(status_events[0]) > events.find(damage.back()),"All targets receive their fifth damage pulse before final Burning begins")
			check(m.enemies[1].hp == 100000-total,"Preview total equals actual Storm damage")
			check(m.apply_player_step(0).is_empty(),"Finishing twice cannot reapply Storm Burning")
