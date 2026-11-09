extends SceneTree
## Gem ownership, combat snapshots, merging, persistence and real inventory pointer gestures.
const Run = preload("res://scripts/progression/run_rules.gd")
const Gems = preload("res://scripts/dice/gemstone_inventory.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(270110)
	m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for enemy in m.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	m.begin_round()
	return m

func equip(m, slot: int, id: String, level: int = 1) -> void:
	m.gemstones.add(id,level)
	check(m.gemstones.equip(slot,id,level),"Gem can be equipped in a physical socket")

func form(m, indices: Array) -> void:
	m.dice_turn.selected = indices.duplicate()
	check(not m.form_selected_skill().is_empty(),"A physical straight forms")

func automatic(m) -> void:
	for i in range(36):
		if m.roll_attacks.is_empty(): break
		m.resolve_roll_attack_step()
	check(m.roll_attacks.is_empty(),"Automatic attack queue terminates")

func gem_value(g) -> int:
	var value := 0
	for i in range(g.order.size()): value += 1 << (int(g.bag_gem(i).level)-1)
	for gem in g.sockets:
		if not gem.is_empty(): value += 1 << (int(gem.level)-1)
	return value

## Exercise every drag direction and ensure merges conserve ownership without losing order.
func inventory_rules() -> void:
	var g = Gems.new()
	for id in Gems.Catalog.ids(): g.add(id,1,4)
	var worth: int = gem_value(g)
	check(g.order.size() == Gems.Catalog.ids().size()*4 and g.count("burning") == 4,"Every obtained gem has an ordered spare slot")
	check(g.transfer({"bag":0},{"bag":1}) and g.bag_gem(0) == {"id":"burning","level":2},"Matching bag gems merge where dropped")
	check(gem_value(g) == worth and g.order.size() == Gems.Catalog.ids().size()*4-1,"Merge consumes exactly two copies")
	check(g.transfer({"bag":0},{"socket":0}) and g.sockets[0].level == 2,"Drag equips one socket")
	check(g.transfer({"bag":0},{"bag":1}),"Second burning pair merges")
	check(g.transfer({"bag":0},{"socket":0}) and g.sockets[0].level == 3,"Dropping onto a matching socket upgrades it")
	check(g.transfer({"socket":0},{"socket":3}) and g.sockets[0].is_empty(),"Socket gems can move to empty sockets")
	check(g.equip(0,"healing"),"Equip a different type")
	check(g.transfer({"socket":0},{"socket":3}) and g.sockets[0].id == "burning" and g.sockets[3].id == "healing","Different socket gems swap")
	check(g.transfer({"socket":3},{"bag":0}) and g.sockets[3].is_empty() and g.bag_gem(0).level == 2,"Socket-to-bag merge retains result in bag")
	var before: Array = g.order.duplicate()
	check(g.transfer({"bag":0},{"bag":g.order.size()-1}) and g.order[-1] == before[0],"Nonmatching drops reorder without merging")
	check(g.unequip(0) and gem_value(g) == worth,"Unequip returns the same gem without loss")
	check(not g.merge({"id":"burning","level":3}) and not g.transfer({"socket":6},{"bag":0}),"Max tier and invalid locations are rejected")
	var saved: Dictionary = g.save()
	var copy = Gems.new(); copy.restore(saved)
	check(copy.save() == saved,"Gem bag order and sockets round-trip exactly")
	copy.add("healing")
	check(g.save() == saved,"Checkpoint data is independent of live equipment")
	copy.restore({"bag":{"burning:9":4,"healing:1":-4},"sockets":[{"id":"evil","level":1}]})
	check(copy.order.is_empty() and copy.sockets.all(func(gem): return gem.is_empty()),"Malformed gems never load into a socket")
	# Cover merge-button partners in spare bags and another socket.
	g = Gems.new(); g.add("corrosive",1,2); g.equip(0,"corrosive"); g.equip(1,"corrosive")
	check(g.merge(g.sockets[1],1) and g.sockets[0].is_empty() and g.sockets[1].level == 2,"Explicit merge keeps the selected equipped location")
	g.add("healing",3,2)
	check(g.transfer({"bag":0},{"bag":1}) and g.order.size() == 2,"Max-tier duplicates move without consuming either")
	for id in Gems.Catalog.ids():
		for level in range(1,4): check(g.count(id,level) == g.order.count(Gems.key(id,level)),"Bag count and ordered slots agree")

## Check both source hooks, committed snapshots and recovery timing across damage pulses.
func combat_rules() -> void:
	var m = fresh(); m.hp = 20
	equip(m,0,"healing",3)
	m.roll_pool(false,[1,2,3,4,5,6])
	check(m.leftover_total_healing() == 0,"Healing gems no longer heal unused dice")
	m.end_dice_turn(); m.apply_player()
	check(m.hp == 20 and m.phase == "enemy","Leftovers finish the turn without recovery")
	m = fresh(); m.hp = 20; m.max_hp = 150
	equip(m,0,"healing",1); equip(m,1,"healing",3)
	m.roll_pool(false,[2,2,3,4,5,6]); m.gemstones.unequip(0); m.gemstones.unequip(1)
	m.resolve_roll_attack_step()
	check(m.hp == 26,"Matching group heals once using every locked healing socket, rounded after summing")
	m.resolve_roll_attack_step(); check(m.hp == 26,"Subsequent automatic hits do not repeat group recovery")
	m = fresh(); m.hp = 20
	equip(m,0,"healing",2); equip(m,1,"guarding",3)
	m.roll_pool(false,[1,2,3,4,5,6]); form(m,[0,1,2]); m.gemstones.unequip(0); m.gemstones.unequip(1)
	m.apply_player(0)
	check(m.hp == 22 and m.shield == 6,"Straight heals and shields from committed physical pips")
	m = fresh(); m.hp = 20
	equip(m,0,"healing",3); equip(m,1,"guarding",3)
	m.apply_affliction(m.Status.DARKNESS,1); m.apply_affliction(m.Status.CORROSION,1)
	m.roll_pool(false,[1,2,3,4,5,6]); form(m,[0,1,2]); m.apply_player(0)
	check(m.hp == 20 and m.shield == 0,"Darkness blocks healing and Corrosion blocks gemstone shields")
	for length in [5,6]:
		m = fresh(); m.hp = 20; equip(m,0,"healing",2); equip(m,1,"darkness",3)
		m.roll_pool(false,[1,2,3,4,5,6]); form(m,range(length))
		for tick in range(m.pending.damage_ticks):
			m.apply_player_step(0)
			check(m.hp == 22,"Sustained damage ticks never repeat gemstone recovery")
			if tick < (5 if length == 5 else 10)-1:
				check(m.living().all(func(i): return m.enemy_status_count(i,m.Status.DARKNESS) == 0),"Status gems wait until the full damaging use ends")
		check(m.living().all(func(i): return m.enemy_status_count(i,m.Status.DARKNESS) <= 1),"One gem checks once per target, never once per tick")
	m = fresh(); m.hp = 20; equip(m,0,"healing")
	m.roll_pool(false,[1,2,3,4,5,6]); m.tarot_effects.extra_uses = 1; form(m,[0,1,2]); m.apply_player(0)
	check(m.hp == 22,"True extra uses each trigger one healing application")
	m = fresh(); equip(m,0,"darkness",3)
	m.pending = m.make_straight_skill([3,4,5]); m.pending.cast_source = "enchanted_missile"; m.phase = "player"; m.apply_player(0)
	check(m.enemy_status_count(0,m.Status.DARKNESS) == 0,"Generated skills do not borrow arbitrary equipped dice")
	# Force a successful check from every status type to verify routing and stack addition.
	m = fresh()
	var all_statuses: Array = ["burning","corrosive","freezing","plague","darkness"].map(func(id): return {"id":id,"level":3})
	var proc_rng := RandomNumberGenerator.new()
	var seed_value := 0
	while true:
		proc_rng.seed = seed_value
		if m.GemEffects.roll_statuses(all_statuses,false,proc_rng).size() == 5: break
		seed_value += 1
	var probe: MultiHitSkill = m.make_straight_skill([1,2,3,4,5]); probe.socket_gems = all_statuses
	for repeat in range(2):
		m.rng.seed = seed_value
		m._apply_gem_statuses(probe,0)
		for status in [m.Status.BURNING,m.Status.CORROSION,m.Status.FROZEN,m.Status.PLAGUE,m.Status.DARKNESS]: check(m.enemy_status_count(0,status) == repeat+1,"Every successful gem applies one independent stack to the enemy")
	m = fresh(); equip(m,0,"darkness",3)
	m.roll_pool(false,[2,2,3,4,5,6]); m.gemstones.unequip(0)
	proc_rng.seed = 1
	seed_value = 0
	while true:
		proc_rng.seed = seed_value
		if proc_rng.randf() < 0.45: break
		seed_value += 1
	m.roll_attacks[0].skill.target = 0; m.rng.seed = seed_value
	m.resolve_roll_attack_step()
	check(m.enemy_status_count(0,m.Status.DARKNESS) == 1,"Automatic attack applies its snapshotted status gem after unequipping")
	m = fresh(); equip(m,0,"critical",3)
	m.roll_pool(false,[1,2,3,4,5,6]); m.end_dice_turn()
	var cleanup_rng: int = m.rng.state
	m.begin_player_cast()
	check(m.rng.state == cleanup_rng,"Ending with an unused critical gem cannot consume combat randomness")
	# Preview totals and ordered HUD traces agree, including after committed critical rolls.
	m = fresh()
	for entry in [[0,"strength",2],[1,"strength",3],[2,"focus",2],[3,"critical",2],[4,"critical",2],[5,"empower",3]]: equip(m,entry[0],entry[1],entry[2])
	m.roll_pool(false,[1,2,3,4,5,6]); form(m,range(6))
	var state: int = m.rng.state
	check(is_equal_approx(m.raw_attack_damage(m.pending),10*1.5*1.2*1.3),"Base, multiplier and potency gems combine by summed levels in their own stages")
	var steps: Array = m.attack_damage_steps(m.pending)
	check(is_equal_approx(steps.back().base_after*steps.back().after,m.raw_attack_damage(m.pending)*10),"Damage feedback agrees with gemstone damage")
	m.selection_status_labels(m.pending); m.selection_damage_caption(m.pending)
	check(m.rng.state == state and not m.pending.gem_roll_locked,"Repeated previews do not spend random rolls or lock critical outcomes")
	m.begin_player_cast(0)
	var critical: float = m.pending.gem_critical_factor
	check(critical == 1.0 or is_equal_approx(critical,1.9),"Critical uses the participating level sum for multiplier")
	for tick in range(9):
		m.apply_player_step(0)
		check(m.pending.gem_critical_factor == critical,"Critical stays locked across all damage ticks")
	var copy: MultiHitSkill = m.pending.duplicate()
	check(copy.same_as(m.pending),"Skill snapshots retain critical outcome and lock state")
	m = fresh(); equip(m,0,"empower",3); equip(m,1,"healing",3); m.hp = 20
	m.roll_pool(false,[1,2,3,4,5,6]); form(m,[0,1,2]); m.apply_player(0)
	check(m.hp == 26 and m.enemy_status_count(0,m.Status.BURNING) == 2,"Empowering changes damage, not gem recovery or native status stacks")

## Verify independent probabilities and overflow with bounded deterministic samples.
func probability_rules() -> void:
	var fx = preload("res://scripts/dice/gemstone_effects.gd")
	var rng := RandomNumberGenerator.new(); rng.seed = 280111
	for id in Gems.Catalog.ids():
		var gem := {"id":id,"level":3}
		for automatic in [false,true]:
			var expected: float = fx.status_chance(gem,automatic)
			if expected == 0: continue
			var total := 0
			for trial in range(6000):
				for application in fx.roll_statuses([gem],automatic,rng): total += application.amount
			check(absf(total/6000.0-expected)<0.025,"Proc rates match the catalog for "+id+str(automatic))
	var doubles := [{"id":"darkness","level":1},{"id":"darkness","level":1}]
	check(is_equal_approx(fx.status_chances(doubles)[Run.Status.DARKNESS],0.51),"Two 30% gems mean a 51% chance of at least one proc")
	var both := false
	for i in range(100):
		if fx.roll_statuses(doubles,false,rng).size() == 2: both = true
	check(both,"Same-attribute gems can both trigger independently")
	for i in range(100): check(fx.roll_stacks(2.5,rng) in [2,3],"Over-100% chances grant whole stacks plus one fractional roll")
	check(fx.recovery([{"id":"healing","level":1}],[1],150,"heal") == 2,"Half-point healing rounds after aggregation")
	check(fx.factor([{"id":"strength","level":2},{"id":"strength","level":2}],"base") == 1.4,"Two level-two gems sum to four levels")
	var crits := 0
	for i in range(6000):
		if fx.critical_factor([{"id":"critical","level":2},{"id":"critical","level":2}],rng)>1: crits += 1
	check(absf(crits/6000.0-0.4)<0.025,"Critical chance uses summed participating levels")

## Drops are independent, uniform, credited once and carried between campaign levels.
func rewards_and_save() -> void:
	var m = fresh()
	for i in range(12000): m._roll_enemy_gemstone_drop(0)
	check(m.gemstones.order.size() > 1070 and m.gemstones.order.size() < 1330,"Observed drops match a ten-percent chance")
	for id in Gems.Catalog.ids(): check(m.gemstones.count(id) > 65 and m.gemstones.count(id) < 160,"All eleven types have equal eligibility")
	var guaranteed_seed := -1
	for seed_value in range(100):
		var rng := RandomNumberGenerator.new(); rng.seed = seed_value
		if rng.randf() < Gems.Catalog.DROP_CHANCE: guaranteed_seed = seed_value; break
	m = fresh(); m.reward_rng.seed = guaranteed_seed
	# Isolate the gemstone hook from the independently consumed tarot reward RNG.
	m._roll_enemy_gemstone_drop(0)
	check(m.gemstones.order.size() == 1,"Successful roll credits one tier-one gem")
	equip(m,0,"burning",2); equip(m,4,"healing",3)
	m.stage = 9
	var checkpoint: Dictionary = Run.Campaign.capture(m)
	var restored = Run.new(14)
	check(Run.Campaign.restore(restored,checkpoint) and restored.gemstones.save() == m.gemstones.save(),"Campaign continuation retains exact gemstones and sockets")
	checkpoint.run.erase("gemstones")
	check(Run.Campaign.restore(restored,checkpoint) and restored.gemstones.order.is_empty(),"Older checkpoints remain compatible with empty sockets")
	var cli = Session.new(12)
	cli.model.gemstones.add("corrosive",1,2)
	check(cli.command({"action":"gem_move","from":{"bag":1},"to":{"socket":2}}).ok,"CLI uses the same any-time socket transaction")
	check(cli.command({"action":"gem_merge","from":{"socket":2}}).ok and cli.snapshot().gemstones.sockets[1].level == 2,"CLI exposes and merges socket equipment")
	check(not cli.command({"action":"gem_move","from":{"socket":0},"to":{"bag":1}}).ok,"CLI rejects invalid one-based locations")
	for signal_name in ["enemy_souls_dropped","enemy_crystals_dropped","tarot_granted","tarot_expired","character_leveled","boss_changed","damage_redirected"]:
		for connection in cli.model.get_signal_connection_list(signal_name): cli.model.disconnect(signal_name,connection.callable)

func tap(g, at: Vector2) -> void:
	g._handle_click(at); g._handle_release(at)

func drag(g, from: Vector2, to: Vector2) -> void:
	g._handle_click(from); g._handle_motion(to); g._handle_release(to)

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/gemstones-"+label+".png")

## Test touch-sized controls, drag merges and preview clearance at both screen sizes.
func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	for e in g.model.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
	g.model.roll_pool(false,[1,2,3,4,5,6]); g._show_pending_skill(false)
	for i in range(6): g.dice[i].face = i+1
	g._open_debug(); g._debug_give_gemstones(); g._close_debug(false)
	check(g.model.gemstones.order.size() == Gems.Catalog.ids().size()*2,"Debug grants two of each gem")
	var page = g.inventory_page
	tap(g,page.button_rect().get_center())
	check(page.opened and page.tab == 0,"Backpack opens on relics first")
	tap(g,page.tab_rect(1).get_center())
	var ui = page.gem_page
	check(page.tab == 1,"Second tab opens all gemstones")
	check(ui.PER_PAGE == 20,"Gem bag shows five columns and four rows")
	for cell in range(ui.PER_PAGE):
		check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(ui.bag_rect(cell)),"All twenty bag cells stay on-screen")
		check(ui.bag_rect(cell).end.y < (1442 if phone else 606),"Four gem rows leave the description readable")
		for other in range(cell): check(not ui.bag_rect(cell).intersects(ui.bag_rect(other)),"Gem cells do not overlap")
	for i in range(6):
		check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(ui.socket_rect(i)),"Outer socket stays on-screen")
		check(ui.socket_rect(i).get_center().distance_to(ui.center()) > ui.die_center(i).distance_to(ui.center()),"Socket is outside its matching die")
	drag(g,ui.bag_rect(0).get_center(),ui.bag_rect(1).get_center())
	check(g.model.gemstones.bag_gem(0).level == 2 and g.model.gemstones.order.size() == Gems.Catalog.ids().size()*2-1,"Real drag merges identical spare gems")
	check(ui.selected == {"bag":0},"Merged gem remains selected after a preceding spare is removed")
	drag(g,ui.bag_rect(0).get_center(),ui.socket_rect(0).get_center())
	check(g.model.gemstones.sockets[0].level == 2,"Real drag equips outer socket")
	tap(g,ui.bag_rect(0).get_center()); tap(g,ui.socket_rect(1).get_center())
	check(g.model.gemstones.sockets[1].id == "healing","Tap gem then socket equips without merging")
	drag(g,ui.bag_rect(1).get_center(),ui.socket_rect(2).get_center())
	check(g.model.gemstones.sockets[2].id == "corrosive","Corrosive socket equips independently")
	drag(g,ui.socket_rect(1).get_center(),ui.socket_rect(5).get_center())
	check(g.model.gemstones.sockets[5].id == "healing","Equipped gems move between dice by drag")
	for id in Gems.Catalog.ids(): g.model.gemstones.add(id,1,7)
	check(ui.max_page() == ceili(g.model.gemstones.order.size()/20.0)-1,"More than twenty gems paginate")
	for locale in ["zh_CN","en"]:
		GameText.set_language(locale,false)
		tap(g,ui.socket_rect(0).get_center())
		await capture(("portrait" if phone else "landscape")+"-inventory-"+locale)
	tap(g,page.close_rect().get_center()); g._process(0)
	check(not page.opened and g.dice[0].socket_gem.id == "burning" and g.dice[5].socket_gem.id == "healing","Equipped colors propagate to real dice")
	var state: int = g.model.rng.state
	g.model.dice_turn.selected = [0,1,2,3,4]; g.dice_selection._selection_changed(); g.dice_selection._process(0.2)
	check(g.dice_selection.status_preview[g.Status.BURNING] == "2 + 20%" and g.dice_selection.status_preview[g.Status.CORROSION] == "10%","Preview distinguishes native stacks from gem proc chances")
	check(g.dice_selection.damage_text == "35 damage (1 use)","Preview shows one-use damage rather than five internal ticks")
	g.model.tarot_effects.extra_uses = 1; g.dice_selection._refresh_preview()
	check(g.dice_selection.damage_text == "35 damage (2 uses)","Extra uses remain a separate count")
	check(g.model.rng.state == state,"Status and damage previews consume no randomness")
	for i in range(6): check(not g.dice_selection.preview_rect().intersects(g.dice_selection.die_rect(i)),"New summary never overlaps selectable dice")
	for locale in ["zh_CN","en"]:
		GameText.set_language(locale,false); g.dice_selection._refresh_preview()
		await capture(("portrait" if phone else "landscape")+"-preview-"+locale)
	for phase in ["rolling","resolving","forming","frozen"]:
		g.view_phase = phase
		check(page.available(),"Gem inventory can open during "+phase)
	g.view_phase = "ready"
	g._restart(); g.queue_free(); await process_frame

func run() -> void:
	if "--inventory-only" in OS.get_cmdline_user_args():
		inventory_rules()
		print("Gemstone inventory: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0)
		return
	GameText.initialize(); GameText.set_language("en",false)
	inventory_rules(); combat_rules(); probability_rules(); rewards_and_save()
	await scene(false); await scene(true)
	print("Gemstones: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _initialize() -> void: call_deferred("run")
