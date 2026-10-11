class_name GameText
extends RefCounted
## Presentation-only localization. Gameplay IDs, catalogs and saved runs stay language-neutral.
const DEFAULT_LANGUAGE := "zh_CN"
const LANGUAGES := ["zh_CN", "en"]
const LANGUAGE_NAMES := ["简体中文", "English"]
const CsvSource = preload("res://scripts/translation_csv.gd")
static var language: String = ""
static var settings_path: String = "user://settings.cfg"
static var csv_path: String = "res://assets/localization/ui.csv"
static var _csv: CsvSource
static var _live_translations: Array[Translation] = []
static var _reported_error: String = ""
static var _description_font: FontFile

static func initialize() -> void:
	if OS.has_feature("editor") and _csv == null: reload_translations(true)
	if not language.is_empty(): return
	var settings := ConfigFile.new()
	settings.load(settings_path)
	var saved: String = str(settings.get_value("interface", "language", DEFAULT_LANGUAGE))
	set_language(saved if saved in LANGUAGES else DEFAULT_LANGUAGE, false)

static func reload_translations(immediate: bool = false) -> bool:
	# Exported games use the bundled, imported translations and never watch files.
	if not OS.has_feature("editor"): return false
	if _csv == null or _csv.path != csv_path:
		_csv = CsvSource.new(csv_path,LANGUAGES)
	var changed: bool = _csv.refresh(immediate)
	if not _csv.last_error.is_empty() and _csv.last_error != _reported_error:
		push_warning("Translations unchanged: %s (%s)" % [_csv.last_error,csv_path])
	_reported_error = _csv.last_error
	if not changed: return false
	# Remove this catalog's compiled versions too, so deleted keys cannot revive
	# stale imported text. Other translation catalogs remain registered.
	for locale in LANGUAGES:
		var compiled_path: String = "res://assets/localization/ui.%s.translation" % locale
		if ResourceLoader.exists(compiled_path):
			TranslationServer.remove_translation(load(compiled_path))
	for previous in _live_translations: TranslationServer.remove_translation(previous)
	_live_translations = _csv.translations
	for translation in _live_translations: TranslationServer.add_translation(translation)
	return true

static func set_language(value: String, persist: bool = true) -> void:
	if value not in LANGUAGES: return
	language = value
	TranslationServer.set_locale(value)
	if persist:
		var settings := ConfigFile.new()
		settings.load(settings_path)
		settings.set_value("interface", "language", value)
		var error := settings.save(settings_path)
		if error != OK: push_warning("Could not save language setting: %s" % error_string(error))

static func text(source: String) -> String:
	initialize()
	return TranslationServer.translate(source)

static func format(source: String, values: Variant) -> String:
	return text(source) % values

static func prepare_font(font: FontFile, scalable: bool = false) -> void:
	initialize()
	# Bundle CJK glyphs so web/mobile never depend on installed system fonts.
	var chinese := FontVariation.new()
	var cjk: FontFile = preload("res://assets/fonts/NotoSansSC.ttf").duplicate()
	if scalable:
		cjk.multichannel_signed_distance_field = true
		cjk.msdf_size = 96
	chinese.base_font = cjk
	var weight_tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	chinese.variation_opentype = {weight_tag: 600.0}
	font.fallbacks = [chinese]

static func description_font() -> FontFile:
	if _description_font == null:
		# Keep pixel letterforms; a finer distance-field atlas preserves clean edges at phone scale.
		_description_font = preload("res://assets/fonts/Silkscreen-Regular.ttf").duplicate()
		_description_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_description_font.multichannel_signed_distance_field = true
		_description_font.msdf_size = 96
		prepare_font(_description_font,true)
	return _description_font

static func lines(source: String, font: Font, size: int, width: float) -> PackedStringArray:
	var translated := text(source)
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(translated, font, size, language)
	var result := PackedStringArray()
	for i in range(paragraph.get_line_count()):
		var span := paragraph.get_line_range(i)
		result.append(translated.substr(span.x, span.y - span.x).strip_edges())
	return result

static func remaining(amount: int, unit: String = "turn") -> String:
	# Full plural templates let translators choose their own word order.
	var singular := {"turn":"%d turn remaining.", "throw":"%d throw remaining.", "stack":"%d stack remaining."}
	var plural := {"turn":"%d turns remaining.", "throw":"%d throws remaining.", "stack":"%d stacks remaining."}
	return format(singular[unit] if amount == 1 else plural[unit], amount)
