extends SceneTree
## Shortcut views preserve card identities and share existing cast/gesture rules.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func tap(g, at: Vector2) -> void: g._handle_click(at); g._handle_release(at)
func settle(g) -> void:
	var deadline: int = Time.get_ticks_msec()+8000
	while g.tarot_cast.active() and g.tarot_cast.choice_type.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not g.tarot_cast.busy,"Shortcut cast completes")
func capture(g, label: String) -> void:
	g.queue_redraw(); g.tarot_quick._process(0)
	await process_frame; await process_frame
	if DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/tarot-quick/"+label+".png")
func focus(g,id: String) -> Vector2:
	var q = g.tarot_quick
	var lane: String = Catalog.quick_lane(id)
	var index: int = q.lanes[lane].cards.find_custom(func(item): return item.id == id)
	q.lanes[lane].swipe.reset(index)
	q._process(0.3)
	if lane == "next" and not q.next_open:
		tap(g,q.pose(lane,index).at)
		q._process(0.3)
	var at: Vector2 = q.pose(lane,index).at
	check(q.card_at(at).get("item",{}).get("id","") == id,"The center of "+id+" selects that exact card")
	return at

## Real reroll-mode controls must not allow a left shortcut to start another dice edit.
func check_reroll_shortcuts(g) -> void:
	var q = g.tarot_quick
	var cards: Array = g.model.tarots.items.duplicate(true)
	for version in [g.ControlVersion.V1,g.ControlVersion.V2]:
		g.debug_control_version = version
		focus(g,"magician")
		tap(g,g.DICE_CENTER); q._process(0.1)
		check(g.dice_selection.reroll_mode,"Middle button enters the selected reroll mode")
		var index: int = q.lanes.now.cards.find_custom(func(c): return c.id == "magician")
		var p: Dictionary = q.pose("now",index)
		check(q.lane_shown("now") and p.brightness < 0.5 and p.glow < 0.2,"Left tarot stays visible but dimmed during reroll selection")
		g._handle_click(p.at); g._handle_motion(g.DICE_CENTER); g._handle_release(g.DICE_CENTER)
		check(not g.tarot_cast.active() and not g.tarot_ui.external_drag and g.model.tarots.items == cards,"Disabled left cards cannot inspect, drag, or consume a tarot")
		check(q.lane_enabled("field") and q.lane_enabled("next"),"Reroll selection leaves the other shortcut lanes unchanged")
		tap(g,g.DICE_CENTER); q._process(0.1)
		p = q.pose("now",index)
		check(not g.dice_selection.reroll_mode and not q.card_at(p.at).is_empty() and p.brightness == 1.0,"Done immediately restores left tarot interaction and brightness")
	g.debug_control_version = g.ControlVersion.V1

func motion_checks() -> void:
	var Swipe = preload("res://scripts/tarot/card_swipe.gd")
	var slow = Swipe.new(); var fast = Swipe.new()
	for swipe in [slow,fast]: swipe.friction = 3.2; swipe.release_boost = 0.35; swipe.begin(0)
	slow.move(0.2,100); fast.move(1.2,100)
	slow.release(100); fast.release(100)
	var slow_start: float = slow.position; var fast_start: float = fast.position
	slow.advance(0.5); fast.advance(0.5)
	check(fast.position-fast_start > (slow.position-slow_start)*5,"Fast flicks coast substantially farther than gentle swipes")
	var coarse = Swipe.new(); var fine = Swipe.new()
	coarse.friction = 3.2; fine.friction = 3.2
	coarse.velocity = 7; fine.velocity = 7
	coarse.advance(0.5)
	for i in range(50): fine.advance(0.01)
	check(is_equal_approx(coarse.position,fine.position),"Momentum travel is independent of frame rate")
	fast.begin(200); fast.move(1,210); fast.release(400)
	check(fast.velocity == 0,"Holding before release cancels momentum")
	var audio = preload("res://scripts/tarot/card_scroll_audio.gd").new()
	check(not audio.update(0,false,0),"Initial positioning is silent")
	check(audio.update(1,true,100),"Crossing a card clicks")
	check(not audio.update(4,true,110),"A rapid multi-card jump does not pile up sounds")
	check(not audio.update(4,true,200),"No delayed click backlog")
	check(audio.update(5,true,250),"Coasting to another card clicks after the quiet interval")

