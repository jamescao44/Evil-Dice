extends SceneTree
## Rare matching rolls: numerical tuning, one-beam pulses, borrowed dice and safe cleanup.
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
class TimedBattle extends Battle:
	var damage_times: Array = []
	func _show_events(events: Array) -> void:
		for event in events:
			if event.type == "damage" and event.target == 0: damage_times.append(Time.get_ticks_usec())
		super._show_events(events)
class TimedPortrait extends Portrait:
	var damage_times: Array = []
	func _show_events(events: Array) -> void:
		for event in events:
			if event.type == "damage" and event.target == 0: damage_times.append(Time.get_ticks_usec())
		super._show_events(events)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func fresh():
	var m = Run.new(728)
	m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
	for enemy in m.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	m.begin_round()
	return m
func resolve(m) -> Array:
	var result: Array = []
	for i in range(20):
		if m.roll_attacks.is_empty(): break
		result.append_array(m.resolve_roll_attack_step())
	check(m.roll_attacks.is_empty(),"Automatic queue always terminates")
	return result.filter(func(e): return e.type == "damage")
func rules() -> void:
	for count in range(2,7):
		for face in range(1,7):
			var m = fresh()
			var values: Array = []; values.resize(count); values.fill(face)
			var skill = m.Patterns.automatic_groups(values,range(count))[0].skill
			var factor: float = (0.5+0.05*face)*(8 if count == 6 else 4 if count == 5 else 1)
			check(is_equal_approx(m.attack_base(skill),5*factor),"Face and group-size coefficients compose before rounding")
			check(skill.hits_all() == (count == 6),"Only six alike attacks all enemies")
			m.acquire_relic("twin_scythes")
			check(m.skill_use_count(skill) == count,"Matching attacks remain immune to combo extra-hit relics")
	var m = fresh()
	m.tarot_effects.strength = 2; m.tarot_effects.extra_uses = 4
	m.roll_pool(false,[4,4,4,4,4,1])
	var hits := resolve(m)
	check(hits.size() == 5 and hits.all(func(e): return e.display_amount == 14),"Five fours fire five quadrupled random hits")
	check(m.enemies.reduce(func(total,e): return total+100000-e.hp,0) == 70,"Five alike damage is not applied to all enemies")
	check(m.tarot_effects.strength == 2 and m.tarot_effects.extra_uses == 4,"Rare auto attacks preserve next-skill tarot")
	check(m.dice_turn.locked.is_empty() and m.dice_turn.rolls_left == 2,"Ritual attacks spend neither dice nor an extra roll")
	m = fresh(); m.roll_pool(false,[6,6,6,6,6,6]); hits = resolve(m)
	check(hits.size() == 18 and hits.all(func(e): return e.display_amount == 32),"Six sixes apply six eightfold pulses to every enemy")
	check(m.enemies.all(func(e): return e.hp == 99808),"Each enemy takes exactly 192 at level one")
	m = fresh(); m.enemies[0] = m.make_enemy(3); m.enemies[0].shield = 0
	m.roll_pool(false,[2,2,2,2,2,2]); hits = resolve(m)
	check(hits.filter(func(e): return e.target == 0).all(func(e): return e.display_amount == 24),"Six alike deals full damage to Paladin")
	check(hits.filter(func(e): return e.target != 0).all(func(e): return e.display_amount == 12),"Six alike follows existing area protection")
	for count in [5,6]:
		m = fresh()
		for enemy in m.enemies: enemy.hp = 1
		m.roll_pool(false,[6,6,6,6,6,6] if count == 6 else [6,6,6,6,6,1]); hits = resolve(m)
		check(hits.size() == 3 and hits.all(func(e): return not e.get("corpse_hit",false)),"Rare attacks stop when no living enemies remain")
		check(m.phase == "finished","Early rare attack clear cannot strand the turn")

func until(predicate: Callable, seconds: float = 15.0) -> bool:
	var deadline: int = Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/rare-match-"+name+".png")

