extends SceneTree
## Exact summon cells, silhouette holds, menu deferral and real level-start sequencing.
const Entrance = preload("res://scripts/player/player_entrance.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func timeline() -> void:
	for form in range(3):
		var entry = Entrance.new()
		entry.start(form,true)
		var clip: Dictionary = Entrance.CLIPS[form]
		for frame in range(clip.first,clip.last+1):
			check(entry.frame_number(2) == frame,"Summon visits every authored cell at 10 FPS")
			var image: Image = Entrance.Sprite.sheet(form).get_image()
			check(image.get_region(Rect2i(Entrance.Sprite.region(frame,form))).get_used_rect().has_area(),"Entrance cells contain artwork")
			if clip.has("white_last") and frame <= clip.white_last:
				check(is_equal_approx(entry.white_alpha(),1),"Evolution keeps all requested frames fully silhouetted")
			if form == 2:
				check(entry.ring_alpha() == (1 if frame >= 146 else 0),"Divine ring remains absent until frame 146")
				if frame == 146: check(is_equal_approx(entry.ring_flash(),1),"Ring appears in a full white flash at the cue")
				if frame > 146: check(entry.ring_flash() > 0,"Ring flash continues through the added entrance frames")
			entry.advance(0.1)
		check(entry.active(),"Summoning circle lingers briefly after the authored clip")
		entry.advance(Entrance.FADE+0.01)
		check(not entry.active() and entry.frame_number(2) == 2,"Entrance returns to idle after the circle fades")
		entry.start(form,false)
		check(entry.white_alpha() == 0,"Ordinary level entry preserves sprite colors")
		entry.reset(); check(not entry.active(),"Reset clears an unfinished summon")

func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g._update_battlefield_view(1); g.queue_redraw(); g.arena_actors.queue_redraw(); g.evolution.queue_redraw()
	await process_frame; RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/entrance-"+label+".png")

func scene(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	g.muted = true; g.level_entrance_enabled = true
	g.model.character_level = 10
	root.add_child(g); g.set_process(false); g.set_process_input(false); g.evolution.set_process(false)
	check(g.view_phase == "entering" and g.evolution.entrance.form == 2,"Level entry uses the checkpoint's form")
	g.menu_open = true; g.evolution._process(4)
	check(g.evolution.entrance.age == 0 and g.view_phase == "entering","Menu pauses summoning and opening turn effects")
	g.menu_open = false; g.evolution._process(0.6)
	check(g.evolution.entrance.frame_number(1) == 140,"Resumed entry continues its authored cells")
	await capture(g,"level-start-"+str(phone))
	g.evolution._process(2); await process_frame
	check(g.view_phase == "ready" and not g.evolution.active(),"First player turn starts after summoning completes")
	for form in range(3):
		g.model.character_level = [1,5,10][form]; g.evolution.reset()
		g.player_animation.play_emote(); g.evolution.start_entrance()
		check(not g.player_animation.emoting(),"Entrance replaces an already playing emote")
		g._update_battlefield_view(1)
		g._handle_click(g._player_point())
		check(not g.player_animation.emoting() and g.evolution.blocks_emote(),"Tapping the character cannot interrupt its entrance")
		var rect: Rect2 = g._player_world_sprite_rect()
		var anchor: Vector2 = Entrance.Sprite.ground_anchor(rect,form)
		var counter: Vector2 = g._character_counter_center()
		check(is_equal_approx(anchor.x,counter.x) and is_equal_approx(anchor.x,g._player_world_feet().x),"Circle and counters share the torso axis")
		check(is_equal_approx(g.evolution.visible_rect(rect).position.y-counter.y,24 if phone else 18),"Counter leaves extra clearance above the sprite")
		var effect: Vector2 = g._player_effect_center(0,1)
		check(is_equal_approx(effect.x,(g.battlefield_view.transform*counter).x),"Status and tarot badges stay centered on the character")
		g.evolution._process(0.6)
		await capture(g,"form%d-%s" % [form,phone])
		g.evolution.reset()
		g._handle_click(g._player_point())
		check(g.player_animation.emoting(),"Tapping works again after the entrance ends")
		g.player_animation.cancel_emote()
	# Drive real model level signals and freeze their clocks for preview snapshots.
	for old_level in [4,9]:
		g.model.character_level = old_level; g.evolution.reset()
		g.model.character_level = old_level+1; g.soul_pickup.reset(); g.evolution.enqueue(old_level+1)
		g.evolution._process(0.60)
		check(g.evolution.displayed_level == old_level,"Outgoing form remains throughout silhouette preparation")
		var body: Rect2 = g._player_world_sprite_rect()
		check(g.evolution.blocks_emote(),"Evolution preparation blocks emotes")
		await capture(g,"silhouette%d-%s" % [old_level,phone])
		g.evolution._process(0.25)
		check(g.evolution.displayed_level == old_level+1 and g.evolution.entrance.evolved,"Evolution switches into the destination summon clip")
		check(g.evolution.source_rect == body,"Crossfade preserves the outgoing sprite proportions")
		var white_hold: float = g.evolution.entrance.white_release_time()
		g.evolution._process(white_hold-0.05)
		check(is_equal_approx(g.evolution.entrance.white_alpha(),1),"Full silhouette survives until the specified hold ends")
		await capture(g,"white%d-%s" % [old_level,phone])
		g.evolution._process(0.25)
		check(g.evolution.entrance.white_alpha() < 1 and g.evolution.entrance.white_alpha() > 0,"Silhouette releases gradually into white particles")
		await capture(g,"release%d-%s" % [old_level,phone])
		if old_level == 9:
			g.evolution._process(0.4)
			check(g.evolution.entrance.ring_alpha() == 1 and g.evolution.entrance.ring_flash() > 0.9,"Evolution reveals the ring on frame 146")
			await capture(g,"ring-flash-"+str(phone))
		g.evolution._process(4)
		check(not g.evolution.active(),"Evolution finishes before queued enemy actions resume")
	g.queue_free(); await process_frame

func run() -> void:
	timeline()
	await scene(false); await scene(true)
	print("Player entrances: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
