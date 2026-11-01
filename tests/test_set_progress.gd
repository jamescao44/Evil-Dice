extends SceneTree
## Exercise ownership changes through real inventory fusion, sale and localized descriptions.
const Inventory = preload("res://scripts/relics/relic_inventory.gd")
const Sets = preload("res://scripts/relics/relic_sets.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	for key in Sets.RECIPES:
		var inv = Inventory.new()
		var recipe: Dictionary = Sets.RECIPES[key]
		for part in recipe.ingredients:
			check(Sets.collection_progress(part,inv.items).y == recipe.ingredients.size(),"Set total follows its recipe")
		var count := 0
		for part in recipe.ingredients:
			check(inv.add(part),"Acquire "+part)
			count += 1
			for inspected in recipe.ingredients:
				check(Sets.collection_progress(inspected,inv.items) == Vector2i(count,recipe.ingredients.size()),"Offers count owned ingredients, not the unclaimed offer")
			for item in inv.items:
				check(Catalog.description(item,Callable(),inv.items).contains("%d/%d" % [count,recipe.ingredients.size()]),"Inventory reflects exact retained fusion components")
		check(inv.items.size() == 1,"Completed recipe is a single fused inventory item")
		inv.remove(0)
		check(Sets.collection_progress(recipe.ingredients[0],inv.items).x == 0,"Selling a fusion removes all of its collection progress")
	var inv = Inventory.new()
	inv.add("fries"); inv.add("hamburger")
	GameText.set_language("zh_CN",false)
	check(Catalog.short_description("fried_chicken",GameText.text,inv.items).contains("2/5）"),"Chinese offer uses current two-piece meal count")
	check(not Catalog.short_description("fried_chicken",GameText.text,inv.items).contains("Set:"),"Chinese set hint has no English fallback")
	check(Sets.collection_progress("fries",inv.items+inv.items).x == 2,"Duplicate presentation references do not double-count components")
	check(not Catalog.short_description("bracelet",GameText.text,inv.items).contains("/"),"Unrelated items gain no set hint")
	inv = Inventory.new()
	for i in range(10):
		inv.add("codex_page")
		check(Sets.collection_progress("codex_page",inv.items) == Vector2i(i+1,10),"Stacked pages and final codex preserve progress")
	inv = Inventory.new()
	var stones := ["orange_stone","blue_stone","purple_stone","yellow_stone","green_stone","black_stone"]
	for i in range(stones.size()):
		inv.add(stones[i])
		check(Sets.collection_progress("prismatic_stone",inv.items) == Vector2i(i+1,6),"Stones and final fusion preserve progress")
	print("Set progress: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
