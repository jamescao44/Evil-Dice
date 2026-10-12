extends SceneTree
const Motion = preload("res://scripts/combat_motion.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const Status = preload("res://scripts/status_effect.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func motion_checks() -> void:
	var motion = Motion.new()
	for target in [-2,-1,0]: motion.hit(target)
	check(motion.offset(0,160,0) == 0 and motion.offset(-1,240,0) == 0,"Hits start at the actor's original position")
	motion.advance(0.05)
	check(motion.offset(0,160,0) > 0 and motion.offset(-1,240,0) < 0,"Enemies recoil right; the Horror recoils left")
	check(motion.offset(-2,500,0) == 0 and not motion.hits.has(-2),"City damage never moves the city")
	check(motion.offset(0,160,0,false,true) == 0,"Reduced effects disable actor motion")
	motion.advance(0.25)
	check(motion.offset(0,160,0) == 0 and motion.offset(-1,240,0) == 0,"Actors return exactly to their starting position")
	check(motion.offset(0,160,0.03,true)*motion.offset(0,160,0.10,true) < 0,"Unable-to-act motion nudges in both horizontal directions")
	motion.skip(0)
	motion.advance(0.035)
	check(motion.offset(0,160,0) != 0,"Skipped action remains visibly animated after its status is consumed")
	motion.clear()
	check(motion.hits.is_empty() and motion.blocked.is_empty(),"New fights clear all actor motion")

func scene_checks(portrait: bool) -> void:
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.set_process(false)
	g.damage_feedback.set_process(false)
	g._show_events([Rules.damage_event(0,5,5),Rules.damage_event(-1,5,5),Rules.damage_event(-2,5,5)])
	g.combat_motion.advance(0.05)
	check(g.combat_motion.offset(0,100,0)>0 and g.combat_motion.offset(-1,240,0)<0 and not g.combat_motion.hits.has(-2),"Damage events drive actor recoil in either layout")
	g._show_events([Rules.event(0,0,"skip","IMMOBILIZED")])
	check(g.combat_motion.blocked.has(0),"Skipped enemy actions trigger nudge feedback")
	g._restart(10)
	g.speed = 1
	g.model.set_test_roll([1,1,3])
	g.model.begin_player_cast()
	g.view_phase = "resolving"
	var panel = g.damage_feedback
	panel.start(g.model.attack_damage_steps(g.model.pending))
	g._begin_cast_cinematic(Rules.Kind.SPECIAL)
	var before: float = g.model.volley_clock
	g._process(0.02)
	check(g._world_time_scale() == 1 and g.model.volley_clock < before,"City continues advancing while damage is being calculated")
	panel._process(0.04)
	check(is_equal_approx(panel.age,0.08),"City damage animation advances at double speed")
	g.menu_open = true
	panel._process(0.1)
	g._process(0.1)
	check(is_equal_approx(panel.age,0.08),"Menus still pause the damage animation")
	g.menu_open = false
	g._restart()
	g.guide = true
	g._handle_click(g.GUIDE_STATUSES.get_center())
	check(g.guide_status_page,"Status-effect help opens from its tab")
	var entries: Array = g.Statuses.help_entries()
	check(entries.size() == 8 and entries.all(func(item): return not item.text.is_empty()),"Help describes all eight implemented status effects")
	var ceremony = g.tarot_ui.ceremony
	ceremony.start(["fool","magician","high_priestess"],g.fx.canvas_size,g.description_font,Vector2.ZERO,false)
	ceremony.state = "fan"
	ceremony.draws = [{"from":Vector2.ZERO,"angle":0.0,"age":1.0},{"from":Vector2.ZERO,"angle":0.0,"age":1.0}]
	ceremony.sky_age = 0.2
	var a: Vector2 = ceremony.row_point(0)
	ceremony.advance(0.25)
	var b: Vector2 = ceremony.row_point(0)
	check(a.x == b.x and a.y != b.y and ceremony.row_rect(0).get_center() == b,"Drawn cards bob vertically and their click targets follow")
	check(not is_equal_approx(ceremony.row_point(0).y,ceremony.row_point(1).y),"Drawn cards bob with staggered phases")
	ceremony.reduced = true
	check(ceremony.row_point(0).y == ceremony.row_point(1).y,"Reduced effects keep drawn cards steady")
	g.queue_free()
	await process_frame

func run() -> void:
	motion_checks()
	await scene_checks(false)
	await scene_checks(true)
	print("Combat presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
