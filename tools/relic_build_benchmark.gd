extends "res://tools/build_comparison.gd"
## Reuse the original ten-turn policy while comparing explicitly budgeted loadouts.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")

## Check acquisition costs before fusion and confirm every input can actually be acquired.
func validate_build(entry: Dictionary) -> void:
	var counts := [0,0,0,0]
	var session = Session.new(1)
	for id in entry.items:
		if not Catalog.ITEMS.has(id):
			failures.append({"build":entry.id,"unknown_item":id}); continue
		counts[mini(3,Catalog.ITEMS[id].rarity)] += 1
		if not session.model.acquire_relic(id): failures.append({"build":entry.id,"acquisition_failed":id})
	var expected: Array = entry.get("budget",[1,3,2,1]).map(func(value): return int(value))
	if counts != expected: failures.append({"build":entry.id,"rarity_budget":counts})
	entry.acquisition_budget = counts
	entry.starting_inventory = session.model.relics.items.duplicate(true)
	for info in session.model.get_signal_list():
		for connection in session.model.get_signal_connection_list(info.name):
			session.model.disconnect(info.name,connection.callable)

## Read a saved comparison plan; preserve the old roll seeds and one-roll policy unchanged.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Expected a JSON plan and output path"); quit(1); return
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var results: Array = []
	for entry in plan.builds: validate_build(entry)
	if not failures.is_empty():
		print(JSON.stringify(failures)); quit(1); return
	for targets in [1,3]:
		for entry in plan.builds:
			for sample in range(1,int(plan.samples)+1):
				var row := probe(entry.family,entry.items,targets,sample)
				row.build = entry.id
				row.family = entry.family
				results.append(row)
			print("Compared ",entry.id," / targets ",targets)
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(JSON.stringify({"plan":plan,"results":results,"failures":failures},"\t"))
	print("Saved ",args[1],"; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
