extends SceneTree
## Verify the supplied atlas, shared formation coverage, real hit cadence and frontmost labels.
const Beam = preload("res://scripts/effects/brimstone.gd")
const Effects = preload("res://scripts/effects/effects.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
class HeardBattle extends Battle:
	var impact_times: Array = []
	func _sound(clip: String, _pitch: float = 1.0, _volume: float = -15.0) -> void:
		if clip == "player/hit": impact_times.append(fx.flame_state().get("age",-1.0))
class HeardPortrait extends Portrait:
	var impact_times: Array = []
	func _sound(clip: String, _pitch: float = 1.0, _volume: float = -15.0) -> void:
		if clip == "player/hit": impact_times.append(fx.flame_state().get("age",-1.0))
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Check the complete sheet and formation geometry without touching player saves.
func timeline() -> void:
	check(Beam.SHEET.get_size() == Vector2(40*64,64),"Updated sheet has forty intact 64px cells")
	check(Beam.OPACITY == 0.7,"Authored pillar is thirty percent transparent")
	check(is_equal_approx(Beam.LOOP_FPS,20.8) and Beam.LOOP_REPEATS == 4,"Damage loop is thirty percent faster and plays four times")
	check(Beam.GLOW_SCALE == 2,"Golden halo has double its previous spread")
	var fx = Effects.new()
	fx.set_process(false)
	var targets := [Vector2(360,260),Vector2(580,320)]
	var feet := [Vector2(360,350),Vector2(580,410)]
	var bars := [Vector2(360,388),Vector2(580,448)]
	fx.flame_cast(4,Vector2.ZERO,targets,1.0,[20,200],feet,bars)
	fx.spell.hold_damage = true
	var original: Dictionary = fx.spell.duplicate(true)
	var anchor: Vector2 = fx.projected_spell(fx.spell).brimstone_anchor
	check(anchor == Vector2(470,448+Beam.FLOOR_PADDING),"Beam base sits just below the lowest ground health bar")
	check(Beam.visual_alpha(fx.spell.brimstone) == 0,"Circle starts fully faded out")
	var small: Rect2 = Beam.visual_rect(fx.projected_spell(fx.spell))
	fx.spell.brimstone.age = Beam.EXPAND_DURATION
	var full: Rect2 = Beam.visual_rect(fx.projected_spell(fx.spell))
	check(full.size.is_equal_approx(Vector2.ONE*Beam.LANDSCAPE_SIDE*0.7),"Brimstone scales width and height together to seventy percent")
	check(Beam.FLOOR_PADDING == 40.0,"Brimstone is anchored twenty-four pixels lower")
	check(is_equal_approx(small.size.x/full.size.x,0.15) and Beam.visual_alpha(fx.spell.brimstone) == 1,"Circle fades in and expands to full size over fourteen frames")
	check(is_equal_approx(full.position.y+full.size.y*Beam.GROUND_PIXEL,anchor.y),"Circle expansion keeps its ground contact fixed")
	fx.flame_cast(4,Vector2.ZERO,[Vector2(470,100)],1.0,[999999],[Vector2(470,448)],[bars[1]])
	fx.spell.brimstone.age = Beam.EXPAND_DURATION
	check(Beam.visual_rect(fx.projected_spell(fx.spell)).size == full.size,"A giant single enemy and extreme damage cannot change the fixed size")
	fx.spell = original
	fx.world_transform = Transform2D(0,Vector2(12,28)).scaled(Vector2.ONE*1.2)
	fx.spell.brimstone.age = Beam.EXPAND_DURATION
	check(Beam.visual_rect(fx.projected_spell(fx.spell)).size == full.size,"Camera zoom moves the anchor without changing the fixed size")
	for i in range(24):
		fx.spell.brimstone.age = Beam.BUILD_DURATION*(i+0.1)/24
		check(Beam.frame(fx.spell) == i,"Buildup reads all twenty-four frames")
	check(fx.flame_loop_shake() == Vector2.ZERO,"No beam rumble during buildup")
	fx._process(0.16)
	check(not fx.spell.brimstone.emitter.packets.is_empty(),"Golden particles already rise across the base during buildup")
	check(fx.spell.brimstone.emitter.kind == "beam" and fx.spell.brimstone.emitter.packets.size() <= Beam.Emitter.MAX_PACKETS,"Sparks rise from the damaging beam's full width")
	fx.begin_flame_damage()
	for i in range(32):
		fx.spell.brimstone.age = (i+0.1)/Beam.LOOP_FPS
		check(Beam.frame(fx.spell) == 24+i%8,"Four loops use frames twenty-five through thirty-two")
	fx.spell.brimstone.age = 5
	check(Beam.frame(fx.spell) == 31,"Late combat holds the final frame instead of adding a loop")
	fx.spell.brimstone.age = 0.3
	var beam_shake: float = fx.flame_loop_shake().length()
	check(beam_shake > 2 and beam_shake < 6.4,"Brimstone rumble is strong but bounded")
	var crossings := 0
	var previous_x := 0.0
	for i in range(100):
		fx.spell.brimstone.age = 0.1+i*0.01
		var x: float = fx.flame_loop_shake().x
		if x*previous_x < 0: crossings += 1
		previous_x = x
	check(crossings >= 10 and crossings <= 13,"Shake makes about six readable cycles per second")
	fx.spell.brimstone.age = 0.3
	fx.reduced = true
	check(fx.flame_loop_shake() == Vector2.ZERO,"Reduced effects suppresses continuous rumble")
	fx.reduced = false; fx.time_factor = 0; fx._process(1)
	check(fx.spell.brimstone.age == 0.3 and fx.flame_loop_shake() == Vector2.ZERO,"Pauses hold frames and suppress shake")
	fx.time_factor = 0.1; fx._process(0.2)
	check(is_equal_approx(fx.spell.brimstone.age,0.32),"Kill slow motion slows the beam clock")
	fx.finish_flame_damage()
	check(fx.spell.is_empty() and fx.finishing_spells.size() == 1,"Fade survives independently after damage finishes")
	for i in range(8):
		fx.finishing_spells[0].brimstone.age = (i+0.1)/Beam.FADE_FPS
		check(Beam.frame(fx.finishing_spells[0]) == 32+i,"All eight closing frames each play once")
	fx.finishing_spells[0].brimstone.age = Beam.FADE_DURATION*0.5
	check(is_equal_approx(Beam.visual_alpha(fx.finishing_spells[0].brimstone),0.5),"Sprite and halo gradually lose opacity during fade frames")
	fx.time_factor = 1; fx._process(1.3)
	check(fx.finishing_spells.is_empty(),"Closing beam fully expires")
	fx.flame_cast(3,Vector2.ZERO,targets,1)
	fx.begin_flame_damage(); fx.spell.storm.age = 0.3
	check(fx.flame_loop_shake().length() < beam_shake*0.4,"Fire Storm rumble is much lighter")
	fx.free()

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame; RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/brimstone-"+label+".png")

## Run the real cast against several enemies, including a first-tick wipe.
func scene(phone: bool, wipe: bool = false) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = HeardPortrait.new() if phone else HeardBattle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1),g.model.make_enemy(2)]
	for e in g.model.enemies:
		e.hp = 1 if wipe else 1000; e.max_hp = e.hp; e.shield = 0
	g.model.roll_pool(false,[1,2,3,4,5,6])
	g.model.dice_turn.selected = [0,1,2,3,4,5]; g.model.form_selected_skill()
	g._show_pending_skill(false); g._activate_skill(0)
	var hp: int = g.model.enemies[0].hp
	var hits := 0
	var saw_build := false; var saw_fade := false; var saw_small := false; var saw_late_fade := false
	var final_age := 0.0
	var deadline: int = Time.get_ticks_msec()+12000
	var prefix: String = ("portrait" if phone else "landscape")+("-wipe" if wipe else "")
	while Time.get_ticks_msec() < deadline:
		if g.fx.spell.has("brimstone"):
			var state: Dictionary = g.fx.spell.brimstone
			if state.phase == "loop": final_age = state.age
			if state.phase == "build" and state.age > Beam.EXPAND_DURATION*0.35 and not saw_small:
				saw_small = true; await capture(prefix+"-small")
			if state.phase == "build" and state.age > Beam.BUILD_DURATION*0.65 and not saw_build:
				saw_build = true; await capture(prefix+"-build")
		if g.model.enemies[0].hp < hp:
			hits += 1; hp = g.model.enemies[0].hp
			if hits == 4: await capture(prefix+"-loop")
		if not g.fx.finishing_spells.is_empty() and not saw_fade:
			saw_fade = true; await capture(prefix+"-fade")
		if not g.fx.finishing_spells.is_empty() and g.fx.finishing_spells[0].brimstone.age > Beam.FADE_DURATION*0.6 and not saw_late_fade:
			saw_late_fade = true; await capture(prefix+"-late-fade")
		if saw_fade and g.fx.spell.is_empty() and g.fx.finishing_spells.is_empty(): break
		await process_frame
	check(saw_build and saw_fade,"Real Brimstone has complete buildup and fade")
	check(hits == (1 if wipe else 10),"Ten damage ticks are preserved and stop after a wipe")
	check(g.impact_times.size() == hits,"Multiple enemies share one impact sound per tick")
	check(final_age >= Beam.LOOP_DURATION-0.05 and final_age < Beam.LOOP_DURATION+0.15,"The beam completes four loops even on a wipe")
	if not wipe:
		for tick in range(10): check(absf(g.impact_times[tick]-Beam.damage_tick_time(tick,10)) < 0.08,"Ten hits spread across all four authored loops")
	check(g.fx.damage_layer.layer > g.screen_ripple.layer,"Damage text renders above the ultimate ripple")
	g.menu_open = true; await process_frame; await process_frame
	check(not g.fx.damage_layer.visible,"Damage text hides behind menus along with other combat FX")
	g.queue_free(); await process_frame

func run() -> void:
	timeline()
	await scene(false); await scene(true); await scene(true,true)
	print("Brimstone visual: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
