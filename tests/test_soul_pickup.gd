extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Check role rewards, shields, corpse hits and status kills through the real damage path.
func kills() -> void:
	for role in range(Enemy.ITEMS.size()):
		for elite in [false,true]:
			var m = Run.new(51)
			m.enemies = [Enemy.make(role,1,elite)]
			var drops: Array = []
			m.enemy_souls_dropped.connect(func(target,amount): drops.append([target,amount]))
			var expected: int = Enemy.soul_reward(m.enemies[0])
			m.enemies[0].shield = 10
			m.hit_enemy(0,9999)
			check(drops.is_empty() and m.souls == 0,"Shield break awards no XP")
			m.hit_enemy(0,9999,true)
			if m.enemies[0].get("boss",false):
				check(drops.is_empty(),"First boss phase grants no XP")
				m.hit_enemy(0,9999,true)
			check(drops == [[0,expected]],"Kill grants class-specific XP once")
			check(m.souls+5*m.character_level*(m.character_level-1) == expected,"XP remains exact after automatic spending")
			m.hit_enemy(0,9999,true)
			check(drops.size() == 1,"Corpse hits cannot award more souls")
	var m = Run.new(52)
	m.acquire_relic("soul_vessel")
	m.enemies = [Enemy.make(0),Enemy.make(1,1,true),Enemy.make(3),Enemy.make(4,1,true)]
	for i in range(4): m.hit_enemy(i,9999,true)
	check(m.character_level == 4 and m.souls == 37 and is_equal_approx(m.enemy_soul_remainder,0.75),"Soul Vessel boosts 85 base enemy XP by 15 percent with fractional carry")
	m = Run.new(53)
	m.enemies[0].hp = 5
	m.apply_enemy_status(0,m.Status.BURNING,1)
	m._tick_enemy_statuses(); m._tick_enemy_statuses()
	check(m.souls == 5 and m.character_level == 1,"Burning awards XP once")

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	for node in root.get_children():
		if node is Node2D:
			node.queue_redraw()
			if node.get("arena_actors") != null: node.arena_actors.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/"+name+".png")

## Verify simultaneous receipts, XP rollover, player absorption, milestone forms and both layouts.
func scene(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	GameText.set_language("zh_CN" if portrait else "en",false)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
	var p = g.soul_pickup
	p.set_process(false); g.evolution.set_process(false)
	g.model.enemies = [Enemy.make(0),Enemy.make(1)]
	g.model.hit_enemy(0,9999,true); g.model.hit_enemy(1,9999,true)
	g._sync_corpses()
	check(p.orbs.size() == 20 and p.pending_total == 10,"Simultaneous kills retain both receipt clouds")
	check(g.model.character_level == 2 and p.counter_state() == {"souls":0,"level":1},"Model grants once while the displayed XP waits for collection")
	g.debug_open = true; p._process(0.5)
	check(p.orbs[0].age == 0 and not p.visible,"Menus hide and pause soul receipts")
	g.debug_open = false; p.visible = true; p.advance(0.5)
	check(p.pending_total == 10 and p.orbs.all(func(o): return p.position_of(o).distance_to(o.rest) < 5),"Souls scatter and hover before pickup")
	await capture("xp-blue-drops-"+str(portrait))
	p.advance(0.62)
	check(p.pending_total > 0 and p.pending_total < 10,"Arrivals progressively fill the XP bar")
	await capture("xp-bar-progress-"+str(portrait))
	p.advance(1)
	check(p.orbs.is_empty() and p.counter_state() == {"souls":0,"level":2},"XP bar rolls into the new level exactly")
	check(p.pulse > 0,"Absorbed souls light the player")
	g.evolution._process(0.25)
	check(g.evolution.displayed_level == 2 and g.evolution.form_index(2) == 0,"Normal level celebrates without changing form")
	await capture("xp-level-up-"+str(portrait))
	g.evolution._process(2)
	var origin: Vector2 = g.wave_chest.chest_rect().get_center()
	var state: int = g.model.reward_rng.state
	g.model.gain_souls(50); p.enqueue(origin,50)
	g.model.gain_souls(40); p.enqueue(origin,40)
	check(p.pending_total == 90 and p.orbs.size() == 96,"Chest and other grants accumulate without replacing earlier receipts")
	check(p.orbs[0].tint.is_equal_approx(p.GOLD) and p.orbs[-1].tint != p.BLUE,"Large drops become gold and retain their individual colors")
	p.advance(0.45)
	await capture("xp-gold-drops-"+str(portrait))
	var landed: Dictionary = p.orbs[0].duplicate(); landed.age = 10
	check(p.position_of(landed).is_equal_approx(g._player_point()),"Every soul converges on the player, not the old currency header")
	p.advance(2)
	check(p.counter_state() == {"souls":0,"level":5} and g.model.reward_rng.state == state,"Receipts do not grant twice or reroll rewards")
	g.evolution._process(1); g.evolution._process(1); g.evolution._process(1)
	check(g.evolution.displayed_level == 5 and g.evolution.is_evolution() and g.evolution.form_index(5) == 1,"Level five reveals the second form")
	await capture("xp-evolution-"+str(portrait))
	check(g.evolution.form_index(4) == 0 and g.evolution.form_index(9) == 1 and g.evolution.form_index(10) == 2 and g.evolution.form_index(20) == 2,"Five-level evolution intervals safely retain the last available form")
	var bar: Rect2 = g.player_health_rect()
	check(g.ARENA.encloses(Rect2(bar.position,bar.size+Vector2(0,14))),"Health and XP both fit inside the battlefield")
	g.reduced = true; g.model.gain_souls(40); p.enqueue(origin,40); p.advance(3)
	check(p.orbs.is_empty(),"Reduced effects still finishes every receipt")
	g.model.gain_souls(310) # Reach level 10: 450 total XP.
	g.evolution.reset()
	check(g.model.character_evolution_stage() == 2 and g.model.character_passive.charge_limit(2) == 3,"The evolved HUD retains three charge circles")
	await capture("xp-final-form-"+str(portrait))
	g._restart()
	check(p.pending_total == 0 and p.orbs.is_empty() and p.counter_state() == {"souls":0,"level":1} and not g.evolution.active(),"Restart clears all receipts and level celebrations")
	g.queue_free(); await process_frame

func run() -> void:
	kills()
	await scene(false)
	await scene(true)
	print("Soul XP and pickups: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
