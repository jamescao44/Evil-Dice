extends SceneTree
## Verify that the authored sixth frame, area damage and shared impact sound coincide.
const Slash = preload("res://scripts/effects/fiery_slash.gd")
const Effects = preload("res://scripts/effects/effects.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
class HeardBattle extends Battle:
	var impacts: Array = []
	var impact_sounds: Array = []
	func _sound(clip: String, _pitch: float = 1.0, _volume: float = -15.0) -> void:
		if clip == "player/hit" and fx.spell.has("fiery_slash"): impact_sounds.append(Effects.FierySlash.frame(fx.spell))
	func _show_events(events: Array) -> void:
		for e in events:
			if e.type == "damage" and e.target >= 0 and fx.spell.has("fiery_slash"):
				impacts.append({"target":e.target,"frame":Effects.FierySlash.frame(fx.spell)})
		super._show_events(events)
class HeardPortrait extends Portrait:
	var impacts: Array = []
	var impact_sounds: Array = []
	func _sound(clip: String, _pitch: float = 1.0, _volume: float = -15.0) -> void:
		if clip == "player/hit" and fx.spell.has("fiery_slash"): impact_sounds.append(Effects.FierySlash.frame(fx.spell))
	func _show_events(events: Array) -> void:
		for e in events:
			if e.type == "damage" and e.target >= 0 and fx.spell.has("fiery_slash"):
				impacts.append({"target":e.target,"frame":Effects.FierySlash.frame(fx.spell)})
		super._show_events(events)
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Delayed impact, slow motion, pauses and a following spell preserve all ten cells.
func timeline() -> void:
	check(Slash.SHEET.get_size() == Vector2(320,32),"Source preserves ten 32px cells")
	var fx = Effects.new()
	fx.set_process(false)
	fx.flame_cast(2,Vector2.ZERO,[Vector2(300,300)],Slash.CAST_DURATION)
	check(is_equal_approx(fx.spell.fiery_slash.build_duration,5.0/18.0),"Windup and first-hit timing remain unchanged")
	check(is_equal_approx(fx.spell.fiery_slash.damage_fps,18.0*0.7),"Damaging follow-through runs at seventy percent speed")
	fx.spell.hold_damage = true
	for i in range(5):
		fx.spell.fiery_slash.age = (i+0.1)/Slash.FPS
		check(Slash.frame(fx.spell) == i,"Windup reads each of the first five frames")
	fx._process(1)
	check(Slash.frame(fx.spell) == 4,"Delayed combat cannot advance beyond frame five")
	fx.begin_flame_damage()
	check(Slash.frame(fx.spell) == 5,"Damage starts on authored frame six")
	fx.finish_flame_damage()
	check(fx.spell.is_empty() and fx.finishing_spells.size() == 1,"Slash ending survives independently of the next cast")
	var tail: Dictionary = fx.finishing_spells[0]
	for i in range(5):
		tail.fiery_slash.age = (i+0.1)/(Slash.FPS*Slash.DAMAGE_SPEED)
		check(Slash.frame(tail) == i+5,"Recovery plays every remaining frame in order")
	tail.fiery_slash.age = 0
	fx.time_factor = 0; fx._process(1)
	check(tail.fiery_slash.age == 0,"Menus pause the ending")
	fx.time_factor = 0.1; fx._process(0.2)
	check(is_equal_approx(tail.fiery_slash.age,0.02),"Kill slow motion also slows the slash frames")
	fx.flame_cast(1,Vector2.ZERO,[Vector2(300,300)],0.46)
	check(fx.finishing_spells.size() == 1,"Next Fireball does not erase the slash tail")
	fx.time_factor = 1; fx._process(1)
	check(fx.finishing_spells.is_empty(),"Last frame expires without a stuck glow")
	fx.free()

## Render the actual cast optionally, with damage above the clipped orange slash.
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/fiery-slash-"+label+".png")

## All enemies take one hit on frame six at both speeds, including reduced effects.
func scene(phone: bool, fast: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = HeardPortrait.new() if phone else HeardBattle.new()
	root.add_child(g); g.muted = true; g.speed = 2 if fast else 1; g.reduced = fast; g.set_process_input(false)
	g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1),g.model.make_enemy(2)]
	for e in g.model.enemies: e.hp = 1000; e.max_hp = 1000; e.shield = 0
	g.model.roll_pool(false,[1,2,3,4,5,6])
	g.model.dice_turn.selected = [0,1,2,3]; g.model.form_selected_skill()
	g._show_pending_skill(false); g._activate_skill(0)
	var saw_windup := false
	var captured := false
	var deadline: int = Time.get_ticks_msec()+6000
	while Time.get_ticks_msec() < deadline:
		if g.fx.spell.has("fiery_slash"):
			saw_windup = true
			check(g.model.enemies.all(func(e): return e.hp == 1000),"Enemies take no premature windup damage")
		if not g.fx.finishing_spells.is_empty() and not captured:
			captured = true
			capture(("portrait" if phone else "landscape")+("-fast" if fast else ""))
		if captured and g.fx.finishing_spells.is_empty() and g.view_phase == "ready": break
		await process_frame
	check(saw_windup and captured,"Real cast includes authored windup and recovery")
	check(g.impacts.size() == 3 and g.impacts.all(func(hit): return hit.frame == 5),"All three targets are damaged exactly once on frame six")
	check(g.impact_sounds == [5],"Area impact plays one shared hit sound on frame six")
	check(g.fx.spell.is_empty() and g.fx.finishing_spells.is_empty(),"Real cast completes and cleans up its FX")
	g._restart(); g.queue_free(); await process_frame

func run() -> void:
	timeline()
	await scene(false,false); await scene(true,false)
	await scene(false,true); await scene(true,true)
	print("Fiery Slash visual: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
