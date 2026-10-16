extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Tarot = preload("res://scripts/tarot/tarot_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func uncached_lines(source: String, font: Font, size: int, width: float) -> PackedStringArray:
	var translated := GameText.text(source)
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(translated,font,size,GameText.language)
	var result := PackedStringArray()
	for i in range(paragraph.get_line_count()):
		var span := paragraph.get_line_range(i)
		result.append(translated.substr(span.x,span.y-span.x).strip_edges())
	return result

func text_checks() -> void:
	var font := GameText.description_font()
	for language in GameText.LANGUAGES:
		GameText.set_language(language,false)
		for source in ["Tap twice to throw. Drag skills to the field, or tap targeted skills to choose a foe. SAVE banks a bonus cast.","First line\nSecond line","冰冻、腐蚀与黑暗；多个状态。", "", "OneVeryLongWordWithoutAnySpaces"]:
			for width in [80.0,220.0,718.0]:
				var expected := uncached_lines(source,font,26,width)
				check(GameText.lines(source,font,26,width) == expected,"New wrapping matches the original Unicode layout")
				var result := GameText.lines(source,font,26,width)
				result.append("caller edit")
				check(GameText.lines(source,font,26,width) == expected,"Callers cannot mutate cached lines")
	font.emit_changed()
	check(GameText._line_cache.is_empty(),"Changed font metrics invalidate wrapped text")
	for i in range(GameText.LINE_CACHE_LIMIT+30): GameText.lines("Value %d" % i,font,26,200)
	check(GameText._line_cache.size() <= GameText.LINE_CACHE_LIMIT,"Dynamic descriptions cannot grow the cache indefinitely")
	GameText.set_language("zh_CN",false)
	check(GameText._line_cache.is_empty(),"Switching language clears wrapped text")
	var translation := Translation.new()
	translation.locale = "zh_CN"
	translation.add_message("Layout cache fixture","旧描述")
	TranslationServer.add_translation(translation)
	check(GameText.lines("Layout cache fixture",font,26,718) == PackedStringArray(["旧描述"]),"External translation is visible")
	translation.add_message("Layout cache fixture","新描述")
	check(GameText.lines("Layout cache fixture",font,26,718) == PackedStringArray(["新描述"]),"Translation edits cannot reuse stale layout")
	TranslationServer.remove_translation(translation)
	GameText.clear_line_cache()

func scene_checks(portrait: bool) -> void:
	var game = Portrait.new() if portrait else Battle.new()
	game.muted = true
	root.add_child(game)
	game.set_process(false)
	var backdrop = game.backdrop
	backdrop.refresh()
	var revision: int = backdrop.revision
	for i in range(100): backdrop.refresh()
	check(backdrop.revision == revision,"Unchanged terrain reuses recorded draw commands")
	game.clock_time += 1
	game.model.hp -= 1
	backdrop.refresh()
	check(backdrop.revision == revision,"Actor animation and health do not rebuild scenery")
	game.background_offset += 1
	backdrop.refresh()
	check(backdrop.revision == revision+1,"Scrolling updates scenery")
	game.visual_stage += 0.25
	backdrop.refresh()
	check(backdrop.revision == revision+2,"Growth updates scenery")
	game.ARENA.size.x -= 1
	backdrop.refresh()
	check(backdrop.revision == revision+3,"Arena geometry updates scenery")
	game._restart(20)
	backdrop.refresh()
	check(backdrop.revision == revision+4,"Loading the city updates scenery")
	game._restart(1)
	backdrop.refresh()
	check(backdrop.revision == revision+5,"Restart restores first-wave scenery")
	check(backdrop.z_index < 0,"Cached scenery remains behind actors and all overlays")
	for i in range(100): game.model.tarots.add(Tarot.ITEMS.keys()[i%22])
	var ui = game.tarot_ui
	for scroll in [-123.4,-1.0,0.0,0.5,9.75,100.0]:
		ui.scroll = scroll
		var expected: Array = range(100)
		expected.sort_custom(func(a,b):
			var da: float = ui.carousel_pose(a).depth
			var db: float = ui.carousel_pose(b).depth
			return da < db if not is_equal_approx(da,db) else a < b)
		check(ui.carousel_order() == expected,"Depth-only sorting preserves carousel layering and tie order")
	ui._process(0.1)
	check(ui.float_levels.is_empty(),"Closed inventory allocates no per-card lift state")
	ui.opened = true
	ui.inspected = 5
	ui._process(0.1)
	check(ui.float_levels.size() == 1 and ui.float_levels[game.model.tarots.items[5].instance_id] > 0,"Inspected card still rises")
	ui.inspected = -1
	ui._process(0.2)
	check(ui.float_levels.is_empty(),"Lowered cards release obsolete lift state")
	game.queue_free()
	await process_frame

func run() -> void:
	text_checks()
	await scene_checks(false)
	await scene_checks(true)
	print("Presentation reuse: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
