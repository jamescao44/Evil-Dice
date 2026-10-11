extends RefCounted
## Test player: aims single-target skills; drags other skills onto the field.
static func cast_pending(game) -> void:
	if game.view_phase == "relic_reward":
		game.model.skip_relic()
		return
	if game.view_phase != "skill": return
	game._handle_click(game._skill_center())
	if game._skill_needs_target(): game._handle_release(game._skill_center())
	else:
		var field: Vector2 = game.ARENA.get_center()
		game._handle_motion(field)
		game._handle_release(field)
	if game.view_phase == "targeting":
		var targets: Array = game._skill_targets()
		if not targets.is_empty():
			var point: Vector2 = game._target_rect(targets[0]).get_center()
			game._handle_click(point)
			game._handle_release(point)

static func resolve_held(game) -> void:
	cast_pending(game)
	var deadline: int = Time.get_ticks_msec()+12000
	while game.view_phase not in ["ready", "feeding", "over"] and Time.get_ticks_msec() < deadline:
		cast_pending(game)
		await game.get_tree().process_frame
	assert(Time.get_ticks_msec() < deadline, "Skill resolution timed out")
