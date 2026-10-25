extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(ids: Array = [], city: bool = false):
	var m = Run.new(538)
	if city: m.load_debug_wave(Waves.COUNT)
	m.begin_round()
	if not city:
		m.enemies = [Rules.make_enemy(0),Rules.make_enemy(1),Rules.make_enemy(2)]
		for e in m.enemies: e.hp = 10000; e.max_hp = 10000; e.shield = 0
	for id in ids: m.acquire_relic(id)
	return m

func losses(events: Array) -> Array:
	return events.filter(func(e): return e.type in ["damage","shield_hit"] and e.target != -1)

func roll_proc_checks() -> void:
	for row in [["worn_bow",[1,2,3,4,5,6],false,1,5],["tissue_pack",[1,1,2,4,4,6],false,1,10],["magic_slingshot",[1,2,3,4,5,6],false,1,15],["pet_ghost",[1,2,3,4,5,6],false,3,20],["pet_dragon",[1,2,3,4,5,6],false,2,15],["spiked_helmet",[1,2,3,4,5,6],true,1,13]]:
		var m = fresh([row[0]])
		m.roll_pool(row[2],row[1])
		var before: Array = m.dice_turn.values.duplicate()
		var hits: Array = losses(m.resolve_perfect_relic())
		check(hits.size() == row[3],"Roll proc hit count: "+row[0])
		check(hits.all(func(hit): return hit.display_amount == row[4]),"Roll proc damage: "+row[0])
		check(m.dice_turn.values == before and m.pending.is_empty(),"Roll proc preserves the six-die pool: "+row[0])
		check(m.resolve_perfect_relic().is_empty(),"Roll proc only resolves once: "+row[0])
	var m = fresh(["tissue_pack","spiked_helmet"])
	m.roll_pool(false,[1,2,3,4,5,6]); check(m.resolve_perfect_relic().is_empty(),"Conditional procs reject unmatched rolls")
	m = fresh(["pet_ghost","bracelet","ancient_codex","cursed_skull"])
	m.statuses[Status.MIGHT].apply(3)
	m.tarot_effects.strength = 2; m.tarot_effects.extra_uses = 3
	m.roll_pool(false,[1,2,3,4,5,6])
	m.apply_enemy_status(0,Status.CORROSION,3)
	check(losses(m.resolve_perfect_relic()).all(func(e): return e.display_amount == 20),"Incomplete-set Ghost fixed damage ignores other damage bonuses")
	check(m.status_count(Status.MIGHT) == 3 and m.tarot_effects.strength == 2 and m.tarot_effects.extra_uses == 3,"Item attacks preserve all next-skill charges")
	m = fresh(["pet_dragon","bracelet","ancient_codex"])
	m.roll_pool(false,[1,2,3,4,5,6])
	check(losses(m.resolve_perfect_relic()).all(func(e): return e.display_amount == 40),"Base-damage pets receive flat and multiplier bonuses")
	m = fresh(["pet_ghost"])
	for e in m.enemies: e.hp = 1
	m.roll_pool(false,[1,2,3,4,5,6]); m.resolve_perfect_relic()
	check(m.outcome() == "wave_clear" and m.phase == "finished" and m.pending.is_empty(),"Proc clearing a wave finishes before a skill is formed")
	m = fresh(["pet_dragon"]); m.enemies.resize(1); m.enemies[0].hp = 1
	m.roll_pool(false,[1,2,3,4,5,6])
	check(losses(m.resolve_perfect_relic()).size() == 1 and m.roll_relic_actions.is_empty(),"Roll pets stop when no living targets remain")

