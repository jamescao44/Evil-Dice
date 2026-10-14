extends RefCounted
## Shared chest economy. Tier 0 is a wave chest, not an earned Perfect tier.
const NAMES := ["Normal Chest", "Perfect Chest", "Greed Chest", "Ultra Chest"]
const COLORS := [Color("eee0b9"), Color("ffd773"), Color("ce82ff"), Color("ff6977")]
const COUNTS := [1, 1, 3, 5]
const CRYSTALS := [30, 50, 70, 100]
const THRESHOLDS := [0, 3, 8, 15]
const MIN_RARITY := [0, 1, 2, 3]
const UPGRADE_CHANCE := 0.25
const PITY_ATTEMPTS := 4
const TAROT_PRICE := 30

static func tier_for_progress(progress: int) -> int:
	for tier in range(3, 0, -1):
		if progress >= THRESHOLDS[tier]: return tier
	return 0

static func roll_wave_tier(rng: RandomNumberGenerator, misses: Array = []) -> int:
	# Only attempted tiers advance. A successful upgrade resets its own drought.
	if misses.is_empty(): misses = [0,0,0]
	var tier: int = 0
	while tier < 3:
		if misses[tier] < PITY_ATTEMPTS-1 and rng.randf() >= UPGRADE_CHANCE:
			misses[tier] += 1
			break
		misses[tier] = 0
		tier += 1
	return tier
