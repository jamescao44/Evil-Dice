extends SceneTree
## Exercise new relics at model boundaries: loot, ordered effects, turns and generated casts.
const Run = preload("res://scripts/progression/run_rules.gd")
const C = preload("res://scripts/relics/relic_catalog.gd")
const Conditions = preload("res://scripts/relics/relic_conditions.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh(ids: Array = []):
	var m = Run.new(102525)
	m.enemies = [m.make_enemy(0),m.make_enemy(0)]
	for e in m.enemies: e.hp = 100000; e.max_hp = 100000
	for id in ids: check(m.acquire_relic(id),"Acquire "+id)
	m.begin_round()
	return m
func settle_roll(m) -> void:
	for guard in range(100):
		if m.perfect_relic_ready: m.resolve_roll_relic_step(); continue
		if m.phase == "roll_attacks": m.resolve_roll_attack_step(); continue
		if m.start_roll_chip_casts(): continue
		if m.phase in ["player","executing"] and m.pending.cast_source != "manual": m.apply_player(); continue
		return
	check(false,"Generated roll casts must terminate")
func set_checks() -> void:
	check(C.ITEMS.magic_sword.rarity == C.Rarity.EPIC,"Magic Sword is Epic")
	var m = fresh()
	check(not m.relics.can_add("unidentified_ring"),"Ring locked without five bones")
	for id in Conditions.BONES: m.acquire_relic(id)
	check(m.relics.items.size() == 5 and m.relics.can_add("unidentified_ring"),"Five bones wait for ring")
	var actions: Array = m.RelicEffects.roll_actions(m,false)
	check(actions.map(func(a): return int(a.amount)) == [5,5,5,10,10],"Bones produce five individual attacks")
	check(m.relics.draw_one(m.reward_rng,[],[0,0,1,0,0]) != "witch_ghost","Fusion never drops directly")
	m.acquire_relic("unidentified_ring")
	check(m.relics.items.size() == 1 and m.relics.has("witch_ghost"),"Six remains fuse into one Witch")
	actions = m.RelicEffects.roll_actions(m,false)
	check(actions.size() == 1 and actions[0].amount == 50,"Witch replaces component attacks with 50 base")
	check(Conditions.BONES.all(func(id): return m.relics.has(id) and not m.relics.can_add(id)),"Fusion preserves component exclusion")
	m.sell_relic(0)
	check(not m.relics.can_add("unidentified_ring"),"Selling Witch closes ring pool")
	m = fresh(["broken_blade"])
	check(is_equal_approx(m.damage_multiplier(),1.3),"Blade adds 0.3")
	m.acquire_relic("broken_hilt")
	check(m.relics.items.size() == 1 and is_equal_approx(m.damage_multiplier(),3.0),"General sword replaces component bonus with +2")
	for id in C.ITEMS:
		var set_title: String = C.Sets.set_label(id)
		check(C.short_description(id).contains("(Set: "+set_title+")") if not set_title.is_empty() else not C.short_description(id).contains("(Set:"),"Set hint for "+id)
		if C.Sets.uses_composite_art(id): continue
		var sprite: String = Paint._load_sprite(id)
		check(Paint.textures[sprite] != null,"Artwork for "+id)
	check(Paint.textures[Paint._load_sprite("witch_ghost")] == Paint.textures[Paint._load_sprite("unidentified_ring")],"Witch uses identical ring texture")
func ordered_checks() -> void:
	var m = fresh(["precognition_eye","mithril_blade"])
	for i in range(4): m.RelicEffects.tarot_used(m)
	check(is_equal_approx(m.damage_multiplier(),2.4),"Eye adds before rightward multiplier")
	m.relics.move(0,1)
	check(is_equal_approx(m.damage_multiplier(),2.2),"Moving Eye changes ordered calculation")
	m.RelicEffects.tarot_used(m,false)
	check(is_equal_approx(m.damage_multiplier(),2.2),"Prophecy replays do not grow Eye twice for one card")
	m.sell_relic(1)
	check(is_equal_approx(m.damage_multiplier(),2),"Selling Eye removes its saved bonus")
	m = fresh(["holy_grail"])
	var skill = m.make_straight_skill([3,4,5])
	check(is_equal_approx(m.raw_attack_damage(skill),10.5),"Grail halves skill damage")
	var auto = m.Patterns.automatic_groups([1,1,2,3,4,5],range(6))[0].skill
	check(is_equal_approx(m.raw_attack_damage(auto),2.75),"Grail leaves automatic attacks unchanged")
	check(m.RelicEffects.Attack.apply(m,"test",10)[0].amount == 20,"Grail doubles item damage")
	check(m.RelicEffects.Attack.apply(m,"test",10,true)[0].amount == 20,"Grail also doubles fixed item damage")
	m = fresh(["hellfire","nightmare_totem","corrupt_crystal"])
	for id in [m.Status.BURNING,m.Status.DARKNESS,m.Status.CORROSION]: m.apply_enemy_status(0,id,1)
	check(is_equal_approx(Conditions.target_factor(m,0),pow(1.3,3)),"Three status vulnerabilities multiply independently")
	check(m.attack_damage(m.make_straight_skill([3,4,5]),0) == 68,"Skill damage includes corrosion and three vulnerabilities")
	check(m.RelicEffects.Attack.apply(m,"test",10,false,false,0)[0].amount == 31,"Item damage includes target vulnerabilities")
func turn_checks() -> void:
	var m = fresh(["ticket"])
	check(m.dice_turn.rolls_left == 4 and m.dice_turn.ticket_rolls_left == 1,"Ticket grants fourth roll")
	for i in range(3):
		m.roll_pool(false,[1,2,3,4,5,6]); settle_roll(m)
	check(m.dice_turn.rolls_left == 1 and m.dice_turn.ticket_rolls_left == 1,"Ordinary rolls consumed first")
	m._bank_unused_rolls(); check(m.reroll_progress == 0,"Ticket never banks treasure")
	m.roll_pool(false,[1,2,3,4,5,6]); settle_roll(m)
	check(m.dice_turn.rolls_left == 0 and m.dice_turn.ticket_rolls_left == 0,"Ticket consumed last")
	m._grant_dice_bonus_turn()
	check(m.dice_turn.rolls_left == 3,"Bonus pool cannot refresh spent ticket")
	m.phase = "round_end"; m.begin_round()
	check(m.dice_turn.rolls_left == 4,"Full turn refreshes ticket")
	m = fresh(["ticket"]); m.roll_pool(false,[1,2,3,4,5,6]); m._bank_unused_rolls()
	check(m.reroll_progress == 2,"Unused ordinary rolls still count")
	m = fresh(["frozen_tilapia"]); m.roll_pool(false,[1,2,3,4,5,6]); m.end_dice_turn()
	var events: Array = m.apply_player()
	check(events.any(func(e): return e.type == "damage" and e.amount == 21),"Tilapia snapshots leftover pip sum before dice lock")
	check(m.relic_recovery.finish_player_turn(m).is_empty(),"Tilapia triggers only once")
	m = fresh(["banana","magic_banana"])
	check(is_equal_approx(m.damage_multiplier(),2.25),"Banana addition precedes Magic Banana multiplier")
	var removed := 0
	for seed_value in range(200):
		m.relics.clear(); m.relics.add("banana"); m.rng.seed = seed_value
		Conditions.turn_finished(m)
		if not m.relics.has("banana"): removed += 1
	check(removed > 20 and removed < 65,"Banana disappearance samples near 20 percent")
func chip_checks() -> void:
	var m = fresh(["red_chip","blue_chip","echo_bell","magic_sword"])
	m.relics.items[3].charges = 1
	m.tarot_effects.strength = 2
	m.statuses[m.Status.MIGHT].apply(2)
	m.roll_pool(false,[1,2,3,4,5,6])
	check(m.roll_chip_casts.size() == 2 and m.roll_chip_casts[0].skill.dice == [1,2,3,4,5,6] and m.roll_chip_casts[1].skill.dice == [4,5,6],"Red longest, Blue shortest, high-pip tie")
	var before: int = m.enemies[0].hp+m.enemies[1].hp
	settle_roll(m)
	check(m.phase == "roll" and m.pending.is_empty() and m.dice_turn.locked.is_empty(),"Chip casts return to same unspent dice pool")
	check(m.enemies[0].hp+m.enemies[1].hp < before,"Chip casts actually damage enemies")
	check(m.character_passive.charge == 0 and m.relics.items[2].get("casts",0) == 0,"Chip casts do not fill character or Echo counters")
	check(m.relics.items[3].charges == 1 and m.tarot_effects.strength == 2 and m.statuses[m.Status.MIGHT].count == 2,"Chips preserve next-skill and attack-buff charges")
	m = fresh(["black_chip"]); m.roll_pool(false,[1,1,3,3,5,5]); settle_roll(m)
	check(m.damage_multiplier() == 6,"No straight activates Black Chip")
	m.roll_pool(false,[1,2,3,4,5,6]); settle_roll(m)
	check(m.damage_multiplier() == 1,"Next throw replaces Black Chip condition")
	m.roll_pool(false,[1,1,3,3,5,5]); settle_roll(m); m.RelicEffects.turn_finished(m)
	check(m.damage_multiplier() == 1,"Black Chip expires at turn end")
func potion_checks() -> void:
	var m = fresh(["mystery_potion"])
	var entry: Dictionary = m.RelicEffects.Sequence.entries(m.relics.items)[0]
	var proc_count := 0
	for seed_value in range(1000):
		m.enemies[0].erase("statuses"); m.rng.seed = seed_value
		var events: Array = Conditions.after_hit(m,0,entry)
		if not events.is_empty():
			proc_count += 1
			check(events[0].get("status",-1) in Conditions.RANDOM_STATUSES and events[0].amount == 1,"Potion applies one supported stack")
	check(proc_count >= 60 and proc_count <= 140,"Potion samples near ten percent")
	m.active_relic_procs.append("mystery_potion")
	for seed_value in range(100):
		m.rng.seed = seed_value
		check(Conditions.after_hit(m,0,entry).is_empty(),"Potion does not recurse through status item attacks")

func plague_checks() -> void:
	var m = fresh(["potion_x"])
	m.apply_enemy_status(0,m.Status.PLAGUE,10,false)
	check(not m.is_enemy_alive(0),"Potion X kills ordinary enemy at threshold")
	check(m.enemy_status_count(0,m.Status.PLAGUE) == 10,"Potion X preserves stacks")
	m = fresh(["potion_x","disguise_mask"])
	m.enemies = [m.make_enemy(m.EnemyCatalog.Role.COMMANDER)]
	var e: Dictionary = m.enemies[0]
	e.hp = 10000; e.max_hp = 10000
	m.apply_enemy_status(0,m.Status.PLAGUE,10,false)
	check(e.hp == 6930,"Boss loses 30 percent current HP once, even with copy relic")
	m.apply_enemy_status(0,m.Status.PLAGUE,1,false)
	check(e.hp == 6930,"Extra stacks do not retrigger same phase")
	m.apply_enemy_status(0,m.Status.BURNING,5,false); m.apply_enemy_status(0,m.Status.FROZEN,1,false)
	m.phase = "executing"; m.direct_enemy_hp_damage(0,e.hp)
	check(e.get("phase_transition_pending",false),"Boss transition waits for sequence end")
	m.BossRules.finish_attack_sequence(m)
	check(e.boss_phase == 2 and e.get("statuses",{}).is_empty(),"New boss phase clears old statuses")
	var before: int = e.hp
	m.apply_enemy_status(0,m.Status.PLAGUE,10,false)
	check(e.hp == before-100-floori((before-100)*0.3),"Fresh phase can trigger Potion X once again")
func companion_checks() -> void:
	var m = fresh()
	var ghost = preload("res://scripts/relics/witch_companion.gd").new()
	var random_state: int = m.rng.state
	ghost.advance(1,m)
	check(ghost.opacity == 0,"Ghost is absent without the relic")
	m.acquire_relic("witch_ghost"); ghost.advance(0.3,m)
	check(ghost.opacity == 1,"Witch acquisition fades in the follower")
	ghost.activate("pet_ghost")
	check(ghost.pulse == 0,"Pet Ghost is a separate companion")
	ghost.activate("witch_ghost")
	check(ghost.pulse == 1,"Witch attack lights the spectral follower")
	m.sell_relic(0); ghost.advance(0.3,m)
	check(ghost.opacity == 0,"Selling the ring removes its follower")
	check(m.rng.state == random_state,"Ghost motion never consumes combat RNG")

func _initialize() -> void:
	set_checks(); ordered_checks(); turn_checks(); chip_checks(); potion_checks(); plague_checks(); companion_checks()
	print("October relics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
