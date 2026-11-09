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
		if clip == "player/slash": launches.append(player_animation.last_launch.duplicate())
	func _show_events(events: Array) -> void:
		for event in events:
			if event.type == "damage" and event.target >= 0: impacts.append({"frame":player_animation.frame_number(),"action":player_animation.action,"phase":player_animation.phase})
		super._show_events(events)
class SeenPortrait extends Portrait:
	var launches: Array = []
	var impacts: Array = []
	func _sound(clip: String, _pitch: float = 1, _volume: float = -15) -> void:
		if clip == "player/slash": launches.append(player_animation.last_launch.duplicate())
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

## Verify frame indexing, one shared cadence and actor-owned release/impact cues.
func timeline() -> void:
	check(Sprite.SHEET.get_size() == Vector2(1280,512),"Final sheet remains intact")
	check(Sprite.EARLY_SHEET.get_size() == Vector2(1280,320),"Early-form sheet remains intact")
	check(Sprite.FIRST_SHEET.get_size() == Vector2(1280,256),"First-form sheet remains intact")
	check(Sprite.texture(2,0).atlas != Sprite.texture(2,1).atlas and Sprite.silhouette(0) != Sprite.silhouette(1),"Atlas and silhouette caches keep the first two forms distinct")
	check(Sprite.region(20) == Rect2(1216,0,64,64) and Sprite.region(21) == Rect2(0,64,64,64),"Atlas frames wrap by row")
	check(ActorAnimation.FPS == Sprite.IDLE_FPS,"All character clips share idle's frame rate")
	var a = ActorAnimation.new()
	a.advance(0,true)
	var walked: Array = []
	for i in range(18):
		walked.append(a.frame_number()); a.advance(0.1,true)
	check(walked == range(12,21)+range(12,21),"Walking plays each frame for 100ms without following eased travel")
	a.reset(); check(not a.walking and a.walk_age == 0,"Restart clears walking state")
	a.set_form(0); a.advance(0,true); walked.clear()
	for i in range(12):
		walked.append(a.frame_number()); a.advance(0.1,true)
	check(walked == range(10,16)+range(10,16),"First form walks through all six new cells in order")
	a.advance(0,false)
	check(a.frame_number() in range(2,10),"First form returns to idle when travel stops")
	a.reset()
	for form in range(3):
		a.set_form(form)
		for name in a.clips():
			var clip: Dictionary = a.clips()[name]
			a.begin(name)
			for frame in range(clip.first,clip.launch):
				check(a.frame_number() == frame and not a.ready(),"No attack releases before its authored cue")
				a.advance(0.1)
			check(a.ready() and a.frame_number() == clip.launch,"Release is reached at idle's frame rate")
			var delay: float = a.impact_delay()
			a.launch()
			check(a.last_launch.frame == clip.launch,"Release records the actual cue before weak attacks return idle")
			if clip.get("idle_on_launch",false):
				check(a.action.is_empty() and a.frame_number() == 2,"Early weak attacks return immediately to idle after frame 14")
				continue
			for frame in range(clip.launch,clip.impact):
				check(a.frame_number() == frame,"Post-release frames stay at 100ms each")
				a.advance(0.1)
			check(is_equal_approx(delay,float(clip.impact-clip.launch)/Sprite.IDLE_FPS),"Effect buildup follows actor timing")
			check(a.frame_number() == clip.impact,"Actor reaches impact without borrowing an effect clock")
			a.damage()
			check(a.frame_number() == clip.impact,"Damage event does not jump or reset the pose")
			if clip.has("loop_end"):
				for i in range((clip.loop_end-clip.impact+1)*3):
					check(a.frame_number() == clip.impact+i%(clip.loop_end-clip.impact+1),"Sustained loops retain idle's exact cadence")
					a.advance(0.1)
				var before: int = a.frame_number()
				a.finish()
				check(a.frame_number() == before,"Ending damage never skips the remaining loop frames")
				for frame in range(before,clip.last+1):
					check(a.frame_number() == frame,"Recovery follows the current frame in sequence")
					a.advance(0.1)
			else:
				a.finish(); a.advance(2)
			check(a.action.is_empty(),"Each clip returns to idle")

