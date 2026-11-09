extends SceneTree
## New document rules exercise damage ratios, copy safety, fusion and first-throw boundaries.
const Run = preload("res://scripts/progression/run_rules.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh(ids: Array = []):
	var m = Run.new(881)
	m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for e in m.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
	for id in ids: check(m.acquire_relic(id),"Acquire "+id)
	return m
func damage(events: Array) -> Array:
	return events.filter(func(e): return e.type == "damage").map(func(e): return e.display_amount)
func settle(m) -> void:
	for step in range(100):
		if m.perfect_relic_ready: m.resolve_roll_relic_step()
		elif m.phase == "roll_attacks": m.resolve_roll_attack_step()
		else: return
	check(false,"Queues terminate")
func _initialize() -> void:
	for spec in [["worn_spear",0.5,2,false],["war_hammer",0.5,1,true],["trident",2.0,3,false],["unknown_arm",0.5,1,false],["unknown_skull",1.0,1,false],["witch_ghost",5.0,1,false],["pet_dragon",1.5,2,false],["spiked_helmet",1.0,1,false],["prismatic_stone",3.0,1,false]]:
		var m = fresh(["basic_crystal",spec[0]])
		var actions: Array = m.RelicEffects.roll_actions(m,true)
		check(actions.size() == spec[2],"Attack count: "+spec[0])
		m.acquire_relic("master_crystal")
		var base: float = m.character_base_damage()+m.relic_base_damage()
		for a in actions:
			var events: Array = m.RelicEffects.Attack.apply(m,a.id,a.amount,a.fixed,a.area,-1,a.options)
			var hits: Array = damage(events)
			check(hits.size() == (2 if spec[3] else 1),"Target count: "+spec[0])
			check(hits[0] == floori(base*spec[1]),"Live relic-adjusted base: "+spec[0])
	for id in ["worn_spear","war_hammer","trident","unknown_arm","witch_ghost"]:
		var m = fresh([id]); m.begin_round(); m.roll_pool(false,[1,2,3,4,5,6]); settle(m)
		var hp: Array = m.enemies.map(func(e): return e.hp)
		m.reroll_die(0,[2]); settle(m)
		m.reroll_dice([1,2],[3,4]); settle(m)
		m.roll_pool(false,[1,2,3,4,5,6],true); settle(m)
		check(m.enemies.map(func(e): return e.hp) == hp,"No single, batch or Justice reroll triggers: "+id)
	var m = fresh(["warrior_greatsword","basic_crystal"])
	for source in ["manual","missile","character_bonus","chip","echo"]:
		var skill = m.make_straight_skill([3,4,5]); skill.cast_source = source
		check(damage(m.relic_skills.cast_finished(m,skill)) == [20],"Greatsword base ratio: "+source)
	var auto = m.make_straight_skill([3,4,5]); auto.pattern = "match_auto"
	check(m.relic_skills.cast_finished(m,auto).is_empty(),"Greatsword excludes auto attacks")
	m = fresh(["rice","miso_soup","salad","pickles","tempura"])
	check(m.relics.items.size() == 1 and m.relics.has("teishoku"),"Five Teishoku pieces fuse")
	check(m.relic_base_damage() == 30 and is_equal_approx(m.damage_multiplier(),2.7),"Teishoku retains food and adds 20 base")
	check(Catalog.Sets.collection_progress("rice",m.relics.items) == Vector2i(5,5),"Fused set tracks all food")
	check(not m.relics.can_add("rice"),"Fused ingredients excluded from rewards")
	var save = Run.Campaign.capture(m); var restored = fresh()
	check(Run.Campaign.restore(restored,save) and restored.relics.items == m.relics.items,"New fusion survives checkpoint")
	m = fresh(["resonance_stone","orange_stone","blue_stone"])
	check(m.damage_multiplier() == 2,"Two stones grant one multiplier")
	for id in ["purple_stone","yellow_stone","green_stone","black_stone"]: m.acquire_relic(id)
	check(m.relics.has("prismatic_stone") and m.damage_multiplier() == 4,"Six fused stones retain three multiplier")
	m = fresh(["resonance_stone","orange_stone","blue_stone","ancient_codex"])
	check(m.damage_multiplier() == 4,"Resonance follows left to right multiplier order")
	m.relics.move(3,0)
	check(m.damage_multiplier() == 3,"Moving Codex before resonance changes result")
	m = fresh(["iron_chain","perfectionist"]); m.perfect_combo = 3; m.relics.items[1].charges = 1
	check(m.RelicEffects.protect_perfect(m,false,false) and m.relics.items[0].charges == 2,"Perfectionism before chain")
	check(m.RelicEffects.protect_perfect(m,false,false) and m.relics.items[0].charges == 1,"First chain charge")
	check(m.RelicEffects.protect_perfect(m,false,false) and not m.relics.has("iron_chain"),"Second charge removes chain")
	m = fresh(["iron_chain"])
	check(not m.RelicEffects.protect_perfect(m,false,false) and m.relics.items[0].charges == 2,"No combo consumes no chain")
	check(m.RelicEffects.protect_perfect(m,false,true) and m.relics.items[0].charges == 2,"Reroll preservation consumes no chain")
	m = fresh(["diamond_crown"])
	check(damage(m.RelicEffects.Attack.apply(m,"test",100,false,true)) == [120,120],"Area item damage benefits from crown")
	check(damage(m.RelicEffects.Attack.apply(m,"test",100,true,true)) == [120,120],"Fixed area item also benefits")
	check(damage(m.RelicEffects.Attack.apply(m,"test",100,false,false)) == [100],"Single target unaffected")
	var area = m.make_straight_skill([1,2,3,4]); var single = m.make_straight_skill([1,2,3])
	check(is_equal_approx(m.damage_multiplier(area),1.2) and m.damage_multiplier(single) == 1,"Crown affects area skills only")
	m = fresh(["overflow_prism"])
	check(damage(m.RelicEffects.Attack.apply(m,"test",100,false,false)) == [100,30],"Prism transfers nonlethal damage once")
	check(damage(m.RelicEffects.Attack.apply(m,"test",100,false,true)) == [100,100],"Prism excludes area hits")
	m = fresh(["overflow_prism","supreme_crystal"])
	check(damage(m.RelicEffects.Attack.apply(m,"test",100,false,false)) == [400,120],"Prism does not reapply multiplier")
	m.enemies[0].phase_transition_pending = true
	check(m.RelicCombat.overflow(m,0,100,100,false).is_empty(),"Prism cannot cross a boss phase")
	m = fresh(["split_arrow"]); var skill = m.make_straight_skill([1,2,3]); var base: float = m.attack_base(skill)*m.damage_multiplier(skill)
	m.relic_skills.configure_split(m,skill)
	check(is_equal_approx(m.raw_attack_damage(skill),base*0.6) and skill.base_uses == 2,"Split Arrow applies 60 percent twice")
	check(preload("res://scripts/shared/content_validation.gd").all_errors().is_empty(),"All content metadata validates")
	m = fresh(["basic_crystal","trident","disguise_mask"])
	var actions: Array = m.RelicEffects.roll_actions(m,false)
	check(actions.size() == 6,"Mask repeats all three Trident hits")
	m.character_level = 10
	var expected: int = floori((m.character_base_damage()+m.relic_base_damage())*2)
	check(damage(m.RelicEffects.Attack.apply(m,"trident",0,false,false,-1,actions[0].options)) == [expected],"Item ratios scale with character level as well as relics")
	m = fresh(["powder_keg"])
	check(damage(m.apply_enemy_status(0,m.Status.BURNING,10,false)) == [25,25],"Powder Keg uses five times base")
	for id in ["rice","miso_soup","salad","pickles","tempura","worn_spear","war_hammer","trident","iron_chain","resonance_stone","diamond_crown","banana","magic_banana"]:
		check(ResourceLoader.exists(Catalog.sprite_path(id)),"Icon imported: "+id)
		var path: String = Paint._load_sprite(id)
		check(Paint.regions[path].has_area(),"Nonempty icon: "+id)
	print("Relic scaling updates: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
