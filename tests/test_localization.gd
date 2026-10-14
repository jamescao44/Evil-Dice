extends SceneTree
const Home = preload("res://scripts/home/home.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Statuses = preload("res://scripts/status/status_catalog.gd")
const Rewards = preload("res://scripts/rewards/reward_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/language-"+label+".png")

func catalog_checks() -> void:
	var csv := FileAccess.open("res://assets/localization/ui.csv",FileAccess.READ)
	csv.get_csv_line()
	var keys: Dictionary = {}
	var placeholders := RegEx.create_from_string("%[-+0-9.]*[dsf]")
	var font: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf").duplicate()
	GameText.prepare_font(font)
	var server := TextServerManager.get_primary_interface()
	var weight_tag: int = server.name_to_tag("wght")
	check(server.font_get_variation_coordinates(font.get_rids()[1]).get(weight_tag) == 600.0,"CJK fallback applies the readable weight to the actual font RID")
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() < 3: continue
		check(not keys.has(row[0]),"No duplicated translation key: "+row[0])
		keys[row[0]] = true
		var patterns: Array = []
		for value in [row[1],row[2]]:
			var tokens: Array = []
			for token in placeholders.search_all(value): tokens.append(token.get_string())
			patterns.append(tokens)
		check(patterns[0] == patterns[1],"Placeholders agree: "+row[0])
		for i in range(2):
			GameText.set_language(["en","zh_CN"][i],false)
			check(GameText.text(row[0]) == row[i+1],"Translation imported: "+row[0])
		for character in row[2]:
			if character.unicode_at(0) > 127:
				check(font.fallbacks[0].has_char(character.unicode_at(0)),"Bundled font covers "+character)
	var sources: Array = [Rules.NORMAL_NAME]
	for group in [Rules.PAIR_NAMES,Rules.PAIR_TEXT,Rules.SPECIAL_NAMES,Rules.SPECIAL_TEXT,Rules.CITY_SPECIAL_TEXT,Home.TABS]: sources.append_array(group)
	for entry in Relics.ITEMS.values()+Statuses.ENTRIES.values()+Rewards.ITEMS:
		sources.append(entry.name)
		sources.append(entry.text)
	for key in sources: check(keys.has(key),"Visible catalog entry has translation: "+key)
	for locale in GameText.LANGUAGES:
		GameText.set_language(locale,false)
		for source in [Relics.ITEMS.prismatic_stone.text,Statuses.ENTRIES[Rules.Status.PLAGUE].text,"AReallyLongWordWithoutSpaces abc 123", "First paragraph.\nSecond paragraph."]:
			var rows := GameText.lines(source,font,22,180)
			check(rows.size() > 1,"Paragraph wraps in "+locale)
			for line in rows: check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x <= 181,"Wrapped line fits in "+locale+": "+line)
	GameText.set_language("zh_CN",false)
	check(GameText.remaining(2) == "剩余2回合。","Chinese grammar handles count templates")
	check(GameText.format("POWER %d%%",70) == "力量 70%","Percent placeholders render correctly")
	check("残页：3 / 10。" in Relics.description({"id":"codex_page","count":3},GameText.text),"Relic counters translate with their description")
	check("Pages: 3 / 10." in Relics.description({"id":"codex_page","count":3}),"Model catalog remains independent of locale")

func scene_checks(portrait: bool) -> void:
	var home := Home.new()
	home.portrait = portrait
	home.muted = true
	root.add_child(home)
	var layout: String = "portrait" if portrait else "landscape"
	for locale in GameText.LANGUAGES:
		GameText.set_language(locale,false)
		home.modal = ""
		await capture(layout+"-"+locale+"-home")
		home._activate(home.settings_rect().get_center())
		check(home.modal == "settings","Settings reachable before battle")
		await capture(layout+"-"+locale+"-home-settings")
		home._activate(home.language_rect(1).get_center())
		check(GameText.language == "en" and GameText.text("Settings") == "Settings","Home switches to English immediately")
		home._activate(home.language_rect(0).get_center())
		check(GameText.language == "zh_CN" and GameText.text("Settings") == "设置","Home switches back to Chinese immediately")
		GameText.set_language(locale,false)
		home.modal = "skills"
		home.skill_page = 1
		await capture(layout+"-"+locale+"-skills")
	home.modal = ""
	home.start_battle()
	var g = home.battle
	g.muted = true
	g.model.acquire_relic("codex_page")
	g.model.acquire_relic("cursed_skull")
	g.model.set_test_roll([5,5,3])
	g.view_phase = "skill"
	g.skill_bubble.begin(g.model.pending)
	g.skill_bubble.age = 5
	g._handle_click(g.MENU_RECT.get_center())
	var state: int = g.model.rng.state
	var hp: int = g.model.hp
	var faces: Array = g.model.pending.dice.duplicate()
	for locale in GameText.LANGUAGES:
		var index: int = GameText.LANGUAGES.find(locale)
		g._handle_click(g._language_rect(index).get_center())
		check(GameText.language == locale and g.menu_open,"Battle language changes keep menu open")
		check(g.model.rng.state == state and g.model.hp == hp and g.model.pending.dice == faces,"Language change preserves current battle and randomness")
		await capture(layout+"-"+locale+"-battle-settings")
		g._handle_click(g.GUIDE_RECT.get_center())
		await capture(layout+"-"+locale+"-guide")
		g._handle_click(g.GUIDE_CLOSE.get_center())
		g._handle_click(g.MENU_RESUME.get_center())
		await capture(layout+"-"+locale+"-battle")
		check(("随机攻击" if locale == "zh_CN" else "random attack") in g.skill_bubble.description_text(),"Existing skill description switches with locale")
		g._handle_click(g.MENU_RECT.get_center())
	g.menu_open = false
	GameText.set_language("zh_CN",false)
	g.view_phase = "wave_reward"
	g.wave_chest.after_chest(3)
	await capture(layout+"-zh_CN-relics")
	g.wave_chest.cancel()
	g.view_phase = "ready"
	g.model.begin_round()
	g.model.enemies[0].intent = {"type":"attack","amount":10,"attribute":Rules.Status.Attribute.ICE}
	g.inspecting_enemy = 0
	await capture(layout+"-zh_CN-intent")
	g.inspecting_enemy = -1
	home._return_home()
	check(GameText.language == "zh_CN" and home.visible,"Locale survives return to home")
	home.queue_free()
	await process_frame

func run() -> void:
	# Never modify the real player's preferences during tests or captures.
	GameText.settings_path = "user://localization-test-%d.cfg" % OS.get_process_id()
	TranslationServer.set_locale("en")
	GameText.language = ""
	GameText.initialize()
	check(GameText.language == "zh_CN","New install defaults to Chinese regardless of OS language")
	var settings := ConfigFile.new()
	settings.set_value("fixture","keep",17)
	settings.save(GameText.settings_path)
	GameText.set_language("en")
	GameText.language = ""
	GameText.initialize()
	check(GameText.language == "en","Language choice survives reloading saved settings")
	settings.load(GameText.settings_path)
	check(settings.get_value("fixture","keep") == 17,"Saving language preserves unrelated settings")
	settings.set_value("interface","language","unsupported")
	settings.save(GameText.settings_path)
	GameText.language = ""
	GameText.initialize()
	check(GameText.language == "zh_CN","Unsupported saved locale falls back to Chinese")
	GameText.set_language("unsupported")
	check(GameText.language == "zh_CN","Invalid locale cannot change the current language")
	catalog_checks()
	await scene_checks(false)
	await scene_checks(true)
	DirAccess.remove_absolute(GameText.settings_path)
	print("Localization: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
