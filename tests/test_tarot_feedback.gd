extends SceneTree
## Pending badges observe real consumption, preserve previews, and align in both layouts.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func capture(g, label: String) -> void:
	g.queue_redraw(); g.tarot_feedback.queue_redraw()
	await process_frame; await process_frame
	if DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/tarot-feedback/"+label+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output/tarot-feedback")
	for phone in [true,false]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.set_process_input(false)
		var ui = g.tarot_feedback
		var effects = g.model.tarot_effects
		g.model.enemies[0].hp = 100000; g.model.enemies[0].max_hp = 100000
		effects.strength = 1
		check(ui.begin_arrival("strength",{}) == "skill","Strength uses player badge destination")
		check(ui.displayed_indicators("skill").is_empty(),"New badge waits for orb")
		ui.finish_arrival("strength","skill")
		check(ui.displayed_indicators("skill")[0].count == 1,"Arrival reveals live effect")
		effects.strength = 3
		ui.begin_arrival("strength",{"strength":1})
		check(ui.displayed_indicators("skill")[0].count == 1,"Stack increase waits for arrival")
		ui.finish_arrival("strength","skill")
		check(ui.displayed_indicators("skill")[0].count == 3,"Arrival reveals stacked count")
		ui.begin_arrival("strength",{"strength":2})
		ui._applied("strength","skill")
		effects.strength = 0
		ui.finish_arrival("strength","skill")
		check(ui.displayed_indicators("skill").is_empty(),"Consumption cannot resurrect arriving effect")
		ui.reset()
		effects.strength = 2; effects.lovers = true; effects.star_throws = 3; effects.dice_boost = 1
		g.model.set_status_counts({Rules.Status.MIGHT:2,Rules.Status.IMMUNITY:1})
		g.model.perfect_combo = 3
		g._update_battlefield_view(1.0)
		var rng: int = g.model.rng.state
		var roll_items: Array = effects.active_indicators("roll")
		check(roll_items.size() == 3 and effects.active_indicators("skill")[0].count == 2,"Concurrent effects produce separate badges and stacked Strength keeps its count")
		var a: Vector2 = ui.indicator_center(roll_items[0].id,"roll")
		var b: Vector2 = ui.indicator_center(roll_items[-1].id,"roll")
		check(is_equal_approx((a.x+b.x)/2,g.DICE_CENTER.x),"Throw badges center as one row")
		var left: Vector2 = g._status_center(Rules.Status.MIGHT)
		var right: Vector2 = ui.indicator_center("strength","skill")
		check(is_equal_approx((left.x+right.x)/2,(g.battlefield_view.transform*g._character_counter_center()).x),"Statuses and skill tarot share the character-centered row")
		check(g.model.rng.state == rng and effects.strength == 2,"Reading and positioning indicators does not consume effects or randomness")
		if phone:
			check(g._saved_slot_center().y < 1120 and g._perfect_combo_center().y == g._saved_slot_center().y,"Combo and End Turn occupy the gap above the dice")
			check(g.dice_selection.preview_rect().position.x > g._perfect_combo_center().x+g._saved_slot_radius(),"Skill preview stays between the moved controls")
		var inspect = ui.inspection
		var phase_before: String = g.model.phase
		for stage in ["ready","enemy","resolving","transition","wave_reward","over"]:
			g.view_phase = stage
			ui._process(0)
			check(ui.visible and ui.shown(),"Effect layer persists during "+stage)
			g._handle_click(ui.indicator_center("strength","skill"))
			check(inspect.opened and inspect.rows().size() == 4,"Tarot remains inspectable during "+stage)
			g._handle_release(Vector2.ZERO)
			check(inspect.opened,"Opening release does not dismiss inspection")
			g._handle_click(Vector2.ZERO)
			g._handle_release(Vector2.ZERO)
			check(not inspect.opened and g.model.phase == phase_before,"Dismissal cannot trigger gameplay during "+stage)
			g._handle_click(g._status_center(Rules.Status.MIGHT))
			check(inspect.opened and inspect.status_id == Rules.Status.MIGHT,"Statuses remain inspectable during "+stage)
			g._handle_release(Vector2.ZERO)
			g._handle_click(inspect.close_rect().get_center()); g._handle_release(Vector2.ZERO)
		check(g.model.rng.state == rng and effects.strength == 2,"Inspection never changes random state or pending effects")
		g.view_phase = "enemy"; g._process(0)
		check(ui.roll_tint() == g.dice[0].self_modulate and ui.roll_tint().r < 1,"Pending roll effects dim with the disabled dice")
		g.view_phase = "ready"
		effects.devil = 5; effects.carried_rolls = 4
		check(effects.active_indicators("roll").filter(func(item): return item.id == "devil")[0].count == 3,"Devil shows stacked applications rather than guaranteed sixes")
		g._handle_click(ui.indicator_center("strength","skill")); g._handle_release(Vector2.ZERO)
		check(inspect.rows().size() == 6 and Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(inspect.panel_rect()),"All six tarot effects fit the inspector")
		g._process(0)
		check(not g.fx.damage_layer.visible and inspect.z_index > g.HELD_ITEM_Z,"Inspector covers combat numbers and held art")
		await capture(g,("phone" if phone else "desktop")+"-inspection")
		g._handle_click(Vector2.ZERO); g._handle_release(Vector2.ZERO)
		effects.devil = 0; effects.carried_rolls = 0
		g._handle_click(g._status_center(Rules.Status.MIGHT)); g._handle_release(Vector2.ZERO)
		await capture(g,("phone" if phone else "desktop")+"-status")
		g._handle_click(Vector2.ZERO); g._handle_release(Vector2.ZERO)
		g.view_phase = "transition"
		await capture(g,("phone" if phone else "desktop")+"-advancing")
		g.view_phase = "charging"
		await capture(g,("phone" if phone else "desktop")+"-pending")
		g.view_phase = "ready"
		# A failed roll cannot consume or pop pending cards.
		g.model.phase = "player"
		check(g.model.roll_pool().is_empty() and ui.queued_roll.is_empty(),"Rejected throws do not pop badges")
		g.model.phase = "roll"
		var changed: Array = g.model.roll_pool(false,[1,2,3,4,5,6])
		check(not effects.lovers and effects.star_throws == 2 and effects.dice_boost == 1,"Lovers consumes once while Star and Priestess retain remaining effects")
		check(ui.queued_roll.size() == 3 and ui.waves.is_empty(),"Applied roll effects wait until the dice finish landing")
		check(ui.held_roll.size() == 3 and ui.held_roll.any(func(item): return item.id == "lovers"),"Consumed badges remain visible until their landing pop")
		var held_slot: int = ui.held_roll.find_custom(func(item): return item.id == "lovers")
		g._handle_click(ui.roll_center(held_slot,ui.held_roll.size())); g._handle_release(Vector2.ZERO)
		check(inspect.opened and inspect.rows().any(func(item): return item.id == "lovers"),"A consumed badge waiting for landing remains inspectable at its drawn position")
		check(inspect.remaining_text({"id":"lovers","count":1}) == GameText.text("Applying this throw"),"Committed throws are labeled as applying now")
		g._handle_click(Vector2.ZERO); g._handle_release(Vector2.ZERO)
		for index in changed:
			g.dice[index].stop_charge()
			g.dice[index].face = g.model.dice_turn.values[index]
		ui.roll_landed(changed)
		check(ui.pops.size() == 3 and ui.waves.size() == 1 and ui.held_roll.is_empty(),"Landing pops all applied cards and creates one shared wave")
		ui._process(0.36)
		check(g.dice.all(func(d): return d.tarot_glow > 0),"Passing wave lights the affected dice purple")
		g.set_process(false); ui.set_process(false)
		for die in g.dice: die.set_process(false)
		await capture(g,("phone" if phone else "desktop")+"-wave")
		g.set_process(true); ui.set_process(true)
		ui.reset()
		ui.queued_roll.append({"id":"justice","at":g.DICE_CENTER,"age":0.0,"lane":"roll"})
		ui.roll_landed([0,2]); ui._process(0.4)
		check(g.dice[0].tarot_glow > 0 and g.dice[2].tarot_glow > 0 and g.dice[1].tarot_glow == 0,"Used dice are excluded from reroll glow")
		ui.reset()
		var skill = g.model.Patterns.classify([3,4,5])
		effects.begin_skill(skill)
		check(skill.effect_multiplier == 3 and effects.strength == 0 and ui.pops.size() == 1,"Strength pops only as its bonus locks into the actual skill")
		effects.begin_skill(skill)
		check(ui.pops.size() == 1,"Repeated resolution of a locked skill cannot pop again")
		g.menu_open = true; ui._process(0.1)
		check(ui.visible and not ui.inspection.available(),"Menus cover indicators without removing their underlying battlefield layer")
		g.menu_open = false
		g.view_phase = "ready"
		g.model.phase = "roll"
		effects.dice_boost = 0; effects.star_throws = 0; effects.lovers = false
		g.model.dice_turn.reset()
		g.model.roll_pool(false,[1,2,3,4,5,6])
		ui.reset()
		for index in range(g.dice.size()):
			g.dice[index].stop_charge()
			g.dice[index].face = g.model.dice_turn.values[index]
		check(g._can_end_turn() and g.model.dice_turn.rolls_left == 2,"End-turn caption fixture displays two unused rolls")
		await capture(g,("phone" if phone else "desktop")+"-end-turn")
		GameText.set_language("en",false)
		await capture(g,("phone" if phone else "desktop")+"-end-turn-en")
		GameText.set_language("zh_CN",false)
		g.model.reset(); ui.reset()
		check(ui.effects == g.model.tarot_effects and ui.pops.is_empty() and ui.waves.is_empty(),"Restart rebinds listeners and clears old feedback")
		# The same pending Strength stays close to both forms, even beside crowded enemies.
		for wave in [3,7,10,15]:
			g._restart(wave)
			g.model.tarot_effects.strength = 2
			var before := Vector2.ZERO
			for level in [5,10]:
				g.model.character_level = level
				g.evolution.reset()
				g._update_battlefield_view(1.0)
				var point: Vector2 = ui.indicator_center("strength","skill")
				var head: Vector2 = g.battlefield_view.transform*g._character_counter_center()
				check(absf(point.y-maxf(g.ARENA.position.y+64,head.y-(60 if phone else 42))) < 1,"Strength follows the current form without enemy-avoidance row jumps")
				if level == 10: check(absf(point.y-before.y) < 45,"Evolving moves the badge only by the change in character height")
				before = point
				check(g.model.tarot_effects.strength == 2,"Evolution preserves pending Strength stacks")
		g.queue_free(); await process_frame
	print("Tarot feedback: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
