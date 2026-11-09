extends SceneTree
## Damage trails must survive successive hits without delaying real HP or shield changes.
const Trails = preload("res://scripts/combat/health_trails.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Exercise timing, healing, phase replacement and simultaneous deaths without rendering.
func model_checks() -> void:
	var model := {"hp":1000,"max_hp":1000,"enemies":[{"hp":100,"max_hp":100,"shield":30,"boss_phase":1}]}
	var trails = Trails.new()
	trails.reset(model)
	model.hp = 600; model.enemies[0].hp = 40
	trails.sync(model)
	check(trails.value(-1,600) == 1000 and trails.value(0,40) == 100,"Simultaneous hits keep previous HP behind the immediate HP values")
	trails.advance(trails.bars[-1].hold)
	check(trails.value(-1,600) == 1000,"Lost health stays visible throughout the hold")
	trails.advance(trails.bars[-1].recede*0.5)
	check(is_equal_approx(trails.value(-1,600),800) and trails.value(0,40) > 70,"Larger relative loss waits longer before its quick recession")
	model.hp = 500; trails.sync(model)
	check(is_equal_approx(trails.value(-1,500),800),"A second hit starts from the visible trail without jumping backward")
	trails.advance(trails.bars[-1].hold)
	check(is_equal_approx(trails.value(-1,500),800),"Repeated damage refreshes the short hold")
	trails.advance(5)
	check(trails.value(-1,500) == 500 and not trails.lingering(-1),"Trails end exactly at actual HP even after a long frame")
	check(model.hp == 500 and model.enemies[0].hp == 40,"Presentation never mutates health")
	model.hp = 300; trails.sync(model); model.hp = 400; trails.sync(model)
	check(trails.value(-1,400) == 400 and not trails.lingering(-1),"Healing clears old damage rather than implying unearned HP")
	model.hp = 200; trails.sync(model); model.max_hp = 800; trails.sync(model)
	check(trails.value(-1,200) == 200,"Maximum-HP changes reset the trail's scale")
	model.enemies[0].shield = 0; trails.sync(model)
	check(not trails.lingering(0),"Shield-only changes do not pretend that health was lost")
	model.enemies[0].hp = 0; trails.sync(model)
	check(trails.lingering(0) and trails.value(0,0) == 40,"Lethal damage also has a trail")
	model.enemies[0].boss_phase = 2; model.enemies[0].hp = 20; trails.sync(model)
	check(trails.value(0,20) == 20 and not trails.lingering(0),"A new boss phase cannot inherit the previous phase's damage")
	model.enemies[0].hp = 0; trails.sync(model)
	model.enemies[0] = {"hp":10,"max_hp":100,"shield":0,"boss_phase":2}; trails.sync(model)
	check(trails.value(0,10) == 10,"A replacement actor in the same slot starts clean")
	model.enemies.clear(); trails.sync(model)
	check(trails.bars.size() == 1,"Removed enemies leave no lingering state")
	for fps in [30,60,144]:
		trails.reset(model); model.hp -= 50; trails.sync(model)
		for frame in range(fps): trails.advance(1.0/fps)
		check(trails.value(-1,model.hp) == model.hp,"Trail duration is independent of frame rate")
	var small: Vector2 = Trails.timing(50,1000)
	var large: Vector2 = Trails.timing(500,1000)
	check(large.x > small.x and large.y == small.y and is_equal_approx(large.y,0.2),"Only hold duration scales; every trail recedes in 200ms")
	check(large == Trails.timing(50000,100000),"Equal percentages last equally long at different power levels")
	check(is_equal_approx(small.x+small.y,0.4035) and is_equal_approx(large.x+large.y,0.615),"Five-percent hits clear quickly while half-health hits linger")
	check(Trails.timing(1000000,1000) == Trails.timing(1000,1000),"Timing has a full-health cap instead of growing with overkill")
	model.hp = 1000; model.max_hp = 1000
	trails.reset(model); model.hp = 600; trails.sync(model)
	model.hp = 500; trails.sync(model)
	check(is_equal_approx(trails.bars[-1].hold,large.x) and is_equal_approx(trails.bars[-1].recede,large.y),"Rapid consecutive hits use their combined visible health loss")
	trails.advance(large.x+large.y-0.01)
	check(trails.lingering(-1),"Large hit remains visible until its own duration ends")
	trails.advance(0.02)
	check(not trails.lingering(-1) and trails.value(-1,500) == 500,"Large hit still settles exactly onto actual HP")

## Optional captures compare hold, receding, settled and boss health in both layouts.
func capture(g, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	g._update_battlefield_view(1)
	g.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://test-output/health-trails")
	root.get_texture().get_image().save_png("res://test-output/health-trails/"+name+".png")

func scene_checks(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
	g._restart(1)
	g.model.enemies = [g.Rules.make_enemy(0),g.Rules.make_enemy(1)]
	g.health_trails.sync(g.model)
	var enemy_hp: int = g.model.enemies[0].hp
	g.model.hp = 600; g.model.shield = 100
	g.model.enemies[0].hp = int(enemy_hp*0.4)
	g._show_events([])
	check(g.health_trails.value(-1,600) == 1000 and g.health_trails.value(0,0) == enemy_hp,"Battle events immediately update player and enemy trails")
	var name: String = "portrait" if phone else "landscape"
	await capture(g,name+"-hold")
	g.menu_open = true; g._process(1)
	check(g.health_trails.value(-1,600) == 1000,"Menus pause the trail")
	g.menu_open = false; g.inspecting_enemy = 0; g._process(1)
	check(g.health_trails.value(-1,600) == 1000,"Enemy inspection pauses the trail")
	g.inspecting_enemy = -1; g.kill_slow_remaining = 0; g._process(g.health_trails.bars[-1].hold+g.health_trails.bars[-1].recede*0.5)
	check(is_equal_approx(g.health_trails.value(-1,600),800),"Closing overlays resumes smooth recession")
	await capture(g,name+"-receding")
	g.health_trails.advance(3)
	await capture(g,name+"-settled")
	g.model.enemies[0].hp = 0; g.health_trails.sync(g.model)
	check(g.BattlefieldRender.health_visible(g,0) and not g.BattlefieldRender.labels_visible(g,0),"A dead enemy keeps only its trailing health bar")
	g.health_trails.advance(3)
	check(not g.BattlefieldRender.health_visible(g,0),"Lethal trail disappears once empty")
	g._restart(8)
	check(not g.health_trails.lingering(-1) and not g.health_trails.lingering(0),"Restart clears every actor's old trail")
	var boss_hp: int = g.model.enemies[0].hp
	g.model.enemies[0].hp = int(boss_hp*0.35); g._show_events([])
	check(g.health_trails.value(0,0) == boss_hp,"Boss health uses the same damage feedback")
	await capture(g,name+"-boss")
	g.queue_free(); await process_frame

func run() -> void:
	model_checks()
	for phone in [false,true]: await scene_checks(phone)
	print("Health trails: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
