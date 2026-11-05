extends SceneTree
## Verify growth plateaus in both layouts without freezing travel or encounter progression.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Waves = preload("res://scripts/progression/wave_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Save native previews of the plateau and final boss without touching user saves.
func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.arena_actors.queue_redraw(); g.backdrop.refresh()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/growth-cap-"+label+".png")

func run() -> void:
	check(is_equal_approx(Battle.ActorScale.player_size(1),224+64*11.0/19),"Second form retains the previous wave-12 player size")
	check(is_equal_approx(Battle.ActorScale.enemy_size(2),192-104*11.0/18),"Final evolution retains the previous wave-12 enemy size")
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
		g._restart(12); g._update_battlefield_view(1)
		var sizes: Array = [g.PAVING_SIZES,g.SCENERY_SIZES,[96.0,64.0,40.0,24.0,18.0]]
		var capped: Array = sizes.map(func(values): return g._stage_size(values,Waves.SCENERY_CURVE_SPAN if values.size() == 5 else -1))
		check(is_equal_approx(capped[-1],44.0),"Distant buildings retain the original wave-12 height after extending the chapter")
		for wave in range(12,Waves.CITY_STAGE+1):
			g._restart(wave); g._update_battlefield_view(1)
			check(g.model.stage == wave-1,"Display cap never caps gameplay progression")
			check(is_equal_approx(g.monster_side,g.ActorScale.player_size(g._display_form())),"Player scale follows its form independently of capped scenery")
			for i in range(sizes.size()): check(is_equal_approx(g._stage_size(sizes[i],Waves.SCENERY_CURVE_SPAN if sizes[i].size() == 5 else -1),capped[i]),"Tiles and scenery retain their relative size")
			for enemy in g.model.living():
				check(g.ARENA.encloses(g._enemy_sprite_rect(enemy)),"Late-wave bodies fit with larger enemy proportions")
				check(g.ARENA.encloses(g._enemy_health_rect(enemy)),"Late-wave health bars fit: phone=%s wave=%d enemy=%d rect=%s" % [phone,wave,enemy,g._enemy_health_rect(enemy)])
				for other in range(enemy): check(not g._enemy_health_rect(enemy).intersects(g._enemy_health_rect(other)),"Late-wave health bars remain separate")
			if wave in [12,24]: await capture(g,("portrait" if phone else "landscape")+"-wave%d" % wave)
		g.visual_stage = 10.5
		check(g._stage_size(g.PAVING_SIZES) > capped[0],"Final scenery approach still interpolates smoothly")
		g.visual_stage = 11.5
		check(is_equal_approx(g._stage_size(g.PAVING_SIZES),capped[0]),"No scenery growth overshoot beyond the plateau")
		g.backdrop.refresh(); var revision: int = g.backdrop.revision
		g.visual_stage = 23; g.backdrop.refresh()
		check(g.backdrop.revision == revision,"Capped scenery does not rebuild merely because the wave changes")
		g.background_offset += 50; g.backdrop.refresh()
		check(g.backdrop.revision > revision,"Travel still scrolls capped scenery")
		g.queue_free(); await process_frame
	print("World growth cap: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
