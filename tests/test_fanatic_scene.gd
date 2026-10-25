extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize(): call_deferred("run")
func settled(g):
	for i in g.model.living():
		g.model.enemies[i].acted = false
		g.model.enemies[i].intent = g.model.choose_intent(i)
	for i in range(80):
		g._process(1.0/60)
		await process_frame
func screenshot(g, label):
	if DisplayServer.get_name() == "headless": return
	g.queue_redraw(); await process_frame; RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/progression-20261025/"+label+".png")
func check_visible(g):
	for i in g.model.living():
		check(g.ARENA.grow(2).encloses(g._enemy_sprite_rect(i)),"Live creature fits battlefield")
		check(g.ARENA.encloses(g._enemy_health_rect(i)),"Live creature health bar fits battlefield")
		check(g.ARENA.encloses(g._enemy_intent_rect(i)),"Live creature intention fits battlefield")
		check(not g.player_health_rect().grow(3).intersects(g._enemy_health_rect(i)),"Enemy health never covers player vitals")
		for other in g.model.living():
			if i == other: continue
			check(not g._enemy_health_rect(i).intersects(g._enemy_health_rect(other)),"Living enemy health bars remain separate")
func run():
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process_input(false); g._restart(30)
		g.model.character_level = 22; g.model.hp = g.model.max_hp; g.evolution.reset(); g.soul_pickup.reset()
		g.model.BossRules.Fanatic.summon(g.model,0)
		g.model.BossRules.Fanatic.split(g.model,0)
		g.model.begin_round()
		await settled(g)
		check_visible(g)
		await screenshot(g,"fanatic-servants-"+str(phone))
		for i in g.model.BossRules.Fanatic.servants(g.model,0): g.model.BossRules.Fanatic.dismiss(g.model,i)
		g.model.hit_enemy(0,g.model.enemies[0].hp,true)
		var demon: int = g.model.enemies.size()-1
		g.model.enemies[demon].charging = true; g.model.enemies[demon].charge = 1
		g.model.enemies[demon].acted = false
		g.model.enemies[demon].intent = g.model.EnemyActions.intent(g.model,demon,"charge")
		await settled(g)
		check_visible(g)
		check(g._enemy_intent_data(demon).description.contains("3") or g._enemy_intent_data(demon).description.contains("三"),"Demon inspection describes break marks")
		await screenshot(g,"fanatic-demon-"+str(phone))
		g.model.BossRules.Fanatic.summon(g.model,0); g.model.BossRules.Fanatic.split(g.model,0)
		g.model.begin_round()
		await settled(g)
		check_visible(g)
		check(g.model.BossRules.Fanatic.servants(g.model,0).all(func(i): return g.model.enemies[i].summon_slot < 6),"Demon does not consume a small servant's formation slot")
		await screenshot(g,"fanatic-full-phase2-"+str(phone))
		g.queue_free(); await process_frame
	print("Fanatic scene: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
