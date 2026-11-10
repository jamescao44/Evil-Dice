extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Types = preload("res://scripts/relics/relic_types.gd")
const Sins = preload("res://scripts/sins/sin_catalog.gd")
const Aura = preload("res://scripts/sins/sin_aura.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
var waited := false

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fresh():
	var model = Run.new(871)
	model.enemies = [Run.make_enemy(0),Run.make_enemy(1)]
	for enemy in model.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	return model

func fill(model, ids: Array) -> void:
	for id in ids: check(model.acquire_relic(id,-1,true),"Acquire fixture "+id)

## Exercise every gameplay hook with real model transactions, never UI-only unlocks.
func run() -> void:
	for index in range(7):
		check(is_equal_approx(Aura.pulse_age(index*0.3+0.2,index),0.2),"Each additional sin starts 0.3 seconds later")
		check(is_equal_approx(Aura.pulse_age(index*0.3+3.2,index),0.2),"Sin silhouette pulses repeat every three seconds")
		check(Aura.pulse_age(index*0.3+1.5,index) >= Aura.DURATION,"Silhouette fully fades between pulses")
	for id in Catalog.ITEMS: check(Catalog.ITEMS[id].get("type","") in Types.NAMES,"Catalog type: "+id)
	check(Types.stacks({"id":"witch_ghost"},Catalog.ITEMS) == {"biotic":5,"treasure":1},"Witch retains five Biotic bones and the Treasure ring")
	check(Types.stacks({"id":"ancient_codex"},Catalog.ITEMS) == {"artefact":10},"Codex keeps ten pages")
	check(Types.stacks({"id":"prismatic_stone"},Catalog.ITEMS) == {"artefact":6},"Prismatic keeps six stones")
	check(Types.stacks({"id":"happy_meal","ingredients":["fries","hamburger","lemon_soda"]},Catalog.ITEMS) == {"food":3},"Partial meal keeps actual three components")
	var m = fresh()
	fill(m,["worn_bow","disguise_mask","ancient_tentacle"])
	check(Types.owned(m.relics.items,Catalog.ITEMS).weapon == 1,"Retriggers never inflate owned collection counts")
	check(not Catalog.description({"id":"worn_bow","count":1}).contains("Wrath"),"Relic descriptions reveal types without mentioning sins")
	m = fresh()
	fill(m,["lemon_soda","fries","hamburger","oreo_sundae","fried_chicken","rice","miso_soup","salad","pickles"])
	check(not m.sins.has("gluttony"),"Nine owned Food stacks do not awaken")
	check(m.acquire_relic("tempura"),"Tenth Food acquired")
	check(m.sins.has("gluttony") and m.sins.food_consumed == 10 and m.relics.items.is_empty(),"Gluttony consumes both meals per ingredient")
	check(is_equal_approx(m.standing_damage_values().x,105) and is_equal_approx(m.standing_damage_values().y,11),"Ten consumed Food grant +100 base and +10 multiplier")
	check(m.acquire_relic("fortune_cookie") and m.tarots.items.is_empty() and m.sins.food_consumed == 11,"Future Food is consumed without its original acquisition gift")
	for id in ["lemon_soda","fries","hamburger","oreo_sundae","fried_chicken","rice","miso_soup","salad","pickles","tempura","super_meal","teishoku","fortune_cookie"]:
		check(not m.relics.can_add(id,-1,true) and not m.relics.Conditions.loot_allowed(m.relics,id),"Consumed Food and meal components cannot reappear: "+id)
	check(not m.acquire_relic("fortune_cookie",-1,true) and m.sins.food_consumed == 11,"Duplicate acquisition cannot consume the same Food twice")
	check(m.relics.can_add("vodka"),"Uneaten Food stays eligible after Gluttony awakens")
	var excluded: Array = Catalog.ITEMS.keys().filter(func(id): return id != "fries")
	check(m.relics.draw_one(m.reward_rng,excluded).is_empty(),"Loot exhaustion cannot fall back to consumed Food")
	for refresh in range(20):
		m.shop._restock(m)
		check(m.shop.offers.all(func(offer): return offer.kind != "relic" or offer.id not in m.relics.consumed_food_ids),"Shop refresh excludes consumed Food")
	fill(m,["worn_bow","bracelet","heart","basic_crystal","coin","glass_marble","armor","ticket","cross","blood_bag"])
	check(not m.relics.needs_slot("vodka") and m.acquire_relic("vodka"),"Gluttony accepts uneaten Food even with ten occupied slots")
	check(m.relics.items.size() == 10 and m.sins.food_consumed == 12,"Eating new Food never replaces an owned non-Food relic")
	var food_checkpoint: Dictionary = m.Campaign.capture(m)
	var food_restore = fresh()
	check(food_restore.Campaign.restore(food_restore,food_checkpoint) and food_restore.relics.consumed_food_ids == m.relics.consumed_food_ids,"Consumed Food exclusions survive next-level checkpoints")
	check(not food_restore.relics.can_add("fries") and not food_restore.relics.can_add("vodka"),"Restored consumed foods stay out of reward pools")
	food_restore.reset_run()
	check(food_restore.relics.consumed_food_ids.is_empty() and food_restore.relics.can_add("fries"),"Restarting the chapter restores consumed Food to the pool")
	food_restore.acquire_relic("fries"); food_restore.acquire_relic("hamburger")
	food_restore.sins.awaken(food_restore,["gluttony"])
	check(not food_restore.relics.can_add("fries") and not food_restore.relics.can_add("hamburger") and food_restore.relics.can_add("lemon_soda"),"Consuming a partial meal excludes only its actual ingredients")
	for seed in range(12):
		var reroll_model = fresh()
		reroll_model.Campaign.restore(reroll_model,food_checkpoint)
		reroll_model.begin_round(); reroll_model.reward_rng.seed = seed
		check(reroll_model.tarot_effects.eligible_relics(reroll_model,"emperor").all(func(id): return id not in reroll_model.relics.consumed_food_ids),"Emperor excludes consumed Food")
		var fool: Dictionary = reroll_model.tarots.add("fool")
		var reroll_result: Dictionary = reroll_model.tarot_effects.cast(reroll_model,fool.instance_id)
		check(not reroll_result.has("error") and reroll_model.sins.food_consumed == 12,"Fool keeps consumption history while replacing inventory")
	m = fresh()
	fill(m,Array(range(10)).map(func(_i): return "worn_bow"))
	check(m.sins.has("wrath"),"Ten physical weapons awaken Wrath")
	m.begin_round(); m.roll_pool(false,[1,2,3,4,5,6])
	check(m.roll_relic_actions.size() == 20,"Initial throw schedules original shots and ten Wrath shots")
	check(m.roll_relic_actions.filter(func(a): return a.options.get("base_scale",0) == 2.0).size() == 10,"Each weapon gains exactly one 2x-base attack")
	m.resolve_perfect_relic(); m.reroll_die(0,[2])
	check(m.roll_relic_actions.is_empty(),"Rerolls do not activate Wrath")
	m = fresh(); m.sins.unlocked = ["sloth","envy"]
	var auto = m.Patterns.automatic_groups([1,1,2,3,4,5],range(6))[0].skill
	var fireball = m.make_straight_skill([3,4,5])
	check(m.sins.skill_factor(auto) == 3 and m.sins.skill_factor(fireball) == 2.25,"Sloth and Envy stay in separate attack categories")
	var item_skill = m.Skill.new(m.Kind.PAIR,1,[]); item_skill.cast_source = "relic"
	check(m.sins.skill_factor(item_skill) == 1,"Envy never buffs item attacks")
	var buffed: float = m.raw_attack_damage(fireball)
	m.sins.unlocked.clear()
	check(is_equal_approx(buffed/m.raw_attack_damage(fireball),2.25),"Envy applies exactly once to skill damage")
	for i in range(11): m.RelicEffects.tarot_used(m)
	check(not m.sins.has("envy"),"Eleven cards do not awaken Envy")
	m.RelicEffects.tarot_used(m,false)
	check(m.sins.tarot_uses == 11,"Prophecy repeats do not count as another card consumed")
	m.RelicEffects.tarot_used(m)
	check(m.sins.has("envy"),"Twelfth consumed tarot awakens Envy")
	m = fresh(); fill(m,Array(range(10)).map(func(_i): return "basic_crystal"))
	check(m.sins.has("greed"),"Ten Treasure stacks awaken Greed")
	m.blood_gems = 119
	check(m.standing_damage_values().x == 60,"Greed adds one base per whole twenty current gems")
	m.blood_gems = 19
	check(m.standing_damage_values().x == 55,"Spending gems reduces Greed's current bonus")
	m = fresh(); fill(m,["witch_ghost","pet_orb","demon_clock"])
	check(m.sins.has("pride"),"Three complete held sets awaken Pride")
	var base: float = m.character_base_damage()+m.RelicEffects.base_damage(m.relics.items,m.character_base_damage())
	m.hp = m.max_hp/2
	check(is_equal_approx(m.standing_damage_values().x,base+maxf(100,base)*0.5),"Pride uses current HP percent and does not compound itself")
	m.sell_relic(0); check(m.sins.has("pride"),"Selling an awakening ingredient does not remove an unlocked sin")
	m = fresh(); fill(m,Array(range(10)).map(func(_i): return "blood_bag"))
	check(m.sins.has("lust"),"Ten Biotic stacks awaken Lust")
	m.hp = 500
	check(m.heal(25) == 100,"Lust doubles recovery after ordinary healing bonuses")
	m.relics.clear(); m.hp = 1000
	var result: Array = m.receive_damage(100)
	check(result.filter(func(e): return e.target >= 0 and e.type == "damage").size() == 2,"Lust retaliates once on each enemy")
	check(m.enemies[0].hp == 99985 and m.enemies[1].hp == 99985,"Lust retaliation uses HP-loss fraction plus base damage")
	m.shield = 100; var before: int = m.enemies[0].hp; m.receive_damage(50)
	check(m.enemies[0].hp == before,"Fully shielded hits do not count as HP loss")
	m.lose_hp(90); result = m.sins.resolve_retaliations(m)
	check(not result.is_empty(),"Self-damage costs also trigger Lust")
	# A nested Tentacle cost triggered by recovery appends a reaction instead of recursing the call stack.
	m = fresh(); m.sins.unlocked = ["lust"]; fill(m,["bloodstone","ancient_tentacle"])
	for enemy in m.enemies: enemy.hp = 90
	m.hp = 1000; m.receive_damage(100)
	check(m.enemies.all(func(e): return e.hp < 75) and m.sins.retaliation_queue.is_empty() and not m.sins.resolving_retaliation,"Lifesteal copies pay HP and add another retaliation before healing naturally ends the chain")
	m = fresh()
	for stage in range(8): m.stage = stage; m._load_wave(); m.sins.wave_cleared(m)
	check(m.sins.has("sloth"),"Eight cleared waves without reroll awaken Sloth")
	m = fresh()
	for stage in range(8):
		m.stage = stage; m._load_wave()
		if stage == 0: m.sins.rerolled()
		m.sins.wave_cleared(m)
	check(not m.sins.has("sloth"),"A reroll in the first wave disqualifies the whole level")
	for stage in range(8,16): m.stage = stage; m._load_wave(); m.sins.wave_cleared(m)
	check(m.sins.has("sloth"),"A later clean level can still awaken Sloth")
	var saved: Dictionary = m.Campaign.capture(m)
	m.sins.unlocked.append("gluttony"); m.sins.food_consumed = 7
	saved = m.Campaign.capture(m)
	var loaded = fresh()
	check(loaded.Campaign.restore(loaded,saved) and loaded.sins.has("sloth") and loaded.sins.food_consumed == 7,"Level-entry checkpoint restores chapter awakenings and bonuses")
	loaded.reset_run(); check(loaded.sins.unlocked.is_empty() and loaded.sins.food_consumed == 0,"Fresh chapter clears all sin progress")
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800); root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.view_phase = "ready"; g.player_animation.reset()
		g.model.relics.consumed_food_ids = food_checkpoint.run.consumed_food_ids.duplicate()
		g.chest._refresh_scroll_symbols()
		check(g.chest.scroll_symbols.all(func(index): return g.chest.symbols[index].get("relic_id","") not in g.model.relics.consumed_food_ids),"Chest reels exclude all consumed Food")
		g.model.sins.unlocked = ["wrath"]
		g.sin_view.enqueue("wrath")
		check(paused and g.sin_view.active(),"Awakening pauses the whole scene in both layouts")
		check(g.sin_view.get_parent().layer > BattleLayers.DAMAGE_CANVAS,"Sin page covers damage, spells, rewards and menus")
		waited = false
		finish_wait(g)
		var clock_before: float = g.clock_time
		for frame in range(4): await process_frame
		check(not waited and g.clock_time == clock_before,"The battle clock and awaited actions both stop behind an awakening")
		g.sin_view.age = 1; g.sin_view.mode = "hold"
		await capture(g,"awakening",phone)
		g.sin_view.mode = "leave"; g.sin_view._process(0.5)
		check(not paused and not g.sin_view.active(),"Minimizing restores prior pause state")
		for frame in range(4): await process_frame
		check(waited,"Awaited battle actions resume after the awakening closes")
		g.model.sins.unlocked = Sins.ORDER.duplicate()
		for id in Sins.ORDER: check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(g.sin_view.icon_rect(id)),"Icon remains onscreen: "+id)
		await capture(g,"icons",phone)
		g.sin_view._open("pride",false)
		check(paused and not g.sin_view.opening,"Inspection reopens the same information page")
		g.sin_view.enqueue("envy"); g.sin_view.mode = "leave"; g.sin_view._process(0.5)
		check(paused and g.sin_view.current == "envy","Queued awakenings do not briefly resume gameplay")
		g.sin_view.mode = "leave"; g.sin_view._process(0.5)
		check(not paused,"Last queued page correctly releases the pause")
		if not phone and DisplayServer.get_name() != "headless": await aura_bounds(g)
		g.queue_free(); await process_frame
	print("Seven sins: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func finish_wait(game) -> void:
	await game._wait(0.001)
	waited = true

## Render actual expanding contours and ensure every form stays above its feet.
func aura_bounds(game) -> void:
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.evolution.entrance.reset()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400,400); viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Node2D.new(); viewport.add_child(canvas)
	var rect := Rect2(40,20,320,320)
	canvas.draw.connect(func(): game.sin_view.paint_aura(canvas,rect))
	for level in [1,5,10]:
		game.evolution.displayed_level = level
		var form: int = game.evolution.form_index(level)
		var ground: Vector2 = game.sin_view.PlayerSprite.ground_anchor(rect,form)
		for time in [0.15,0.7,1.5]:
			game.clock_time = time; canvas.queue_redraw()
			await process_frame; await RenderingServer.frame_post_draw
			var shot: Image = viewport.get_texture().get_image()
			var below := 0; var visible := 0
			for y in range(400):
				for x in range(400):
					if shot.get_pixel(x,y).a <= 0.001: continue
					visible += 1
					if y >= ceili(ground.y): below += 1
			check(visible > 100,"Sin aura stays visible in form "+str(form+1))
			check(below == 0,"Sin outlines never extend below form "+str(form+1)+" feet")
			if "--capture" in OS.get_cmdline_user_args() and time == 0.7:
				shot.save_png("/tmp/evil-dice-sin-aura-form-%d.png" % (form+1))
	viewport.queue_free(); await process_frame

func capture(game, tag: String, phone: bool) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	game.queue_redraw(); game.sin_view.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/evil-dice-sins-%s-%s.png" % [tag,"portrait" if phone else "landscape"])
