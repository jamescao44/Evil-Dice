extends SceneTree
## Navigation dots clear on opening Gemstones; each copy clears only when tapped or dragged.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Markers follow copies through equipment and merges without changing gameplay dictionaries.
func metadata() -> void:
	var gems = preload("res://scripts/dice/gemstone_inventory.gd").new()
	gems.add("burning"); gems.add("burning",1,1,true); gems.add("healing")
	check(gems.unseen_bag == [false,true,false],"An old copy of the same type is not marked new")
	gems.transfer({"bag":1},{"bag":2})
	check(gems.unseen_bag == [false,false,true],"Reordering preserves the exact newly found copy")
	gems.transfer({"bag":2},{"socket":0})
	check(gems.is_new({"socket":0}) and gems.unseen_bag == [false,false],"Drag-to-equip moves the marker into its socket")
	gems.equip(1,"healing"); gems.transfer({"socket":0},{"socket":1})
	check(not gems.is_new({"socket":0}) and gems.is_new({"socket":1}),"Swapping sockets swaps their markers")
	gems.transfer({"socket":1},{"bag":0})
	check(gems.bag_gem(0) == {"id":"burning","level":2} and gems.is_new({"bag":0}),"Socket-to-bag merge preserves a newly found ingredient")
	gems.add("burning",2); gems.transfer({"bag":0},{"bag":1})
	check(gems.bag_gem(0).level == 3 and gems.is_new({"bag":0}),"Bag merges retain newness at the merged location")
	gems.equip(2,"burning",3); gems.unequip(2)
	check(not gems.is_new({"socket":2}) and gems.is_new({"bag":0}),"Tap equip and unequip retain the same marker")
	gems.add("corrosive",1,2,true); gems.equip(3,"corrosive"); gems.equip(4,"corrosive")
	gems.merge(gems.sockets[3],3)
	check(gems.sockets[3].level == 2 and gems.is_new({"socket":3}) and not gems.is_new({"socket":4}),"Merge button carries the marker from both sockets")
	gems.add("corrosive",2); gems.transfer({"bag":1},{"socket":3})
	check(gems.sockets[3].level == 3 and gems.is_new({"socket":3}),"Bag-to-socket merge retains an already-new equipped gem")
	gems.add("freezing",1,1,true); gems.add("freezing")
	gems.merge({"id":"freezing","level":1})
	check(gems.is_new({"bag":gems.order.size()-1}),"Bag merge button preserves a new ingredient")
	var saved: Dictionary = gems.save()
	check(gems.snapshot([3])[0] == {"id":"corrosive","level":3},"Combat snapshots never include notification metadata")
	gems.acknowledge({"bag":0})
	check(not gems.is_new({"bag":0}) and gems.is_new({"socket":3}),"Acknowledging one copy leaves other bag and socket markers alone")
	gems.acknowledge({"socket":3})
	check(not gems.is_new({"socket":3}) and gems.save() == saved,"Socket acknowledgement never changes gameplay data")
	gems.acknowledge_new()
	check(not true in gems.unseen_bag and not true in gems.unseen_sockets and gems.save() == saved,"Acknowledging changes only visual flags")
	gems.restore(saved)
	check(gems.unseen_bag.size() == gems.order.size() and not true in gems.unseen_bag,"Restored existing gems are not treated as new drops")
	var copies = preload("res://scripts/dice/gemstone_inventory.gd").new()
	copies.add("burning",1,2); copies.add("burning",1,1,true)
	copies.equip(0,"burning",1,2)
	check(copies.is_new({"socket":0}) and copies.unseen_bag == [false,false],"Tap equips the selected new copy rather than an older identical one")
	copies.unequip(0); copies.merge({"id":"burning","level":1},-1,2)
	check(copies.order == ["burning:1","burning:2"] and copies.unseen_bag == [false,true],"Merge button consumes the selected copy and leaves unrelated old copies unmarked")

## Exercise the actual modal input path without letting clicks fall through to combat.
func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)

