extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Effects = preload("res://scripts/relics/relic_effects.gd")
const Sets = preload("res://scripts/relics/relic_sets.gd")
const Rolls = preload("res://scripts/relics/relic_roll_rules.gd")
const Inventory = preload("res://scripts/relics/relic_inventory.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var m = Run.new(431)
	m.begin_round()
	return m
func _initialize() -> void:
	var foods: Array = Sets.RECIPES.meal.ingredients
	# Every ingredient subset must preserve its exact ownership and current-tier bonus.
	for mask in range(1,32):
		var inv = Inventory.new()
		inv.add("heart")
		var chosen: Array = []
		for i in range(5):
			if mask & (1<<i): chosen.append(foods[i]); check(inv.add(foods[i]),"Ingredient acquired")
		check(inv.items.size()==2,"Foods occupy one slot")
		for id in chosen: check(inv.has(id) and not inv.can_add(id),"Fused ingredients stay unique")
		if chosen.size()>1:
			check(inv.items[1].ingredients==chosen,"Exact collected graphics and order retained")
			var bonus: float = [0,0,0,0,10,30][chosen.size()]
			check(is_equal_approx(Effects.base_damage(inv.items),bonus+(10 if "oreo_sundae" in chosen else 0)),"Only current tier bonus")
	var m = fresh()
	for id in ["fries","heart","armor","coin","worn_dagger","worn_bow","tissue_pack","pet_bat","bloodstone","runestone"]: check(m.acquire_relic(id),"Fill inventory")
	check(m.acquire_relic("hamburger") and m.relics.items.size()==10,"Full inventory permits fusion")
	check(m.relics.items[0].id=="budget_meal","Fusion retains earliest slot")
	for id in ["lemon_soda","oreo_sundae","fried_chicken"]: check(m.acquire_relic(id),"Upgrade full inventory")
	check(m.relics.items[0].id=="super_meal","All five form final meal")
	var skill = m.Patterns.classify([1,2,3])
	check(is_equal_approx(m.damage_multiplier(skill),3.135),"(1+.3+.6)*1.1*1.5; no earlier tier multiplier")
	check(is_equal_approx(m.relic_base_damage(),47),"Sundae10 + final bonus30 + Runestone5 + Dagger2")
	for i in range(50): check(m.relics.draw_one(m.reward_rng) not in foods,"Owned set ingredients excluded from rewards")
	m = fresh(); m.acquire_relic("fried_chicken"); m.acquire_relic("codex_page")
	check(is_equal_approx(m.damage_multiplier(skill),1.3),"Factor then addition")
	m.relics.move(0,1)
	check(is_equal_approx(m.damage_multiplier(skill),1.32),"Addition then factor")
	m = fresh(); m.acquire_relic("fries"); m.acquire_relic("fried_chicken"); m.acquire_relic("disguise_mask"); m.acquire_relic("ancient_tentacle")
	var expected := 1.0
	for i in range(4): expected = (expected+0.3)*1.1+0.3
	check(is_equal_approx(m.damage_multiplier(skill),expected),"Mask and Tentacle replay ordered set modifiers four times")
	check(m.relic_base_damage()==0,"Retriggers repeat current tier bonus only")
	check(m.relics.remove(0).ingredients==["fries","fried_chicken"] and m.relics.can_add("fries"),"Removing a set releases its components into reward eligibility")
	m = fresh(); m.acquire_relic("magic_sword"); m.acquire_relic("codex_page")
	skill.critical=true
	check(is_equal_approx(m.damage_multiplier(skill),3.2),"Critical at inventory position")
	m.relics.move(0,1)
	check(is_equal_approx(m.damage_multiplier(skill),3.6),"Critical after addition")
	var trace: Array = m.attack_damage_steps(skill)
	check(is_equal_approx(trace.back().base_after*trace.back().after,m.raw_attack_damage(skill)),"Trace equals damage")
	skill.critical=false
	m = fresh(); m.acquire_relic("lemon_soda")
	var auto = m.Patterns.automatic_groups([2,2,3,4,5,6],range(6))[0].skill
	check(is_equal_approx(m.attack_base(auto),6.0),"Soda adds to auto base before the pip coefficient")
	check(is_equal_approx(m.attack_base(skill),18),"Soda does not buff straight")
	trace=m.attack_damage_steps(auto)
	check(is_equal_approx(trace.back().base_after*trace.back().after,m.raw_attack_damage(auto)),"Auto trace matches")
	# Verify actual damage as a four-piece meal upgrades, without retaining its old bonus.
	m = fresh(); m.enemies = [m.make_enemy(0)]
	m.enemies[0].hp = 10000; m.enemies[0].max_hp = 10000; m.enemies[0].shield = 0
	for id in ["lemon_soda","fries","hamburger","oreo_sundae"]: m.acquire_relic(id)
	m.pending = m.Patterns.classify([1,2,3]); m.phase = "player"
	m.apply_player(0)
	check(m.enemies[0].hp == 9784,"Four-piece Fireball deals (5+10+10)*3.6*(1+.3+.6+.5) = 216")
	m.acquire_relic("fried_chicken")
	m.pending = m.Patterns.classify([1,2,3]); m.phase = "player"
	m.apply_player(0)
	check(m.enemies[0].hp == 9277,"Five-piece Fireball deals (5+10+30)*3.6*((1+.3+.6)*1.1*1.5) = 507")
	m = fresh(); m.acquire_relic("lucky_die")
	for i in range(10): Rolls.apply(m,range(6))
	check(m.relics.items[0].throws==10,"Ready after ten throws")
	m.dice_turn.values=[6,6,6,6,6,6]
	Rolls.apply(m,[0,1,2])
	check(m.relics.items[0].throws==10,"Wait with fewer dice")
	Rolls.apply(m,[0,1,2,3])
	check(m.relics.items[0].throws==0 and m.dice_turn.values[4]==6 and m.dice_turn.values[5]==6,"Guarantee spends once, preserves used dice")
	check(m.Patterns.has_combination(m.dice_turn.values.slice(0,4)),"Guaranteed straight")
	m.relics.items[0].throws=10; m.tarot_effects.devil=6
	m.roll_pool(false,[1,1,1,1,1,1])
	check(m.dice_turn.values==[6,6,6,6,6,6],"Tarot overrides relic guarantee")
	for spec in [["three_leaf_clover",3,0.20],["four_leaf_clover",4,0.10],["five_leaf_clover",5,0.05]]:
		m=fresh();m.acquire_relic(spec[0]); var activated := 0
		for i in range(10000):
			m.dice_turn.values=[6,6,6,6,6,6]
			Rolls.apply(m,range(6))
			if m.dice_turn.values!=[6,6,6,6,6,6]: activated+=1
		check(absf(activated/10000.0-spec[2])<0.015,"Clover proc rate")
	# Clover may rewrite only unused dice, and must not consume RNG when ineligible.
	m=fresh();m.acquire_relic("three_leaf_clover")
	var state: int = m.rng.state
	m.dice_turn.values=[6,6,6,6,6,6]
	Rolls.apply(m,[0,1])
	check(m.rng.state == state and m.dice_turn.values == [6,6,6,6,6,6],"Three-leaf Clover waits with fewer than three unused dice")
	var triggered := false
	for i in range(100):
		m.dice_turn.values=[6,6,6,2,4,6]
		Rolls.apply(m,[0,1,2])
		check(m.dice_turn.values.slice(3) == [2,4,6],"Clover preserves already-used dice")
		if m.dice_turn.values.slice(0,3) != [6,6,6]:
			triggered = true
			check(m.Patterns.has_combination(m.dice_turn.values.slice(0,3)),"Common clover creates a legal three-straight")
	check(triggered,"Common clover triggers in deterministic eligible trials")
	m.tarot_effects.devil=6
	m.roll_pool(false,[1,1,1,1,1,1])
	check(m.dice_turn.values == [6,6,6,6,6,6],"Tarot transforms still override common clover")
	m=fresh();m.acquire_relic("tissue_pack");m.acquire_relic("magic_slingshot");m.acquire_relic("worn_bow")
	m.dice_turn.values=[6,6,6,6,6,6]
	var actions: Array=Effects.roll_actions(m,false)
	check(actions.size()==3 and actions[0].amount==10 and actions[1].amount==18 and not actions[2].fixed,"Roll damage rules")
	m.dice_turn.values=[1,2,3,4,5,6]
	check(Effects.roll_actions(m,false).size()==2,"No tissue with available straight")
	print("Relic sets: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
