extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Visuals = preload("res://scripts/enemies/enemy_visuals.gd")
var checks := 0
var failures := 0

## Start after the scene tree and autoloads are available.
func _initialize() -> void: call_deferred("run")

## Report a presentation or lifecycle regression with a searchable label.
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

## Save optional native-rendered frames for inspecting the new sprite and breakup.
func capture(label: String, game) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/mage-"+label+".png")

## Check deaths, menu pause, floor bounds and resets in both battle layouts.
func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.set_process(false)
	for child in g.get_children(): child.set_process(false)
	g.model.enemies = [g.Rules.make_enemy(2),g.Rules.make_enemy(2,1,true),g.Rules.make_enemy(0)]
	g.model.phase = "new"
	g.model.begin_round()
	g.enemy_debris.cosmetic.seed = 47
	var label: String = "portrait" if portrait else "landscape"
	check(Visuals.art_key(g.model.enemies[0]) == "mage_normal" and g.art.mage_normal.get_size() == Vector2(64,64),"Normal mage uses the 64px first frame")
	check(Visuals.art_key(g.model.enemies[1]) == "mage" and Visuals.debris(g.model.enemies[1]).is_empty(),"Elite mage retains its original sprite and death pose")
	await capture(label+"-alive",g)
	g.model.hit_enemy(0,9999,true)
	var rng_before: int = g.model.rng.state
	g._sync_corpses()
	check(g.kill_slow_remaining == g.KILL_SLOW_DURATION,"A new kill starts the complete impact envelope")
	check(is_equal_approx(g._world_time_scale(),0.1),"Kill impact immediately drops to 0.1x speed")
	for elapsed in [0.0,0.08,0.149]:
		g.kill_slow_remaining = g.KILL_SLOW_DURATION-elapsed
		check(is_equal_approx(g._world_time_scale(),0.1),"Kill impact holds moving slowmo for 0.15 seconds")
	var was_reduced: bool = g.reduced
	g.reduced = false
	g.kill_slow_remaining = g.KILL_SLOW_DURATION
	check(g._kill_impact_shake().length() > 0,"Camera wobble starts immediately with the speed drop")
	g.kill_slow_remaining = g.KILL_SLOW_OUT*0.65
	check(g._kill_impact_shake().length() > 0 and g._kill_impact_shake().length() < 5,"Recovery adds only a small camera wobble")
	g.kill_slow_remaining = 0
	check(g._kill_impact_shake() == Vector2.ZERO,"Camera wobble ends with recovery")
	g.reduced = was_reduced
	check(g.model.rng.state == rng_before,"Death pieces never consume combat RNG")
	check(g.enemy_debris.bodies.size() == 1 and g.enemy_debris.bodies[0].pieces.size() == 8,"A normal mage death spawns all eight authored pieces once")
	check(g.enemy_debris.bodies[0].blood.size() == 24,"Death adds a fuller pixel blood splatter")
	check(g.model.blood_gems == 5 and g.crystal_pickup.pending_total == 5,"Breakup preserves normal enemy crystal rewards")
	var body: Dictionary = g.enemy_debris.bodies[0]
	var first: Dictionary = body.pieces[0]
	g.model.hit_enemy(0,9999,true)
	g.kill_slow_remaining = 0.09
	g._sync_corpses()
	check(g.kill_slow_remaining == 0.09,"Repeated corpse hits cannot restart kill slowdown")
	check(g._world_time_scale() > 0 and g._world_time_scale() < 1,"Kill slowdown smoothly recovers")
	check(g.enemy_debris.bodies.size() == 1 and g.model.blood_gems == 5,"Corpse hits do not duplicate pieces or currency")
	var start: Vector2 = first.p
	g.menu_open = true
	g._process(0.1)
	check(g.kill_slow_remaining == 0.09,"Menu pause preserves the remaining kill impact")
	check(first.p == start and body.age == 0,"Menus pause the breakup")
	g.menu_open = false
	g.inspecting_enemy = 1
	g._process(0.1)
	check(first.p == start,"Enemy inspection pauses the breakup")
	g.inspecting_enemy = -1
	g.cinematic_remaining = 0
	g._process(0.1)
	check(first.p != start and first.angle != 0,"Closing the overlay resumes flying and spinning")
	await capture(label+"-burst",g)
	# Observe a real first ground bounce before it settles.
	var bounced: bool = false
	var inside: bool = true
	for frame in range(220):
		g.enemy_debris.advance(1.0/60.0,false)
		for piece in body.pieces:
			bounced = bounced or (piece.bounces == 1 and piece.v.y < 0)
			inside = inside and g.ARENA.encloses(Rect2(piece.p-Vector2.ONE*piece.radius,Vector2.ONE*piece.radius*2))
		if frame in [8,20,38,60,100]: await capture(label+"-frame"+str(frame),g)
	check(bounced,"Pieces visibly bounce before resting")
	check(inside and body.pieces.all(func(p): return p.resting),"All rotated pieces stay in the arena and settle")
	check(body.blood.all(func(p): return p.resting and p.bounces == 1) and body.age > 3.5,"Blood lands without bouncing and its floor splatter fades")
	check(body.pieces.all(func(p): return is_equal_approx(p.size.x/p.texture.get_width(),g._enemy_side()/64.0)),"Piece pixels match the character scale")
	g.model.hit_enemy(1,9999,true)
	g.model.hit_enemy(2,9999,true)
	g._sync_corpses()
	check(g.fallen.size() == 3 and g.enemy_debris.bodies.size() == 1,"Other enemies retain their existing corpse presentation")
	g._restart(19)
	check(g.enemy_debris.bodies.is_empty(),"Debug wave changes clear all debris")
	g.reduced = true
	g.model.enemies = [g.Rules.make_enemy(2),g.Rules.make_enemy(2)]
	g.model.phase = "new"
	g.model.begin_round()
	for i in range(2): g.model.hit_enemy(i,9999,true)
	g._sync_corpses()
	check(g.enemy_debris.bodies.size() == 2,"Simultaneous mage deaths keep separate pieces")
	for frame in range(120): g.enemy_debris.advance(1.0/60.0,true)
	for reduced_body in g.enemy_debris.bodies.values():
		check(reduced_body.pieces.size() == 8 and reduced_body.blood.size() == 6,"Reduced effects retain eight pieces with fewer droplets")
		check(reduced_body.pieces.all(func(p): return p.resting and p.angle == 0 and p.bounces == 1),"Reduced effects use a quiet unspun fall")
	g._restart()
	check(g.enemy_debris.bodies.is_empty(),"Restart clears fragments before enemy indices are reused")
	g.queue_free()
	await process_frame

