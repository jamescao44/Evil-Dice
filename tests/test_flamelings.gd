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
			check(is_equal_approx(m.attack_base(groups[0].skill),5*(0.5+face*0.1)),"Automatic base follows pip coefficient")
	for length in range(3,7):
		for first in range(1,8-length):
			var values: Array = range(first,first+length); values.reverse()
			var skill = Patterns.classify(values)
			check(skill.pattern == "straight" and skill.is_attack(),"Every unique consecutive set attacks")
			check(skill.hits_all() == (length >= 4),"Only Fireball needs a single target")
			check(skill.use_count() == 1 and skill.duplicate().same_as(skill),"Straights start with one use and copy correctly")
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
	check(hits.map(func(e): return e.display_amount) == [5,5,4,4,3,3],"Highest-to-lowest automatic queue uses pip-weighted damage")
	check(m.dice_turn.locked.is_empty() and m.dice_turn.rolls_left == 2 and m.phase == "roll","Automatic attacks never spend dice or extra rolls")
	check(m.tarot_effects.strength == 2 and m.tarot_effects.extra_uses == 3,"Automatic hits preserve next-skill tarot")
	check(m.resolve_roll_attack_step().is_empty(),"Resolving the queue twice cannot repeat hits")
	m = fresh(); m.roll_pool(false,[1,2,3,4,4,6]); automatic(m)
	form(m,[0,1,2]); m.apply_player(0)
	check(m.roll_pool(false,[6,6,2]) == [3,4,5],"Rerolls only unused physical dice")
	check(automatic(m).size() == 2,"Only newly rerolled matching dice fire")
	# Burning doubles read the status before the hit, and new stacks follow damage.
	for length in [3,4,5]:
		m = fresh(); m.pending = Patterns.classify(range(1,length+1)); m.phase = "player"
		m.apply_enemy_status(0,Status.BURNING,1,false)
		var base: int = [18,15,32][length-3]
		check(m.attack_damage(m.pending,0) == (65 if length == 5 else base*2 if length == 4 else base),"Burning doubles only Slash and Storm")
		check(m.attack_damage(m.pending,1) == base,"Unburned preview is not doubled")
		var events: Array = m.apply_player_step(0)
		var damage: Array = events.filter(func(e): return e.type == "damage")
		check(damage.size() == (1 if length == 3 else 3),"Correct single/area target count")
		check(m.enemy_status_count(0,Status.BURNING) == (3 if length in [3,5] else 1),"Two Burning stacks applied after Fireball/Storm")
		if length == 5:
			check(damage[1].display_amount == base and m.enemy_status_count(1,Status.BURNING) == 2,"Storm's new Burning cannot double its own first hit")
	m = fresh(); m.enemies[0] = m.make_enemy(3); m.enemies[0].hp = 100000; m.enemies[0].shield = 0
	m.pending = Patterns.classify([1,2,3,4]); m.phase = "player"
	var taunt_hits: Array = m.apply_player_step(0).filter(func(e): return e.type == "damage")
	check(taunt_hits[0].display_amount == 15 and taunt_hits[1].display_amount == 7,"Area fire respects Paladin protection")
	m = fresh(); m.hp = 20; m.enemies[0].shield = 9999
	m.pending = Patterns.classify([1,2,3,4,5,6]); m.phase = "player"
	var annihilation: Array = m.apply_player(0).filter(func(e): return e.type == "damage")
	check(m.living().is_empty() and m.enemies[0].shield == 0,"Brimstone kills all through shields")
	check(m.hp == 20 and annihilation.all(func(e): return e.instant_kill and e.text.is_empty()),"Brimstone adds neither obsolete healing nor damage numbers")
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
	print("Flamelings rules: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
