extends SceneTree
## Exercise the new document relics through real inventory, roll, cast and reward paths.
const Run = preload("res://scripts/progression/run_rules.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
const NEW := ["glass_marble","blood_bag","piggy_bank","bookmark","cross","light_sword","steel_marble","perfectionist","overflow_prism","gold_marble","powder_keg","echo_bell","alternating_gears","enchanted_missile","royal_seal","magician_hat"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(count: int = 2):
	var m = Run.new(251025)
	m.enemies.clear()
	for i in range(count):
		var enemy: Dictionary = m.make_enemy(0)
		enemy.hp = 100000; enemy.max_hp = 100000
		m.enemies.append(enemy)
	m.begin_round()
	return m

## Finish every automatically generated cast without a second player decision.
func settle_cast(m, values: Array = [3,4,5]) -> Array:
	m.pending = m.Patterns.classify(values)
	m.phase = "player"
	var events: Array = m.apply_player(0)
	for guard in range(50):
		if m.phase != "player" or m.pending.cast_source == "manual": break
		events.append_array(m.apply_player())
	return events

func stat_and_fusion_checks() -> void:
	var m = fresh()
	for id in ["glass_marble","steel_marble","gold_marble"]: check(m.acquire_relic(id),"Acquire "+id)
	var fireball = m.Patterns.classify([3,4,5])
	check(is_equal_approx(m.damage_multiplier(fireball),1.6),"Marbles add to an independent 1.6 factor")
	check(m.damage_multiplier(m.Patterns.classify([2,3,4,5])) == 1,"Marbles do not boost longer straights")
	check(m.relics.items.size() == 3,"Marbles stay separate until all four ingredients are present")
	for id in ["heart","armor","coin","bookmark","blood_bag","cross","light_sword"]: m.acquire_relic(id)
	check(m.relics.items.size() == 10 and not m.relics.needs_slot("magic_slingshot"),"Final fusion component fits a full inventory")
	check(m.acquire_relic("magic_slingshot") and m.relics.items.size() == 8 and m.relics.items[0].id == "enchanted_missile","Four-part fusion occupies earliest ingredient slot")
	check(m.relic_base_damage() == 10 and is_equal_approx(m.damage_multiplier(fireball),2.0),"Fusion replaces ingredient stats instead of retaining extra bonuses")
	check(not m.relics.can_add("glass_marble") and not m.relics.can_add("magic_slingshot"),"Fused components stay excluded from rewards")
	check(not m.relics.draw_one(m.reward_rng,[],[0,0,0,1,0]).is_empty(),"Legendary reward pool stays usable")
	var steps: Array = m.attack_damage_steps(fireball)
	check(is_equal_approx(steps.back().after,m.damage_multiplier(fireball)),"Damage display and actual marble multiplier agree")
	m = fresh(); m.acquire_relic("glass_marble"); m.acquire_relic("disguise_mask"); m.acquire_relic("ancient_tentacle")
	check(is_equal_approx(m.damage_multiplier(fireball),1.4),"Copies add within the marble family")
	m = fresh(); m.acquire_relic("light_sword")
	check(m.damage_multiplier(fireball) == 1,"Light Sword requires a sole enemy")
	m.enemies[1].hp = 0
	check(m.damage_multiplier(fireball) == 3.0,"Light Sword activates immediately when one enemy remains")
	m.acquire_relic("mithril_blade")
	check(m.damage_multiplier(fireball) == 6.0,"Light Sword adds two before a later independent multiplier")
	m.move_relic(0,1)
	check(m.damage_multiplier(fireball) == 4.0,"Moving Light Sword after Mithril adds two after doubling")
	var solo_trace: Array = m.attack_damage_steps(fireball)
	check(is_equal_approx(solo_trace.back().after,m.damage_multiplier(fireball)),"Solo-target damage display follows the same ordered addition")
	m = fresh(); m.acquire_relic("blood_bag"); m.hp = 1
	check(m.heal(20) == 22,"Blood Bag improves ordinary healing")
	m.acquire_relic("bloodstone"); m.hp = 1
	m.RelicEffects.after_hit(m,0,10000,fireball)
	check(m.hp == 11,"Blood Bag cannot bypass the lifesteal cap")
	m.apply_affliction(m.Status.DARKNESS,1)
	check(m.heal(20) == 0,"Darkness still blocks amplified recovery")

func drop_and_sale_checks() -> void:
	var m = fresh(5)
	m.acquire_relic("soul_vessel"); m.acquire_relic("piggy_bank")
	var before: int = m.blood_gems
	for i in range(4): m.hit_enemy(i,1000000)
	check(m.blood_gems-before == 20,"Soul Vessel does not increase blood gems")
	check(m.character_level == 2 and m.souls == 13,"Four 5-soul enemies grant 23 souls with fractional carry")
	var slot: int = m.relics.index_of("piggy_bank")
	check(m.relic_sale_preview(slot) == 14,"Piggy savings add 20% of enemy gems to sale value")
	m.gain_blood_gems(100); m.gain_souls(10)
	check(m.relic_sale_preview(slot) == 14,"Chest/shop grants do not increase piggy savings")
	check(m.sell_relic(slot) == 14,"Selling pays stored savings exactly once")
	m = fresh(); m.acquire_relic("piggy_bank"); m.RelicEffects.enemy_gems_dropped(m,8)
	for id in ["armor","heart","coin","glass_marble","blood_bag","bookmark","cross","light_sword","steel_marble"]: m.acquire_relic(id)
	before = m.blood_gems
	check(m.acquire_relic("gold_marble",0) and m.blood_gems-before == 11,"Replacement also pays whole stored gems")
	m = fresh(); m.acquire_relic("cross")
	check(is_equal_approx(m.RelicEffects.tarot_drop_chance(m.relics.items),0.175),"Cross adds five percentage points to one-in-eight drops")
	m.acquire_relic("disguise_mask")
	check(is_equal_approx(m.RelicEffects.tarot_drop_chance(m.relics.items),0.225),"Copied Cross repeats the additive drop bonus")

func tarot_and_perfect_checks() -> void:
	var m = fresh(); m.acquire_relic("bookmark")
	var card: Dictionary = m.grant_tarot("strength")
	m.tarot_effects.prepare(m,card.instance_id)
	check(m.shield == 0,"Tarot inspection does not grant shields")
	check(not m.tarot_effects.cast(m,card.instance_id).has("error") and m.shield == 10,"Committed tarot grants ten shield")
	m.acquire_relic("ancient_prophecy"); card = m.grant_tarot("strength")
	m.tarot_effects.cast(m,card.instance_id); m.tarot_effects.cast(m,m.tarot_effects.pending_repeat.instance_id)
	check(m.shield == 30,"Prophecy repeats committed tarot shield effects")
	m = fresh(); m.acquire_relic("magician_hat")
	check(m.tarots.items.size() == 1 and m.tarots.items[0].id == "magician","Hat grants a Magician on pickup")
	for i in range(3): m.RelicEffects.turn_finished(m)
	check(m.tarots.items.size() == 1,"Hat waits four complete turns")
	m.RelicEffects.turn_finished(m)
	check(m.tarots.items.size() == 2 and m.tarots.items[1].id == "magician","Hat grants its next specific card on turn four")
	m = fresh(); m.acquire_relic("perfectionist")
	for i in range(3): m.record_perfect(true)
	check(m.relics.items[0].charges == 1 and m.perfect_combo == 3,"Three actual Perfect attempts bank protection")
	m.record_perfect(false,true)
	check(m.relics.items[0].charges == 1 and m.perfect_combo == 3,"Justice spends no protection")
	m.record_perfect(false)
	check(m.perfect_combo == 3 and m.relics.items[0].charges == 0,"One miss preserves combo and spends protection")
	m.record_perfect(false)
	check(m.perfect_combo == 0,"A second miss resets the combo")

func pet_checks() -> void:
	var m = fresh(); m.acquire_relic("pet_bat"); m.hp = 1
	m.RelicEffects.attack_used(m)
	check(m.hp == 2,"Bat heals one percent maximum HP")
	m.acquire_relic("pet_lizard")
	m.apply_enemy_status(0,m.Status.BURNING,1)
	check(m.enemy_status_count(0,m.Status.BURNING) == 3,"Lizard adds two Burning stacks")
	for id in ["pet_slime","pet_ghost","pet_dragon"]: m.acquire_relic(id)
	check(m.relics.items.size() == 1 and m.RelicEffects.Sets.collection_complete(m.relics.items,"pets"),"Pet set fuses into one inventory slot")
	m.hp = 1; m.RelicEffects.attack_used(m)
	check(m.hp == 3,"Complete pets double Bat's heal")
	m.apply_enemy_status(1,m.Status.BURNING,1)
	check(m.enemy_status_count(1,m.Status.BURNING) == 5,"Complete pets add four Burning stacks")
	m.RelicEffects.after_hit(m,0,1,m.Patterns.classify([1,2,3]))
	check(m.enemy_status_count(0,m.Status.CORROSION) == 1 and m.enemies[0].statuses[m.Status.CORROSION].permanent,"Complete Slime grants permanent skill-hit Corrosion")
	m.dice_turn.values = [1,2,3,4,5,6]
	var actions: Array = m.RelicEffects.roll_actions(m,false)
	check(actions.filter(func(a): return a.id == "pet_dragon").size() == 3,"Complete Dragon fires three times")
	m.sell_relic(m.relics.index_of("pet_ghost"))
	check(not m.RelicEffects.Sets.collection_complete(m.relics.items,"pets"),"Selling a pet disables collection upgrades")
	m.hp = 1; m.RelicEffects.attack_used(m)
	check(m.hp == 1,"Selling the pet fusion removes the Bat effect")

func secondary_damage_checks() -> void:
	var m = fresh(); m.acquire_relic("overflow_prism")
	m.enemies[0].hp = 5
	var damage: int = m.attack_damage(m.Patterns.classify([3,4,5]),0)
	var events: Array = settle_cast(m)
	check(m.enemies[1].hp == 100000-floori((damage-5)*0.5),"Prism transfers only half the excess once")
	m = fresh(); m.acquire_relic("overflow_prism"); m.enemies[0].shield = 1
	settle_cast(m)
	check(m.enemies[0].hp == 100000 and m.enemies[1].hp == 100000,"Shield absorption produces no killing overflow")
	m = fresh(); m.acquire_relic("powder_keg")
	m.apply_enemy_status(0,m.Status.BURNING,9)
	events = m.apply_enemy_status(0,m.Status.BURNING,1)
	check(m.enemy_status_count(0,m.Status.BURNING) == 5,"Keg consumes five stacks at the threshold")
	check(m.enemies[0].hp == 99985 and m.enemies[1].hp == 99985,"Keg hits every enemy for three character bases")
	check(events.filter(func(e): return e.type == "relic_explosion").size() == 1,"Keg supplies one visible explosion event")
	m.acquire_relic("orange_stone")
	m.apply_enemy_status(1,m.Status.BURNING,9,false)
	events = m.apply_enemy_status(0,m.Status.BURNING,5,false)
	check(events.filter(func(e): return e.type == "relic_explosion").size() == 1,"On-hit Burning cannot recursively chain keg explosions")

func cast_checks() -> void:
	var m = fresh(); m.acquire_relic("royal_seal")
	m.roll_pool(false,[1,2,3,4,5,6]); m.dice_turn.selected = [3,4,5]
	var skill = m.form_selected_skill()
	check(skill.dice == [3,4,5,6] and skill.source_dice == [4,5,6],"Seal extends downward at the six-face boundary")
	check(m.cancel_formed_skill() and not m.relic_skills.first_manual_used,"Cancelling does not consume the Seal")
	m.dice_turn.selected = [0,1,2]; m.form_selected_skill()
	check(m.pending.dice == [1,2,3,4],"Seal extends upward when possible")
	m.apply_player(0)
	check(m.dice_turn.committed.size() == 3 and m.relic_skills.first_manual_used,"Upgraded skill spends only its three physical dice")
	m.dice_turn.selected = [3,4,5]; m.form_selected_skill()
	check(m.pending.dice == [4,5,6],"Only the first manual skill upgrades")
	m.cancel_formed_skill()
	m.phase = "round_end"
	m.begin_round()
	check(m.relic_skills.first_manual_used,"A new turn does not refresh Royal Seal")
	check(m.relic_skills.preview_upgrade(m,m.Patterns.classify([1,2,3])).dice.size() == 3,"Later turns in the wave cannot upgrade again")
	m.stage += 1
	m._load_wave()
	check(not m.relic_skills.first_manual_used,"Entering a new wave refreshes Royal Seal")
	check(m.relic_skills.preview_upgrade(m,m.Patterns.classify([1,2,3])).dice.size() == 4,"First straight in the new wave upgrades")
	m = fresh(); m.acquire_relic("alternating_gears")
	settle_cast(m,[1,2,3])
	check(m.damage_multiplier(m.Patterns.classify([4,5,6])) == 1,"Changing pips does not change skill identity")
	check(m.damage_multiplier(m.Patterns.classify([1,2,3,4])) == 1.5,"Changing skill tier grants the Gears bonus")
	m = fresh(); m.acquire_relic("echo_bell")
	settle_cast(m); settle_cast(m)
	m.character_passive.charge = 0
	var before: int = m.enemies[0].hp+m.enemies[1].hp
	var events: Array = settle_cast(m)
	check(before-m.enemies[0].hp-m.enemies[1].hp == 31,"Third Fireball deals 21 plus one 10-damage echo")
	check(m.relics.items[0].get("casts",-1) == 0 and m.character_passive.charge == 1,"Echo charges neither itself nor the character counter")
	check(events.filter(func(e): return e.type == "damage").size() == 2,"Echo is one additional cast, not one repeat per damage tick")
	# Character Fireballs are distinct visuals but must not advance the two skill relics.
	m = fresh(); m.acquire_relic("echo_bell"); m.acquire_relic("alternating_gears")
	m.relic_skills.previous_skill = "straight:4"; m.relics.items[0]["casts"] = 2
	var bonus = m.Patterns.classify([3,4,5]); bonus.cast_source = "character_bonus"
	m.relic_skills.cast_started(m,bonus)
	check(m.relics.items[0].casts == 2 and m.relic_skills.previous_skill == "straight:4" and m.relic_skills.queued.is_empty(),"Character bonus skills advance neither Bell nor Gears")
	check(m.damage_multiplier(bonus) == 1,"Character bonus skills receive no Gears bonus")
	bonus.cast_source = "missile"
	m.relic_skills.cast_started(m,bonus)
	check(m.relics.items[0].casts == 0 and m.relic_skills.previous_skill == "straight:3" and m.relic_skills.queued.size() == 1,"Enchanted Missile advances both skill relics")
	var echo = m.relic_skills.queued[0].skill
	for factor in [0.5,1.5]:
		echo.effect_multiplier = factor
		var trace: Array = m.attack_damage_steps(echo)
		check(is_equal_approx(trace.back().base_after*trace.back().after,m.raw_attack_damage(echo)),"Echo damage display matches its fractional effect")
	m = Run.new(251025); m.load_debug_wave(10); m.begin_round(); m.acquire_relic("echo_bell")
	m.relics.items[0]["casts"] = 2
	m.enemies[0].charging = true; m.enemies[0].charge = 1; m.enemies[0].break_marks = 5
	settle_cast(m)
	check(m.enemies[0].break_marks == 4,"Echo cannot consume a second boss interruption mark")
	m = fresh()
	for id in ["glass_marble","steel_marble","gold_marble","magic_slingshot"]: m.acquire_relic(id)
	m.phase = "round_end"; m.begin_round()
	check(m.phase == "player" and m.pending.cast_source == "missile" and m.pending.dice == [3,4,5],"Fusion queues a fixed turn-start skill")
	m.apply_player()
	check(m.phase == "roll" and m.dice_turn.rolls_left == 3 and m.character_passive.charge == 1,"Missile keeps all dice/rolls and charges the character")
	m._grant_dice_bonus_turn()
	check(m.pending.is_empty(),"Bonus dice pools do not generate another turn-start missile")

func _initialize() -> void: call_deferred("run")
func run() -> void:
	stat_and_fusion_checks(); drop_and_sale_checks(); tarot_and_perfect_checks(); pet_checks(); secondary_damage_checks(); cast_checks()
	for id in NEW:
		check(ResourceLoader.exists("res://assets/art/relics/"+id+".png"),"Relic icon imports: "+id)
	print("New relics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
