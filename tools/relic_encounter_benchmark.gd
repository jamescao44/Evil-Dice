extends "res://tools/balance_probe.gd"
## Evaluate percent-HP and execution effects against real encounters, never immortal dummies.

## Hold the six supporting items fixed and swap only the highest-rarity relic.
func loadout(_wave: int, name: String) -> Array:
	return ["worn_dagger","light_sword","steel_marble","oreo_sundae","black_stone","runestone",name]

## Reuse the existing encounter policy, level-from-XP setup and live enemy progression.
func _initialize() -> void:
	perfect_rate = 0.35
	var probes: Array = []
	for wave in [24,30]:
		for build in ["potion_x","hellfire","mithril_blade"]:
			for sample in range(1,41): probes.append(encounter(wave,build,sample))
			print("Encounter ",wave," / ",build)
	var args := OS.get_cmdline_user_args()
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	file.store_string(JSON.stringify({"conditions":{"waves":[24,30],"samples":40,"perfect_probability":perfect_rate,"notes":"Real enemies and boss phases. Same six support relics, different legendary. Start level follows prior combat XP; no tarot or loot. Separate from ten-turn dummy DPS."},"probes":probes,"failures":failures},"\t"))
	print("Saved ",args[0],"; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
