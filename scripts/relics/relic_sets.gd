extends RefCounted
## Set recipes are data: ordered ingredients, replacement tier bonuses and composite art.
const RECIPES := {
	"meal": {
		"ingredients":["lemon_soda","fries","hamburger","oreo_sundae","fried_chicken"],
		"tiers":[
			{"id":"budget_meal","count":2,"stats":{"base_damage":10.0}},
			{"id":"happy_meal","count":3,"stats":{"base_damage":20.0}},
			{"id":"deluxe_meal","count":4,"stats":{"base_damage":20.0,"damage_add":2.0}},
			{"id":"super_meal","count":5,"stats":{"base_damage":50.0,"damage_factor":2.0}},
		],
	},
}

## Resolve a component or fused item's recipe without knowing a particular set.
static func recipe_for(id: String) -> Dictionary:
	for recipe in RECIPES.values():
		if id in recipe.ingredients or recipe.tiers.any(func(tier): return tier.id == id): return recipe
	return {}

static func is_fused(id: String) -> bool:
	var recipe: Dictionary = recipe_for(id)
	return not recipe.is_empty() and id not in recipe.ingredients

static func ingredients(item: Dictionary) -> Array:
	var recipe: Dictionary = recipe_for(item.id)
	if recipe.is_empty(): return []
	return item.get("ingredients",[]) if is_fused(item.id) else [item.id]

## A new component merges in place without needing an extra inventory slot.
static func can_merge(items: Array, id: String) -> bool:
	var recipe: Dictionary = recipe_for(id)
	return not recipe.is_empty() and id in recipe.ingredients and items.any(func(item): return not ingredients(item).is_empty() and recipe_for(item.id) == recipe)

## Fuse each recipe independently, retaining component order and the earliest slot.
static func fuse(items: Array) -> void:
	for recipe in RECIPES.values():
		var gathered: Array = []
		var slots: Array = []
		for i in range(items.size()):
			if recipe_for(items[i].id) != recipe: continue
			var parts: Array = ingredients(items[i])
			if parts.is_empty(): continue
			slots.append(i)
			for id in parts:
				if id not in gathered: gathered.append(id)
		var tier: Dictionary = {}
		for candidate in recipe.tiers:
			if gathered.size() >= candidate.count: tier = candidate
		if tier.is_empty(): continue
		var first: int = slots[0]
		for i in range(slots.size()-1,-1,-1): items.remove_at(slots[i])
		items.insert(first,{"id":tier.id,"ingredients":gathered,"count":1,"turns":0,"charges":0,"kills":0,"waves":0})

## Ingredients apply in their retained order; only the latest tier bonus follows them.
static func modifiers(item: Dictionary, definitions: Dictionary) -> Array:
	if not is_fused(item.id): return [definitions.get(item.id,{})]
	var result: Array = []
	for id in ingredients(item): result.append(definitions.get(id,{}))
	for tier in recipe_for(item.id).tiers:
		if tier.id == item.id: result.append(tier.stats)
	return result

## Aggregate flat stats; ordered multiplier calculation uses modifiers directly.
static func stats(item: Dictionary, definitions: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for part in modifiers(item,definitions):
		for key in part:
			if part[key] is bool: result[key] = result.get(key,false) or part[key]
			elif key.ends_with("factor"): result[key] = result.get(key,1.0)*part[key]
			else: result[key] = result.get(key,0.0)+part[key]
	return result

## Provide a representative icon only when no owned component data exists yet.
static func display_parts(id: String, item: Dictionary) -> Array:
	if not item.is_empty(): return ingredients(item)
	var recipe: Dictionary = recipe_for(id)
	for tier in recipe.tiers:
		if tier.id == id: return recipe.ingredients.slice(0,tier.count)
	return []
