extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var model = Run.new(714)
	model.begin_round()
	return model

func complete_turn(model) -> Array:
	model.relic_turn_closed = false
	return model._complete_relic_turn()

func cast_first(model, id: String, choice: Dictionary = {}) -> Dictionary:
	var card: Dictionary = model.tarots.add(id)
	var result: Dictionary = model.tarot_effects.cast(model,card.instance_id,choice)
	check(not result.has("error"),"First activation: "+id)
	check(model.tarots.find_instance(card.instance_id) < 0,"Original consumed exactly once: "+id)
	check(model.tarot_effects.pending_repeat.get("id","") == id,"Prophecy queues one repeat: "+id)
	return result

func cast_repeat(model, choice: Dictionary = {}) -> Dictionary:
	var echo: int = model.tarot_effects.pending_repeat.instance_id
	var result: Dictionary = model.tarot_effects.cast(model,echo,choice)
	check(not result.has("error") and model.tarot_effects.pending_repeat.is_empty(),"Second activation finishes without recursion")
	check(model.tarot_effects.cast(model,echo,choice).has("error"),"Repeated activation cannot be submitted twice")
	return result

func prophecy_model():
	var m = fresh()
	m.acquire_relic("ancient_prophecy")
	for e in m.enemies: e.hp = 1000; e.max_hp = 1000; e.shield = 0
	return m

func prophecy_checks() -> void:
	var m
	for id in ["strength","high_priestess","star","devil","hierophant"]:
		m = prophecy_model(); cast_first(m,id); cast_repeat(m)
		match id:
			"strength": check(m.tarot_effects.strength == 2,"Strength stacks once per activation")
			"high_priestess": check(m.tarot_effects.dice_boost == 2,"Priestess adds two turn boosts")
			"star": check(m.tarot_effects.star_throws == 3,"Star refreshes rather than stacking")
			"devil": check(m.tarot_effects.devil == 4,"Devil adds one guaranteed six on repeat")
			"hierophant": check(m.Status.HARMFUL.all(func(id): return m.status_count(id) == 0),"Cleanse repeats safely")
	m = prophecy_model(); m.roll_pool(false,[1,2,3,4,5,6])
	cast_first(m,"magician",{"die":0,"face":2}); cast_repeat(m,{"die":0,"face":6})
	check(m.dice_turn.values == [6,2,3,4,5,6],"Repeated Magician edits a selected die a second time")
	m = prophecy_model(); cast_first(m,"lovers"); cast_repeat(m)
	check(m.tarot_effects.lovers,"Repeated Lovers refreshes one next-roll guarantee")
	m = prophecy_model(); m.roll_pool(false,[1,2,3,4,5,6])
	var first_roll: Dictionary = cast_first(m,"justice")
	m.roll_pool(false,[1,2,3,4,5,6],true)
	var second_roll: Dictionary = cast_repeat(m)
	check(first_roll.reroll and second_roll.reroll and m.dice_turn.rolls_left == 2,"Justice requests two separate free animated throws")
	m = prophecy_model(); m.roll_pool(false,[1,2,3,4,5,6])
	m.dice_turn.selected = [0,1,2]; m.form_selected_skill(); m.apply_player(0)
	cast_first(m,"hermit")
	check(m.tarot_effects.prepare(m,m.tarot_effects.pending_repeat.instance_id).has("error"),"Second Hermit safely skips when no spent dice remain")
	m.tarot_effects.dismiss_repeat()
	m = prophecy_model(); cast_first(m,"hanged_man",{"ban":"sun"}); cast_repeat(m,{"ban":"moon"})
	check(m.tarot_effects.banned == ["sun","moon"],"Two bans use distinct choices")
	m = prophecy_model(); cast_first(m,"empress"); cast_repeat(m)
	check(m.tarots.items.size() == 4,"Empress grants two cards twice, with no echo inventory item")
	m = prophecy_model(); cast_first(m,"chariot"); cast_repeat(m)
	check(m.shield == 100,"Chariot grants fifty shield twice")
	m = prophecy_model(); m.hp = 10; cast_first(m,"sun"); cast_repeat(m)
	check(m.hp == m.max_hp and m.enemy_status_count(0,m.Status.BURNING) == 2,"Sun heals twice and applies burning twice")
	m = prophecy_model(); cast_first(m,"moon"); cast_repeat(m)
	check(m.enemy_status_count(0,m.Status.DARKNESS) == 2 and m.enemies[0].statuses[m.Status.DARKNESS].permanent,"Repeated Moon applies one stack twice and remains permanent")
	m = prophecy_model(); m.roll_pool(false,[1,2,3,4,5,6]); cast_first(m,"temperance"); cast_repeat(m)
	check(m.tarot_effects.carried_rolls == 4 and m.tarot_effects.pending_turn_end and m.dice_turn.rolls_left == 0,"Temperance repeats the carry amount but requests only one end turn")
	m = prophecy_model()
	for i in range(11): m.enemies.append(m.make_enemy(0))
	cast_first(m,"death",{"target":0})
	check(m.tarot_effects.prepare(m,m.tarot_effects.pending_repeat.instance_id,{"target":0}).has("error"),"Death requires another living target")
	cast_repeat(m,{"target":1})
	check(m.living().size() == 10,"Death executes two selected targets")
	m = prophecy_model(); m.roll_pool(false,[1,1,2,4,4,6])
	while not m.roll_attacks.is_empty(): m.resolve_roll_attack_step()
	cast_first(m,"judgement"); cast_repeat(m)
	check(m.dice_turn.rolls_left == 6,"Judgement grants two rerolls per activation")
	m = prophecy_model(); cast_first(m,"tower"); cast_repeat(m)
	check(m.enemies[0].hp == 900 and m.hp == 40,"Tower repeats fixed HP damage for both sides")
	m = prophecy_model(); cast_first(m,"wheel"); cast_repeat(m)
	check(m.tarot_effects.bonus_chests.size() <= 2,"Wheel rolls independently for each activation")
	m = prophecy_model(); m.acquire_relic("heart"); cast_first(m,"fool")
	var first_ids: Array = m.relics.items.map(func(item): return item.id)
	check(not m.relics.has("ancient_prophecy"),"Fool can remove the triggering relic")
	cast_repeat(m)
	check(m.relics.items.all(func(item): return item.id not in first_ids),"Snapshot repeat rerolls the first replacements even after losing Prophecy")
	m = prophecy_model(); cast_first(m,"emperor"); cast_repeat(m)
	check(m.relics.items.size() == 3,"Emperor grants two different unowned relics")
	m = prophecy_model()
	for id in ["ancient_tentacle","pet_dragon","twin_scythes"]: m.acquire_relic(id)
	# Put copying relics before Prophecy so this case still has one repeat.
	m.relics.move(m.relics.index_of("ancient_tentacle"),0)
	cast_first(m,"world")
	check(m.relics.has("mithril_blade"),"World grants the only unowned eligible legendary")
	check(m.tarot_effects.prepare(m,m.tarot_effects.pending_repeat.instance_id).has("error"),"World does not fabricate a prize when the second pool is exhausted")
	m.tarot_effects.dismiss_repeat()
	check(m.tarot_effects.pending_repeat.is_empty(),"An unavailable repeat can be safely dismissed")
	m = prophecy_model()
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone"]: m.acquire_relic(id)
	cast_first(m,"emperor",{"replace":1})
	var echo: int = m.tarot_effects.pending_repeat.instance_id
	var setup: Dictionary = m.tarot_effects.prepare(m,echo)
	var state: int = m.reward_rng.state
	check(setup.get("choice","") == "replace" and m.tarot_effects.prepare(m,echo) == setup and state == m.reward_rng.state,"Second reward locks while replacement choice is open")
	cast_repeat(m,{"replace":2})
	check(m.relics.items[2].id == setup.relic and m.relics.items.size() == 10,"Second reward replaces its own selected slot")

