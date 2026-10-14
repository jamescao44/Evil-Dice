extends RefCounted
## Reads an editable CSV without relying on Godot's resource importer.
## A complete, validated snapshot replaces the previous one atomically.
var path: String
var locales: Array
var translations: Array[Translation] = []
var last_error: String = ""
var _accepted: String = ""
var _pending: String = ""
var _rejected: String = ""
var _formats := RegEx.create_from_string("%%|%[-+0-9.*]*[diouxXfscv]")

func _init(csv_path: String, supported_locales: Array) -> void:
	path = csv_path
	locales = supported_locales

func refresh(immediate: bool = false) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	# Editors may briefly remove the original during an atomic save.
	if file == null: return false
	var fingerprint: String = file.get_as_text().sha256_text()
	if fingerprint == _accepted:
		_pending = ""
		_rejected = ""
		last_error = ""
		return false
	if fingerprint == _rejected: return false
	# Two identical polls debounce in-place writes, including same-second saves.
	if not immediate and fingerprint != _pending:
		_pending = fingerprint
		return false
	file.seek(0)
	var candidate: Array[Translation] = _read(file)
	file.seek(0)
	if file.get_as_text().sha256_text() != fingerprint:
		_pending = ""
		return false
	if candidate.is_empty():
		_rejected = fingerprint
		return false
	translations = candidate
	_accepted = fingerprint
	_pending = ""
	_rejected = ""
	last_error = ""
	return true

func _read(file: FileAccess) -> Array[Translation]:
	var header := file.get_csv_line()
	header[0] = header[0].trim_prefix("\uFEFF")
	if header[0] != "keys": return _invalid("First column must be 'keys'.")
	var columns: Dictionary = {}
	for locale in locales:
		if header.count(locale) != 1: return _invalid("Expected one '%s' column." % locale)
		var translation := Translation.new()
		translation.locale = locale
		columns[header.find(locale)] = translation
	var keys: Dictionary = {}
	var row_number: int = 1
	while not file.eof_reached():
		var row := file.get_csv_line()
		row_number += 1
		if row.size() == 1 and row[0].is_empty(): continue
		if row.size() != header.size(): return _invalid("Row %d has the wrong number of columns." % row_number)
		var key: String = row[0]
		if key.is_empty() or keys.has(key): return _invalid("Row %d has an empty or duplicate key." % row_number)
		keys[key] = true
		var expected: PackedStringArray = _placeholders(key)
		for column in columns:
			# Match the CSV importer's unescape_translations=true setting.
			var value: String = row[column].c_unescape()
			if value.is_empty(): continue # TranslationServer uses the English fallback.
			if _placeholders(value) != expected: return _invalid("Row %d changes formatting placeholders." % row_number)
			columns[column].add_message(key,value)
	if keys.is_empty(): return _invalid("The CSV contains no translations.")
	var result: Array[Translation] = []
	for translation in columns.values(): result.append(translation)
	return result

func _invalid(message: String) -> Array[Translation]:
	last_error = message
	return []

func _placeholders(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	for token in _formats.search_all(value):
		if token.get_string() != "%%": result.append(token.get_string())
	return result