## Optional native captures keep the phone and desktop markers reviewable.
func capture(g, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.inventory_page.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/gemstone-notice-"+name+".png")

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
	g.view_phase = "ready"
	var page = g.inventory_page
	check(not page.new_gemstones,"Fresh inventory has no unread indicator")
	check(not g.model.grant_gemstone("invalid") and not page.new_gemstones,"Rejected grants do not notify")
	g.model.gemstones.add("burning")
	check(g.model.grant_gemstone("burning",1,0) and page.new_gemstones,"Enemy pickup immediately marks the owned gemstone as unread")
	check(not g.model.gemstones.is_new({"bag":0}) and g.model.gemstones.is_new({"bag":1}),"Only the newly acquired duplicate gets an individual dot")
	page._process(0.8)
	check(is_equal_approx(page.gem_notice_brightness(),0.78),"Blink dims gently and never disappears")
	page._process(0.8)
	check(is_equal_approx(page.gem_notice_brightness(),1.0),"Blink returns smoothly to full brightness")
	g.reduced = true; page.gem_notice_age = 0.8
	check(page.gem_notice_brightness() == 1.0,"Reduced effects keep a steady marker")
	g.reduced = false; page.gem_notice_age = 0
	await capture(g,"bag-"+("phone" if phone else "wide"))
	tap(g,page.button_rect().get_center())
	check(page.opened and page.tab == 0 and page.new_gemstones,"Opening the relic tab preserves the gemstone notice")
	await capture(g,"tab-"+("phone" if phone else "wide"))
	tap(g,page.close_rect().get_center())
	check(not page.opened and page.new_gemstones,"Closing without inspecting gemstones preserves the notice")
	g.view_phase = "wave_reward"; page._process(0.1)
	check(page.new_gemstones,"Wave reward transitions do not acknowledge unseen gemstones")
	tap(g,page.button_rect().get_center()); tap(g,page.tab_rect(1).get_center())
	check(page.opened and page.tab == 1 and not page.new_gemstones,"Opening Gemstones clears the bag and tab dots immediately")
	check(g.model.gemstones.is_new({"bag":1}),"Opening the page does not clear individual dots")
	var cell: Rect2 = page.gem_page.bag_rect(1)
	check(page.gem_notice_center(cell) == Vector2(cell.end.x,cell.position.y),"Dot is centered on the bounding-box corner")
	page.gem_notice_age = 0; page._process(0.8)
	check(is_equal_approx(page.gem_notice_brightness(),0.78),"Individual dots keep blinking after the navigation dots clear")
	page.gem_notice_age = 0
	await capture(g,"gems-"+("phone" if phone else "wide"))
	var dot: Vector2 = page.gem_notice_center(cell)+Vector2(2,-2)
	tap(g,dot)
	check(not g.model.gemstones.is_new({"bag":1}) and page.gem_page.selected == {"bag":1},"Tapping outside the cell on its dot acknowledges and selects that copy")
	g.model.grant_gemstone("healing")
	check(not page.new_gemstones and g.model.gemstones.is_new({"bag":2}),"New grants on the open page mark only the individual gem")
	var drag_origin: Vector2 = page.gem_notice_center(page.gem_page.bag_rect(2))+Vector2(2,-2)
	g._handle_click(drag_origin)
	page.motion(drag_origin+Vector2(0,-30))
	check(page.gem_page.dragging and not g.model.gemstones.is_new({"bag":2}),"Starting a drag from a dot clears it immediately")
	g._handle_release(Vector2(20,500))
	check(g.model.gemstones.bag_gem(2).id == "healing" and not g.model.gemstones.is_new({"bag":2}),"Cancelled drags still acknowledge the touched copy")
	g.model.grant_gemstone("corrosive")
	tap(g,page.gem_page.bag_rect(3).get_center())
	check(not g.model.gemstones.is_new({"bag":3}),"Tapping the gem itself also clears its marker")
	g.menu_open = true; g.model.grant_gemstone("freezing")
	check(page.new_gemstones,"A menu covering the gem tab keeps a new grant unread")
	page._process(1)
	check(page.new_gemstones,"Hidden gem tab cannot clear the navigation notice")
	g.menu_open = false; page._process(0)
	check(not page.new_gemstones and g.model.gemstones.is_new({"bag":4}),"Returning to Gemstones clears navigation only")
	tap(g,page.close_rect().get_center())
	check(not page.new_gemstones and g.model.gemstones.is_new({"bag":4}),"Closing the page preserves untouched gemstone dots")
	g.model.gemstones.equip(0,"healing"); g.model.gemstones.unequip(0)
	check(not page.new_gemstones,"Moving owned gems does not masquerade as a new pickup")
	g.model.grant_gemstone("burning")
	check(page.new_gemstones,"A later pickup restores the navigation notice")
	tap(g,page.button_rect().get_center()); tap(g,page.tab_rect(1).get_center()); tap(g,page.tab_rect(0).get_center())
	check(not page.new_gemstones and g.model.gemstones.has_new(),"Switching away keeps individual markers without restoring navigation dots")
	tap(g,page.tab_rect(1).get_center())
	check(g.model.gemstones.is_new({"bag":g.model.gemstones.order.size()-1}),"Untouched copy remains marked when reopening the tab")
	var socket_gem: int = g.model.gemstones.order.size()-1
	g.model.gemstones.equip(1,"burning",1,socket_gem)
	tap(g,page.gem_notice_center(page.gem_page.socket_rect(1))+Vector2(2,-2))
	check(not g.model.gemstones.is_new({"socket":1}),"Equipped gemstone corner dots are also directly tappable")
	g.model.grant_gemstone("healing")
	g._restart(1)
	check(not page.new_gemstones,"Restarting an encounter clears stale notices")
	g.queue_free(); await process_frame

func run() -> void:
	GameText.set_language("zh_CN",false)
	metadata()
	await scene(false)
	await scene(true)
	print("Gemstone notices: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
