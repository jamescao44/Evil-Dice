extends SceneTree
## Exercise focus routing, demon immunity and the real drag handle without touching saves.
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Focus = preload("res://scripts/relics/relic_focus.gd")
const Attack = preload("res://scripts/relics/relic_attack.gd")
const Fanatic = preload("res://scripts/enemies/fanatical_mage.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func fresh(seed_value: int = 44):
	var m = Run.new(seed_value)
	m.begin_round()
	m.enemies = [m.EnemyCatalog.make(m.EnemyCatalog.Role.PALADIN),m.make_enemy(1),m.make_enemy(2)]
	for e in m.enemies: e.hp = 10000; e.max_hp = 10000; e.shield = 0
	return m

func rules() -> void:
	var m = fresh()
	check(Catalog.ITEMS.challenger_badge.rarity == 2,"Badge enters the epic pool")
	check(m.acquire_relic(Focus.ID) and Focus.current(m) in [0,1,2],"Acquisition immediately marks one living foe")
	Focus.select(m,2)
	var state: int = m.rng.state
	for i in range(20): check(Focus.current(m) == 2 and Focus.targets(m) == [2],"Read-only queries retain the selected foe")
	check(m.rng.state == state,"Drawing and previews never reroll the mark")
	check(m.attack_targets() == [0],"Ordinary targeted tarot still obeys taunt")
	m.pending = m.make_straight_skill([1,2,3]); m.phase = "player"
	check(m.begin_player_cast() and m.pending.target == 2,"Fireball automatically bypasses taunt for the mark")
	Focus.select(m,1)
	check(m.player_target() == 2,"An already-launched Fireball keeps its target")
	var hits: Array = m.apply_player()
	check(hits.any(func(e): return e.target == 2 and e.type == "damage") and m.enemies[0].hp == 10000,"Focused Fireball hits the protected foe")
	m = fresh(); m.acquire_relic(Focus.ID); Focus.select(m,2)
	m.acquire_relic("split_arrow"); m.set_skill_use_multiplier("test",2)
	m.pending = m.make_straight_skill([1,2,3]); m.phase = "player"
	hits = m.apply_player()
	var damage_hits: Array = hits.filter(func(e): return e.type == "damage")
	check(damage_hits.size() == 4 and damage_hits.all(func(e): return e.target == 2),"All split/extra Fireball hits focus the protected target")
	m = fresh(); m.acquire_relic(Focus.ID); Focus.select(m,2)
	m.roll_pool(false,[2,2,3,4,5,6])
	check(m.roll_attack_target() == 2,"Matching dice choose the mark before launch")
	Focus.select(m,1)
	hits = m.resolve_roll_attack_step()
	check(hits.any(func(e): return e.type == "damage" and e.target == 2),"A launched auto-attack lands on its original target")
	check(m.roll_attack_target() == 1,"The next automatic hit follows the moved mark")
	hits = m.resolve_roll_attack_step()
	check(hits.any(func(e): return e.type == "damage" and e.target == 1),"Subsequent automatic damage uses the new mark")
	m = fresh(); m.acquire_relic(Focus.ID); Focus.select(m,2)
	hits = Attack.apply(m,"test",10,true)
	check(hits.any(func(e): return e.type == "damage" and e.target == 2) and m.enemies[0].hp == 10000,"Random item damage also bypasses taunt")
	Attack.apply(m,"retaliation",10,true,false,0)
	check(m.enemies[0].hp == 9990,"Explicit retaliation retains its actual attacker")
	m = fresh(); m.acquire_relic(Focus.ID); Focus.select(m,2)
	m.pending = m.make_straight_skill([1,2,3,4,5]); m.phase = "player"
	m.apply_player()
	check(m.enemies[0].hp == 9965 and m.enemies[1].hp == 9985 and m.enemies[2].hp == 9985,"Area attacks stay area attacks and retain taunt protection")
	m = fresh(); m.acquire_relic(Focus.ID); Focus.select(m,2)
	m.roll_pool(false,[6,6,6,6,6,6]); check(m.roll_attack_target() == 2,"Six-alike ritual starts against the focus")
	Focus.select(m,1)
	hits = m.resolve_roll_attack_step()
	check(hits.filter(func(e): return e.type == "damage").size() == 3,"Moving focus cannot swallow an in-flight area pulse")
	m = fresh(); m.acquire_relic(Focus.ID); Focus.select(m,2)
	m.hit_enemy(2,100000,true)
	check(Focus.current(m) in [0,1],"Death automatically moves the mark to another living foe")
	m.move_relic(0,0)
	check(Focus.current(m) in [0,1],"Inventory ordering does not lose the mark")
	m.sell_relic(0)
	check(Focus.current(m) == -1 and Focus.targets(m) == [0],"Selling the badge immediately restores normal taunt")
	m.acquire_relic(Focus.ID); m._load_wave()
	check(Focus.current(m) in m.living() and m.enemies.filter(func(e): return e.get(Focus.MARK,false)).size() == 1,"A carried badge marks exactly one fresh wave enemy")
	for e in m.enemies: e.hp = 0
	check(Focus.sync(m) == -1,"A cleared wave has no mark")
	var seen := {}
	for seed_value in range(60):
		m = fresh(seed_value); m.acquire_relic(Focus.ID); seen[Focus.current(m)] = true
	check(seen.size() == 3,"Initial random focus includes protected enemies")
	var session = preload("res://scripts/testing/playtest_session.gd").new(12)
	session.model.acquire_relic(Focus.ID)
	var next: int = session.model.living()[-1]
	var reply: Dictionary = session.command({"action":"focus","target":next+1})
	check(reply.ok and Focus.current(session.model) == next,"CLI uses the same one-based focus command")
	check(reply.state.enemies.any(func(e): return e.slot == next+1 and e.focused),"CLI exposes the current focus for balance testing")
	# Break signal closures owned by this temporary CLI fixture before releasing it.
	for signal_info in session.model.get_signal_list():
		for connection in session.model.get_signal_connection_list(signal_info.name): session.model.disconnect(signal_info.name,connection.callable)

func death() -> void:
	var m = fresh()
	m.enemies = [m.EnemyCatalog.make(m.EnemyCatalog.Role.FANATIC)]
	m.phase = "player"; m.hit_enemy(0,100000,true)
	var demon: int = m.enemies.size()-1
	m.phase = "roll"
	var card: Dictionary = m.grant_tarot("death")
	var hp: int = m.enemies[demon].hp
	check(m.enemies[demon].role == m.EnemyCatalog.Role.BOUND_DEMON,"Real second phase summons the tested demon")
	check(m.tarot_effects.targets(m,"death").is_empty(),"Neither boss nor taunting demon is a Death target")
	check(not m.tarot_effects.error(m,"death",{"target":demon}).is_empty(),"Death explicitly rejects the demon")
	check(m.tarot_effects._execute(m,demon).is_empty() and m.enemies[demon].hp == hp,"Direct/repeated execution cannot bypass demon immunity")
	check(m.tarot_effects.cast(m,card.instance_id,{"target":demon}).has("error") and m.enemies[demon].hp == hp,"The real card transaction rejects the demon before consuming anything")
	check(m.tarots.items.any(func(c): return c.instance_id == card.instance_id),"An invalid Death attempt preserves the card")
	m.acquire_relic(Focus.ID); Focus.select(m,0)
	check(m.tarot_effects.targets(m,"death").is_empty(),"Focus never removes Death immunity")
	m = fresh(); m.enemies = [m.make_enemy(0)]; m.phase = "roll"
	check(not m.tarot_effects._execute(m,0).is_empty() and not m.is_enemy_alive(0),"Death still kills an ordinary foe")

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/focus-"+label+".png")

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g._restart(5)
	g.model.enemies = [g.model.EnemyCatalog.make(g.model.EnemyCatalog.Role.PALADIN),g.model.make_enemy(1),g.model.make_enemy(2)]
	g.model.phase = "roll"; g.view_phase = "ready"
	g.model.acquire_relic(Focus.ID); Focus.select(g.model,0)
	g._update_battlefield_view(1.0)
	var ui = g.focus_mark
	ui._process(0.1)
	var old: Vector2 = ui.mark_rect(0).get_center()
	var destination: Vector2 = g._target_rect(2).get_center()
	var state: int = g.model.rng.state
	g._handle_click(old); g._handle_motion(destination)
	check(ui.dragging and ui.hover == 2 and g.pressed_enemy == -1,"Badge drag highlights a non-taunting enemy without opening inspection")
	check(Focus.current(g.model) == 0,"Hover previews without committing the focus")
	await capture("portrait-drag" if phone else "landscape-drag")
	g._handle_release(destination)
	check(not ui.dragging and Focus.current(g.model) == 2,"Releasing over a protected foe commits the mark")
	check(g.model.rng.state == state,"Manual retargeting is free of random rolls")
	check(g.ARENA.encloses(ui.mark_rect(2)),"Badge stays within the battlefield")
	g._handle_click(ui.mark_rect(2).get_center()); g._handle_motion(g.DICE_CENTER); g._handle_release(g.DICE_CENTER)
	check(Focus.current(g.model) == 2 and not ui.dragging,"Dropping outside the battlefield cancels")
	g.menu_open = true; ui._process(0.1)
	check(not ui.visible and not ui.click(old),"Menus hide and block the badge")
	g.menu_open = false
	g._handle_click(ui.mark_rect(2).get_center()); g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not ui.dragging and Focus.current(g.model) == 2,"Focus loss cancels the drag without moving the mark")
	if phone:
		g._restart(24); g.model.acquire_relic(Focus.ID)
		g.model.phase = "player"; g.model.hit_enemy(0,100000,true)
		g.model.phase = "roll"; g.view_phase = "ready"; g.clock_time += 2.0
		Focus.select(g.model,0); g._update_battlefield_view(1.0); ui._process(0.1)
		check(not ui.mark_rect(0).intersects(g.BossPresentation.hud_rect(g,0)),"Boss mark avoids its status and charge HUD")
		await capture("portrait-boss")
	g._restart(); g.queue_free(); await process_frame

func run() -> void:
	rules(); death(); await scene(false); await scene(true)
	print("Relic focus: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
