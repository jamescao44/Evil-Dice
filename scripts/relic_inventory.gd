extends RefCounted
const Catalog = preload("res://scripts/relic_catalog.gd")
const Drops = preload("res://scripts/relic_drop_table.gd")
var items: Array = []

func clear() -> void:
	items.clear()

func remove(index: int) -> Dictionary:
	if index < 0 or index >= items.size(): return {}
	return items.pop_at(index)

func has(id: String) -> bool:
	return index_of(id) >= 0

func index_of(id: String) -> int:
	return items.find_custom(func(item): return item.id == id)

func has_stone(id: String) -> bool:
	return has(id) or has("prismatic_stone")

func move(from: int, to: int) -> bool:
	if from < 0 or from >= items.size() or to < 0 or to >= items.size() or from == to: return false
	var item: Dictionary = items.pop_at(from)
	items.insert(to, item)
	return true

func can_add(id: String) -> bool:
	if id in Catalog.STONES and has("prismatic_stone"): return false
	if id == "codex_page" and has("ancient_codex"): return false
	return Catalog.ITEMS.has(id) and (not has(id) or id == "codex_page")

func draw_one(rng: RandomNumberGenerator, excluded: Array = []) -> String:
	var eligible: Array = []
	for id in Catalog.ITEMS:
		if can_add(id) and id not in excluded: eligible.append(id)
	return Drops.draw(rng,eligible)

func add(id: String, replace_index: int = -1) -> bool:
	if not can_add(id): return false
	var page: int = index_of("codex_page")
	if id == "codex_page" and page >= 0:
		items[page].count += 1
	elif items.size() >= Catalog.MAX_SLOTS:
		if replace_index < 0 or replace_index >= items.size(): return false
		items[replace_index] = _new_item(id)
	else:
		items.append(_new_item(id))
	_fuse()
	return true

func _new_item(id: String) -> Dictionary:
	return {"id":id, "count":1, "turns":0, "charges":0, "kills":0, "waves":0}

func _fuse() -> void:
	var page: int = index_of("codex_page")
	if page >= 0 and items[page].count >= 10 and not has("ancient_codex"):
		items[page] = _new_item("ancient_codex")
	if not has("prismatic_stone") and Catalog.STONES.all(func(id): return has(id)):
		var first: int = items.size()
		for id in Catalog.STONES: first = mini(first, index_of(id))
		items = items.filter(func(item): return item.id not in Catalog.STONES)
		items.insert(first, _new_item("prismatic_stone"))

func offers(rng: RandomNumberGenerator, count: int = 3) -> Array:
	var choices: Array = []
	for slot in range(count):
		var id: String = draw_one(rng,choices)
		if id.is_empty(): break
		choices.append(id)
	return choices
