extends "res://tools/current_balance.gd"
## Paired item probes use real CLI decisions and never touch player saves or pity.
var audit_build := []

func loadout(_wave: int, _name: String) -> Array:
	return audit_build

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0]
	var rows := []
	for wave in [3,7,12,19]:
		for id in ["bare","bracelet","magic_slingshot","unknown_arm","unknown_skull","tissue_pack","pet_bat","bloodstone","contract","steel_sword","royal_dagger","pet_ghost","pet_dragon","mithril_blade","black_chip","red_chip","blue_chip","mysterious_seed","fries","meals","copy"]:
			audit_build = [] if id == "bare" else [id]
			if id == "meals": audit_build = ["lemon_soda","fries","hamburger","oreo_sundae","fried_chicken"]
			if id == "copy": audit_build = ["magic_slingshot","disguise_mask","ancient_tentacle"]
			for seed_value in SEEDS.slice(0,6): rows.append(encounter(wave,id,seed_value))
		print("Item audit wave ",wave)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"probes":rows,"failures":failures},"\t"))
	print("Saved ",rows.size()," probes; failures=",failures.size())
	quit(1 if not failures.is_empty() else 0)