func status_checks() -> void:
	for stone in ["purple_stone","green_stone","prismatic_stone"]:
		for bonus in [false,true]:
			var model = fresh((["runestone"] if bonus else [])+[stone])
			var applied: Array = []
			for i in range(64):
				model.enemies[0].statuses = {}
				applied.append_array(model._attack_relic_effects(0,10,Rules.classify([1,2,3])).filter(func(e): return e.type == "status" and e.status in [Status.DARKNESS,Status.CORROSION]))
			check(not applied.is_empty() and applied.all(func(e): return e.amount == (2 if bonus else 1)),"Stone darkness/corrosion applies one base stack plus any Runestone bonus: "+stone)
	for status in [Status.DARKNESS,Status.CORROSION]:
		var model = fresh()
		model.apply_enemy_status(0,status,4)
		check(model.enemy_status_count(0,status) == 4,"Explicit multi-stack applications retain their specified amount")
		model._tick_enemy_statuses()
		check(model.enemy_status_count(0,status) == 3,"Explicit multi-stack applications still lose one stack per turn")
	var m = fresh(["pet_lizard","runestone"])
	m.apply_enemy_status(0,Status.BURNING,1)
	check(m.enemy_status_count(0,Status.BURNING) == 4,"Lizard and Runestone boost direct status applications")
	m.apply_affliction(Status.BURNING,1)
	check(m.status_count(Status.BURNING) == 1,"Enemy status modifiers do not amplify player afflictions")
	m.apply_enemy_status(0,Status.BURNING,50)
	check(m.enemy_status_count(0,Status.BURNING) == 10,"Extra burning retains ten-stack cap")
	m = fresh(["pet_lizard","orange_stone"])
	m._attack_relic_effects(0,10,Rules.classify([1,2,3]))
	check(m.enemy_status_count(0,Status.BURNING) == 3,"Lizard boosts later stone in inventory order")
	m = fresh(["pet_slime"])
	m.apply_enemy_status(0,Status.CORROSION,3)
	for i in range(5): m._tick_enemy_statuses()
	check(m.enemy_status_count(0,Status.CORROSION) == 3 and m.enemies[0].statuses[Status.CORROSION].permanent,"Slime corrosion does not decay")
	m = fresh(["ice_rose","bracelet"])
	check(losses(m.apply_enemy_status(0,Status.FROZEN,1))[0].display_amount == 15,"Ice Rose deals modified base damage to the frozen target")
	m.acquire_relic("blue_stone")
	for i in range(30):
		var events: Array = m.apply_enemy_status(0,Status.FROZEN,1)
		check(losses(events).size() == 1 and m.active_relic_procs.is_empty(),"Ice Rose cannot recursively retrigger itself")
	m = fresh(["ice_rose"],true)
	check(m.apply_enemy_status(-2,Status.FROZEN,1).is_empty() and m.city_hp == Run.CITY_MAX_HP,"City status immunity also prevents Ice Rose")
	m = fresh(["ice_rose"])
	m.set_test_roll([2,2,3])
	check(losses(m.apply_player_step()).size() == 3,"Freeze support triggers one Ice Rose hit per enemy")

func attack_checks() -> void:
	var m = fresh(["pet_bat"])
	m.hp = 10; m.set_test_roll([4,4,4]); m.apply_player_step(0)
	check(m.hp == 11,"Bat heals once for an area attack, not per target")
	m = fresh(["pet_bat"])
	m.hp = 10; m.set_test_roll([5,5,5]); m.apply_player()
	check(m.hp == 16,"Bat heals separately for all six combo attacks")
	m = fresh(["pet_bat"])
	m.hp = 10; m.set_test_roll([2,2,3]); m.apply_player_step()
	check(m.hp == 10,"Freeze support does not trigger attack healing")
	m = fresh(["pet_bat"])
	m.hp = 10; m.apply_affliction(Status.DARKNESS,3); m.set_test_roll([1,2,3]); m.apply_player_step(0)
	check(m.hp == 10,"Darkness blocks Bat healing")
	m = fresh(["spiked_helmet","bracelet","ancient_codex"])
	var before: int = m.enemies[1].hp
	m.receive_damage(5,false,1)
	check(m.enemies[1].hp == before-10 and m.hp == 95,"Helmet retaliates fixed damage at the attacker")
	before = m.enemies[1].hp
	m.receive_damage(5,true,1)
	check(m.enemies[1].hp == before,"Burn damage cannot trigger retaliation")
	m = fresh(["spiked_helmet"],true)
	m._city_hit(3)
	check(m.city_hp == Run.CITY_MAX_HP-10,"Helmet retaliates against the city")

