extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Art = preload("res://scripts/dice/dice_art.gd")
const Motion = preload("res://scripts/dice/dice_roll_motion.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

## Fail on incorrect atlas mappings, unsafe travel or changes to real dice results.
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Sample many cosmetic throws to catch clipped cells and synchronized motion.
func motion_checks() -> void:
	check(Art.SHEET.get_size() == Vector2(624,48),"Atlas is thirteen 48px cells")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8123
	var starts := {}; var directions := {}; var routes := {}
	for i in range(100):
		var motion = Motion.new()
		motion.begin(rng,Vector2(0,-170),Vector2.ZERO,232,0.95)
		starts[motion.start_frame] = true; directions[motion.frame_direction] = true; routes[motion.control_a] = true
		check(motion.position_at(0) == Vector2(0,-170) and motion.position_at(1).is_equal_approx(Vector2(0,-170)),"Travel starts and ends at its own vertex")
		var first: int = motion.frame_at(0)
		check(motion.frame_at(1.01/(motion.seconds*motion.frames_per_second)) == 6+posmod(first-6+motion.frame_direction,7),"Frames advance in the selected forward/reverse order")
		for step in range(121):
			var t: float = step/120.0
			check(motion.frame_at(t) in range(6,13),"Only frames 7–13 are used while rolling")
			check(motion.position_at(t).length() <= 232,"Dice travel stays inside the dice circle")
		check(absf(wrapf(motion.rotation_at(1),-PI,PI)) < 0.001,"Rotation returns upright")
	check(starts.size() == 7 and directions.size() == 2 and routes.size() == 100,"Starting frames, directions and paths vary independently")
	var distances: Array[float] = []
	for strength in [0.0,0.5,1.0]:
		rng.seed = 731
		var motion = Motion.new()
		motion.begin(rng,Vector2(0,-170),Vector2.ZERO,232,0.82,strength,strength == 1.0)
		var previous := Vector2(0,-170)
		var distance := 0.0
		for step in range(241):
			var point: Vector2 = motion.position_at(step/240.0)
			check(point.length() <= 232,"Powered bounces remain inside the dice area")
			distance += point.distance_to(previous)
			previous = point
		distances.append(distance)
		check(previous.is_equal_approx(Vector2(0,-170)),"Every power level snaps back exactly")
	check(distances[2] > distances[1] and distances[1] > distances[0],"Meter strength progressively increases travel")
	check(distances[2] > distances[0]*4,"Perfect throws bounce substantially farther than weak throws")

## Sample the same frame for every die: Perfect reveals must coincide even on slow frames.
func perfect_landing_checks() -> void:
	for speed in [1.0,2.0]:
		for count in [4,6]:
			for step in [1.0/60.0,1.0/24.0]:
				var dice: Array = []
				for i in range(count):
					var die = preload("res://scripts/dice/die.gd").new()
					root.add_child(die); die.set_process(false)
					die.roll_to(i%6+1,i,speed,1.0,true)
					dice.append(die)
				for frame in range(120):
					for die in dice: die._process(step)
					var landed: int = dice.filter(func(d): return not d.rolling).size()
					check(landed == 0 or landed == count,"Perfect throw never leaves partially revealed dice")
					if landed == count: break
				check(dice.all(func(d): return not d.rolling and d.position == d.resting),"Perfect dice reach all vertices together")
				for die in dice: die.queue_free()

## Capture real rendered poses without allowing time to advance between samples.
func capture(g, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g._process(0)
	for die in g.dice: die.set_process(false)
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/dice-sprites-"+name+".png")

## Exercise six real dice, quick counterclockwise landings, rerolls and cancellation.
func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 1; g.reduced = false
	g.set_process_input(false); g.set_process(false)
	var label: String = "portrait" if portrait else "landscape"
	var lands: Array = []
	var record_landing: Callable = func(index): lands.append(index)
	for i in range(6):
		g.dice[i].set_process(false)
		g.dice[i].cosmetic.seed = 710+i
		g.dice[i].landed.connect(record_landing.bind(i))
		check(g.dice[i].sprite_frame() == i,"Faces 1–6 use the first six cells")
	await capture(g,label+"-ready")
	g.debug_choice = 0
	g._roll(0.8,"--perfect" in OS.get_cmdline_user_args())
	check(g.dice[0].duration > 0.85,"Rolling uses the slower animation pace")
	var gameplay_rng: int = g.model.rng.state
	var reward_rng: int = g.model.reward_rng.state
	for sample in range(16):
		for frame in range(6):
			for die in g.dice: die._process(1.0/60.0)
		for die in g.dice:
			check(die.position.distance_to(g.DICE_CENTER) <= g.DICE_RADIUS,"Rendered travel stays in its layout's circle")
			check(die.sprite_frame() in range(6,13) if die.rolling else die.sprite_frame() == die.final_face-1,"Moving art cannot replace the locked result")
		if sample in [1,3,5,10]: await capture(g,label+"-"+str(sample))
	check(lands == ([0,1,2,3,4,5] if "--perfect" in OS.get_cmdline_user_args() else [0,5,4,3,2,1]),"All dice land in the expected timing order")
	check(g.model.rng.state == gameplay_rng and g.model.reward_rng.state == reward_rng,"Animation never consumes combat or reward randomness")
	for i in range(6):
		check(g.dice[i].face == i+1 and g.dice[i].position == g.DICE_POSITIONS[i] and g.dice[i].rotation == 0,"Final faces return to the original selectable positions")
	await process_frame
	g.model.dice_turn.locked = [0,1]
	g.model.dice_turn.committed = [0,1]
	g.view_phase = "ready"
	g._roll()
	check(not g.dice[0].rolling and not g.dice[1].rolling and g.dice.slice(2).all(func(d): return d.rolling),"Rerolls animate only unused dice")
	g.menu_open = true; g._process(0)
	var paused: float = g.dice[2].elapsed
	await create_timer(0.05).timeout
	check(g.dice[2].elapsed == paused and not g.dice[2].is_processing(),"Menus pause sprite animation and travel together")
	g._restart()
	for die in g.dice: die.set_process(false)
	check(g.dice.all(func(d): return not d.rolling and d.position == d.resting and d.rotation == 0),"Restart cancels every rolling pose")
	g.reduced = true; g._roll()
	for die in g.dice: die.reduced = true; die._process(0.2)
	check(g.dice.all(func(d): return d.position == d.resting and d.rotation == 0),"Reduced effects keep the new rolling frames without wandering or spinning")
	g._restart(); await process_frame
	g.queue_free(); await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	motion_checks()
	perfect_landing_checks()
	await layout(false); await layout(true)
	print("Dice sprites: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
