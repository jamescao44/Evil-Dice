extends Node2D
## Battle-facing input/FX adapter. Rules and transactional consumption stay in the model.
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Paint = preload("res://scripts/tarot/tarot_paint.gd")
const STATUS_STEP_INTERVAL := 0.12
const Relics = preload("res://scripts/relics/relic_catalog.gd")
var battle
var busy: bool = false
var choice_type: String = ""
var instance_id: int = -1
var drop_point := Vector2.ZERO
var origin := Vector2.ZERO
var values: Array = [1,1,1]
var prepared: Dictionary = {}
var notice: String = ""
var notice_time: float = 0
var resume_phase: String = "ready"

func _ready() -> void:
	z_index = 130
	battle.tarot_ui.use_requested.connect(request)

func active() -> bool:
	return busy or not choice_type.is_empty()

func reset() -> void:
	busy = false
	choice_type = ""
	instance_id = -1
	prepared.clear()
	notice = ""
	notice_time = 0
	resume_phase = "ready"

func request(card: int, point: Vector2, from: Vector2) -> void:
	if active() or not battle.tarot_ui.available(): return
	instance_id = card
	resume_phase = battle.view_phase
	drop_point = point
	origin = from
	var target: int = battle._enemy_inspect_at(point)
	prepared = battle.model.tarot_effects.prepare(battle.model,card,{"target":target})
	if prepared.has("error"):
		message(prepared.error)
		return
	choice_type = prepared.get("choice","")
	values = [1,1,1]
	battle.tarot_ui.inspected = -1
	battle.tarot_ui.cancel_gesture()
	if choice_type.is_empty(): _cast({"target":target})
	queue_redraw()

func message(value: String) -> void:
	notice = value
	notice_time = 3.0
	queue_redraw()

func portrait() -> bool: return battle.tarot_ui.portrait()

func panel_rect() -> Rect2:
	return Rect2(42,380,720,930) if portrait() else Rect2(286,144,708,520)

func cancel_rect() -> Rect2:
	var panel: Rect2 = panel_rect()
	return Rect2(panel.position+Vector2(24,panel.size.y-74),Vector2(panel.size.x-48,52))

func cell_rect(index: int, columns: int, rows: int) -> Rect2:
	var panel: Rect2 = panel_rect()
	var top: float = (286 if portrait() else 186) if choice_type == "replace" else (156 if portrait() else 112)
	var area := Rect2(panel.position+Vector2(24,top),Vector2(panel.size.x-48,panel.size.y-top-98))
	var cell := Vector2(area.size.x/columns,area.size.y/rows)
	return Rect2(area.position+Vector2(index%columns,index/columns)*cell+Vector2(4,4),cell-Vector2(8,8))

func options() -> Array:
	return Catalog.ITEMS.keys().filter(func(id): return id not in battle.model.tarot_effects.banned)

func click(point: Vector2) -> bool:
	if busy: return true
	if choice_type.is_empty(): return false
	if cancel_rect().has_point(point):
		choice_type = ""
		battle.tarot_ui.swallow_release = true
		if instance_id < 0:
			battle.model.tarot_effects.dismiss_repeat()
			_finish_cast()
		queue_redraw()
		return true
	match choice_type:
		"repeat_target":
			var target: int = battle._enemy_inspect_at(point)
			if target in battle.model.attack_targets(): _cast({"target":target})
		"magician":
			for i in range(18):
				if cell_rect(i,6,4).has_point(point): values[i/6] = i%6+1
			var confirm := cell_rect(3,1,4)
			if confirm.has_point(point): _cast({"dice":values.duplicate()})
		"lovers":
			for i in range(2):
				if cell_rect(i,2,1).has_point(point): _cast({"parity":1-i})
		"hanged_man":
			var ids: Array = options()
			var columns: int = 4 if portrait() else 6
			for i in range(ids.size()):
				if cell_rect(i,columns,ceili(ids.size()/float(columns))).has_point(point):
					_cast({"ban":ids[i]})
					break
		"replace":
			for i in range(battle.model.relics.items.size()):
				if cell_rect(i,2,5).has_point(point):
					_cast({"replace":i})
					break
	queue_redraw()
	return true

