extends RefCounted
## One cosmetic clock links each useful shop set piece with its owned companions.
const Sets = preload("res://scripts/relics/relic_sets.gd")
const Motion = preload("res://scripts/shared/combination_hint.gd")
var groups: Array = []
var signature: Array = []
var age: float = 0.0
var enabled: bool = false
var reduced: bool = false

## Drop stale merchandise and timing when leaving or refreshing a shop.
func reset() -> void:
	groups.clear()
	signature.clear()
	age = 0
	enabled = false

## Cache set membership; counters, prices and gameplay RNG never affect the hint order.
func advance(delta: float, stock, items: Array, can_animate: bool, less_motion: bool) -> void:
	var offers: Array = stock.offers.duplicate()
	if not stock.divination_used and not stock.gift.is_empty(): offers.append(stock.gift)
	var next: Array = [offers.map(func(o): return [o.get("kind",""),o.get("id",""),o.get("sold",false)]),items.map(func(i): return [i.id,i.get("ingredients",[]),i.get("count",1)])]
	if signature != next:
		signature = next.duplicate(true)
		groups.clear()
		age = 0
		for i in range(offers.size()):
			var offer: Dictionary = offers[i]
			if offer.get("kind","") != "relic" or offer.get("sold",false): continue
			var id: String = offer.get("id","")
			var label: String = Sets.set_label(id)
			if label.is_empty(): continue
			var progress: Vector2i = Sets.collection_progress(id,items)
			if progress.x == 0 or progress.x >= progress.y: continue
			# Existing unique ingredients cannot advance a set, even inside a partial fusion.
			if id != "codex_page" and items.any(func(item): return item.id == id or id in Sets.ingredients(item)): continue
			var slot: int = i if i < stock.offers.size() else stock.GIFT_SLOT
			var group_index: int = groups.find_custom(func(group): return group.set == label)
			if group_index >= 0:
				groups[group_index].slots.append(slot)
				continue
			var owned: Array = []
			for index in range(items.size()):
				if Sets.set_label(items[index].id) == label: owned.append(index)
			groups.append({"set":label,"slots":[slot],"owned":owned})
	enabled = can_animate
	reduced = less_motion
	if enabled and not groups.is_empty(): age = fmod(age+delta,Motion.REST+groups.size()*(Motion.DURATION+Motion.GAP))

## Each set hints once per cycle, ordered by its first shop listing; gifts join their set.
func current_group() -> Dictionary:
	if not enabled or groups.is_empty() or age < Motion.REST: return {}
	var slot: int = floori((age-Motion.REST)/(Motion.DURATION+Motion.GAP))
	var elapsed: float = fmod(age-Motion.REST,Motion.DURATION+Motion.GAP)
	return groups[slot] if slot < groups.size() and elapsed < Motion.DURATION else {}

## All members of the active match share exactly the same pose and light envelope.
func pose() -> Vector3:
	if current_group().is_empty(): return Vector3.ZERO
	return Motion.sample(fmod(age-Motion.REST,Motion.DURATION+Motion.GAP),reduced)

func offer_pose(slot: int) -> Vector3:
	return pose() if slot in current_group().get("slots",[]) else Vector3.ZERO

func owned_pose(index: int) -> Vector3:
	return pose() if index in current_group().get("owned",[]) else Vector3.ZERO
