extends SceneTree
## Verify sprite phases against real damage, plus independent loops and bounded emissions.
const Storm = preload("res://scripts/effects/fire_storm.gd")
const Effects = preload("res://scripts/effects/effects.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
class HeardBattle extends Battle:
	var impact_times: Array = []
	func _sound(clip: String, _pitch: float = 1.0, _volume: float = -15.0) -> void:
		if clip == "player/hit": impact_times.append(fx.spell.get("storm",{}).get("age",-1.0))
class HeardPortrait extends Portrait:
	var impact_times: Array = []
	func _sound(clip: String, _pitch: float = 1.0, _volume: float = -15.0) -> void:
		if clip == "player/hit": impact_times.append(fx.spell.get("storm",{}).get("age",-1.0))
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Long holds and overlapping spell endings must not freeze, leak, or truncate the sheet.
func timeline() -> void:
	check(Storm.SHEET.get_size() == Vector2(18*64,64),"Source contains eighteen intact 64px cells")
	var fx = Effects.new()
	fx.cosmetic.seed = 512
	fx.set_process(false)
	var targets: Array = [Vector2(300,300),Vector2(500,300),Vector2(700,300)]
	fx.flame_cast(3,Vector2.ZERO,targets,1.14)
	fx.spell.hold_damage = true
	check(Storm.frame(fx.spell,0) == 0,"Buildup starts at authored frame one")
	for i in range(7):
		fx.spell.storm.age = fx.spell.storm.build_duration*(i+0.1)/7
		check(Storm.frame(fx.spell,0) == i,"Buildup reads every frame in order")
	fx._process(1)
	check(Storm.frame(fx.spell,0) == 6 and fx.spell.storm.emitters[0].packets.is_empty(),"Buildup waits for combat without emitting loop particles")
	fx.begin_flame_damage()
	var first_frames: Array = range(3).map(func(i): return Storm.frame(fx.spell,i))
	check(first_frames[0] != first_frames[1] and first_frames[1] != first_frames[2] and first_frames[0] != first_frames[2],"Nearby storms use different randomized loop offsets")
	for step in range(24):
		fx.spell.storm.age = (step+0.1)/18
		check(Storm.frame(fx.spell,0) == 7+(first_frames[0]-7+step)%6,"Exactly four cycles traverse all six authored loop frames")
	for i in range(240): fx._process(1.0/60)
	check(fx.spell.storm.phase == "loop" and Storm.frame(fx.spell,0) == 7+(first_frames[0]-7+23)%6,"A delayed final tick holds the last frame instead of adding another cycle")
	check(fx.spell.storm.emitters.all(func(emitter): return emitter.packets.size() >= 2 and emitter.packets.size() <= Storm.Emitter.MAX_PACKETS),"Every storm continuously plays bounded overlapping orange emission packets")
	var age: float = fx.spell.storm.age
	fx.time_factor = 0; fx._process(1)
	check(fx.spell.storm.age == age,"Menus pause both sprite and emission clocks")
	fx.time_factor = 0.1; fx._process(0.2)
	check(is_equal_approx(fx.spell.storm.age-age,0.02),"Kill slow motion slows frames and sparks together")
	fx.time_factor = 1
	fx.finish_flame_damage()
	check(fx.spell.is_empty() and fx.finishing_spells.size() == 1,"Finished damage moves the fade into an independent tail")
	var tail: Dictionary = fx.finishing_spells[0]
	for i in range(5):
		tail.storm.age = (i+0.1)/Storm.FADE_FPS
		check(Storm.frame(tail,0) == 13+i,"Fade reads frames fourteen through eighteen once")
	tail.storm.age = 0
	fx.flame_cast(1,Vector2.ZERO,targets,0.46)
	check(fx.finishing_spells.size() == 1,"Following Fireball does not replace the storm fade")
	for i in range(50): fx._process(0.02)
	check(fx.finishing_spells.is_empty(),"Fade and residual sparks fully expire without more emission")
	fx.flame_cast(3,Vector2.ZERO,targets,1.14); fx.finish_flame_damage(); fx.clear()
	check(fx.finishing_spells.is_empty() and fx.spell.is_empty(),"Restart removes active and fading storms")
	fx.free()

## Optional screenshots exercise the actual renderer in both game layouts.
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/fire-storm-"+label+".png")

## Four visual cycles finish even on a wipe; damage and sound never hit dead targets.
func scene(phone: bool, wipe: bool = false, form: int = 2) -> void:
	var g = HeardPortrait.new() if phone else HeardBattle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	g.model.character_level = [1,5,10][form]; g.evolution.reset()
	g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1),g.model.make_enemy(2)]
	for e in g.model.enemies:
		e.hp = 1 if wipe else 1000; e.max_hp = e.hp; e.shield = 0
	g.model.roll_pool(false,[1,2,3,4,5,6])
	g.model.dice_turn.selected = [0,1,2,3,4]; g.model.form_selected_skill()
	var expected_damage: int = g.model.skill_damage_total(g.model.pending,0)
	g._show_pending_skill(false); g._activate_skill(0)
	var hp: int = g.model.enemies[0].hp
	var hits := 0
	var saw_build := false
	var saw_fade := false
	var saw_sparks := false
	var loop_finished_at := 0.0
	var deadline: int = Time.get_ticks_msec()+10000
	var prefix: String = ("portrait" if phone else "landscape")+"-form-"+str(form)+("-wipe" if wipe else "")
	var duration: float = Effects.AttackStyle.loop_timing(form,Storm.LOOP_FRAMES,Storm.LOOP_FPS,5).loop_duration
	while Time.get_ticks_msec() < deadline:
		if g.fx.spell.has("storm"):
			var state: Dictionary = g.fx.spell.storm
			if state.phase == "loop": loop_finished_at = state.age
			if state.phase == "build" and state.age > state.build_duration*0.65 and not saw_build:
				saw_build = true
				await capture(prefix+"-build")
			saw_sparks = saw_sparks or not state.emitters[0].packets.is_empty()
		if g.model.enemies[0].hp < hp:
			hits += 1; hp = g.model.enemies[0].hp
			if hits < 5 and not wipe: check(g.fx.spell.has("storm") and g.fx.spell.storm.phase == "loop","Live damage pulses keep the storm in its loop")
			if hits == 3: await capture(prefix+"-loop")
		if not g.fx.finishing_spells.is_empty() and not saw_fade:
			saw_fade = true
			await capture(prefix+"-fade")
		if saw_fade and g.fx.spell.is_empty() and g.fx.finishing_spells.is_empty(): break
		await process_frame
	check(saw_build and saw_fade,"Real cast includes both authored buildup and fade")
	check(hits == (1 if wipe else 5),"Visual replacement preserves damage count and stops on dead targets")
	check(g.impact_times.size() == hits,"Three targets still play only one shared impact sound per tick")
	check(loop_finished_at >= duration-0.05 and loop_finished_at < duration+0.1,"All casts complete the form's visual cycles before fading, including a wipe")
	if not wipe:
		for tick in range(5): check(absf(g.impact_times[tick]-duration*tick/4) < 0.08,"Damage sounds land evenly across the form's visual cycles")
		check(1000-g.model.enemies[0].hp == expected_damage,"Shorter early-form visuals retain the full calculated damage")
	if not wipe: check(saw_sparks,"Real sustained damage emits orange particles")
	check(g.fx.finishing_spells.is_empty(),"Real cast leaves no stuck storm tail")
	g.queue_free(); await process_frame

func run() -> void:
	timeline()
	await scene(false)
	await scene(true)
	await scene(true,true)
	for form in [0,1]: await scene(true,false,form)
	print("Fire Storm visual: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _initialize() -> void: call_deferred("run")
