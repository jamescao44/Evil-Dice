extends SceneTree
const Dust = preload("res://scripts/enemies/enemy_dust.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var m = Run.new(371)
	m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for e in m.enemies: e.hp = 1; e.shield = 0
	return m
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Dust.SHEET.get_size() == Vector2(528,48),"All eleven 48px cells are imported intact")
	for sequence in [[1,2,3],[1,2,3,4],[1,2,3,4,5],[1,2,3,4,5,6]]:
		var m = fresh()
		m.pending = m.Patterns.classify(sequence); m.phase = "player"
		m.apply_player(0)
		check(m.enemies[0].get("death_source","") == ("fire_storm" if sequence.size() == 5 else "brimstone" if sequence.size() == 6 else ""),"Actual skill kill selects only Storm and Brimstone")
	var m = fresh()
	m.apply_enemy_status(0,m.Status.BURNING,1)
	m._tick_enemy_statuses()
	check(m.enemies[0].death_source == "burn","Burning tick records its lethal source")
	m.hit_enemy(0,999,true)
	check(m.enemies[0].death_source == "burn","Corpse hits cannot overwrite the death cause")
	m = fresh(); m.apply_enemy_status(0,m.Status.BURNING,1); m.hit_enemy(0,5,true)
	check(m.enemies[0].death_source == "","Merely having Burning does not replace a normal death")
	for phone in [false,true]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
		g._restart(1)
		g.model.enemies = [g.model.make_enemy(2),g.model.make_enemy(0)]
		g.model.enemies[0].shield = 0
		var sprite: Rect2 = g._enemy_world_sprite_rect(0)
		var tex: Texture2D = g.art[g.EnemyVisuals.art_key(g.model.enemies[0])]
		var used := Rect2(tex.get_image().get_used_rect())
		var visible := Rect2(sprite.position+used.position*sprite.size/tex.get_size(),used.size*sprite.size/tex.get_size())
		g.model.hit_enemy(0,999999,true,"fire_storm"); g._sync_corpses()
		check(g.enemy_dust.bodies.has(0) and not g.enemy_debris.bodies.has(0),"Dust replaces mage pieces rather than layering both")
		var rect: Rect2 = g.enemy_dust.bodies[0].rect
		var first := Rect2(rect.position+Dust.FIRST_BOUNDS.position*rect.size/48,Dust.FIRST_BOUNDS.size*rect.size/48)
		check(is_equal_approx(first.size.y,visible.size.y) and is_equal_approx(first.end.y,visible.end.y),"First silhouette matches visible enemy height and soles")
		g.fx.set_process(false)
		g.fx.flame_cast(3,Vector2.ZERO,[Vector2(400,300)],1)
		g.view_phase = "resolving"; g._process(0.6)
		check(g.enemy_dust.frame(0) == 0,"Visible attack FX hold the first silhouette")
		g.fx.finish_flame_damage(); g._process(0.1)
		check(g.enemy_dust.frame(0) == 0,"Fading FX also hold dusting")
		g.fx.clear()
		g.player_animation.begin("storm"); g.player_animation.launch(); g.player_animation.damage(); g.player_animation.finish()
		g.menu_open = true; g._process(5)
		check(g.enemy_dust.frame(0) == 0,"Menu pauses the death timer")
		g.menu_open = false; g._process(0.02)
		check(g.enemy_dust.frame(0) == 1,"Dissolve starts as soon as FX disappear")
		check(not g.player_animation.action.is_empty() and g.view_phase == "resolving","Character recovery no longer blocks dusting")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			g.queue_redraw(); g.arena_actors.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/dusted-"+str(phone)+".png")
		g._process(1)
		check(not g.enemy_dust.active() and g.enemy_dust.bodies[0].done,"Dissolve completes and corpse cannot reappear")
		var boss: Dictionary = g.model.enemies[1].duplicate(true); boss.boss = true; boss.death_source = "brimstone"
		check(not g.enemy_dust.spawn(1,boss,sprite,tex),"Bosses retain their normal death")
		g._restart(1)
		check(g.enemy_dust.bodies.is_empty(),"Restart clears dust state")
		g.queue_free(); await process_frame
	print("Enemy dust: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
