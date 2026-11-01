extends RefCounted
## Shared fresh-instance state for ordinary acquisition, replacements and set fusion.
const DEFAULTS := {"count":1,"turns":0,"charges":0,"kills":0,"waves":0}

## Deep copies prevent counters or component lists leaking between owned relics.
static func create(id: String, state: Dictionary = {}) -> Dictionary:
	var item: Dictionary = DEFAULTS.duplicate(true)
	item.merge(state.duplicate(true),true)
	item.id = id
	return item
