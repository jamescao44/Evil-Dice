extends RefCounted
## Set recipes are data: ordered ingredients, replacement tier bonuses and composite art.
const RECIPES := {
	"remains": {
		"name":"Remains",
		"ingredients":["unknown_arm","unknown_pelvis","unknown_leg","unknown_sternum","unknown_skull","unidentified_ring"],
		"retain_effects":false, "composite_art":false,
		"tiers":[{"id":"witch_ghost","count":6,"stats":{}}],
	},
	"broken_sword": {
		"name":"Broken Sword",
		"ingredients":["broken_blade","broken_hilt"],
		"retain_effects":false, "composite_art":false,
		"tiers":[{"id":"general_sword","count":2,"stats":{"damage_add":2.0}}],
	},
	"pets": {
		"name":"Pets",
		"ingredients":["pet_bat","pet_lizard","pet_slime","pet_ghost","pet_dragon"],
		"retain_effects":false,
		"composite_art":false,
		"tiers":[{"id":"pet_orb","count":5,"stats":{}}],
	},
	"marbles": {
		"name":"Marbles",
		"ingredients":["glass_marble","steel_marble","gold_marble","magic_slingshot"],
		"retain_effects":false,
		"composite_art":false,
		"tiers":[{"id":"enchanted_missile","count":4,"stats":{"base_damage":10.0,"three_straight_bonus":1.0}}],
	},
	"meal": {
		"name":"Meal",
		"ingredients":["lemon_soda","fries","hamburger","oreo_sundae","fried_chicken"],
		"tiers":[
			{"id":"budget_meal","count":2,"stats":{"damage_add":0.3}},
			{"id":"happy_meal","count":3,"stats":{"damage_add":0.5}},
			{"id":"deluxe_meal","count":4,"stats":{"base_damage":8.0,"damage_add":0.5}},
			{"id":"super_meal","count":5,"stats":{"base_damage":15.0,"damage_factor":1.3}},
		],
	},
}
const COLLECTIONS := {"pets":["pet_bat","pet_lizard","pet_slime","pet_ghost","pet_dragon"]}

## Collection bonuses survive fusion and disappear when the fused item is sold.
static func collection_complete(items: Array, id: String) -> bool:
	return COLLECTIONS.get(id,[]).all(func(part): return items.any(func(item): return item.id == part or part in ingredients(item)))

static func uses_composite_art(id: String) -> bool:
	return is_fused(id) and recipe_for(id).get("composite_art",true)

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
	if not is_fused(item.id): return [item.id]
	if item.has("ingredients"): return item.ingredients
	for tier in recipe.tiers:
		if tier.id == item.id: return recipe.ingredients.slice(0,tier.count)
	return []

## A new component merges in place without needing an extra inventory slot.
static func can_merge(items: Array, id: String) -> bool:
	var recipe: Dictionary = recipe_for(id)
	if recipe.is_empty() or id not in recipe.ingredients: return false
	var gathered: Array = [id]
	for item in items:
		if recipe_for(item.id) == recipe:
			for part in ingredients(item):
				if part not in gathered: gathered.append(part)
	return gathered.size() >= recipe.tiers[0].count

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
		if slots.size() == 1 and items[first].id == tier.id: continue
		for i in range(slots.size()-1,-1,-1): items.remove_at(slots[i])
		items.insert(first,{"id":tier.id,"ingredients":gathered,"count":1,"turns":0,"charges":0,"kills":0,"waves":0})

## Ingredients apply in their retained order; only the latest tier bonus follows them.
static func modifiers(item: Dictionary, definitions: Dictionary) -> Array:
	if item.id == "prismatic_stone":
		var stones: Array = []
		for id in ["orange_stone","blue_stone","purple_stone","yellow_stone","green_stone","black_stone"]:
			stones.append(definitions.get(id,{}))
		stones.append(definitions.get("prismatic_stone",{}))
		return stones
	if not is_fused(item.id): return [definitions.get(item.id,{})]
	var result: Array = []
	if recipe_for(item.id).get("retain_effects",true):
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

## Resolve a localized set hint for components and their final fusion alike.
static func set_label(id: String) -> String:
	if id in ["orange_stone","blue_stone","purple_stone","yellow_stone","green_stone","black_stone","prismatic_stone"]: return "Magic Stones"
	if id in ["codex_page","ancient_codex"]: return "Codex"
	var recipe: Dictionary = recipe_for(id)
	return recipe.get("name", "")
