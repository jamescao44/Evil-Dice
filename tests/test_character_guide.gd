extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Preview every form in both languages and layouts without mutating the active run.
func scene(phone: bool, language: String) -> void:
	GameText.set_language(language,false)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g.menu_open = true
	g._handle_click(g.GUIDE_RECT.get_center())
	check(g.guide and not g.menu_open and g.character_guide.selected_form == 0,"Help opens on the earned form")
	var hp: int = g.model.hp
	var rng_state: int = g.model.rng.state
	var original: int = g.evolution.displayed_level
	g.guide_page = 1
	for form in range(3):
		g._handle_click(g.character_guide.option_rect(form).get_center())
		check(g.character_guide.selected_form == form,"Pointer selects each preview form")
		var entries: Array = g.character_guide.entries(true)
		check(entries[0].text.contains("3 Burning" if form else "2 Burning"),"Fireball copy follows the preview form")
		check(entries[1].text.contains("Then apply 2 Burning") == (form >= 1),"Slash gains Burning only in evolved previews")
		check(entries[2].text.contains("3 Burning" if form else "2 Burning"),"Storm copy follows the preview form")
		check(g.character_guide.passive_text().begins_with("Every 3 straight skills") == (form == 2),"Second evolution explains any-straight charging")
		check(g.model.hp == hp and g.model.character_level == 1 and g.model.rng.state == rng_state and g.evolution.displayed_level == original,"Browsing leaves live stats, art and RNG untouched")
		for entry in entries:
			var translated: String = GameText.text(entry.text)
			check(language == "en" or translated != entry.text,"Every evolved skill description is translated")
			var lines: Array = GameText.lines(translated,g.description_font,28 if phone else 22,718 if phone else 504)
			check(lines.size() <= (3 if phone else 4),"Descriptions fit their reserved rows")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://test-output/form-guide-%s-%s-%d.png" % ["portrait" if phone else "landscape",language,form])
	g._handle_click(g.GUIDE_STATUSES.get_center())
	check(g.guide_status_page,"Status help remains available")
	var old: int = g.character_guide.selected_form
	g._handle_click(g.character_guide.option_rect(0).get_center())
	check(g.character_guide.selected_form == old,"Hidden form buttons cannot change state on status page")
	g._handle_click(g.GUIDE_CLOSE.get_center())
	g.model.gain_souls(100)
	g._handle_click(g.GUIDE_RECT.get_center())
	check(g.character_guide.selected_form == 1,"Reopening follows the newly earned evolution")
	g.queue_free(); await process_frame

func run() -> void:
	for phone in [false,true]:
		for language in ["en","zh_CN"]: await scene(phone,language)
	print("Character guide: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
