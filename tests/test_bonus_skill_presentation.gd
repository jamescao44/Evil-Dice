extends SceneTree
## Counter bonuses keep real casts but only show the counter label and projectiles.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for phone in [false,true]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.speed = 4; g.set_process_input(false)
		g.model.enemies = [g.model.make_enemy(0)]
		g.model.enemies[0].hp = 100000; g.model.enemies[0].max_hp = 100000
		g.model.enemies[0].shield = 0
		g.model.character_passive.charge = 2
		g.model.roll_pool(false,[1,2,3,4,5,6])
		g.model.dice_turn.selected = [0,1,2]; g.model.form_selected_skill()
		g._show_pending_skill(false)
		check(not g.skill_bubble.roll.is_empty(),"Manual skill still has its normal bubble")
		g._activate_skill(0)
		var hp: int = g.model.enemies[0].hp
		var hits := 0
		var saw_bonus := false
		var saw_label := false
		var bubble_leaked := false
		var invalid_origin := false
		var rebuilt_damage := false
		var deadline := Time.get_ticks_msec()+10000
		while g.view_phase != "ready" and Time.get_ticks_msec() < deadline:
			if g.model.enemies[0].hp < hp:
				hits += 1; hp = g.model.enemies[0].hp
			if g.result.cast_source == "character_bonus":
				saw_bonus = true
				rebuilt_damage = rebuilt_damage or g.damage_feedback.building
				bubble_leaked = bubble_leaked or not g.skill_bubble.roll.is_empty() or g.skill_bubble.dissolving
				invalid_origin = invalid_origin or not g.damage_feedback.flight_from.is_finite()
			if g.fx.floats.any(func(f): return f.text == GameText.text("Extra Skill")): saw_label = true
			await process_frame
		check(saw_bonus and not bubble_leaked,"Bonus projectiles never summon or dissolve a skill bubble")
		check(not rebuilt_damage,"Bonus casts skip damage buildup")
		check(not invalid_origin,"Bubble-free damage feedback has a valid player origin")
		check(saw_label,"Counter consumption shows the localized Extra Skill fade-out")
		check(hits == 3,"Original Fireball and both bonus casts each land once")
		check(g.view_phase == "ready" and g.model.pending.is_empty(),"Bonus sequence returns control without another skill to select")
		check(g.model.character_passive.charge == 0,"Bonus casts do not refill their own counter")
		g.queue_free(); await process_frame
	print("Bonus skill presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
