extends RefCounted
## Physical ownership only: copied activations never create collection stacks.
const Sets = preload("res://scripts/relics/relic_sets.gd")
const NAMES := {"food":"Food","biotic":"Biotic","weapon":"Weapon","treasure":"Treasure","artefact":"Artefact","none":"Untyped"}

## Fusions inherit their actual ingredients, not an additional type for the finished item.
static func stacks(item: Dictionary, definitions: Dictionary) -> Dictionary:
	var parts: Array = []
	if item.id == "prismatic_stone": parts = Sets.MAGIC_STONES
	elif item.id == "ancient_codex": return {"artefact":10}
	elif Sets.is_fused(item.id): parts = Sets.ingredients(item)
	if not parts.is_empty():
		var result: Dictionary = {}
		for id in parts:
			var kind: String = definitions.get(id,{}).get("type","none")
			if kind != "none": result[kind] = result.get(kind,0)+1
		return result
	var kind: String = definitions.get(item.id,{}).get("type","none")
	return {} if kind == "none" else {kind:maxi(1,item.get("count",1))}

## Count every currently held component, including stacked pages and duplicate shop purchases.
static func owned(items: Array, definitions: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		var counts: Dictionary = stacks(item,definitions)
		for kind in counts: result[kind] = result.get(kind,0)+counts[kind]
	return result

## A completed set counts once; partial meal tiers and duplicate finished sets do not add more.
static func completed_sets(items: Array) -> int:
	var completed: Dictionary = {}
	for item in items:
		var label: String = Sets.set_label(item.id)
		var progress: Vector2i = Sets.collection_progress(item.id,items)
		if not label.is_empty() and progress.y > 0 and progress.x >= progress.y: completed[label] = true
	return completed.size()

## Keep type hints independent of any hidden awakening conditions.
static func description(item: Dictionary, definitions: Dictionary, translate: Callable) -> String:
	var values: Array = []
	var counts: Dictionary = stacks(item,definitions)
	for kind in NAMES:
		if counts.get(kind,0) > 0: values.append(translate.call(NAMES[kind])+(" ×%d" % counts[kind] if counts[kind] > 1 else ""))
	return translate.call("Type: %s") % ", ".join(values) if not values.is_empty() else ""
