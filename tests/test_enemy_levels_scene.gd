extends SceneTree
## Check level/HP labels, inspection rewards and special charge previews in both layouts.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Inspection = preload("res://scripts/enemies/enemy_inspection.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.arena_actors.queue_redraw(); g.backdrop.refresh()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/enemy-levels-20261025/"+label+".png")

func run() -> void:
	for portrait in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
		root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
		var inspection = g.get_children().filter(func(node): return node.get_script() == Inspection)[0]
		for language in ["en","zh_CN"]:
			GameText.set_language(language,false)
			for wave in range(1,g.model.PLAYABLE_WAVES+1):
				g._restart(wave); g._update_battlefield_view(1)
				for i in g.model.living():
					var enemy: Dictionary = g.model.enemies[i]
					var bar: Rect2 = g._enemy_health_rect(i)
					var font_size: int = (22 if g.model.enemies.size() < 4 else 20) if portrait else (16 if g.model.enemies.size() < 4 else 12)
					var label_width: float = g.pixel_font.get_string_size("LV.%d" % enemy.level,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(10,font_size-8)).x
					var hp_width: float = g.pixel_font.get_string_size(str(enemy.hp),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
					check(label_width <= bar.size.x and hp_width+10 <= bar.size.x,"Level above and HP inside each fit their own row: wave %d / %s / %s" % [wave,portrait,language])
					check(inspection.level_summary(i).begins_with("LV.%d" % enemy.level),"Every language uses the same LV. prefix")
					check(g.ARENA.encloses(bar),"Level remains within the battlefield")
					for j in g.model.living():
						if i != j: check(not bar.grow(3).intersects(g._enemy_health_rect(j).grow(3)),"Enemy level plates do not overlap")
					check(str(enemy.level) in inspection.level_summary(i) and str(g.model.EnemyCatalog.soul_reward(enemy)) in inspection.level_summary(i),"Inspection exposes the matching level and drop amount")
					if enemy.elite and enemy.role in [3,4]:
						enemy.intent = Actions.intent(g.model,i,"charge")
						var text: String = g._enemy_intent_data(i).description
						check(("立即" in text if language == "zh_CN" else "when full" in text) if enemy.role == 4 else ("下回合" in text if language == "zh_CN" else "next turn" in text),"Charge preview distinguishes elite timings")
				if language == "zh_CN" and wave in [5,10,16,19,20]:
					await capture(g,("portrait" if portrait else "landscape")+"-wave"+str(wave))
				if language == "zh_CN" and wave == 17:
					g.inspecting_enemy = 0
					await capture(g,("portrait" if portrait else "landscape")+"-inspection")
					g.inspecting_enemy = -1
		g.queue_free(); await process_frame
	print("Enemy level presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _initialize() -> void: call_deferred("run")