func passive_checks() -> void:
	var m = fresh(["fries","hamburger"])
	check(is_equal_approx(m.damage_multiplier(),2.2),"Food damage bonuses add")
	m = fresh(["worn_dagger","royal_dagger","twin_scythes"])
	check(m.skill_use_count(Rules.classify([5,5,5])) == 20,"Daggers add hits before Scythes multiply")
	m.relics.move(2,0)
	check(m.skill_use_count(Rules.classify([5,5,5])) == 16,"Reordering Scythes changes the ordered hit formula")
	check(m.skill_use_count(Rules.classify([1,2,3])) == 1 and m.skill_use_count(Rules.classify([2,2,3])) == 1,"Combo relics do not add ordinary or support casts")
	m = fresh(["four_leaf_clover","five_leaf_clover"])
	var base: Dictionary = Rules.throw_rates(0)
	var rates: Dictionary = m.roll_rates(0)
	check(is_equal_approx(rates.pair,base.pair+0.10) and is_equal_approx(rates.triple,base.triple+0.05),"Clovers add percentage points, not relative percent")
	for power in [0.0,0.5,1.0]:
		for perfect in [false,true]:
			for fever in [false,true]:
				rates = m.roll_rates(power,perfect,fever)
				check(rates.values().all(func(v): return v >= -0.000001 and v <= 1.000001) and is_equal_approx(rates.normal+rates.pair+rates.triple,1.0),"Clover odds remain normalized")
	check(m.roll_rates(1,true,true).triple == 1,"City Perfect remains a guaranteed triple")
	check(Catalog.ITEMS.runestone.rarity == 2 and Catalog.ITEMS.twin_scythes.rarity == 3,"Updated document rarities")

func copy_checks() -> void:
	var m = fresh(["bracelet","disguise_mask","ancient_tentacle"])
	check(m.relic_base_damage() == 20,"Bracelet + Mask + Tentacle activates base damage four times")
	var sequence: Array = m.RelicEffects.Sequence.entries(m.relics.items)
	check(sequence.map(func(e): return e.activators) == [["bracelet"],["disguise_mask","bracelet"],["ancient_tentacle","bracelet"],["ancient_tentacle","disguise_mask","bracelet"]],"Tentacle replays both original and Mask in order")
	check(sequence.map(func(e): return m.RelicEffects.Sequence.animation_speed(e)) == [1.0,1.5,1.5,1.5],"Only copied activations receive 1.5x playback")
	var observed: Array = []
	var callback: Callable = func(_id): observed.append(m.relic_activation_speed)
	m.relic_activated.connect(callback)
	m.RelicEffects.Sequence.activate(m,sequence[1])
	m.relic_activated.disconnect(callback)
	check(observed == [1.5,1.5] and m.relic_activation_speed == 1.0,"Retrigger speed is scoped to its activation callbacks")
	var damage_steps: Array = m.attack_damage_steps(Rules.classify([1,2,3])).filter(func(step): return step.source == "relic")
	check(damage_steps.map(func(step): return step.speed) == [1.0,1.5,1.5,1.5],"Damage feedback uses the same retrigger pacing")
	m = fresh(["ancient_tentacle","disguise_mask","fries"])
	check(is_equal_approx(m.damage_multiplier(),1.3),"Mask cannot copy Tentacle; empty-left copies do nothing")
	m = fresh(["fries","disguise_mask","ancient_tentacle"])
	check(is_equal_approx(m.damage_multiplier(),2.2),"Copies repeat additive multiplier bonuses")
	m = fresh(["worn_dagger","disguise_mask","ancient_tentacle"])
	check(m.skill_use_count(Rules.classify([5,5,5])) == 10,"Copies do not overwrite repeated hit-modifier keys")
	m = fresh(["worn_bow","disguise_mask","ancient_tentacle"])
	m.set_test_roll([2,2,3]); check(losses(m.resolve_perfect_relic()).size() == 4,"Copied roll triggers each attack once")
	m = fresh(["magic_shield","disguise_mask","ancient_tentacle"])
	for i in range(5): m.relic_turn_closed = false; m._complete_relic_turn()
	check(m.relics.items[0].turns == 5 and m.relics.items[0].charges == 0,"Copies do not accelerate the turn counter")
	m.relic_turn_closed = false; m._complete_relic_turn()
	check(m.relics.items[0].turns == 0 and m.relics.items[0].charges == 4,"Sixth-turn payout grants four stored shields")
	m = fresh(["crystal_ball","disguise_mask","ancient_tentacle"])
	m.phase = "round_end"; m.begin_round()
	check(m.tarots.items.size() == 4,"Copied generators repeat their payout")
	m = fresh(["heart","disguise_mask","ancient_tentacle"])
	check(m.max_hp == 146,"Copied health multipliers apply in sequence")
	m.hp = 146; m.move_relic(0,2)
	check(m.max_hp == 110 and m.hp == 110,"Reordering clamps HP when copied maximum health shrinks")
	m.move_relic(2,0)
	check(m.max_hp == 146 and m.hp == 110,"Reordering cannot farm free healing")
	m = fresh(["armor","disguise_mask","ancient_tentacle"])
	m.receive_damage(10)
	check(m.hp == 93,"Copied armor reduces incoming damage four times")
	m = fresh(["bloodstone","disguise_mask","ancient_tentacle"])
	m.hp = 1
	m._attack_relic_effects(0,1000,Rules.classify([4,4,4]))
	m._attack_relic_effects(1,1000,Rules.classify([4,4,4]))
	check(m.hp == 41,"Each copied lifesteal payout gets one cap shared across AOE targets")
	m = fresh(["ancient_prophecy","disguise_mask","ancient_tentacle"])
	var card: Dictionary = m.tarots.add("strength")
	m.tarot_effects.cast(m,card.instance_id)
	var repeats: int = 0
	while not m.tarot_effects.pending_repeat.is_empty() and repeats < 10:
		m.tarot_effects.cast(m,m.tarot_effects.pending_repeat.instance_id)
		repeats += 1
	check(repeats == 4 and m.tarot_effects.strength == 5 and m.tarots.items.is_empty(),"Four Prophecy activations each replay the consumed card once without recursion")
	m = fresh(["bracelet","fries","disguise_mask","ancient_tentacle","cursed_skull"])
	var skill = Rules.classify([1,1,6])
	var steps: Array = m.attack_damage_steps(skill)
	check(steps.back().base_after == m.attack_base(skill) and is_equal_approx(steps.back().after,m.damage_multiplier(skill)),"Damage presentation matches copied base and multiplier math")

