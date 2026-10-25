extends SceneTree
const Home = preload("res://scripts/home/home.gd")
var home
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func touch(point: Vector2, pressed: bool, finger: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = home.get_global_transform_with_canvas() * point
	event.pressed = pressed
	event.index = finger
	home._input(event)

func tap(point: Vector2) -> void:
	touch(point, true)
	touch(point, false)

func run() -> void:
	for portrait in [true, false]:
		home = Home.new()
		home.campaign_path = ""
		home.portrait = portrait
		home.muted = true
		root.add_child(home)
		await process_frame
		check(home.page == 2 and home.visible, "Start on Play")
		for page in [0, 1, 2, 3, 4]:
			tap(home.tab_rect(page).get_center())
			check(home.page == page, "Touch navigation opens " + home.TABS[page])
			check(Rect2(Vector2.ZERO, home.canvas_size()).encloses(home.tab_rect(page)), "Navigation is within the canvas")
		tap(home.tab_rect(0).get_center())
		tap(home.dice_card(0).get_center())
		check(home.modal == "dice" and home.preview_die.visible, "Die opens expanded detail")
		tap(home.tab_rect(2).get_center())
		check(home.page == 0 and home.modal.is_empty(), "Tap outside modal dismisses without activating background")
		tap(home.dice_card(0).get_center())
		tap(home.equip_rect().get_center())
		check(home.dice_index == 0 and home.modal.is_empty(), "Equipped die returns to collection")
		tap(home.tab_rect(1).get_center())
		tap(home.skills_rect().get_center())
		for page in range(3):
			tap(home.skill_tab_rect(page).get_center())
			check(home.modal == "skills" and home.skill_page == page, "All skill categories accessible")
		tap(home.city_rect().get_center())
		check(home.city_skills == home.Run.CITY_FEVER_ENABLED, "City skill adaptations follow the active route")
		tap(home.close_rect().get_center())
		tap(home.picker_rect().get_center())
		check(home.modal == "ancients", "Ancient picker opens")
		tap(home.collection_rect(0).get_center())
		check(home.modal.is_empty() and home.ancient_index == 0, "Select current Ancient")
		var center: Vector2 = home.stage_rect().get_center()
		touch(center, true)
		touch(center - Vector2(160, 10), false)
		check(home.ancient_index == 0, "Single Ancient swipe remains valid")
		# Fixture only: exercise future collection entries without shipping pretend monsters.
		var second: Dictionary = home.ancients[0].duplicate(true)
		second.id = "fixture"
		second.name = "Test Ancient"
		home.ancients.append(second)
		touch(center, true)
		touch(center - Vector2(160, 10), false)
		check(home.ancient_index == 1, "Left swipe selects next Ancient")
		touch(center, true)
		touch(center + Vector2(160, 0), false)
		check(home.ancient_index == 0, "Right swipe selects previous Ancient")
		touch(center, true)
		touch(center + Vector2(5, 180), false)
		check(home.ancient_index == 0, "Vertical drag does not change Ancient")
		tap(home.picker_rect().get_center())
		tap(home.collection_rect(1).get_center())
		check(home.ancient_index == 1, "Visual picker selects a different Ancient")
		tap(home.tab_rect(2).get_center())
		check(home.ancient_index == 1, "Selection survives page changes")
		home.ancient_index = 0
		home.ancients.pop_back()
		var button: Vector2 = home.play_rect().get_center()
		touch(button, true)
		touch(button + Vector2(200, 0), false)
		check(not is_instance_valid(home.battle), "Dragged Play press does not launch a battle")
		touch(button, true)
		home._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		touch(button, false)
		check(not is_instance_valid(home.battle), "Focus loss cancels pending tap")
		tap(button)
		check(is_instance_valid(home.battle) and not home.visible, "Play launches battle and hides home")
		check(home.battle.selected_ancient_id == "horror" and home.battle.selected_dice_id == "bone", "Battle receives the selected loadout")
		check(home.battle.model.stage == 0 and home.battle.view_phase == "ready", "A new battle starts on wave one")
		home.battle._handle_click(home.battle.DICE_CENTER)
		check(home.battle.view_phase == "charging", "Roll button starts the charge timer")
		home.battle._handle_click(home.battle.MENU_RECT.get_center())
		home.battle._handle_click(home.battle.GUIDE_RECT.get_center())
		home.battle._handle_click(home.battle._home_rect().get_center())
		await process_frame
		check(not is_instance_valid(home.battle) and home.visible and home.page == 2, "Grimoire Home leaves battle and restores home")
		check(home.dices[home.dice_index].id == "bone", "Loadout survives return from battle")
		tap(home.play_rect().get_center())
		check(home.battle.model.stage == 0 and home.battle.view_phase == "ready", "Second Play starts a fresh run")
		home.battle.view_phase = "over"
		home.battle._handle_click(home.battle._home_rect().get_center())
		await process_frame
		check(home.visible and not is_instance_valid(home.battle), "Ending Home returns to home")
		home.queue_free()
		await process_frame
	print("Home: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