## Exercise both screen sizes, modal pause, early victory, restart and reduced effects.
func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	for count in [5,6]:
		g.model = fresh()
		# Keep original model signals: replace only the combat state for this isolated render.
		g.model.roll_pool(false,[6,6,6,6,6,6] if count == 6 else [4,4,4,4,4,1])
		for i in range(6): g.dice[i].face = g.model.dice_turn.values[i]
		g.view_phase = "rolling"
		var original: Array = g.dice.map(func(d): return {"p":d.position,"s":d.scale,"z":d.z_index})
		g._resolve_roll_triggers(g.run_id)
		var r = g.match_ritual
		check(await until(func(): return r.phase == "rise"),"Matching dice form a linked polygon before traveling")
		check(g.dice[0].scale.is_equal_approx(original[0].s*0.35),"Gathered dice retain the additional 30% reduction")
		await capture("%d-%s-rise" % [count,str(phone)])
		g.menu_open = true
		var positions: Array = g.dice.map(func(d): return d.position)
		var age: float = r.age
		for i in range(6): await process_frame
		check(g.dice.map(func(d): return d.position) == positions and is_equal_approx(r.age,age),"Pause freezes ring, dice and particles")
		check(not r.visible,"Ritual never draws above a modal menu")
		g.menu_open = false
		check(await until(func(): return r.phase == "charge"),"Polygon moves beside player before charging")
		check(r.center.x > g._player_point().x and g.ARENA.has_point(r.center),"Casting ring sits right of the character in the battlefield")
		check(g.dice[0].scale.distance_to(original[0].s*0.224) < original[0].s.length()*0.01,"Casting dice retain the additional 30% reduction")
		await capture("%d-%s-charge" % [count,str(phone)])
		check(await until(func(): return r.phase == "fire" and r.shots_fired >= 1),"Laser first impact resolves during the sustained beam")
		await capture("%d-%s-beam" % [count,str(phone)])
		if count == 6:
			check(await until(func(): return r.phase == "hold"),"Six alike waits after firing")
			var hold_started: int = Time.get_ticks_msec()
			check(await until(func(): return r.phase == "return"),"Six alike eventually returns its dice")
			check(Time.get_ticks_msec()-hold_started >= 930,"Post-beam hold remains one real second even at 2x")
		check(await until(func(): return not r.active),"Every borrowed die settles after the attack")
		check(r.shots_fired == count,"Visual commits exactly five or six pulses")
		for i in range(6):
			check(g.dice[i].position.is_equal_approx(original[i].p) and g.dice[i].scale.is_equal_approx(original[i].s) and g.dice[i].z_index == original[i].z,"Dice transform and layer restored without duplicates")
		check(g.model.phase == "roll" and g.model.dice_turn.can_roll(),"Dice can be rerolled immediately after the ritual")
		check(r.particles.is_empty() and r.beam_targets.is_empty(),"No orphan beam or particles remain")
	# Cancel during travel, before the first damage event.
	g.model = fresh(); g.model.roll_pool(false,[3,3,3,3,3,3]); g.view_phase = "rolling"
	g._resolve_roll_triggers(g.run_id)
	check(await until(func(): return g.match_ritual.phase == "travel"),"Restart fixture reaches aerial travel")
	g._restart()
	for i in range(6): await process_frame
	check(not g.match_ritual.active and g.dice.all(func(d): return d.position.is_equal_approx(d.resting)),"Restart restores borrowed dice and cancels stale coroutine")
	g.reduced = true
	g.model = fresh(); g.model.roll_pool(false,[6,6,6,6,6,6]); g.view_phase = "rolling"
	g._resolve_roll_triggers(g.run_id)
	check(await until(func(): return not g.match_ritual.active),"Reduced-effects ritual completes")
	check(g.match_ritual.shots_fired == 6,"Reduced effects preserves all six area damage pulses")
	g.queue_free(); await process_frame

func run() -> void:
	rules()
	await scene(false)
	await scene(true)
	await straight_timing(false)
	await straight_timing(true)
	print("Rare matches: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

## Measure actual hit spacing and visual lifetime through the casting coroutine, including 2x.
func straight_timing(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = TimedPortrait.new() if phone else TimedBattle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	for length in [5,6]:
		for rate in [1.0,2.0]:
			g.model = fresh(); g.speed = rate
			g.damage_times.clear()
			g.model.pending = g.model.Patterns.classify(range(1,length+1))
			g.model.phase = "player"
			g._show_pending_skill(false)
			g._activate_skill(0)
			var hits: Array = []
			var hp: int = g.model.enemies[0].hp
			var deadline: int = Time.get_ticks_msec()+12000
			while Time.get_ticks_msec() < deadline:
				await process_frame
				if g.model.enemies[0].hp < hp:
					hits.append(Time.get_ticks_usec())
					hp = g.model.enemies[0].hp
					check(not g.fx.spell.is_empty(),"Every straight damage tick retains the same active spell visual")
					if hits.size() == 3:
						await capture("straight-%d-speed-%s-%s" % [length,str(rate),str(phone)])
				if g.view_phase != "resolving": break
			check(hits.size() == (5 if length == 5 else 10),"Longer straight casts preserve exactly five or ten damage ticks")
			for i in range(1,g.damage_times.size()):
				check(g.damage_times[i]-g.damage_times[i-1] >= 100000,"Straight damage stays at least 100 ms apart on the real clock, even at 2x")
			check(g.model.pending.is_empty() and not g.fx.spell.get("hold_damage",false),"Sustained spell releases its visual hold and completes the cast")
	g.queue_free(); await process_frame
