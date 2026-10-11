extends SceneTree
const Source = preload("res://scripts/translation_csv.gd")
const Home = preload("res://scripts/home.gd")
var checks := 0
var failures := 0
var fixture: String

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func write_rows(path: String, rows: Array) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	for row in rows: file.store_csv_line(PackedStringArray(row))

func rows(pair: String) -> Array:
	return [["keys","en","zh_CN"],["DOUBLES","DOUBLES",pair],["Settings","Options","选项"],["regen 5 for %s turns","regen 5 for %s turns","回复5点，持续%s回合"]]

func parser_checks() -> void:
	write_rows(fixture,rows("初始对子"))
	var source := Source.new(fixture,GameText.LANGUAGES)
	check(source.refresh(true),"CSV loads directly without import metadata")
	var original: Translation = source.translations[0]
	check(not source.refresh(true) and source.translations[0] == original,"Unchanged contents do not rebuild translations")
	write_rows(fixture,rows("保存一"))
	check(not source.refresh(),"First changed snapshot waits for save to stabilize")
	write_rows(fixture,rows("保存二"))
	check(not source.refresh(),"Another save restarts the debounce even within the same timestamp")
	check(source.refresh() and source.translations[0].get_message("DOUBLES") == "保存二","Stable latest save replaces the catalog")
	for invalid in [[],[["keys","en"]],[['keys','en','zh_CN'],['DOUBLES','DOUBLES']],[['keys','en','zh_CN'],['DOUBLES','DOUBLES','对子'],['DOUBLES','DOUBLES','重复']],[['keys','en','zh_CN'],['Damage %d','Damage %d','伤害%s']]]:
		write_rows(fixture,invalid)
		check(not source.refresh(true) and not source.last_error.is_empty(),"Incomplete/invalid CSV is rejected")
		check(source.translations[0].get_message("DOUBLES") == "保存二","Invalid saves retain the entire last good catalog")
	DirAccess.remove_absolute(fixture)
	check(not source.refresh() and source.translations[0].get_message("DOUBLES") == "保存二","Temporarily missing file keeps the displayed text")
	write_rows(fixture+".tmp",rows("原子保存"))
	check(DirAccess.rename_absolute(fixture+".tmp",fixture) == OK,"Editor-style rename save succeeds")
	check(source.refresh(true) and source.last_error.is_empty(),"Corrected save recovers automatically")
	var special: Array = [["\uFEFFkeys","en","zh_CN"],["DOUBLES","Pair","对子，双骰\n第二行"],["POWER %d%%","POWER %d%%","力量 %d%%"]]
	write_rows(fixture,special)
	check(source.refresh(true),"UTF-8 BOM, quoted commas, multiline cells and percent literals are accepted")
	check(source.translations[0].get_message("DOUBLES") == "对子，双骰\n第二行","Quoted multiline text survives parsing")
	write_rows(fixture,[["keys","en","zh_CN"],["DOUBLES","Pair",""]])
	check(source.refresh(true) and source.translations[0].get_message("DOUBLES").is_empty(),"Blank translations are left to the English fallback")

func wait_for_text(key: String, expected: String) -> void:
	var timeout: int = Time.get_ticks_msec()+1800
	while GameText.text(key) != expected and Time.get_ticks_msec() < timeout:
		await process_frame
	check(GameText.text(key) == expected,"Automatic watcher updates '%s' to '%s'" % [key,expected])

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/translation-live-"+label+".png")

func integration_checks() -> void:
	write_rows(fixture,rows("自动对子"))
	GameText.csv_path = fixture
	GameText.set_language("zh_CN",false)
	await wait_for_text("DOUBLES","自动对子")
	check(TranslationServer.translate("DOUBLES") == "自动对子","Standard Godot translations also use the current CSV")
	var home := Home.new()
	home.muted = true
	root.add_child(home)
	home.modal = "skills"
	home.skill_page = 1
	await capture("before")
	write_rows(fixture,rows("保存即更新"))
	await wait_for_text("DOUBLES","保存即更新")
	await capture("after")
	check(home.modal == "skills" and home.skill_page == 1,"Open home panel survives reload")
	write_rows(fixture+".tmp",rows("替换保存"))
	check(DirAccess.rename_absolute(fixture+".tmp",fixture) == OK,"Atomic replacement of an existing CSV works")
	await wait_for_text("DOUBLES","替换保存")
	home.start_battle()
	var g = home.battle
	g.model.set_test_roll([2,2,3])
	g.view_phase = "skill"
	g.skill_bubble.begin(g.model.pending)
	g.skill_bubble.age = 5
	g.menu_open = true
	var rng: int = g.model.rng.state
	var hp: int = g.model.hp
	var roll: Array = g.model.pending.dice.duplicate()
	var edited := rows("战斗对子")
	edited[3][2] = "每回合恢复5点，持续%s回合"
	paused = true
	write_rows(fixture,edited)
	await wait_for_text("DOUBLES","战斗对子")
	check(g.skill_bubble.description_text() == "每回合恢复5点，持续3回合","Already-created skill uses edited dynamic wording")
	check(g.model.rng.state == rng and g.model.hp == hp and g.model.pending.dice == roll and g.menu_open,"Reload preserves battle state, paused menu, and gameplay RNG")
	paused = false
	GameText.set_language("en",false)
	check(GameText.text("Settings") == "Options","Reload updated English too")
	GameText.set_language("zh_CN",false)
	write_rows(fixture,[["keys","en","zh_CN"],["Settings","Options","设置"]])
	await wait_for_text("DOUBLES","DOUBLES")
	check(GameText.text("DOUBLES") == "DOUBLES","Deleted CSV key does not fall back to stale imported Chinese")
	home._return_home()
	home.queue_free()
	await process_frame

func run() -> void:
	fixture = "user://translation-live-test-%d.csv" % OS.get_process_id()
	var original_path: String = GameText.csv_path
	parser_checks()
	await integration_checks()
	GameText.csv_path = original_path
	GameText.reload_translations(true)
	DirAccess.remove_absolute(fixture)
	print("Translation live reload: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
