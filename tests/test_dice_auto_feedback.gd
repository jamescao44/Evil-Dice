extends SceneTree
const Idle = preload("res://scripts/dice/dice_idle_feedback.gd")
const Pool = preload("res://scripts/dice/dice_turn.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Maximal hints include tied physical choices, never their smaller straight subsets.
func hint_checks() -> void:
	for values in [[1,2,3,4,5,6],[1,2,3,4,5,5],[1,2,2,3,4,6],[1,1,2,3,4,4],[1,1,2,2,3,3],[1,1,2,4,5,6],[1,1,3,3,5,5]]:
		var groups: Array = Idle.longest_straights(values,range(6))
		var expected: int = 0
		for first in range(1,5):
			for length in range(3,8-first):
				if range(first,first+length).all(func(face): return face in values): expected = maxi(expected,length)
		check(groups.is_empty() == (expected == 0),"Hints exist exactly when a straight is available")
		for group in groups:
			check(group.size() == expected,"Every hinted group has maximum length")
			var faces: Array = group.map(func(i): return values[i]); faces.sort()
			check(faces == range(faces[0],faces[0]+expected),"Hint uses unique consecutive faces")
	var choices: Array = Idle.longest_straights([1,2,2,3,4,6],range(6))
	check(choices == [[0,1,3,4],[0,2,3,4]],"Both four-die alternatives cycle without any three-die subset")
	check(Idle.longest_straights([1,2,3,4,5,6],[0,1,2,3]) == [[0,1,2,3]],"Spent dice cannot extend a hint")
	check(Idle.combination_indices([1,1,2,3,5,6],range(6)) == [0,1,2,3],"Only dice participating in a complete straight receive rings")
	check(Idle.combination_indices([1,1,2,3,5,6],range(6),[0]) == [0,2,3],"Selected pip excludes its duplicate from compatible combinations")
	check(Idle.combination_indices([1,1,3,3,5,5],range(6)).is_empty(),"Automatic-only rolls have no selection rings")
	check(Idle.combination_indices([1,2,3,4,5,6],[0,1,4,5]).is_empty(),"Spent middle dice cannot complete a straight")
	var pool = Pool.new(); pool.reset(); pool.values = [1,2,3,4,5,6]; pool.rolls_left = 2; pool.rolls_made = 1
	var idle = Idle.new(); idle.advance(0.95,pool,true,false)
	check(idle.groups == [range(6)] and idle.hint_pose(5).x > 0,"Six-straight hints every die together")
	pool.locked = [4,5]; pool.committed = [4,5]; idle.advance(0.95,pool,true,false)
	check(idle.groups == [[0,1,2,3]] and idle.hint_pose(4) == Vector2.ZERO,"Hint cache refreshes after dice are spent")
	pool.selected = [0]; idle.advance(0.1,pool,true,false)
	check(idle.hint_pose(0) == Vector2.ZERO,"Selecting a die still suppresses hints")
	pool.values = [1,1,2,3,5,6]; pool.locked.clear(); pool.committed.clear(); idle.advance(0.1,pool,true,false)
	check(idle.ring_indices == [0,2,3],"Ring cache updates when selected faces change")
	pool.selected.clear(); idle.advance(0.1,pool,true,false)
	check(idle.ring_indices == [0,1,2,3],"Deselection restores alternative physical dice rings")
	idle.advance(0.1,pool,false,false)
	check(idle.ring_indices.is_empty(),"No stale rings remain during rolls or menus")

## Real roll feedback pauses under menus and resets without touching gameplay state.
func scene_checks() -> void:
	root.content_scale_size = Vector2i(804,1748); root.size = Vector2i(402,874)
	var g = Portrait.new(); root.add_child(g)
	g.muted = true; g.speed = 2; g.set_process_input(false)
	for enemy in g.model.enemies: enemy.hp = 100000; enemy.max_hp = 100000
	g.debug_choice = 12; g._roll()
	var deadline := Time.get_ticks_msec()+6000
	while g.dice.any(func(d): return d.rolling) and Time.get_ticks_msec() < deadline: await process_frame
	var revealed_at: int = Time.get_ticks_msec()
	await create_timer(0.20).timeout
	check(g.dice.all(func(d): return not d.auto_attack_active) and g.model.enemies[0].hp == 100000,"Revealed dice remain readable before any automatic shot, even at 2x")
	g.menu_open = true
	await create_timer(0.20).timeout
	check(g.dice.all(func(d): return not d.auto_attack_active),"Menus pause the post-reveal delay")
	g.menu_open = false
	while not g.dice[0].auto_attack_active and Time.get_ticks_msec() < deadline: await process_frame
	check(Time.get_ticks_msec()-revealed_at >= 680,"The half-second reveal delay excludes time spent in menus")
	check(g.dice.all(func(d): return d.auto_attack_active),"A matching group glows together when automatic attacks begin")
	await create_timer(0.06).timeout
	check(g.dice[0].auto_attack_bounce() > 0,"Firing dice visibly lift and enlarge")
	check(g.dice[0].position == g.dice[0].resting,"Bounce does not move the interaction hitbox")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame; RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://test-output/auto-match-bounce.png")
	g.menu_open = true; await process_frame
	var pulse: float = g.dice[0].auto_attack_pulse
	await create_timer(0.12).timeout
	check(g.dice[0].auto_attack_pulse == pulse,"Menus pause automatic dice animation")
	g.menu_open = false; g.reduced = true; await process_frame; await process_frame
	check(g.dice[0].auto_attack_bounce() == 0 and g.dice[0].auto_attack_active,"Reduced effects retain glow without bounce")
	g._restart(); await process_frame
	check(g.dice.all(func(d): return not d.auto_attack_active and d.auto_attack_pulse == 0),"Restart clears all automatic feedback")
	g.queue_free(); await process_frame

func run() -> void:
	hint_checks(); await scene_checks()
	print("Automatic dice feedback: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
