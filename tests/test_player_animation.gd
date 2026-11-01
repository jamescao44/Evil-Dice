extends SceneTree
## Authored atlas mapping, exact launch cues and real combat/effect synchronization.
const ActorAnimation = preload("res://scripts/player/player_animation.gd")
const Sprite = preload("res://scripts/player/player_sprite.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Home = preload("res://scripts/home/home.gd")
class SeenBattle extends Battle:
	var launches: Array = []
	var impacts: Array = []
	func _sound(clip: String, _pitch: float = 1, _volume: float = -15) -> void:
		if clip == "player/slash": launches.append({"frame":player_animation.frame_number(),"action":player_animation.action})
	func _show_events(events: Array) -> void:
		for event in events:
			if event.type == "damage" and event.target >= 0: impacts.append({"frame":player_animation.frame_number(),"action":player_animation.action,"phase":player_animation.phase})
		super._show_events(events)
class SeenPortrait extends Portrait:
	var launches: Array = []
	var impacts: Array = []
	func _sound(clip: String, _pitch: float = 1, _volume: float = -15) -> void:
		if clip == "player/slash": launches.append({"frame":player_animation.frame_number(),"action":player_animation.action})
	func _show_events(events: Array) -> void:
		for event in events:
			if event.type == "damage" and event.target >= 0: impacts.append({"frame":player_animation.frame_number(),"action":player_animation.action,"phase":player_animation.phase})
		super._show_events(events)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")

## Verify row wrapping and every declared frame without letting trailing empty cells play.
func timeline() -> void:
	check(Sprite.SHEET.get_size() == Vector2(1280,384),"Original twenty-column sheet is intact")
	check(Sprite.region(20) == Rect2(1216,0,64,64) and Sprite.region(21) == Rect2(0,64,64,64),"Frames wrap left-to-right into the next row")
	check(Sprite.region(109) == Rect2(512,320,64,64),"Last animation excludes eleven blank atlas cells")
	check(frame_empty(32),"Updated sheet retains the empty frame 32 placeholder")
	var a = ActorAnimation.new()
	for i in range(7): check(Sprite.idle_frame(i/10.0+0.001) == i+1,"Idle traverses frames one through seven")
	a.advance(0.1,true); check(a.frame_number() >= 14 and a.frame_number() <= 22,"Walking is separate from idle")
	for speed in [1.0,2.0]:
		for name in ActorAnimation.CLIPS:
			var clip: Dictionary = ActorAnimation.CLIPS[name]
			a.begin(name,speed)
			check(a.frame_number() == clip.first,"Cast begins on its declared first frame")
			a.advance((clip.launch-clip.first)/(ActorAnimation.FPS*speed)+0.00001)
			check(a.ready(),"Launch is ready at both game speeds")
			a.launch(0.6)
			check(a.frame_number() == clip.launch,"FX launch begins on the specified actor cue")
			a.damage()
			check(a.frame_number() == clip.impact,"First hit enters its damage frame")
			if clip.has("loop_end"):
				for tick in range(40):
					a.advance(0.083)
					check(a.frame_number() >= clip.impact and a.frame_number() <= clip.loop_end,"Sustained damage remains within the supplied loop")
			a.finish(); a.advance(1)
			check(a.action.is_empty(),"All recoveries return to idle")
	a.begin("ultimate"); a.advance(4)
	check(a.frame_number() in range(78,92),"Lengthy preparation repeats only channel frames 78-91")
	a.launch(1.2); a.advance(1.1)
	check(a.frame_number() in range(92,97),"Channel releases into frames 92-96 before the first hit")
	var state := {"age":0.0,"phase":"loop"}
	a.launch(1.2,state); a.damage(); state.age = 0.25
	check(a.frame_number() == 102,"Authored FX clock drives the exact damage-loop frame")
	a.reset(); check(a.action.is_empty() and a.frame_number() == 1,"Restart clears interrupted poses")
	for phase_name in ["windup","build","damage","recover"]:
		a.begin("fireball"); a.phase = phase_name; a.build_duration = 0.3
		for i in range(100):
			a.age = i*0.01
			check(a.frame_number() in range(23,32),"Fireball never samples blank frame 32")
	a.begin("slash"); a.damage(); a.advance(1.01/(ActorAnimation.FPS*0.7))
	check(a.frame_number() == 51,"Slash actor slows only its damage and recovery frames")
	a.finish(); a.advance(5.0/ActorAnimation.FPS)
	check(not a.action.is_empty(),"Slower Slash recovery outlasts the old thirty-FPS ending")
	a.advance(0.1); check(a.action.is_empty(),"Slower Slash still returns to idle")

## Check the reserved blank cell without changing the uploaded asset or atlas indexing.
func frame_empty(frame_number: int) -> bool:
	return Sprite.SHEET.get_image().get_region(Rect2i(Sprite.region(frame_number))).get_used_rect().size == Vector2i.ZERO

## Capture real battlefield output; nothing writes campaign or player save files.
func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.arena_actors.queue_redraw()
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/diablo-"+label+".png")

## Exercise skills and matching attacks through the production coroutines in both layouts.
func scene(phone: bool, length: int, matching: bool = false) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = SeenPortrait.new() if phone else SeenBattle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1),g.model.make_enemy(2)]
	for e in g.model.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
	for form in range(3): check(g.evolution.forms[form].atlas == Sprite.SHEET,"Every evolution shares the supplied atlas")
	var anchor: Vector2 = g._character_counter_center()
	g.player_animation.advance(0.35)
	check(g._character_counter_center() == anchor,"Animated cells never move fixed status/counter anchors")
	var prefix: String = ("portrait" if phone else "landscape")+("-match-" if matching else "-skill-")+str(length)
	var values: Array = [1,2,3,4,5,6]
	if matching:
		values = [2,2,3,4,5,6] if length == 2 else [2,2,2,4,5,6] if length == 3 else [2,2,2,2,5,6] if length == 4 else [2,2,2,2,2,6] if length == 5 else [2,2,2,2,2,2]
	g.model.roll_pool(false,values)
	if matching:
		g.view_phase = "rolling"; g._resolve_roll_triggers(g.run_id)
	else:
		g.model.dice_turn.selected = range(length); g.model.form_selected_skill()
		g._show_pending_skill(false); g._activate_skill(0)
	var deadline: int = Time.get_ticks_msec()+15000
	var saw: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		var a = g.player_animation
		if not a.action.is_empty():
			var tag: String = a.phase
			if not saw.has(tag):
				saw[tag] = true
				if tag in ["build","damage"]: capture(g,prefix+"-"+tag)
		if not g.impacts.is_empty() and a.action.is_empty() and (g.model.roll_attacks.is_empty() if matching else g.view_phase == "ready"): break
		await process_frame
	check(Time.get_ticks_msec() < deadline,"Attack and actor recovery finish without deadlock")
	check(saw.has("windup") and saw.has("build"),"Authored preparation and effect launch both play")
	check(not g.impacts.is_empty(),"Real attack commits damage")
	if not matching and length == 4:
		check(g.launches[0].frame == 45,"Fiery Slash spawns exactly on actor frame 45")
		check(g.impacts[0].frame == 50,"Slash frame-six impact matches the actor follow-through")
	if length >= 5:
		var low: int = 97 if matching or length == 6 else 59
		var high: int = 104 if low == 97 else 66
		check(g.impacts.all(func(hit): return hit.frame >= low and hit.frame <= high),"All damage pulses stay inside the damaging animation loop")
	if matching and length <= 4:
		check(g.launches[0].action == ("pair" if length == 2 else "fireball" if length == 3 else "storm"),"Each matching tier uses its requested clip")
	# Menu and freeze hold the exact pose; advance uses walk instead of a generic bob.
	g.player_animation.reset(); g.view_phase = "transition"
	await process_frame; await process_frame
	check(g.player_animation.frame_number() in range(14,23),"Advancing plays walking cells")
	capture(g,prefix+"-walk")
	g.menu_open = true
	var before: float = g.player_animation.idle_age
	await create_timer(0.08).timeout
	check(g.player_animation.idle_age == before,"Menus freeze animation clocks")
	g.menu_open = false; g.model.statuses[g.Status.FROZEN].apply(1)
	await create_timer(0.08).timeout
	check(g.player_animation.idle_age == before,"Frozen characters do not animate")
	g._restart(); check(g.player_animation.action.is_empty(),"Restart clears any active character cast")
	g.queue_free(); await process_frame

func run() -> void:
	timeline()
	for phone in [false,true]:
		for length in range(3,7): await scene(phone,length)
	for length in range(2,7): await scene(true,length,true)
	var home = Home.new(); home.campaign_path = ""; root.add_child(home)
	check(home.art.flameling.atlas == Sprite.SHEET,"Home uses a frame rather than the whole spritesheet")
	home.queue_free(); await process_frame
	print("Diablo player: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
