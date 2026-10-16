extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Swipe = preload("res://scripts/tarot/card_swipe.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func fresh(city: bool = false):
	var m = Run.new(604)
	if city: m.load_debug_wave(Waves.COUNT)
	else:
		m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
		for e in m.enemies: e.hp = 10000; e.max_hp = 10000
	m.begin_round()
	return m
func use(m, id: String, choice: Dictionary = {}) -> Dictionary:
	var card: Dictionary = m.tarots.add(id)
	var result: Dictionary = m.tarot_effects.cast(m,card.instance_id,choice)
	check(not result.has("error"),"Cast %s: %s" % [id,result.get("error","")])
	check(m.tarots.find_instance(card.instance_id) == -1,"Consume exactly the cast instance: "+id)
	return result
func finish(m) -> void:
	if m.phase == "enemy":
		for i in m.living():
			m.enemies[i].intent = {"type":"attack","target":-1,"amount":0}
			m.enemy_act(i)
	m.end_round()
func _initialize() -> void:
	var m = fresh()
	use(m,"strength")
	m.set_test_roll([5,5,2])
	var expected: int = floori(m.attack_base(m.pending))
	check(m.unmitigated_damage(m.pending) == expected,"Strength preview doubles the next skill")
	m.begin_player_cast()
	check(m.tarot_effects.strength == 0 and m.pending.effect_multiplier == 2,"Strength locks once for all hits")
	var steps: Array = m.attack_damage_steps(m.pending)
	check(is_equal_approx(steps.back().after,m.cast_damage_multiplier(m.pending)),"Animated recipe includes Strength")
	for i in range(3):
		var events: Array = m.apply_player_step(0)
		check(events[0].display_amount == expected,"Every combo hit keeps the captured Strength")
	finish(m); m.begin_round()
	check(m.tarot_effects.skill_factor(m.classify([1,2,3])) == 1,"Strength does not leak into later skills")
	for values in [[2,2,4],[3,3,4],[3,3,3],[6,6,4],[2,2,2]]:
		m = fresh()
		m.hp = 10
		use(m,"strength")
		m.set_test_roll(values)
		m.apply_player()
		var id: int = 33 if values == [3,3,3] else values[0]
		if values not in [[2,2,2],[2,2,4]]:
			check(m.status_count(id) == (3 if id == 33 else 4),"Strength keeps support duration unchanged")
			if id != 6: check(m.statuses[id].potency == 2,"Strength doubles support potency")
		if id == 3: check(m.attack_multiplier() == 2,"Double Might adds 1.0 rather than 0.5")
		if id == 33: check(m.attack_multiplier() == 5,"Double Ascension adds 4.0 rather than 2.0")
		if values == [2,2,4]:
			check(m.living().all(func(i): return m.enemy_status_count(i,Status.FROZEN) == 2),"Strength doubles freeze stacks")
			finish(m); m.begin_round()
			check(m.hp == 10 and m.status_count(Status.REGEN) == 0,"Freeze replaces regeneration without healing")
		if values == [2,2,2]: check(m.hp == m.max_hp,"Full healing remains full healing")
	m = fresh()
	use(m,"devil"); use(m,"justice"); use(m,"hierophant"); use(m,"lovers",{"parity":0}); use(m,"magician",{"dice":[1,2,3]})
	m.tarot_effects.revelation = 4
	check(m.set_test_roll([6,6,6]).dice == [1,2,3] and m.tarot_effects.devil == 1,"Latest base setting wins while unmatched conditional effects stay pending")
	m.apply_player(0); finish(m); m.begin_round()
	check(m.set_test_roll([2,2,2]).dice == [6,6,6] and m.tarot_effects.devil == 0,"Reserved Devil transforms and consumes on the next triple")
	m = fresh(); use(m,"hierophant")
	var face: int = m.tarot_effects.revelation
	check(face >= 1 and face <= 6 and m.set_test_roll([face,1,2]).dice == [face,face,face],"Random revelation transforms matching throws")
	check(m.tarot_effects.revelation == 0,"Revelation expires after one accepted throw")
	for parity in [0,1]:
		m = fresh(); use(m,"lovers",{"parity":parity})
		check(m.set_test_roll([1,2,3]).dice.all(func(v): return v%2 == parity),"Lovers guarantees selected parity")
	m = fresh(); use(m,"justice")
	check(m.set_test_roll([1,2,3]).kind == Skill.Kind.SPECIAL,"Justice guarantees a triple")
	m = fresh(); use(m,"star")
	for i in range(4):
		var result: MultiHitSkill = m.set_test_roll([1,2,3])
		check(result.perfect == (i < 3),"Star forces exactly three accepted throws")
		m.apply_player(0); finish(m); m.begin_round()
	m = fresh(); m.set_test_roll([1,2,3]); var pending: MultiHitSkill = m.pending.duplicate()
	use(m,"high_priestess")
	check(m.phase == "player" and m.pending.same_as(pending),"Tarot after a roll preserves the pending skill")
	check(m.skill_use_count(m.pending) == 2,"Priestess adds an immediate use to a rolled normal skill")
	check(m.skill_use_count(m.classify([5,5,1])) == 4 and m.skill_use_count(m.classify([5,5,5])) == 7,"Priestess affects every damaging skill tier")
	m.apply_player(0); finish(m); m.begin_round()
	check(m.tarot_effects.extra_uses == 0,"Priestess consumes on the next eligible skill")
	for city in [false,true]:
		m = fresh(city); use(m,"hermit")
		for turn in range(3):
			var hp: int = m.hp
			m.receive_damage(20)
			if city:
				m.volley_clock = 0.01
				m.tick_city(0.25)
			check(m.hp == hp and m.status_count(Status.HIDDEN) == 3-turn,"Hermit blocks targeting for three full rounds in either mode")
			m.set_test_roll([3,3,2]); m.apply_player(); finish(m); m.begin_round()
		check(m.status_count(Status.HIDDEN) == 0,"Hermit ends after round three")
		m.receive_damage(10); check(m.hp < m.max_hp,"Enemies can hit after invisibility expires")
	m = fresh(); use(m,"hermit"); m.set_test_roll([1,2,3]); m.begin_player_cast()
	check(m.status_count(Status.HIDDEN) == 0,"Using an attack skill breaks invisibility")
	m = fresh(); use(m,"moon")
	for i in range(6): m._tick_enemy_statuses()
	check(m.enemies.all(func(e): return e.statuses[Status.DARKNESS].count == 1 and e.statuses[Status.DARKNESS].permanent),"Moon applies one permanent darkness stack that cannot tick away")
	m = fresh(); m.hp = 1; use(m,"sun")
	check(m.hp == m.max_hp and m.living().all(func(i): return m.enemy_status_count(i,Status.BURNING) == 1),"Sun fully heals and burns all foes")
	m = fresh(); m.enemies[0].shield = 20; m.enemies[1].hp = 1; use(m,"chariot")
	check(m.enemies[0].hp == 10000 and m.enemies[0].shield == 0 and m.enemies[1].hp == 0 and m.enemies[2].hp == 9950,"Chariot applies fifty fixed damage with shield and overkill rules")
	m = fresh(true); use(m,"chariot"); check(m.city_hp == Run.CITY_MAX_HP-50,"Chariot can damage the city")
	for city in [false,true]:
		var fixed = fresh(city)
		fixed.acquire_relic("bracelet")
		fixed.acquire_relic("codex_page")
		fixed.perfect_combo = 10
		fixed.statuses[Status.MIGHT].apply(2)
		fixed.statuses[Status.ASCENSION].apply(3)
		fixed.statuses[Status.DARKNESS].apply(2)
		fixed.tarot_effects.strength = 2
		fixed.tarot_effects.extra_uses = 3
		if not city: fixed.apply_enemy_status(0,Status.CORROSION,3)
		var cast: Dictionary = use(fixed,"chariot")
		var hits: Array = cast.events.filter(func(e): return e.type == "damage")
		check(hits.size() == (1 if city else 3) and hits.all(func(e): return e.display_amount == 50),"Chariot ignores flat bonuses, combo, boons, darkness and target vulnerability")
		check(fixed.city_hp == Run.CITY_MAX_HP-50 if city else fixed.enemies.all(func(e): return e.hp == 9950),"Fixed Chariot removes exactly fifty health per target")
		check(fixed.status_count(Status.MIGHT) == 2 and fixed.status_count(Status.ASCENSION) == 3 and fixed.tarot_effects.strength == 2 and fixed.tarot_effects.extra_uses == 3,"Chariot preserves next-skill modifiers and attack charges")
	for id in ["death","judgement"]:
		var card: Dictionary = m.tarots.add(id)
		check(m.tarot_effects.cast(m,card.instance_id,{"target":0}).has("error") and m.tarots.find_instance(card.instance_id) >= 0,"Invalid city execution retains the card")
	m = fresh(); m.enemies[0].shield = 100
	var execution: Dictionary = use(m,"death",{"target":0})
	check(m.enemies[0].hp == 0 and execution.events[0].instant_kill and execution.events[0].text.is_empty(),"Death ignores shields and displays no damage number")
	m = fresh(); m.enemies.append_array([m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)])
	use(m,"judgement"); check(m.living().size() == 3,"Judgement executes a random half of six enemies")
	m = fresh(); use(m,"tower")
	check(m.tarot_effects.pending_steps.size() == 10 and m.statuses.values().all(func(effect): return effect.count == 0) and m.enemies.all(func(enemy): return enemy.get("statuses",{}).is_empty()),"Tower queues all ten effects without applying them up front")
	check(m.tarot_effects.pending_steps.all(func(step): return step.target != -1 or step.status != Status.PLAGUE),"Tower never assigns plague to the player")
	var next_card: Dictionary = m.tarots.add("strength")
	check(m.tarot_effects.cast(m,next_card.instance_id).has("error"),"Other tarot cannot interrupt the pending burst")
	var frozen_applied: bool = false
	for i in range(10):
		var step: Dictionary = m.tarot_effects.resolve_next_step(m)
		check(not step.is_empty() and m.tarot_effects.pending_steps.size() == 9-i,"Each Tower step consumes exactly one application")
		check(step.count == 1 and step.events.filter(func(e): return e.type == "status").all(func(e): return e.amount == 1),"Every Tower status application adds one base stack, including darkness and corrosion")
		if step.target == -1 and step.status == Status.FROZEN: frozen_applied = true
		if i < 9: check(m.phase == "roll","Freeze does not hand control back before the burst finishes")
	check(m.phase == ("frozen" if frozen_applied else "roll") and m.tarot_effects.resolve_next_step(m).is_empty(),"Tower finalizes once, with no extra applications")
	var total: int = 0
	for effect in m.statuses.values(): total += effect.count
	for enemy in m.enemies:
		for effect in enemy.get("statuses",{}).values(): total += effect.count
	check(total > 0 and total <= 10,"Ten one-stack Tower applications may refresh existing action locks")
	m = fresh(); use(m,"tower"); m.hp = 0
	check(m.tarot_effects.resolve_next_step(m).is_empty() and m.tarot_effects.pending_steps.is_empty(),"Defeat discards unapplied Tower steps")
	m = fresh(); use(m,"tower"); m.reset_run()
	check(m.tarot_effects.pending_steps.is_empty(),"Restart clears an unfinished burst")
	m = fresh(); use(m,"hanged_man",{"ban":"sun"})
	for i in range(100): check("sun" not in Catalog.draw_choices(m.reward_rng,m.tarot_effects.banned),"Banned cards never enter future reward draws")
	for id in Catalog.ITEMS:
		if id != "fool": m.tarot_effects.banned.append(id)
	use(m,"empress")
	check(m.tarots.items.size() == 2 and m.tarots.items.all(func(item): return item.id == "fool"),"Empress respects bans and allows duplicates")
	m = fresh(); use(m,"emperor"); check(m.relics.items.size() == 1,"Emperor grants a real relic")
	m = fresh(); use(m,"world"); check(m.relics.items.size() == 1 and m.Relics.Catalog.ITEMS[m.relics.items[0].id].rarity == 3 and not m.Relics.Catalog.ITEMS[m.relics.items[0].id].get("fusion",false),"World only draws eligible non-fusion legendary relics")
	for id in m.Relics.Catalog.ITEMS:
		if m.Relics.Catalog.ITEMS[id].rarity == 3 and not m.Relics.Catalog.ITEMS[id].get("fusion",false): m.acquire_relic(id)
	var world: Dictionary = m.tarots.add("world")
	check(m.tarot_effects.cast(m,world.instance_id).has("error") and m.tarots.find_instance(world.instance_id) >= 0,"Exhausted World pool does not consume the card")
	m = fresh()
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","twin_scythes"]: m.acquire_relic(id)
	var full: Dictionary = m.tarots.add("emperor")
	var prepared: Dictionary = m.tarot_effects.prepare(m,full.instance_id)
	var reward_state: int = m.reward_rng.state
	check(prepared.get("choice","") == "replace","Full inventory requires a replacement choice")
	check(m.tarot_effects.prepare(m,full.instance_id) == prepared and m.reward_rng.state == reward_state,"Cancel/reopen keeps the same locked relic and RNG")
	check(m.tarot_effects.cast(m,full.instance_id).has("error") and m.tarots.find_instance(full.instance_id) >= 0,"Missing replacement retains the card")
	check(not m.tarot_effects.cast(m,full.instance_id,{"replace":4}).has("error") and m.relics.items[4].id == prepared.relic,"Confirm atomically replaces and consumes")
	var owned: Array = m.relics.items.map(func(item): return item.id)
	use(m,"fool")
	check(m.relics.items.size() == 10 and m.relics.items.all(func(item): return item.id not in owned),"Fool rerolls every slot excluding every originally owned ID")
	check(m.relics.items.map(func(item): return item.id).all(func(id): return m.relics.items.filter(func(item): return item.id == id).size() == 1),"Fool replacements are unique")
	for city in [false,true]:
		m = fresh(city); m.set_test_roll([1,2,3]); use(m,"temperance")
		check(m.pending.is_empty() and m.tarot_effects.next_extra_rolls == 1,"Temperance forfeits the current opportunity after rolling")
		finish(m); m.begin_round()
		var round_number: int = m.round_number
		m.set_test_roll([1,2,3]); m.apply_player(0)
		check(m.phase == "roll" and m.round_number == round_number,"First next-turn skill grants another throw before enemies or status ticks")
		m.set_test_roll([1,2,3]); m.apply_player(0); finish(m)
		check(m.phase == "round_end","Second throw completes the full turn")
	m = fresh(); m.reroll_progress = 6
	var wins: int = 0
	var rares: int = 0
	for i in range(4000):
		var card: Dictionary = m.tarots.add("wheel")
		m.tarot_effects.cast(m,card.instance_id)
		if not m.tarot_effects.bonus_chests.is_empty():
			wins += 1
			if m.tarot_effects.bonus_chests[0] == 2: rares += 1
			m.tarot_effects.bonus_chests.clear()
	check(wins > 850 and wins < 1150 and rares > 65 and rares < 140,"Wheel uses 25% win rate and conditional 10% rare rate")
	m.tarot_effects.bonus_chests.append(2)
	check(m.open_bonus_chest().size() == 3 and m.reroll_progress == 6,"Wheel chest uses the existing reward system without spending Perfect progress")
	m = fresh(); var duplicate: Dictionary = m.tarots.add("strength")
	m.tarot_effects.cast(m,duplicate.instance_id)
	check(m.tarot_effects.cast(m,duplicate.instance_id).has("error") and m.tarot_effects.strength == 1,"Duplicate release cannot consume or apply twice")
	m = fresh()
	for i in range(3): use(m,"strength")
	m.set_test_roll([4,4,4])
	check(m.attack_base(m.pending) == 120 and m.tarot_effects.strength == 3,"Three Strength cards add three bases: 30 + 3 x 30")
	m.begin_player_cast()
	var recipe: Array = m.attack_damage_steps(m.pending)
	check(recipe.filter(func(step): return step.source == "tarot").size() == 3 and recipe.back().base_after == 120 and recipe.back().after == 1,"Each Strength animates an additive base increase, keeping the multiplier separate")
	m = fresh()
	for i in range(3): use(m,"high_priestess")
	m.set_test_roll([3,3,2]); m.apply_player(); finish(m); m.begin_round()
	check(m.tarot_effects.extra_uses == 3,"Buff skills do not consume the queued extra uses")
	check(m.skill_use_count(m.classify([1,1,1])) == 1 and m.skill_use_count(m.classify([6,6,6])) == 1,"Instant kills cannot gain extra uses")
	m.set_test_roll([4,4,4]); m.begin_player_cast()
	check(m.pending.use_count() == 4 and m.tarot_effects.extra_uses == 0,"Worldbreaker gets one plus three uses and consumes the stack once")
	m = fresh(true)
	for i in range(3): use(m,"high_priestess")
	m.set_test_roll([6,6,6]); m.begin_player_cast()
	check(m.pending.use_count() == 4,"City 666 is damaging, so it gains the uses")
	m = fresh()
	for i in range(3): use(m,"devil")
	check(m.tarot_effects.devil == 1,"Repeated Devil overwrites rather than queues three conversions")
	m.set_test_roll([5,5,5]); check(m.pending.dice == [6,6,6] and m.tarot_effects.devil == 0,"Only the next triple consumes Devil")
	m = fresh(); use(m,"star"); m.tarot_effects.star_throws = 1; use(m,"star")
	check(m.tarot_effects.star_throws == 3,"Repeated Star refreshes three throws rather than adding")
	for direct in ["magician","lovers","justice"]:
		m = fresh(); use(m,"magician",{"dice":[2,2,4]})
		if direct == "magician": use(m,"magician",{"dice":[3,4,5]})
		elif direct == "lovers": use(m,"lovers",{"parity":1})
		else: use(m,"justice")
		var roll: MultiHitSkill = m.set_test_roll([1,2,3])
		check(roll.dice == [3,4,5] if direct == "magician" else roll.dice.all(func(v): return v%2 == 1) if direct == "lovers" else roll.kind >= Skill.Kind.SPECIAL,"Latest direct dice setting wins: "+direct)
	m = fresh(); use(m,"hierophant"); m.tarot_effects.revelation = 4; use(m,"magician",{"dice":[2,2,4]})
	check(m.set_test_roll([1,2,3]).dice == [4,4,4],"User example: Magician first makes 224, then earlier Hierophant makes 444")
	for newer in ["hierophant","devil"]:
		m = fresh()
		use(m,"devil" if newer == "hierophant" else "hierophant")
		use(m,newer); m.tarot_effects.revelation = 4
		use(m,"magician",{"dice":[4,4,4]})
		check(m.set_test_roll([1,2,3]).dice == ([4,4,4] if newer == "hierophant" else [6,6,6]),"Newer conditional transformation wins conflicts: "+newer)
		check(m.tarot_effects.devil == (1 if newer == "hierophant" else 0),"An overwritten Devil is retained for a later triple")
	m = fresh(); use(m,"temperance"); finish(m); m.begin_round()
	m.set_test_roll([3,3,4]); m.apply_player(); m.set_test_roll([1,2,3]); m.apply_player(0); finish(m)
	check(m.status_count(3) == 3,"Temperance's extra attack spends one charge of the newly applied boon")
	m = fresh(true); m.set_test_roll([1,2,3]); m.apply_player(); finish(m)
	var previous_round: int = m.round_number
	var city_card: Dictionary = m.tarots.add("magician")
	check(m.tarot_effects.prepare(m,city_card.instance_id).get("choice","") == "magician" and m.round_number == previous_round,"City cards can be inspected between completed rolls without advancing the turn")
	check(not m.tarot_effects.cast(m,city_card.instance_id,{"dice":[2,2,4]}).has("error") and m.phase == "roll" and m.round_number == previous_round+1,"Committed city tarot opens the next turn exactly once")
	use(m,"star"); check(m.round_number == previous_round+1,"Additional free cards do not start additional turns")
	var a = Swipe.new(); var b = Swipe.new()
	for controller in [a,b]: controller.begin(100); controller.move(1.4,140); controller.release(140)
	for i in range(60): a.advance(1.0/60)
	for i in range(15): b.advance(1.0/15)
	check(is_equal_approx(a.position,b.position) and a.position > 1.4,"Swipe inertia has frame-independent travel after release")
	print("Tarot effects: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