## Emotes retain priority, and all sheets share one ground line despite transparent padding.
func early_forms_and_emotes() -> void:
	for form in range(3):
		var a = ActorAnimation.new(); a.set_form(form)
		check(Sprite.has_divine_ring(form) == (form == 2),"Only the final form carries the divine ring")
		var rect := Sprite.grounded_rect(Rect2(0,0,256,256),form)
		check(is_equal_approx(rect.position.y+Sprite.rest_bounds(form).end.y*rect.size.y,256),"Visible feet align across all forms")
		for i in range(Sprite.FORMS[form].idle_count): check(Sprite.idle_frame(i/10.0+0.001,form) == i+(1 if form == 2 else 2),"Idle skips cover art")
		check(Sprite.idle_frame(Sprite.FORMS[form].idle_count/10.0+0.001,form) == Sprite.FORMS[form].idle_first,"Each idle loop includes its full authored range")
		a.begin("ultimate"); a.play_emote()
		a.advance(0.1)
		check(a.frame_number() == a.EMOTES[form].first+1,"Emotes also play at idle speed")
		a.play_emote(); check(a.frame_number() == a.EMOTES[form].first,"Retapping restarts an emote")
		a.advance(1)
		check(a.ready(),"Emotes do not delay attack release")
		a.play_emote()
		a.launch(); a.damage()
		check(a.emoting(),"Attack events do not interrupt the emote")
		a.advance(3)
		check(not a.emoting(),"Emote returns to the current cast")
		a.finish(); a.advance(2)
		check(a.action.is_empty(),"Emote does not leave a stuck cast")
		for name in a.clips():
			var clip: Dictionary = a.clips()[name]
			for frame in range(clip.first,clip.last+1):
				check(Sprite.sheet(form).get_image().get_region(Rect2i(Sprite.region(frame,form))).get_used_rect().has_area(),"Attack frames contain artwork")
		if form == 0:
			a.reset(); a.play_emote()
			check(a.body_rect(rect) == rect,"Jump starts grounded on frame 44")
			for frame in range(45,49):
				a.advance(0.1)
				check(a.frame_number() == frame and a.body_rect(rect).position.y < rect.position.y,"Intermediate emote frames arc above the ground")
			a.advance(0.1)
			check(a.frame_number() == 49 and a.body_rect(rect).is_equal_approx(rect),"Frame 49 lands exactly on the ground")
			a.advance(0.11)
			check(not a.emoting() and a.body_rect(rect) == rect,"Jump finishes without a leftover vertical offset")

## Capture real battlefield output; nothing writes campaign or player save files.
func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.arena_actors.queue_redraw()
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/diablo-"+label+".png")

## Exercise skills and matching attacks through the production coroutines in both layouts.
func resolve_matches(g) -> void:
	await g._resolve_roll_triggers(g.run_id)
	g.set_meta("matches_complete",true)

