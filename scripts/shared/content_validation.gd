extends RefCounted
## Development-time catalog checks catch missing references before a new object enters play.
const Gems = preload("res://scripts/dice/gemstone_catalog.gd")
const Enemies = preload("res://scripts/enemies/enemy_catalog.gd")
const Moves = preload("res://scripts/enemies/enemy_skill_catalog.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Statuses = preload("res://scripts/status/status_effect.gd")
const STAT_KEYS := ["damage_add","damage_factor","max_hp_factor","base_damage","base_factor","auto_damage","incoming_factor","three_straight_bonus","combo_uses_add","combo_uses_factor","combo_uses_per_wave","single_target_factor_per_wave","damage_per_kill","kill_damage_cap","wave_rubies","tarot_repeat","always_perfect","no_ultimate","no_treasure"]
const ACTION_TYPES := ["attack","shield","heal","team_shield","team_heal","empower","team_empower","charge","rest","affliction","summon_minions","split_minions","corrosive_heal"]

## Validation is read-only and uses no combat, reward or cosmetic random numbers.
static func all_errors() -> Array:
	var errors := gems(Gems.ITEMS)
	errors.append_array(enemies(Enemies.ITEMS))
	errors.append_array(relics(Relics.ITEMS))
	for id in Moves.ITEMS:
		var move: Dictionary = Moves.ITEMS[id]
		if move.get("type","") not in ACTION_TYPES: errors.append("Unknown enemy action type: "+id)
		if move.get("name","").is_empty(): errors.append("Missing enemy move name: "+id)
	for name in Relics.Sets.RECIPES:
		var recipe: Dictionary = Relics.Sets.RECIPES[name]
		for id in recipe.ingredients:
			if not Relics.ITEMS.has(id): errors.append("Unknown set ingredient: "+id)
		var previous := 0
		for tier in recipe.tiers:
			if not Relics.ITEMS.has(tier.id): errors.append("Unknown set result: "+tier.id)
			if tier.count <= previous or tier.count > recipe.ingredients.size(): errors.append("Invalid set tier: "+tier.id)
			previous = tier.count
	for id in Relics.DISABLED:
		if not Relics.ITEMS.has(id): errors.append("Unknown disabled relic: "+id)
	return errors

## New status/healing gems need metadata and valid hooks, rather than new UI branches.
static func gems(definitions: Dictionary) -> Array:
	var errors: Array = []
	for id in definitions:
		var gem: Dictionary = definitions[id]
		if str(id).contains(":"): errors.append("Reserved separator in gem ID: "+id)
		for field in ["name","description","icon"]:
			if str(gem.get(field,"")).is_empty(): errors.append("Missing gem "+field+": "+id)
		if not gem.get("color") is Color: errors.append("Missing gem color: "+id)
		var levels: Array = gem.get("levels",[])
		if levels.is_empty() or levels.any(func(value): return not value is int or value <= 0): errors.append("Invalid gem tiers: "+id)
		if gem.get("modifier","") not in ["","base","mult","potency","critical"]: errors.append("Unknown gem modifier: "+id)
		if gem.get("recovery","") not in ["","heal","shield"]: errors.append("Unknown gem recovery: "+id)
		for hook in gem.get("attack_hooks",[]):
			if hook not in ["skill","automatic"]: errors.append("Unknown gem attack hook: "+id)
			if gem.get("status",-1) not in Statuses.HARMFUL: errors.append("Unknown gem status: "+id)
	return errors

## Enemy identities, weighted moves and charge releases must resolve independently of row order.
static func enemies(definitions: Dictionary) -> Array:
	var errors: Array = []
	for role in definitions:
		var data: Dictionary = definitions[role]
		var label := str(data.get("name",role))
		if role not in Enemies.Role.values(): errors.append("Unregistered enemy ID: "+label)
		for field in ["hp"]:
			var values: Array = data.get(field,[])
			if values.size() != 2 or values.any(func(value): return (not value is int and not value is float) or not is_finite(float(value)) or value < 0): errors.append("Invalid enemy "+field+": "+label)
		var percent = Enemies.BossBalance.damage_percent(data.name) if data.get("boss",false) else data.get("damage_percent",-1)
		if (not percent is float and not percent is int) or not is_finite(float(percent)) or percent < 0: errors.append("Invalid enemy damage_percent: "+label)
		if data.get("reward_class","normal") not in Enemies.REWARDS: errors.append("Unknown enemy reward class: "+label)
		for pool in ["skills","elite_skills","phase_two_skills"]:
			for entry in data.get(pool,[]):
				if entry.size() != 2 or entry[0] not in Moves.ITEMS or entry[1] <= 0: errors.append("Invalid enemy move: "+label)
		if data.has("charge_turns"):
			if data.charge_turns <= 0 or data.get("release","") not in Moves.ITEMS: errors.append("Invalid charged release: "+label)
		var art: String = data.get("art_file","res://assets/art/fantasy/"+data.get("art","")+".png")
		if not ResourceLoader.exists(art): errors.append("Missing enemy art: "+label)
		if data.has("normal_art") and not ResourceLoader.exists(data.get("normal_art_file","")): errors.append("Missing normal enemy art: "+label)
	return errors

## Relic metadata owns assets, passive numbers and periodic counters used by presentation.
static func relics(definitions: Dictionary) -> Array:
	var errors: Array = []
	for id in definitions:
		var item: Dictionary = definitions[id]
		if item.get("rarity",-1) not in Relics.Rarity.values(): errors.append("Unknown relic rarity: "+id)
		if item.get("requires_set_parts",false) and Relics.Sets.recipe_for(id).is_empty(): errors.append("Missing required set: "+id)
		for key in item.get("stats",{}):
			if key not in STAT_KEYS: errors.append("Unknown passive stat "+key+": "+id)
		for field in ["turn_charge","tarot_generator"]:
			if item.has(field) and item[field].get("period",0) <= 0: errors.append("Invalid relic period: "+id)
		var path: String = "res://assets/art/relics/"+item.get("sprite",id+".png")
		if not Relics.Sets.uses_composite_art(id) and not ResourceLoader.exists(path): errors.append("Missing relic art: "+id)
	return errors