func curse_and_currency_checks() -> void:
	for id in Catalog.CURSED_DICE:
		var m = fresh([id,"disguise_mask","ancient_tentacle"])
		check(id in Catalog.DISABLED,"Cursed face modifiers remain temporarily disabled")
		m.roll_pool(false,[1,2,3,4,5,6])
		check(m.dice_turn.values == [1,2,3,4,5,6],"Disabled curses cannot rewrite the six-die pool")
		for other in Catalog.CURSED_DICE:
			if other != id: check(not m.acquire_relic(other),"Only one Cursed Die can be held")
		for i in range(30): check(not Catalog.CURSED_DICE.has(m.relics.draw_one(m.reward_rng)),"Owned Cursed Die excludes the whole family from drops")
		m.relics.remove(0)
		check(m.acquire_relic(id),"Removing a Cursed Die makes the family eligible again")
	var m = fresh()
	for i in range(100):
		var reserved: Array = []
		for j in range(5): reserved.append(m.relics.draw_one(m.reward_rng,reserved))
		check(reserved.filter(func(id): return Catalog.CURSED_DICE.has(id)).size() <= 1,"A treasure never reserves two incompatible Cursed Dice")
	m = fresh(["soul_vessel"])
	check(m.gain_blood_gems(100) == 100,"Soul Vessel no longer boosts blood gems")
	var gained: int = 0
	for i in range(4): gained += m.RelicEffects.enemy_soul_bonus(m,5)
	check(gained == 23 and is_zero_approx(m.enemy_soul_remainder),"Fractional enemy-soul bonuses carry forward")
	check(m.gain_souls(10) == 10,"Direct chest and shop soul grants remain unchanged")
	m = fresh(["soul_vessel","disguise_mask","ancient_tentacle"])
	check(m.RelicEffects.enemy_soul_bonus(m,100) == 160,"Four vessel activations add sixty percent enemy souls")
	m = fresh(["coin","soul_vessel"]); m.wave_kind = m.WaveRewards.RELIC
	for e in m.enemies: e.hp = 0
	m.begin_wave_reward()
	check(m.blood_gems == 10,"Wave coin is unaffected by Soul Vessel")
	m.open_wave_chest()
	var expected: int = m.Chests.CRYSTALS[m.opened_chest_tier]
	check(m.release_chest_crystals() == expected and m.blood_gems == 10+expected and m.release_chest_crystals() == 0,"Chest pays base gems once without Soul Vessel")
	m.reset_run()
	check(m.blood_gems == 0 and m.enemy_soul_remainder == 0,"New run clears currency and enemy-soul carry")

func _initialize() -> void:
	roll_proc_checks()
	status_checks()
	attack_checks()
	passive_checks()
	copy_checks()
	curse_and_currency_checks()
	print("Relic expansion: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
