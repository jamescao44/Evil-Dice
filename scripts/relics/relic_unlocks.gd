extends RefCounted
## Chapter discoveries persist until a level checkpoint restores its earlier pool.
var chapter: String = "chapter_1"
var chapters: Dictionary = {}
var save_path: String = ""

## A future chapter selects a separate pool without erasing earlier discoveries.
func configure(path: String, chapter_id: String = "chapter_1") -> void:
	save_path = path
	chapter = chapter_id
	var data := ConfigFile.new()
	if path.is_empty() or data.load(path) != OK: return
	var stored: Variant = data.get_value("relics","chapters",{})
	if stored is Dictionary: chapters = stored.duplicate(true)

func has(id: String) -> bool:
	return id in chapters.get(chapter,[])

## Save discoveries immediately; level-entry snapshots remain authoritative on replay.
func unlock(id: String) -> void:
	if has(id): return
	if not chapters.has(chapter): chapters[chapter] = []
	chapters[chapter].append(id)
	_save()

## Rewind this chapter's pool with its build, leaving other chapters untouched.
func restore(items: Array) -> void:
	chapters[chapter] = items.duplicate()
	_save()

## Persistence is opt-in so model tests never modify a player's chapter pool.
func _save() -> void:
	if save_path.is_empty(): return
	var data := ConfigFile.new()
	data.set_value("relics","chapters",chapters)
	var error: Error = data.save(save_path)
	if error != OK: push_warning("Could not save relic discovery: "+error_string(error))
