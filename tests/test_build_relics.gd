extends SceneTree
## End-to-end checks for build-defining relics, including limits and cancellation-safe previews.
const Run = preload("res://scripts/progression/run_rules.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(ids: Array = []):
	var m = Run.new(251025)
	m.enemies = [m.make_enemy(0),m.make_enemy(0)]
	for e in m.enemies: e.hp = 100000; e.max_hp = 100000
	for id in ids: m.acquire_relic(id)
	m.begin_round()
	return m

func healing_checks() -> void:
	var m = fresh(["magic_bandage","mysterious_seed"])
	m.hp = 90
	check(m.heal(6) == 6,"Bandage does not switch on halfway through a turn")
	m.phase = "round_end"; m.begin_round()
	check(m.heal(10) == 4 and m.hp == 100,"Bandage doubles recovery from the turn-start snapshot")
	var events: Array = m.relic_recovery.finish_player_turn(m)
	var hits: Array = events.filter(func(e): return e.type == "damage")
	check(hits.size() == 1 and hits[0].amount == 32,"Seed fires exactly twice the 16 overhealed HP")
	check(m.relic_recovery.finish_player_turn(m).is_empty(),"One seed release per player turn")
	m = fresh(["mysterious_seed","bloodstone"])
	m.heal(10)
	m.relic_recovery.finish_player_turn(m)
	check(m.relic_recovery.stored.is_empty(),"Seed lifesteal cannot recursively charge itself")
	m.phase = "round_end"; m.begin_round()
	var storm = m.Patterns.classify([1,2,3,4,5])
	for i in range(5): m.RelicEffects.after_hit(m,0,1000,storm)
	check(m.relic_recovery.stored.values().reduce(func(n,v): return n+v,0) == 20,"Lifesteal overhealing cannot bypass the whole-use recovery cap")
	m.phase = "round_end"; m.begin_round(); m.hp = 80
	m.apply_affliction(m.Status.DARKNESS,1)
	check(m.heal(100) == 0 and m.relic_recovery.stored.is_empty(),"Blocked healing grants no overheal")
	m = fresh(["book_of_dead"])
	check(m.max_hp == 300 and m.hp == 300,"Book triples capacity and fills the new capacity on acquisition")
	m.shield = 100; m.statuses[m.Status.IMMUNITY].apply(3)
	m.relic_recovery.full_turn_finished(m)
	check(m.hp == 210 and m.shield == 100,"Book removes current HP directly through all protection")
	m.hp = 1; m.relic_recovery.full_turn_finished(m)
	check(m.hp == 1,"Book cannot kill the player")
	m = fresh(["mysterious_seed"])
	m.dice_turn.rolls_made = 1; m.dice_turn.values = [1,1,1,1,1,1]
	m.end_dice_turn(); events = m.apply_player()
	check(events.any(func(e): return e.type == "damage" and e.amount == 12) and m.phase == "enemy","Leftover overheal fires before the enemy phase through normal End Turn")

func skill_checks() -> void:
	var m = fresh(["steel_sword"])
	check(m.standing_damage_values().y == 4.0,"Steel Sword adds three to the base multiplier of one")
	m = fresh(["prismatic_stone"])
	check(m.relic_base_damage() == 30,"Prismatic Stone retains thirty total base, without another fusion bonus")
	m = fresh(["split_arrow"])
	var skill = m.Patterns.classify([3,4,5])
	check(m.skill_use_count(skill) == 2 and skill.random_target_per_use(),"Single-target skills split into two random uses")
	check(is_equal_approx(m.raw_attack_damage(skill),10.5),"Each split hit is half the original 21 damage")
	check(m.skill_use_count(skill) == 2,"Repeated previews never split again")
	m.acquire_relic("worn_dagger"); m.acquire_relic("twin_scythes")
	check(m.skill_use_count(skill) == 6,"Split hits receive ordered extra-hit relics")
	var bonus = m.Patterns.classify([3,4,5]); bonus.cast_source = "character_bonus"; bonus.inherited_damage = 100
	check(m.skill_use_count(bonus) == 6 and m.raw_attack_damage(bonus) == 50,"Bonus Fireballs split inherited damage and receive extra hits")
	var area = m.Patterns.classify([2,3,4,5])
	check(m.skill_use_count(area) == 1 and not area.split_attack,"Area skills are unchanged")
	var auto = m.Patterns.automatic_groups([4,4,1,2,3,5],range(6))[0].skill
	check(m.skill_use_count(auto) == 2 and not auto.split_attack,"Automatic attacks do not split or gain combo hits")
	m = fresh(["bracelet","contract"])
	check(is_equal_approx(m.character_base_damage()+m.relic_base_damage(),12.0),"Percentage base modifiers include earlier flat additions")
	m.relics.move(1,0)
	check(is_equal_approx(m.character_base_damage()+m.relic_base_damage(),11.0),"Moving the contract changes ordered base calculation")
	var trace: Array = m.attack_damage_steps(m.Patterns.classify([3,4,5]))
	check(is_equal_approx(trace.back().base_after*trace.back().after,m.raw_attack_damage(m.Patterns.classify([3,4,5]))),"Base modifier trace matches actual damage")

func curse_and_pet_checks() -> void:
	var m = fresh(["cursed_die"])
	m.roll_pool(false,[1,2,3,4,5,5]); m.resolve_roll_attack_step()
	check(not m.dice_turn.select(0),"No visible six blocks tap selection")
	m.dice_turn.selected = [0,1,2]
	check(m.form_selected_skill().is_empty(),"Forced stale selections cannot bypass the curse")
	m.phase = "roll"; m.roll_attacks.clear(); m.pending = m.Skill.new()
	m.roll_pool(false,[6,6,6,2,3,4])
	check(m.dice_turn.values == [6,6,6,6,6,6] and m.roll_attacks[0].skill.dice.size() == 6,"Three sixes transform and trigger the six-alike automatic attack")
	m.phase = "roll"; m.roll_attacks.clear(); m.dice_turn.locked = [0,1,2]; m.dice_turn.committed = [0,1,2]
	m.roll_pool(false,[1,2,3])
	check(m.dice_turn.values == [6,6,6,6,6,6] and m.dice_turn.locked == [0,1,2],"Spent visible sixes count without unlocking their dice")
	var ids: Array = m.RelicEffects.Sets.COLLECTIONS.pets
	m = fresh(ids)
	check(m.relics.items.size() == 1 and m.relics.items[0].id == "pet_orb","Five pets fuse into one slot")
	check(ids.all(func(id): return m.relics.has(id) and not m.relics.can_add(id)),"Fusion preserves component ownership and reward exclusions")
	var actions: Array = m.RelicEffects.roll_actions(m,false)
	check(actions.filter(func(a): return a.id == "pet_dragon").size() == 3,"Fused Dragon keeps the three-shot bonus")
	m.hp = 50; m.RelicEffects.attack_used(m)
	check(m.hp == 52,"Fused Bat retains doubled healing")
	m.apply_enemy_status(0,m.Status.BURNING,1)
	check(m.enemy_status_count(0,m.Status.BURNING) == 5,"Fused Lizard retains four extra stacks")
	m.acquire_relic("disguise_mask")
	check(m.RelicEffects.roll_actions(m,false).size() == 8,"Mask copies all fused pet roll triggers once")
	m.sell_relic(0)
	check(not m.relics.has("pet_dragon") and m.RelicEffects.roll_actions(m,false).is_empty(),"Selling the fusion removes every pet effect")
	m = fresh(["vodka"]); m.apply_enemy_status(0,m.Status.BURNING,2)
	check(m._tick_enemy_statuses()[0].amount == 20,"Vodka doubles enemy burn damage")
	m.apply_affliction(m.Status.BURNING,1)
	check(m.status_count(m.Status.BURNING) == 1,"Vodka does not alter player Burning")

func _initialize() -> void:
	healing_checks(); skill_checks(); curse_and_pet_checks()
	for id in ["vodka","mysterious_seed","magic_bandage","steel_sword","split_arrow","book_of_dead"]:
		check(not Paint._load_sprite(id).is_empty(),"New relic art loads: "+id)
	print("Build relics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
