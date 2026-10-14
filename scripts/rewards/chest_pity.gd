extends RefCounted
## Persistent upgrade droughts; seeded models remain in-memory unless configured.
const Rules = preload("res://scripts/rewards/chest_rules.gd")
var misses: Array = [0,0,0]
var last_misses: Array = [0,0,0]
var save_path: String = ""

func configure(path: String) -> void:
	save_path = path
	misses = [0,0,0]
	var data := ConfigFile.new()
	if not path.is_empty() and data.load(path) == OK:
		for tier in range(3):
			var value: Variant = data.get_value("chest_upgrades",str(tier),0)
			if value is int: misses[tier] = clampi(value,0,Rules.PITY_ATTEMPTS-1)
	last_misses = misses.duplicate()

func roll(rng: RandomNumberGenerator) -> int:
	# Save at commitment, never on presentation clicks or reward collection.
	last_misses = misses.duplicate()
	var tier: int = Rules.roll_wave_tier(rng,misses)
	if not save_path.is_empty():
		var data := ConfigFile.new()
		for i in range(3): data.set_value("chest_upgrades",str(i),misses[i])
		var error: Error = data.save(save_path)
		if error != OK: push_warning("Could not save chest pity: %s" % error_string(error))
	return tier
