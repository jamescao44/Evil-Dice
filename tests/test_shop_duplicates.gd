extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	var m = Run.new(77)
	m.shop.open_debug(m)
	m.shop.offers = [{"kind":"relic","id":"bracelet","price":100,"sold":false}]
	m.acquire_relic("bracelet") # Inventory changed after this stock was generated, e.g. Fool.
	check(m.shop.can_buy(m,0),"Existing stock remains purchasable")
	check(not m.shop.buy(m,0).is_empty() and m.relics.items.size()==2,"Purchase creates a second independent copy")
	check(m.relic_base_damage()==10 and not m.relics.can_add("bracelet"),"Both copies apply; ordinary loot stays unique")
	check(m.shop.buy(m,0).is_empty(),"Sold listing cannot pay twice")
	m = Run.new(78)
	m.acquire_relic("fries"); m.acquire_relic("fries",-1,true); m.acquire_relic("hamburger")
	check(m.relics.items.size()==2 and m.relics.items.any(func(i): return i.id=="fries"),"Fusion preserves duplicate ingredients")
	m = Run.new(79)
	for id in m.Relics.Catalog.STONES: m.acquire_relic(id,-1,true)
	check(m.relics.has("prismatic_stone"),"Stone fusion remains functional")
	var repeated := false
	for seed_value in range(1000):
		m = Run.new(seed_value); m.shop.open_debug(m)
		if m.shop.offers.filter(func(o): return o.id=="codex_page").size()>1: repeated=true; break
	check(repeated,"One stock can contain multiple Codex Pages")
	print("Shop duplicate checks: ",failures," failures")
	quit(1 if failures else 0)