func _cast(selection: Dictionary) -> void:
	if busy: return
	var previous_ids: Array = battle.model.relics.items.map(func(item): return item.id)
	var result: Dictionary = battle.model.tarot_effects.cast(battle.model,instance_id,selection)
	if result.has("error"):
		message(result.error)
		return
	choice_type = ""
	busy = true
	var token: int = battle.run_id
	battle.view_phase = "resolving"
	battle.tarot_ui.play_cast(result.id,drop_point)
	battle.fx.z_index = 121
	battle.fx.activate_circle(drop_point,Paint.LILAC,70 if portrait() else 44,0.5)
	battle.fx.burst(drop_point,Paint.GOLD,26,180)
	var targets: Array = []
	for event in result.events:
		var target: Vector2 = battle._player_point() if event.target == -1 else battle.CITY_POINT if event.target == -2 else battle._enemy_impact_point(event.target)
		if target not in targets: targets.append(target)
	if targets.is_empty(): targets.append(battle._player_point())
	battle.fx.cast(3,drop_point,targets,0.35)
	battle._sound("item/bell",1.2,-14)
	battle._show_events(result.events)
	battle._sync_corpses()
	if not result.relic.is_empty(): battle.relic_ui.collect(result.relic,drop_point,50,previous_ids)
	if result.id == "fool":
		for item in battle.model.relics.items: battle.model.relic_activated.emit(item.id)
	if result.id == "hierophant": message(GameText.format("Revelation: %d · next throw",[battle.model.tarot_effects.revelation]))
	if result.id == "empress": message("Two tarot cards added.")
	var finished: bool = await _resolve_steps(token) if not battle.model.tarot_effects.pending_steps.is_empty() else await battle._wait(0.4,token)
	if not finished:
		if battle.run_id == token:
			battle.model.tarot_effects.pending_steps.clear()
			battle.model.tarot_effects.dismiss_repeat()
			busy = false
			battle.fx.z_index = 0
		return
	while battle.relic_ui.pickup.active:
		await get_tree().process_frame
		if not battle._valid_turn(token): return
	battle.fx.z_index = 0
	busy = false
	if _continue_repeat(): return
	_finish_cast()

func _continue_repeat() -> bool:
	var rules = battle.model.tarot_effects
	if rules.pending_repeat.is_empty(): return false
	if not battle.model.outcome().is_empty():
		rules.dismiss_repeat()
		return false
	instance_id = rules.pending_repeat.instance_id
	if rules.pending_repeat.id == "death":
		choice_type = "repeat_target"
	else:
		prepared = rules.prepare(battle.model,instance_id)
		if prepared.has("error"):
			rules.dismiss_repeat() # No eligible target/relic remains for the repeat.
			return false
		choice_type = prepared.get("choice","")
		if choice_type.is_empty():
			_cast({})
			return true
	values = [1,1,1]
	battle.tarot_ui.cast_visual.clear()
	queue_redraw()
	return true

func _finish_cast() -> void:
	var token: int = battle.run_id
	if battle._check_over(): return
	if battle.model.phase in ["enemy","turn_end","round_end"]:
		battle.tarot_ui.close_inventory()
		battle._clear_skill()
		if battle.model.is_city():
			if await battle._resolve_turn_end(token): battle._start_round()
		else: await battle._enemy_phase()
		return
	if battle.model.phase == "frozen":
		battle.tarot_ui.close_inventory()
		battle._clear_skill()
		battle.view_phase = "frozen"
		battle.status_title = "FROZEN"
		return
	battle.view_phase = resume_phase
	# Free actions preserve the rolled skill and update its preview immediately.
	if not battle.model.pending.is_empty():
		battle.result = battle.model.pending.duplicate()
		battle.skill_bubble.roll = battle.result.duplicate()
	while not battle.model.tarot_effects.bonus_chests.is_empty() and battle.view_phase in ["ready","skill"]:
		battle.tarot_ui.close_inventory()
		await battle._reward_sequence(0,false,true)
		if not battle._valid_turn(token): return

func _resolve_steps(token: int) -> bool:
	# Presentation time keeps each application legible during fever / fast-forward.
	var index: int = 0
	while not battle.model.tarot_effects.pending_steps.is_empty():
		var remaining: float = STATUS_STEP_INTERVAL
		while remaining > 0:
			await get_tree().process_frame
			if not battle._valid_turn(token): return false
			if not battle._menus_open(): remaining -= get_process_delta_time()
		var step: Dictionary = battle.model.tarot_effects.resolve_next_step(battle.model)
		if step.is_empty(): break
		var at: Vector2 = battle._player_point() if step.target == -1 else battle._enemy_impact_point(step.target)
		var color: Color = battle.Statuses.ENTRIES[step.status].color
		battle.fx.burst(at,color,8 if battle.reduced else 14,100)
		battle.fx.ring(at,color,34 if portrait() else 22)
		battle._sound("item/bell",1.1+index*0.045,-21)
		# Push earlier Tower labels upwards so rapid hits on one target remain readable.
		for label in battle.fx.floats:
			if label.get("tower_target",-99) == step.target: label.p.y -= label.get("size",24)*1.15
		var first_label: int = battle.fx.floats.size()
		battle._show_events(step.events)
		for i in range(first_label,battle.fx.floats.size()): battle.fx.floats[i].tower_target = step.target
		index += 1
	return battle._valid_turn(token)

