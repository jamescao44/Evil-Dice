extends SceneTree
## Document additions cover real combat, copying, chapter unlocks, fusion and localized art.
const Run = preload("res://scripts/progression/run_rules.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Growth = preload("res://scripts/relics/relic_growth.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
const NEW := ["hour_hand","minute_hand","second_hand","handless_clock","demon_clock","beast_fang","firebird_feather","snowball"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(ids: Array = []):
	var model = Run.new(3112026)
	model.enemies = [model.make_enemy(0),model.make_enemy(1)]
	for enemy in model.enemies: enemy.hp = 100000; enemy.max_hp = 100000
	for id in ids: check(model.acquire_relic(id),"Acquire "+id)
	return model

func clock_checks() -> void:
	var m = fresh(["hour_hand","minute_hand","second_hand"])
	for turn in range(1,7):
		Growth.turn_finished(m)
		var expected: float = 1.0+0.1*(floori(turn/3.0)+floori(turn/2.0)+turn)
		check(is_equal_approx(m.damage_multiplier(),expected),"Independent clock periods on turn %d" % turn)
	Growth.turn_finished(m)
	var before: float = m.damage_multiplier()
	var states: Array = m.relics.items.duplicate(true)
	m.acquire_relic("handless_clock")
	check(m.relics.items.size() == 1 and m.relics.items[0].id == "demon_clock","Four Clock components fuse into one slot")
	check(is_equal_approx(m.damage_multiplier(),before+1.5),"Fusion retains growth and adds 1.5")
	for part in states:
		check(m.relics.items[0].component_states[part.id] == part,"Fusion preserves complete state for "+part.id)
	Growth.turn_finished(m)
	check(is_equal_approx(m.damage_multiplier(),before+1.7),"Minute and second timers continue after fusion")
	check(Catalog.Sets.collection_progress("hour_hand",m.relics.items) == Vector2i(4,4),"Fused Clock keeps set progress")
	check(not m.relics.can_add("hour_hand"),"Fused components stay excluded from offers")
	var saved: Dictionary = Run.Campaign.capture(m)
	var other = Run.new(7)
	check(Run.Campaign.restore(other,saved),"Clock checkpoint restores")
	check(other.relics.items == m.relics.items and is_equal_approx(other.damage_multiplier(),m.damage_multiplier()),"Checkpoint retains Clock growth and timers")
	m.sell_relic(0)
	check(is_equal_approx(m.damage_multiplier(),1.0),"Selling Clock removes all accumulated growth")
	m = fresh(["second_hand","disguise_mask"])
	Growth.turn_finished(m)
	check(is_equal_approx(m.relics.items[0].damage_growth,0.2) and m.relics.items[0].turns == 0,"Mask repeats growth payout, not timer advancement")
	check(is_equal_approx(m.damage_multiplier(),1.4),"Copied Clock benefits follow inventory order")
	m = fresh(["hour_hand","disguise_mask","ancient_tentacle"])
	for turn in range(3): Growth.turn_finished(m)
	check(is_equal_approx(m.relics.items[0].damage_growth,0.4),"Tentacle repeats both original and Mask payout")
	check(m.hp == m.max_hp-20,"Only two copied payouts pay HP")
	m = fresh(["second_hand","ancient_codex"]); Growth.turn_finished(m)
	check(is_equal_approx(m.damage_multiplier(),2.2),"Growth adds before later multiplication")
	m.relics.move(0,1)
	check(is_equal_approx(m.damage_multiplier(),2.1),"Reordering changes the Clock multiplier position")
	m = fresh(["second_hand"]); m.begin_round(); m._complete_relic_turn(); m._complete_relic_turn()
	check(is_equal_approx(m.damage_multiplier(),1.1),"Full turn only counts once")
	var items: Array = m.relics.items.duplicate(true)
	m._grant_dice_bonus_turn()
	check(m.relics.items == items,"Extra dice pool never advances Clock timers")

func status_checks() -> void:
	for id in ["beast_fang","firebird_feather","snowball"]:
		var m = fresh([id])
		var status: int = {"beast_fang":m.Status.PLAGUE,"firebird_feather":m.Status.BURNING,"snowball":m.Status.FROZEN}[id]
		check(m.relic_base_damage() == 2,"Flat base bonus for "+id)
		var entry: Dictionary = m.RelicEffects.Sequence.entries(m.relics.items)[0]
		var successes := 0
		for seed_value in range(2000):
			m.rng.seed = seed_value
			m.enemies[0].statuses = {}
			var events: Array = m.RelicEffects.Conditions.after_hit(m,0,entry)
			if not events.is_empty(): successes += 1
			if not events.is_empty() and seed_value < 30: check(m.enemy_status_count(0,status) == 1,"Applies one native stack: "+id)
		var rate: float = successes/2000.0
		check(absf(rate-(0.1 if id == "snowball" else 0.3)) < 0.04,"Sampled status chance for "+id)
		m.acquire_relic("runestone")
		for seed_value in range(100):
			m.rng.seed = seed_value; m.enemies[0].statuses = {}
			if m.RelicEffects.Conditions.after_hit(m,0,entry).is_empty(): continue
			check(m.enemy_status_count(0,status) == 2,"Runestone adds a stack to "+id)
			break
		m.active_relic_procs.append(id)
		check(m.RelicEffects.Conditions.after_hit(m,0,entry).is_empty(),"Secondary attacks cannot recursively trigger "+id)
		m.active_relic_procs.clear()
		m.enemies[0].hp = 0
		check(m.RelicEffects.Conditions.after_hit(m,0,entry).is_empty(),"Dead targets cannot receive "+id)
	var m = fresh(["runestone","ancient_tentacle","firebird_feather"])
	var activations: Array = []
	m.relic_activated.connect(func(id): activations.append(id))
	for seed_value in range(100):
		m.rng.seed = seed_value; m.hp = m.max_hp; m.enemies[0].statuses = {}; activations.clear()
		if m.RelicEffects.after_hit(m,0,1,m.make_straight_skill([1,2,3])).is_empty(): continue
		check(m.enemy_status_count(0,m.Status.BURNING) == 3,"Status proc includes original and copied Runestone")
		check(activations.count("runestone") == 2 and m.hp == m.max_hp-10,"Each stack modifier activates and pays its copy cost only once")
		break

func ice_rose_checks() -> void:
	var m = fresh(["ice_rose","basic_crystal"])
	var hits: Array = m.apply_enemy_status(0,m.Status.FROZEN,1).filter(func(e): return e.type == "damage")
	check(hits.size() == 2 and hits.map(func(e): return e.target) == [0,1],"Ice Rose hits every living enemy including the frozen target")
	check(hits.all(func(e): return e.display_amount == 15),"Ice Rose applies base-damage relic bonuses to its whole burst")
	check(m.enemy_status_count(1,m.Status.FROZEN) == 0,"Ice Rose damage alone does not spread freeze")
	m.acquire_relic("blue_stone")
	for seed_value in range(30):
		m.rng.seed = seed_value
		hits = m.apply_enemy_status(0,m.Status.FROZEN,1).filter(func(e): return e.type == "damage")
		check(hits.size() == 2 and m.active_relic_procs.is_empty(),"Freezes caused by the burst cannot recursively trigger Ice Rose")
	m.enemies[1].hp = 0
	hits = m.apply_enemy_status(0,m.Status.FROZEN,1).filter(func(e): return e.type == "damage")
	check(hits.size() == 1 and hits[0].target == 0,"Ice Rose skips dead enemies")
	check(GameText.text(Catalog.ITEMS.ice_rose.text).contains("所有敌人"),"Ice Rose Chinese description matches all-enemy targeting")

func tentacle_checks() -> void:
	var m = fresh(["bracelet","disguise_mask","ancient_tentacle"])
	var skill = m.make_straight_skill([1,2,3])
	var hp: int = m.hp
	var random_state: int = m.rng.state
	for i in range(10):
		m.attack_damage_steps(skill); m.raw_attack_damage(skill); m.standing_damage_values()
		Catalog.description(m.relics.items[2])
	check(m.hp == hp and m.rng.state == random_state,"All previews are cost-free and deterministic")
	m.begin_round(); m.roll_pool(false,[1,2,3,4,5,6]); m.dice_turn.selected = [0,1,2]; m.form_selected_skill()
	check(m.begin_player_cast(0),"Manual skill commits")
	check(m.hp == hp-20,"Damage copies each cost 1% once per cast")
	m.apply_player_step(0)
	check(m.hp == hp-20,"Impact does not charge damage buildup twice")
	m = fresh(["worn_bow","disguise_mask","ancient_tentacle"])
	m.begin_round(); m.roll_pool(false,[1,2,3,4,5,6])
	var hits := 0
	while m.perfect_relic_ready:
		hits += m.resolve_roll_relic_step().filter(func(e): return e.target >= 0 and e.type == "damage").size()
	check(hits == 4 and m.hp == m.max_hp-20,"Four bow activations include exactly two paid copies")
	m = fresh(["bracelet","ancient_tentacle"])
	m.hp = 10; m.shield = 10000; m.statuses[m.Status.IMMUNITY].apply(3)
	m.begin_round(); m.roll_pool(false,[1,2,3,4,5,6]); m.dice_turn.selected = [0,1,2]; m.form_selected_skill()
	var enemy_hp: int = m.enemies[0].hp
	m.apply_player_step(0)
	check(m.hp == 0 and m.outcome() == "defeat" and m.enemies[0].hp == enemy_hp,"Lethal cost bypasses defenses and stops the attack")
	check(m.heal(100) == 0,"Ordinary recovery cannot revive a lethal curse")
	m = fresh(["contract","bracelet","ancient_tentacle"]); m.hp = 1
	m.RelicEffects.Sequence.pay_retrigger_cost(m,["ancient_tentacle","bracelet"])
	check(m.hp == roundi(m.max_hp*0.6) and not m.relics.has("contract"),"Contract can prevent death from the curse")
	m = fresh(["ancient_tentacle","disguise_mask"])
	check(m.RelicEffects.Sequence.entries(m.relics.items).is_empty(),"Mask cannot copy Cursed Tentacle")

func unlock_checks() -> void:
	var m = fresh()
	check(not m.relics.can_add("magic_banana"),"Magic Banana starts outside random pools")
	m.acquire_relic("banana"); m.sell_relic(0)
	check(not m.relics.unlocks.has("magic_banana"),"Selling Banana does not unlock its upgrade")
	var path := "res://test-output/relic-unlocks-test.cfg"
	DirAccess.remove_absolute(path)
	m.relics.unlocks.configure(path)
	for seed_value in range(100):
		if not m.relics.has("banana"): m.acquire_relic("banana")
		m.rng.seed = seed_value; m.RelicEffects.Conditions.turn_finished(m)
		if not m.relics.has("banana"): break
	check(m.relics.unlocks.has("magic_banana") and m.relics.can_add("magic_banana"),"Random disappearance unlocks Magic Banana")
	m.reset_run()
	check(m.relics.can_add("magic_banana"),"Unlock survives a new run")
	var other = fresh(); other.relics.unlocks.configure(path)
	check(other.relics.can_add("magic_banana"),"Unlock survives restart from disk")
	other.relics.unlocks.configure(path,"chapter_2")
	check(not other.relics.can_add("magic_banana"),"New chapter has a fresh discovery pool")
	other.relics.unlocks.configure(path,"chapter_1")
	check(other.relics.can_add("magic_banana"),"Returning to the chapter preserves its unlock")
	var saved: Dictionary = Run.Campaign.capture(m)
	var restored = fresh()
	check(Run.Campaign.restore(restored,saved) and restored.relics.can_add("magic_banana"),"Checkpoint transfer preserves chapter discoveries")
	restored = fresh(); restored.relics.unlocks.configure("","chapter_2")
	check(not Run.Campaign.restore(restored,saved) and restored.relics.items.is_empty() and not restored.relics.can_add("magic_banana"),"Different chapter rejects old loadout and unlock checkpoint")
	DirAccess.remove_absolute(path)

func catalog_checks() -> void:
	check([Catalog.ITEMS.disguise_mask.rarity,Catalog.ITEMS.black_chip.rarity,Catalog.ITEMS.overflow_prism.rarity,Catalog.ITEMS.twin_scythes.rarity] == [3,3,3,3],"Updated legendary rarities")
	check(Catalog.ITEMS.red_chip.rarity == Catalog.Rarity.EPIC and Catalog.ITEMS.blue_chip.rarity == Catalog.Rarity.EPIC,"Red swaps to Epic; Blue keeps its rarity")
	check(Catalog.ITEMS.red_chip.sprite == "red_chip.svg" and Catalog.ITEMS.black_chip.sprite == "black_chip.svg","Swapped chips retain their colored artwork")
	check(Catalog.ITEMS.ancient_tentacle.rarity == 4 and Catalog.ITEMS.ancient_tentacle.name == "Cursed Tentacle","Tentacle retains save identity with new name and cursed rarity")
	var m = fresh(["ticket"]); m.begin_round()
	check(m.dice_turn.rolls_left == m.DiceTurn.ROLLS+2 and m.dice_turn.ticket_rolls_left == 2,"Ticket grants two additional rolls")
	m.roll_pool(false,[1,2,3,4,5,6])
	check(m.dice_turn.rewardable_rolls() == m.DiceTurn.ROLLS-1,"Treasure excludes both Ticket rolls")
	for i in range(m.DiceTurn.ROLLS-1): m.reroll_die(0,[2 if i%2 == 0 else 1])
	check(m.dice_turn.rolls_left == 2 and m.dice_turn.ticket_rolls_left == 2,"Ordinary rolls are spent first")
	m.reroll_dice([0,1],[1,2]); m.reroll_dice([0,1],[2,1])
	check(m.dice_turn.rolls_left == 0 and m.dice_turn.ticket_rolls_left == 0,"Batch rerolls can consume both Ticket rolls")
	m = fresh(["red_chip"]); m.begin_round(); m.roll_pool(false,[1,1,3,3,5,5])
	check(m.damage_multiplier() == 11,"Red Chip adds ten")
	m.roll_attacks.clear(); m.phase = "roll"; m.reroll_die(0,[2])
	check(m.damage_multiplier() == 1,"Correction expires Red Chip without reactivation")
	for id in NEW:
		check(ResourceLoader.exists(Catalog.sprite_path(id)),"Art exists for "+id)
		check(Paint.textures.get(Paint._load_sprite(id)) != null,"Shared inventory/reel/orbit sprite loads for "+id)
		check(GameText.text(Catalog.ITEMS[id].name) != Catalog.ITEMS[id].name,"Chinese name for "+id)
		check(GameText.text(Catalog.ITEMS[id].text) != Catalog.ITEMS[id].text,"Chinese description for "+id)
	var pool: Array = Catalog.ITEMS.keys().filter(func(id): return fresh_inventory_eligible(m,id))
	check(not pool.has("demon_clock"),"Clock fusion is never ordinary loot")

func fresh_inventory_eligible(m, id: String) -> bool:
	return m.relics.can_add(id) and not Catalog.ITEMS[id].get("fusion",false) and id not in Catalog.DISABLED

## Check both layouts, localized inspection and defeat while an acquisition overlay is open.
func scene_checks(phone: bool) -> void:
	var g = preload("res://scripts/combat/battle_portrait.gd").new() if phone else preload("res://scripts/combat/battle.gd").new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g.model.relics.items = NEW.map(func(id): return preload("res://scripts/relics/relic_instance.gd").create(id))
	g.view_phase = "ready"; g.inventory_page.open()
	check(g.inventory_page.opened,"Inventory opens with new relics")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		g.inventory_page.queue_redraw(); await process_frame; RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://test-output/relic-november-grid-%s.png" % phone)
	g.inventory_page.selected = 4
	var item: Dictionary = g.model.relics.items[4]
	var description: String = Catalog.description(item,GameText.text,g.model.relics.items)
	var width: float = 672 if phone else 824
	var height: float = 500 if phone else 186
	check(GameText.lines(description,g.description_font,20,width).size()*26 <= height,"Clock description fits the existing inspection panel")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		g.inventory_page.queue_redraw(); await process_frame; RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://test-output/relic-november-clock-%s.png" % phone)
	g.model.relics.items.clear(); g.model.acquire_relic("bracelet"); g.model.acquire_relic("ancient_tentacle")
	g.model.hp = 1; g.view_phase = "shop"
	g.model.RelicEffects.Sequence.pay_retrigger_cost(g.model,["ancient_tentacle","bracelet"])
	await process_frame
	check(g.view_phase == "over" and not g.inventory_page.opened and not g.chest.active,"Lethal curse closes reward/shop overlays and shows defeat")
	g.queue_free(); await process_frame

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var locale: String = GameText.language
	GameText.set_language("zh_CN",false)
	clock_checks(); status_checks(); ice_rose_checks(); tentacle_checks(); unlock_checks(); catalog_checks()
	for phone in [false,true]: await scene_checks(phone)
	GameText.set_language(locale,false)
	print("November relics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