func _initialize() -> void:
	var m = fresh()
	for id in m.Tarot.ITEMS:
		if id != "strength": m.tarot_effects.banned.append(id)
	var combat_state: int = m.rng.state
	check(m.acquire_relic("fortune_cookie") and m.tarots.items.size() == 1,"Cookie grants one tarot immediately")
	check(m.tarots.items[0].id == "strength" and m.rng.state == combat_state,"Generation respects bans and leaves combat RNG alone")
	check(not m.acquire_relic("fortune_cookie") and m.tarots.items.size() == 1,"Failed duplicate acquisition grants nothing")
	complete_turn(m); complete_turn(m)
	check(m.tarots.items.size() == 1,"Cookie waits for three complete turns")
	m.stage += 1; m._load_wave(); m.begin_round()
	complete_turn(m)
	check(m.tarots.items.size() == 2,"Cookie's counter carries across waves")
	m._complete_relic_turn()
	check(m.tarots.items.size() == 2,"Closing the same turn twice never generates again")
	m.acquire_relic("crystal_ball")
	check(m.tarots.items.size() == 2,"Crystal Ball waits for a completed turn")
	var activated: Array = []
	m.relic_activated.connect(func(id): activated.append(id))
	for i in range(3): complete_turn(m)
	check(m.tarots.items.size() == 6,"Both generators fire on the third turn")
	check(activated == ["crystal_ball","crystal_ball","fortune_cookie","crystal_ball"],"Relic activations follow inventory order")
	check(m.tarots.items.all(func(card): return card.id == "strength"),"Every generator respects exclusions")
	m.relics.remove(m.relics.index_of("fortune_cookie"))
	complete_turn(m)
	check(m.tarots.items.size() == 7,"Removing a generator stops future grants")
	m.reset_run()
	check(m.tarots.items.is_empty() and m.relics.items.is_empty(),"New run clears cards and generator counters")
	m = fresh(); m.enemies[0].hp = 10000; m.enemies[0].shield = 0
	m.acquire_relic("fortune_cookie"); m.acquire_relic("crystal_ball")
	var count_before: int = m.tarots.items.size()
	m.roll_pool(false,[1,2,3,1,2,3])
	while not m.roll_attacks.is_empty(): m.resolve_roll_attack_step()
	for indices in [[0,1,2],[3,4,5]]:
		m.dice_turn.selected = indices; m.form_selected_skill(); m.apply_player(0)
	check(m.bonus_turn_count == 1 and m.tarots.items.size() == count_before and m.relics.items[0].turns == 0,"Dice bonus turns do not advance tarot generators")
	m = fresh(); m.load_debug_wave(Waves.COUNT); m.begin_round(); m.acquire_relic("crystal_ball")
	m.set_test_roll([2,2,2]); m.apply_player(); m.end_round()
	check(m.tarots.items.size() == 1,"City generates a card after a complete roll action")
	prophecy_checks()
	print("Tarot relics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
