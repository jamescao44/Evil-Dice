extends SceneTree
## Capture pet ownership, activation hops and travel in both supported layouts.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")

func _initialize() -> void: call_deferred("run")

func capture(g, label: String) -> void:
	g._process(0); g.queue_redraw(); g.arena_actors.queue_redraw(); g.inventory_page.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/pets-20261025/"+label+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output/pets-20261025")
	for phone in [false,true]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process_input(false); g.set_process(false)
		g.relic_ui.set_process(false); g.evolution.set_process(false)
		g._restart(1); g.view_phase = "ready"
		var label: String = "portrait" if phone else "landscape"
		for id in ["pet_bat","pet_lizard","pet_slime","pet_ghost","pet_dragon","bracelet","fries"]: g.model.acquire_relic(id)
		g.pet_companions.rng.seed = 98765
		for i in range(120): g.pet_companions.advance(1.0/60,g.model,false,Vector2.RIGHT,false)
		await capture(g,label+"-idle")
		for id in g.pet_companions.PETS: g.pet_companions.activate(id)
		g.pet_companions.advance(0.3,g.model,false,Vector2.RIGHT,false)
		await capture(g,label+"-jump")
		g.view_phase = "transition"; g.travel_progress = 0.5; g.travel_direction = Vector2(1,-0.6)
		for i in range(90): g.pet_companions.advance(1.0/60,g.model,true,g.travel_direction,false)
		await capture(g,label+"-travel")
		g.view_phase = "ready"
		# Show every food icon together without changing real fusion rules.
		g.model.relics.items.clear()
		for id in g.pet_companions.PETS.keys()+["pet_orb"]: g.model.relics.items.append(g.model.relics._new_item(id))
		g.inventory_page.open(); g.inventory_page.selected = -1
		await capture(g,label+"-food-icons")
		g.queue_free(); await process_frame
	quit()