## Status kills must register immediately, rather than replaying on a later attack.
func status_death(portrait: bool) -> void:
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.set_process(false)
	for child in g.get_children(): child.set_process(false)
	g.model.enemies = [g.Rules.make_enemy(2),g.Rules.make_enemy(0)]
	g.model.enemies[0].hp = 5
	g.model.apply_enemy_status(0,g.Status.BURNING,1)
	var events: Array = g.model._tick_enemy_statuses()
	check(g.model.enemies[0].hp == 0 and 0 not in g.model.living(),"Burning death is already final in combat logic")
	g._show_events(events)
	check(g.fallen.has(0) and g.enemy_debris.bodies.has(0),"Status death registers its animation in the same event dispatch")
	g.fallen[0] = 0.7
	g.kill_slow_remaining = 0.04
	var pieces: Array = g.enemy_debris.bodies[0].pieces.duplicate(true)
	g._show_events([g.model.damage_event(1,g.model.hit_enemy(1,1),1)])
	check(g.fallen[0] == 0.7 and g.kill_slow_remaining == 0.04,"Next attack cannot restart a prior status death")
	check(g.enemy_debris.bodies[0].pieces == pieces and g.model.blood_gems == 5,"Next attack cannot respawn debris or duplicate death rewards")
	g.model.hit_enemy(1,9999,true)
	g._show_events([])
	check(g.fallen.has(1),"Reactive kills register even without a returned damage event")
	g.queue_free()
	await process_frame

## Run the focused death-effect checks in landscape and portrait.
func run() -> void:
	await layout(false)
	await layout(true)
	await status_death(false)
	await status_death(true)
	print("Enemy debris: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
