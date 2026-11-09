extends SceneTree
## Document updates cover live-base attacks, conditional fusion and persistent companion protection.
const Run = preload("res://scripts/progression/run_rules.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh(ids: Array = []):
	var m = Run.new(337)
	m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for enemy in m.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	for id in ids: check(m.acquire_relic(id),"Acquire "+id)
	return m
func hits(events: Array) -> Array:
	return events.filter(func(e): return e.type == "damage" and e.target >= 0).map(func(e): return e.display_amount)
func settle(m) -> void:
	for i in range(100):
		if m.perfect_relic_ready: m.resolve_roll_relic_step()
		elif m.phase == "roll_attacks": m.resolve_roll_attack_step()
		else: return
	check(false,"Roll queue settles")
func _initialize() -> void:
	var m = fresh()
	check(not m.relics.can_add("enchanted_core"),"Core excluded before four components")
	var parts: Array = Catalog.Sets.recipe_for("golden_warrior").ingredients
	for id in parts.slice(0,4): check(m.acquire_relic(id),"Collect warrior component "+id)
	check(m.relics.can_add("enchanted_core"),"Core eligible with all four currently owned")
	var save_items: Array = m.relics.items.duplicate(true)
	m.relics.remove(0)
	check(not m.relics.can_add("enchanted_core"),"Selling component closes core pool")
	m.relics.items = save_items
	for id in ["rice","miso_soup","salad","pickles","heart","coin"]: check(m.acquire_relic(id),"Fill slots "+id)
	check(m.relics.items.size() == 10 and not m.relics.needs_slot("enchanted_core"),"Fusion fits full inventory")
	check(m.acquire_relic("enchanted_core") and m.relics.items.size() == 7,"Five components fuse into one slot")
	check(m.relics.items[0].id == "golden_warrior","Fusion retains earliest position")
	check(Catalog.Sets.collection_progress("armor",m.relics.items) == Vector2i(5,5),"Set progress includes fusion")
	check(not m.relics.can_add("armor") and not m.relics.can_add("enchanted_core"),"Fused parts excluded from pools")
	check(m.RelicEffects.incoming(m.relics.items,100,false,false).amount == 100,"Fusion replaces armor protection")
	m = fresh(["golden_warrior","basic_crystal"])
	var warrior: Dictionary = m.relics.items[0]
	check(warrior.guardian_hp == 300 and warrior.guardian_max_hp == 300,"Warrior has 30 percent max HP")
	check(m.RelicEffects.roll_actions(m,false).size() == 2 and m.RelicEffects.roll_actions(m,true).size() == 3,"Two opening spears, three on Perfect")
	for action in m.RelicEffects.roll_actions(m,true):
		check(hits(m.RelicEffects.Attack.apply(m,action.id,action.amount,action.fixed,action.area,-1,action.options)) == [10],"Each spear uses adjusted live base")
	var events: Array = m.receive_damage(100,false,0)
	check(m.hp == 950 and warrior.guardian_hp == 250,"Share half HP damage")
	check(hits(events) == [10],"Counter attacker once with adjusted base")
	m.shield = 80
	events = m.receive_damage(100,false,0)
	check(m.hp == 940 and warrior.guardian_hp == 240,"Ordinary shield resolves before sharing")
	check(hits(events) == [10],"Partial shield still permits one counter")
	m.shield = 100
	events = m.receive_damage(100,false,0)
	check(warrior.guardian_hp == 240 and hits(events).is_empty(),"Fully blocked damage neither shares nor counters")
	events = m.receive_damage(50,true,0)
	check(m.hp == 890 and warrior.guardian_hp == 240 and hits(events).is_empty(),"Burning bypasses companion")
	warrior.guardian_hp = 20
	events = m.receive_damage(100,false,0)
	check(warrior.guardian_hp == 0 and m.hp == 810,"Sharing cannot exceed remaining companion HP")
	check(hits(events) == [10] and warrior.guardian_recovery == 3,"Breaking hit counters and starts three-turn recovery")
	check(m.RelicEffects.roll_actions(m,true).is_empty(),"Downed warrior has no opening attacks")
	m.receive_damage(10,false,0)
	check(m.hp == 800,"Downed warrior no longer shares")
	m.RelicEffects.turn_finished(m)
	m._load_wave()
	check(warrior.guardian_recovery == 2,"Wave change does not reset recovery")
	m.RelicEffects.turn_finished(m)
	check(warrior.guardian_hp == 0,"Still down after two completed turns")
	events = m.RelicEffects.turn_finished(m)
	check(warrior.guardian_hp == 300 and warrior.guardian_recovery == 0,"Returns full after third completion")
	check(events.any(func(e): return e.type == "guardian_return"),"Recovery emits visible feedback")
	warrior.guardian_hp = 123
	var saved: Dictionary = Run.Campaign.capture(m)
	var restored = fresh()
	check(Run.Campaign.restore(restored,saved),"Checkpoint restores")
	check(restored.relics.items[0].guardian_hp == 123,"Checkpoint does not heal guardian")
	m.relics.move(0,1)
	m.RelicProtection.sync_guardians(m)
	check(warrior.guardian_hp == 123,"Inventory reorder does not heal")
	m.acquire_relic("heart")
	check(warrior.guardian_max_hp == 330 and warrior.guardian_hp == 153,"Capacity follows max HP preserving missing health")
	m = fresh(["golden_warrior","disguise_mask"])
	check(m.RelicEffects.roll_actions(m,true).size() == 6,"Copy repeats spear attacks")
	m.receive_damage(1000,false,0)
	check(m.relics.items[0].guardian_hp == 0 and m.hp == 300,"Copy shares a single finite guardian health pool")
	m.RelicEffects.turn_finished(m)
	check(m.relics.items[0].guardian_recovery == 2,"Copies do not accelerate recovery")
	m = fresh(["rusty_round_shield"])
	m.shield = 50
	m.receive_damage(40,false,0)
	check(m.shield == 10 and not m.relics.items[0].get("shield_triggered",false),"Shield-only damage does not proc")
	m.receive_damage(20,false,0)
	check(m.hp == 990 and m.shield == 100,"First HP loss creates ten-percent shield")
	m.shield += 80
	m.receive_damage(60,false,0)
	check(m.shield == 120,"Temporary shields absorb first")
	m.RelicEffects.turn_finished(m)
	check(m.shield == 80,"Expiration removes only unspent temporary shield")
	m.receive_damage(90,false,0)
	check(m.shield == 100,"Next turn can proc again")
	m.receive_damage(110,false,0)
	check(m.shield == 0,"Further HP loss cannot proc twice this turn")
	m.RelicEffects.turn_finished(m)
	m.statuses[m.Status.CORROSION].count = 1
	m.receive_damage(10,false,0)
	check(m.shield == 0,"Corrosion prevents reactive shield")
	m = fresh(["rusty_round_shield","disguise_mask"])
	m.receive_damage(100,false,0)
	check(m.shield == 200,"Copies repeat first-loss shield payout")
	m._load_wave(); m.shield = 70; m.RelicEffects.turn_finished(m)
	check(m.shield == 70,"Old-wave temporary shield cannot remove next-wave shielding")
	for id in ["magic_shield","magic_sword"]:
		m = fresh([id,"disguise_mask"])
		for i in range(3): m.RelicEffects.turn_finished(m)
		check(m.relics.items[0].charges == 0,"Charge waits four turns: "+id)
		m.RelicEffects.turn_finished(m)
		check(m.relics.items[0].charges == 1,"Fourth turn stores only one charge even with copy: "+id)
		for i in range(8): m.RelicEffects.turn_finished(m)
		check(m.relics.items[0].charges == 1,"Unspent charge cannot stack: "+id)
	m = fresh(["magic_shield"])
	check(m.acquire_relic("magic_shield",-1,true),"Shop duplicate remains valid")
	m.relics.items[0].turns = 3; m.relics.items[1].turns = 1
	m.RelicEffects.turn_finished(m)
	check(m.relics.items[0].charges == 1 and m.relics.items[1].charges == 0,"Duplicate relic timers remain independent")
	m = fresh(["golden_warrior"])
	check(m.acquire_relic("armor",-1,true),"Previously stocked shop can add an owned set component")
	m.receive_damage(100,false,0)
	check(m.hp == 955 and m.relics.items[0].guardian_hp == 255,"Armor reduces damage before sharing")
	m = fresh(["golden_warrior"])
	m.statuses[m.Status.IMMUNITY].count = 1
	check(hits(m.receive_damage(100,false,0)).is_empty() and m.relics.items[0].guardian_hp == 300,"Invincibility causes no sharing or counter")
	m = fresh(["rusty_round_shield"])
	m.receive_damage(10,true)
	check(m.shield == 100,"Burning HP loss can trigger the first-loss shield")
	m.RelicEffects.turn_finished(m)
	check(m.shield == 0,"Shield triggered during status phase expires at its end")
	check(Catalog.ITEMS.magic_shield.rarity == 2,"Magic Shield now epic")
	m = fresh(["worn_bow","tissue_pack","basic_crystal"])
	m.dice_turn.values = [1,1,2,2,5,5]
	var actions: Array = m.RelicEffects.roll_actions(m,false)
	check(actions.size() == 2,"No straight enables tissue attack")
	for action in actions:
		check(hits(m.RelicEffects.Attack.apply(m,action.id,0,false,false,-1,action.options)) == [5 if action.id == "worn_bow" else 10],"Small relic attacks scale with adjusted base: "+action.id)
	m.dice_turn.values = [1,2,3,4,5,6]
	check(m.RelicEffects.roll_actions(m,false).size() == 1,"Straight disables tissue attack")
	m = fresh(["golden_warrior"]); m.begin_round(); m.roll_pool(false,[1,2,3,4,5,6]); settle(m)
	var health: Array = m.enemies.map(func(e): return e.hp)
	m.reroll_die(0,[2]); settle(m)
	m.roll_pool(false,[1,2,3,4,5,6],true); settle(m)
	check(m.enemies.map(func(e): return e.hp) == health,"Rerolls and Justice never fire guardian spears")
	m = fresh(["overflow_prism"])
	var area = m.make_straight_skill([1,2,3,4])
	var hit := {"target":0,"damage":100,"ignore":false}
	check(hits(m._apply_attack_hit(area,hit)) == [100],"Area skill excludes Prism")
	var single = m.make_straight_skill([1,2,3])
	check(hits(m._apply_attack_hit(single,hit)) == [100,30],"Single skill still triggers Prism")
	check(hits(m.RelicEffects.Attack.apply(m,"test",100,true,true)) == [100,100],"Area item excludes Prism")
	check(hits(m.AreaAttack.apply_fixed(m,100,area)) == [100,100],"Tarot area damage excludes Prism")
	check(preload("res://scripts/shared/content_validation.gd").all_errors().is_empty(),"Content references valid")
	for id in ["rusty_round_shield","enchanted_core","golden_warrior"]:
		check(Paint.regions.get(Paint._load_sprite(id),Rect2()).has_area(),"Icon loads: "+id)
	print("Warrior relic update: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
