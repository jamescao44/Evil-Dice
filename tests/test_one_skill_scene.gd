extends SceneTree
## Both layouts finish the cast/bonus visuals, settle treasure and return on a fresh turn.
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
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.speed = 30; g.set_process_input(false)
		for bonus in [false,true]:
			g._restart()
			g.model.enemies = [g.model.make_enemy(0)]
			g.model.enemies[0].hp = 100000; g.model.enemies[0].max_hp = 100000
			g.model.enemies[0].intent = {"skill":"rest","type":"rest","target":0,"amount":0,"name":"Rest"}
			g.model.character_passive.charge = 2 if bonus else 0
			g.model.roll_pool(false,[1,2,3,4,5,6])
			g.model.dice_turn.selected = [0,1,2]
			g.model.form_selected_skill()
			var round_before: int = g.model.round_number
			g._show_pending_skill(false)
			var saw_bonus := false
			var end_seen := false
			var deadline: int = Time.get_ticks_msec()+15000
			while Time.get_ticks_msec() < deadline:
				saw_bonus = saw_bonus or g.model.pending.cast_source == "character_bonus"
				end_seen = end_seen or g.model.phase in ["enemy","turn_end"]
				if g.model.round_number > round_before and g.view_phase == "ready": break
				await process_frame
			check(g.model.round_number == round_before+1 and g.view_phase == "ready","One cast automatically runs one enemy phase and returns controls")
			check(end_seen and g.model.dice_turn.manual_casts == 0 and not g.model.dice_turn.has_rolled(),"The next real turn has a fresh allowance and unopened dice")
			check(g.model.reroll_progress == 2 and g.model.bonus_turn_count == 0,"Visual turn closure pays treasure once without a bonus turn")
			check(saw_bonus == bonus,"Bonus Fireballs finish as part of the committed sequence")
		g.queue_free(); await process_frame
	print("One skill scene: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
