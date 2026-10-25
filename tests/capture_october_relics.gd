extends SceneTree
## Capture the new set descriptions and shared ring artwork in both layouts.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
func _initialize() -> void: call_deferred("run")
func capture(g, label: String) -> void:
	g._process(0); g.queue_redraw(); g.inventory_page.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/relics-20261025/"+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output/relics-20261025")
	GameText.set_language("zh_CN",false)
	for phone in [false,true]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process_input(false); g.set_process(false)
		g.relic_ui.set_process(false); g.evolution.set_process(false)
		g._restart(1); g.view_phase = "ready"
		var ids := ["unidentified_ring","witch_ghost","broken_blade","general_sword","ticket","red_chip","blue_chip","black_chip","potion_x","magic_sword"]
		g.model.relics.items.clear()
		for id in ids: g.model.relics.items.append(g.model.relics._new_item(id))
		g.witch_companion.advance(1,g.model)
		await capture(g,("portrait" if phone else "landscape")+"-ghost")
		g.inventory_page.open()
		var layout: String = "portrait" if phone else "landscape"
		await capture(g,layout+"-inventory")
		g.inventory_page.selected = 1
		await capture(g,layout+"-witch")
		g.queue_free(); await process_frame
	quit()