func _process(delta: float) -> void:
	if not battle.model.outcome().is_empty() and not choice_type.is_empty():
		choice_type = ""
		battle.model.tarot_effects.dismiss_repeat()
	notice_time = maxf(0,notice_time-delta)
	queue_redraw()

func _label(rect: Rect2, title: String, selected: bool = false, size: int = 22) -> void:
	Paint.panel(self,rect,Color("48434d") if selected else Color("26252e"),Paint.GOLD if selected else Color("69616d"),9)
	Paint.wrap(self,battle.description_font,rect.grow(-8),title,size,Paint.GOLD,true)

func _draw() -> void:
	if choice_type == "repeat_target":
		var prompt := Rect2(62,1040,680,110) if portrait() else Rect2(340,560,600,80)
		Paint.panel(self,prompt,Color("211f29"),Paint.GOLD)
		Paint.wrap(self,battle.description_font,prompt.grow(-12),"Ancient Prophecy: choose another enemy.",26 if portrait() else 20,Paint.GOLD,true)
		for target in battle.model.attack_targets():
			var at: Vector2 = battle._enemy_impact_point(target)
			draw_arc(at,48 if portrait() else 32,0,TAU,32,Paint.GOLD,3)
		_label(cancel_rect(),"Skip repeat")
		return
	if not choice_type.is_empty():
		draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color(0.025,0.025,0.04,0.68))
		var panel: Rect2 = panel_rect()
		Paint.panel(self,panel,Color("211f29"),Color("807889"))
		var title: String = {"magician":"Choose the next three dice","lovers":"Choose odd or even","hanged_man":"Exclude one tarot from future draws","replace":"Choose a relic to replace"}.get(choice_type,"")
		if instance_id < 0: title = GameText.text("Ancient Prophecy")+"\n"+GameText.text(title)
		var title_size: int = (25 if portrait() else 20) if instance_id < 0 else (30 if portrait() else 25)
		Paint.wrap(self,battle.description_font,Rect2(panel.position+Vector2(24,20),Vector2(panel.size.x-48,100)),title,title_size,Paint.GOLD,true)
		match choice_type:
			"magician":
				for i in range(18): _label(cell_rect(i,6,4),str(i%6+1),values[i/6] == i%6+1,34 if portrait() else 28)
				_label(cell_rect(3,1,4),"Confirm",true)
			"lovers":
				_label(cell_rect(0,2,1),"ODD · 1 / 3 / 5",false,26)
				_label(cell_rect(1,2,1),"EVEN · 2 / 4 / 6",false,26)
			"hanged_man":
				var ids: Array = options()
				var columns: int = 4 if portrait() else 6
				for i in range(ids.size()): _label(cell_rect(i,columns,ceili(ids.size()/float(columns))),Catalog.ITEMS[ids[i]].name,false,22 if portrait() else 17)
			"replace":
				Paint.text(self,battle.description_font,panel.position+Vector2(panel.size.x/2,124 if portrait() else 91),Relics.ITEMS[prepared.relic].name,24 if portrait() else 20,Relics.rarity_color(prepared.relic))
				Paint.wrap(self,battle.description_font,Rect2(panel.position+Vector2(28,150 if portrait() else 112),Vector2(panel.size.x-56,122 if portrait() else 66)),Relics.ITEMS[prepared.relic].text,24 if portrait() else 18,Color("eee0d6"),true)
				for i in range(battle.model.relics.items.size()): _label(cell_rect(i,2,5),Relics.ITEMS[battle.model.relics.items[i].id].name,false,24 if portrait() else 18)
		_label(cancel_rect(),"Skip repeat" if instance_id < 0 else "Cancel")
	if notice_time > 0:
		var rect := Rect2(62,1000,680,140) if portrait() else Rect2(340,348,600,100)
		Paint.panel(self,rect,Color("25242d",0.96),Color("8c818e"))
		Paint.wrap(self,battle.description_font,rect.grow(-16),notice,26 if portrait() else 20,Paint.GOLD,true)