func scene(phone: bool, length: int, matching: bool = false, form: int = 2, emote_during_cast: bool = false) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = SeenPortrait.new() if phone else SeenBattle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	g.model.character_level = [1,5,10][form]; g.evolution.reset()
	g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1),g.model.make_enemy(2)]
	for e in g.model.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
	for i in range(3): check(g.evolution.forms[i].atlas == Sprite.sheet(i),"Every evolution uses its matching sheet")
	var anchor: Vector2 = g._character_counter_center()
	g.player_animation.advance(0.35)
	check(g._character_counter_center() == anchor,"Animated cells never move fixed status/counter anchors")
	var prefix: String = "form-"+str(form)+"-"+("portrait" if phone else "landscape")+("-match-" if matching else "-skill-")+str(length)
	var values: Array = [1,2,3,4,5,6]
	if matching:
		values = [2,2,3,4,5,6] if length == 2 else [2,2,2,4,5,6] if length == 3 else [2,2,2,2,5,6] if length == 4 else [2,2,2,2,2,6] if length == 5 else [2,2,2,2,2,2]
	g.model.roll_pool(false,values)
	if matching:
		g.view_phase = "rolling"; resolve_matches(g)
	else:
		g.model.dice_turn.selected = range(length); g.model.form_selected_skill()
		g._show_pending_skill(false); g._activate_skill(0)
	var deadline: int = Time.get_ticks_msec()+15000
	var saw: Dictionary = {}
	var tapped := false
	while Time.get_ticks_msec() < deadline:
		var a = g.player_animation
		if not a.action.is_empty():
			var tag: String = a.phase
			if not saw.has(tag):
				saw[tag] = true
				if tag in ["build","damage"]: capture(g,prefix+"-"+tag)
		if emote_during_cast and not tapped and a.phase == "build":
			tapped = true
			var body: Rect2 = g.evolution.visible_rect(g._player_world_sprite_rect())
			g._handle_click(g.battlefield_view.transform*body.get_center())
			check(a.emoting(),"Tapping the moving/casting body starts its emote")
			check(a.frame_number() == a.EMOTES[form].first,"Emote begins at its first authored frame")
			a.advance(0.1)
			g._handle_click(g.battlefield_view.transform*body.get_center())
			check(a.emote_age == 0,"A second tap immediately restarts the emote")
		if not g.impacts.is_empty() and a.action.is_empty() and (g.get_meta("matches_complete",false) if matching else g.view_phase == "ready"): break
		await process_frame
	check(Time.get_ticks_msec() < deadline,"Attack and actor recovery finish without deadlock")
	check((saw.has("windup") or (form == 0 and length >= 4)) and not g.launches.is_empty(),"Authored preparation reaches a real attack release")
	check(not g.impacts.is_empty(),"Real attack commits damage")
	if form < 2 and ((matching and length <= 3) or (not matching and length == 3)):
		check(g.launches.all(func(hit): return hit.frame == (19 if form == 0 else 14)),"Early weak attacks fire at their form's shooting frame")
		if form == 1: check(g.impacts.all(func(hit): return hit.action.is_empty()),"Second-form weak attack returns immediately to idle")
	if not matching and length == 4 and not emote_during_cast:
		check(g.launches[0].frame == [27,20,43][form],"Fiery Slash spawns exactly on the form-specific cue")
		check(g.impacts[0].frame == [29,22,48][form],"Slash frame-six impact matches the actor follow-through")
	if length >= 5 and not emote_during_cast:
		var low: int = (95 if matching or length == 6 else 57) if form == 2 else 38 if form == 0 else 32
		var high: int = (102 if low == 95 else 64) if form == 2 else 36 if form == 1 else 38
		check(g.impacts.all(func(hit): return hit.frame >= low and hit.frame <= high),"All damage pulses stay inside the damaging animation loop")
	if matching and length <= 4:
		check(g.launches[0].action == ("pair" if length == 2 else "fireball" if length == 3 else "storm"),"Each matching tier uses its requested clip")
	# Menu and freeze hold the exact pose; advance uses walk instead of a generic bob.
	g.player_animation.reset(); g.view_phase = "transition"
	g.travel_progress = 0.75
	await process_frame; await process_frame
	check(g.player_animation.frame_number() in ([range(10,16),range(2,9),range(12,21)][form]),"Travel uses first/final-form walking or the floating second-form idle")
	capture(g,prefix+"-walk")
	g.menu_open = true
	g._handle_click(g._player_point())
	check(not g.player_animation.emoting(),"Menu blocks character taps")
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
	early_forms_and_emotes()
	for phone in [false,true]:
		for length in range(3,7): await scene(phone,length)
	for length in range(2,7): await scene(true,length,true)
	for form in [0,1]:
		for length in range(3,7): await scene(true,length,false,form)
		for length in range(2,7): await scene(true,length,true,form)
	for form in [0,2]: await scene(true,6,false,form,true)
	var home = Home.new(); home.campaign_path = ""; root.add_child(home)
	check(home.art.flameling.atlas == Sprite.FIRST_SHEET,"Home uses a frame from the new first-form sheet")
	var body: Rect2 = home._shrine_sprite_rect()
	var bounds := Sprite.rest_bounds(0)
	home._activate(body.position+(bounds.position+bounds.size/2)*body.size)
	check(home.player_animation.emoting(),"Home character also responds with the early-form emote")
	home.queue_free(); await process_frame
	print("Diablo player: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
