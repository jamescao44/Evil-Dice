extends SceneTree
## Exercise the sort button in both layouts without consuming or changing cards.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
 if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for portrait in [false,true]:
  root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
  var game = Portrait.new() if portrait else Battle.new()
  root.add_child(game); game.muted = true
  var ui = game.tarot_ui
  for language in ["en","zh_CN"]:
   GameText.set_language(language,false)
   game.model.tarots.clear()
   for id in ["world","magician","fool","magician"]: game.model.tarots.add(id)
   game.model.tarots.add("magician",true)
   var original = game.model.tarots.items.duplicate(true)
   ui.opened = true; ui.expansion = 1; ui.inspected = 2
   ui.scroll = 2; ui.scroll_target = 3; ui.swipe.velocity = 4
   check(Rect2(Vector2.ZERO,Vector2(root.content_scale_size)).encloses(ui.sort_rect()),"Sort button stays on screen")
   check(ui.click(ui.sort_rect().get_center()) and ui.release(ui.sort_rect().get_center()),"Sort click and release are consumed")
   check(ui.inspected == -1 and ui.swipe.velocity == 0 and ui.scroll == 0,"Sorting clears stale inspection and inertia")
   check(game.model.tarots.items.size() == original.size(),"Sorting preserves card count")
   for item in original: check(game.model.tarots.items.has(item),"Sorting preserves instances and projection flags")
   var names = game.model.tarots.items.map(func(item): return GameText.text(ui.Catalog.ITEMS[item.id].name))
   for i in range(1,names.size()): check(names[i-1].naturalnocasecmp_to(names[i]) <= 0,"Displayed names are sorted")
   var copies = game.model.tarots.items.filter(func(item): return item.id == "magician").map(func(item): return item.instance_id)
   check(copies == [2,4,5],"Duplicate cards retain acquisition order")
   check(not ui.held and ui.pressed_card == -1,"Sorting cannot start a card cast")
  game.queue_free(); await process_frame
 print("Tarot sort: %d failures" % failures)
 quit(1 if failures else 0)
