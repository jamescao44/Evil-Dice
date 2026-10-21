extends RefCounted
## Reward amounts use fixed cumulative tails, independent of cosmetic chest animation.
const BLOOD_GEMS := "blood_gems"
const RELIC := "relic"
const SHOP := "shop"
const SOULS := "souls"
const TYPES := [BLOOD_GEMS, RELIC, SHOP, SOULS]
const BATTLE_TYPES := [BLOOD_GEMS, RELIC, SOULS]
const LABELS := {BLOOD_GEMS:"Blood Gems", RELIC:"Relic", SHOP:"Shop", SOULS:"Souls"}
const COLORS := {BLOOD_GEMS:Color("fa6086"), RELIC:Color("dfc78d"), SHOP:Color("d5ad74"), SOULS:Color("a5e4ef")}

## Pick an inclusive amount with exact 10% and 1% upper tails and logarithmic falloff inside each band.
static func amount(rng: RandomNumberGenerator, kind: String) -> int:
	if kind not in [BLOOD_GEMS, SOULS]: return 0
	var scale: int = 10 if kind == BLOOD_GEMS else 1
	var tail: float = rng.randf()
	var lower: int = (30 if tail < 0.01 else 20 if tail < 0.10 else 10)*scale
	var upper: int = 40*scale if tail < 0.01 else (30 if tail < 0.10 else 20)*scale-1
	# Integrating 1/x gives a log curve; floor preserves every integer, including the maximum.
	return clampi(floori(exp(lerpf(log(float(lower)),log(float(upper+1)),rng.randf()))),lower,upper)