func run() -> void:
	GameText.set_language("zh_CN",false)
	motion_checks()
	DirAccess.make_dir_recursive_absolute("res://test-output/tarot-quick")
	for phone in [true,false]:
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.speed = 10; g.set_process_input(false)
		var q = g.tarot_quick
		check(g.dice.all(func(die): return die.z_index > q.z_index),"Quick cards slide below all dice sprites")
		var prefix: String = "phone" if phone else "desktop"
		for id in Catalog.ITEMS: g.model.tarots.add(id)
		q.sync_inventory(); q._process(0.3)
		check(q.lanes.field.cards.size() == 7 and q.lanes.now.cards.size() == 2 and q.lanes.next.cards.size() == 3,"Cards use explicit quick-access categories")
		check(q.lanes.now.cards.any(func(c): return c.id == "judgement") and q.lanes.next.cards.any(func(c): return c.id == "devil"),"Judgement is eligible before rolling alongside Devil")
		check(not q.lanes.field.cards.any(func(c): return c.id == "emperor"),"Reward cards remain in full inventory")
		var rng: int = g.model.rng.state
		var items: Array = g.model.tarots.items.duplicate(true)
		for lane in q.LANES:
			for i in q.visible_indices(lane):
				var p: Dictionary = q.pose(lane,i)
				if p.alpha > 0.2: check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(Rect2(p.at-p.size/2,p.size)),"Shortcut card fits "+prefix+" "+lane)
		var y: float = q.layout.field_position(0).y
		check(q.lanes.field.cards.all(func(c): return is_equal_approx(q.layout.field_position(q.lanes.field.cards.find(c)).y,y)),"Top row shares a centered baseline")
		check(not is_equal_approx(q.pose("field",0).angle,q.pose("field",1).angle),"Cards have distinct idle sway phases")
		check(is_equal_approx(q.layout.left_center().y,g.DICE_CENTER.y) and is_equal_approx(q.layout.right_center().y,g.DICE_CENTER.y),"Both side controls center vertically with the dice")
		check(g.tarot_ui.icon_rect().position.y > g.DICE_CENTER.y+g.DICE_RADIUS*0.65,"Inventory icons sit below side shortcuts")
		g.model.tarot_effects.strength = 3
		g.model.tarot_effects.star_throws = 2
		await capture(g,prefix+"-overview")
		var at: Vector2 = focus(g,"strength")
		g._handle_click(at)
		check(q.field_focus >= 0 and not g._menus_open(),"Touch previews immediately without dimming or pausing battle")
		q._process(0.05)
		var focused: int = q.lanes.field.cards.find_custom(func(c): return c.instance_id == q.field_focus)
		check(q.pose("field",focused).size.x > q.card_size("field").x and q.pose("field",focused).size.x < q.card_size("field").x*2.1,"Enlargement animates swiftly instead of snapping")
		q._process(0.15)
		check(is_zero_approx(q.pose("field",focused).angle),"Enlarged card is upright")
		var stable_y: float = q.pose("field",focused).at.y
		q._process(0.2)
		check(is_equal_approx(q.pose("field",focused).at.y,stable_y),"Focused card does not bob")
		await capture(g,prefix+"-inspect")
		var neighbor: int = (focused+1)%q.lanes.field.cards.size()
		check(q.pose("field",neighbor).brightness < 0.6 and q.pose("field",focused).brightness == 1.0,"Expanded preview dims neighbors while keeping the held card bright")
		var neighbor_at: Vector2 = q.pose("field",neighbor).at
		g._handle_motion(Vector2(neighbor_at.x,q.layout.row_center().y))
		check(q.field_focus == q.lanes.field.cards[neighbor].instance_id and not g.tarot_ui.external_drag,"Sideways scrubbing changes the preview without pulling out a card")
		g._handle_release(Vector2(neighbor_at.x,q.layout.row_center().y))
		check(q.field_focus >= 0,"Releasing in the row retains the preview")
		tap(g,Vector2(20,20)); q._process(0.2)
		check(q.field_focus < 0 and g.model.tarots.items == items,"Empty-space tap collapses preview without spending cards")
		var middle: float = (q.pose("field",0).at.x+q.pose("field",q.lanes.field.cards.size()-1).at.x)/2
		check(is_equal_approx(middle,g.DICE_CENTER.x),"Fixed field row is centered")
		check(g.model.rng.state == rng and g.model.tarots.items == items,"Browsing shortcuts never mutates card rules or randomness")
		var row_y: float = q.pose("field",0).at.y
		g.view_phase = "charging"
		check(not q.lane_shown("field"),"Timing meter hides the top shortcut row")
		check(not q.lane_shown("now") and not q.lane_shown("next"),"Side arcs hide during timing")
		q._process(0.08)
		check(q.lanes.field.visibility > 0 and q.lanes.field.visibility < 1 and q.pose("field",0).at.y > row_y,"Top row moves down while hiding")
		await capture(g,prefix+"-meter")
		g.view_phase = "ready"
		# A field card follows the same targeting/consumption path as the full carousel.
		at = focus(g,"strength")
		var strength: int = g.model.tarot_effects.strength
		g._handle_click(at); g._handle_motion(at-Vector2(0,140))
		check(g.tarot_ui.external_drag and g.tarot_ui.gesture == "card","Quick drag reuses frontmost held-card rendering")
		g._handle_motion(g.ARENA.get_center()); g._handle_release(g.ARENA.get_center())
		await settle(g); q.sync_inventory()
		check(g.model.tarot_effects.strength == strength+1 and not q.lanes.field.cards.any(func(c): return c.id == "strength"),"Field shortcut consumes exactly one actual card")
		# Invalid drops restore their source icon and do not spend a card.
		at = focus(g,"chariot")
		g._handle_click(at); g._handle_motion(at-Vector2(0,140)); g._handle_release(Vector2(20,20))
		check(not g.tarot_ui.external_drag and q.lanes.field.cards.any(func(c): return c.id == "chariot"),"Canceled quick drag restores the card")
		# Left arc tools can be dropped into the dice area; Magician cancellation is free.
		g.model.tarot_effects.star_throws = 0
		g.model.roll_pool(false,[1,2,3,4,5,6])
		while not g.model.roll_attacks.is_empty(): g.model.resolve_roll_attack_step()
		for i in range(6): g.dice[i].face = g.model.dice_turn.values[i]
		q.sync_inventory()
		check(q.lanes.next.cards.size() == 4,"All four upcoming-roll tools can be eligible after a roll")
		for count in [1,2,3]:
			g.model.dice_turn.selected.assign(range(count))
			g.dice_selection._refresh_preview()
			check(q.lane_shown("field") == (count < 3),"Only a connected skill hides the top row; partial selections keep it")
			check(q.lane_shown("now") and q.lane_shown("next"),"Connecting a skill keeps both side lanes visible")
		g.dice_selection.cancel_gesture()
		check(q.lane_shown("field"),"Deselecting restores the top row")
		check_reroll_shortcuts(g)
		at = focus(g,"magician")
		g._handle_click(at); g._handle_motion(at+Vector2(60,0)); g._handle_motion(g.DICE_CENTER); g._handle_release(g.DICE_CENTER)
		check(g.tarot_cast.choice_type == "magician","Dice shortcut opens real Magician options")
		q._process(0.3)
		check(q.LANES.all(func(l): return q.lane_shown(l) and q.lanes[l].visibility == 1),"Using Magician keeps all quick bars visible")
		check(not q.available(),"Visible shortcuts cannot start overlapping tarot actions")
		tap(g,g.DICE_CENTER)
		check(g.tarot_cast.choice_type.is_empty() and not g.tarot_ui.opened and g.model.tarots.items.any(func(c): return c.id == "magician"),"Cancel returns Magician to quick access unspent")
		# Right-side next-roll cards use the same dice-area drop without spending a roll.
		at = focus(g,"devil")
		check(q.next_open and q.next_expansion == 1,"Right stack expands on tap")
		check(q.pose("next",0).size.x > q.card_size("next").x*2,"Upcoming cards enlarge for use")
		await capture(g,prefix+"-expanded")
		tap(g,Vector2(20,20)); q._process(0.3)
		check(not q.next_open and q.next_expansion == 0,"Empty-space tap retracts right hand without consuming")
		at = focus(g,"devil")
		var budget: int = g.model.dice_turn.rolls_left
		g._handle_click(at); g._handle_motion(at-Vector2(60,0)); g._handle_motion(g.DICE_CENTER)
		var held_item: Dictionary = g.model.tarots.items[g.tarot_ui.pressed_card]
		var held_layout: Dictionary = g.tarot_ui.held_layout(held_item)
		check(held_layout.details.position.y > held_layout.at.y+held_layout.size.y/2,"Held description is underneath the card")
		check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(held_layout.details),"Held description stays within the screen")
		await capture(g,prefix+"-held")
		g._handle_release(g.DICE_CENTER)
		await settle(g); q.sync_inventory()
		check(g.model.tarot_effects.devil == 3 and g.model.dice_turn.rolls_left == budget,"Right shortcut queues Devil without rerolling or spending a roll")
		check(not q.lanes.next.cards.any(func(c): return c.id == "devil"),"Consumed right-side card disappears from its actual shortcut")
		# Duplicate projections and permanent copies remain separate until actual expiry.
		var temporary: Dictionary = g.model.tarots.add("strength",true)
		var permanent: Dictionary = g.model.tarots.add("strength")
		q.sync_inventory()
		check(q.lanes.field.cards.filter(func(c): return c.id == "strength").size() == 1,"Duplicate cards share one shortcut")
		check(q.lanes.field.cards.any(func(c): return c.instance_id == temporary.instance_id),"Expiring projections are used first")
		g.model.tarots.remove_instance(temporary.instance_id); q.sync_inventory()
		check(q.lanes.field.cards.any(func(c): return c.instance_id == permanent.instance_id),"Projection expiry preserves the permanent copy")
		for i in range(200): g.model.tarots.add("sun")
		q.sync_inventory()
		check(q.visible_indices("field").size() <= 11,"Large inventories have a bounded draw window")
		# State-only changes refresh eligibility, and inventory ordering never changes shortcuts.
		var old_order: Array = q.lanes.field.cards.map(func(c): return c.id)
		var old_instances: Array = q.lanes.field.cards.map(func(c): return c.instance_id)
		g.model.tarots.items.reverse(); q.sync_inventory()
		check(q.lanes.field.cards.map(func(c): return c.id) == old_order,"Shortcut sorting ignores acquisition order")
		check(q.lanes.field.cards.map(func(c): return c.instance_id) == old_instances,"Reordering preserves the same duplicate representative")
		g.model.dice_turn.values = [1,1,1,2,2,2]
		g.model.dice_turn.locked = [0,1,2]
		g.model.dice_turn.committed = [0,1,2]
		q.sync_inventory()
		check(q.lanes.now.cards.size() == 4 and not q.lanes.now.cards.any(func(c): return c.id == "hermit"),"All four enabled dice tools are eligible; Hermit stays disabled")
		check(not q.lanes.next.cards.any(func(c): return c.id == "lovers"),"Lovers hides with fewer than four unused dice")
		q._process(0.3)
		check(is_equal_approx(q.arc_radius(),g.DICE_RADIUS*0.8),"Left arc uses eighty percent of dice radius")
		q.lanes.now.swipe.reset(0)
		var original: Vector2 = q.pose("now",0).at
		q.lanes.now.swipe.position += q.lanes.now.cards.size()*4
		check(q.pose("now",0).at.is_equal_approx(original),"Left arc wraps infinitely without changing card identity")
		q.lanes.now.swipe.reset(0)
		at = q.pose("now",0).at
		g._handle_click(at); g._handle_motion(at-Vector2(0,70)); g._handle_release(at-Vector2(0,70))
		check(q.lanes.now.swipe.velocity > 0,"Vertical flick scrolls left arc without needing a floating name label")
		var before_coast: float = q.lanes.now.swipe.position
		q._process(0.15)
		check(q.lanes.now.swipe.position > before_coast,"Left arc coasts after release")
		await capture(g,prefix+"-scroll")
		q.lanes.now.swipe.velocity = 0
		g.menu_open = true; q._process(0.08)
		check(q.lanes.now.visibility > 0 and q.lanes.now.visibility < 1,"Side cards animate off-screen instead of disappearing")
		g.menu_open = false; q._process(0.3)
		g.model.dice_turn.locked.clear(); g.model.dice_turn.committed.clear()
		q.sync_inventory()
		check(not q.lanes.now.cards.any(func(c): return c.id == "hermit"),"Hermit hides when no dice are spent")
		# Both inventory sizes and both languages keep all held descriptions within view.
		var language: String = GameText.language
		for locale in GameText.LANGUAGES:
			GameText.set_language(locale,false)
			for id in Catalog.ITEMS:
				var item := {"id":id}
				g.tarot_ui.pointer = g.fx.canvas_size-Vector2(1,1)
				var h: Dictionary = g.tarot_ui.held_layout(item)
				check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(h.details),"Held "+id+" fits "+locale)
		GameText.set_language(language,false)
		# Targeted field cards retain enemy validation and aim feedback.
		at = focus(g,"death")
		g._handle_click(at); g._handle_motion(at-Vector2(0,140))
		check(g._target_focus_requested(),"Targeted quick tarot uses the existing battlefield targeting camera")
		var victim: Vector2 = g._target_rect(0).get_center()
		g._handle_motion(victim); g._handle_release(victim)
		await settle(g)
		check(not g.model.is_enemy_alive(0) and not g.model.tarots.items.any(func(c): return c.id == "death"),"Death shortcut hits its chosen eligible enemy and consumes once")
		g._restart()
		check(q.inspected < 0 and not q.held and q.lanes.field.cards.is_empty(),"Restart clears shortcut gestures and cards")
		g.queue_free(); await process_frame
	print("Tarot quick access: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
