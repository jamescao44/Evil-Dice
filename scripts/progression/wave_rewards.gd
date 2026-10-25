extends RefCounted
const Balance = preload("res://scripts/progression/encounter_balance.gd")
## Reward amounts use fixed cumulative tails, independent of cosmetic chest animation.
const BLOOD_GEMS := "blood_gems"
const RELIC := "relic"
const SHOP := "shop"
const SOULS := "souls"
const TYPES := [BLOOD_GEMS, RELIC, SHOP, SOULS]
const BATTLE_TYPES := [BLOOD_GEMS, RELIC, SOULS]
const LABELS := {BLOOD_GEMS:"Blood Gems", RELIC:"Relic", SHOP:"Shop", SOULS:"Souls"}
const COLORS := {BLOOD_GEMS:Color("fa6086"), RELIC:Color("dfc78d"), SHOP:Color("d5ad74"), SOULS:Color("a5e4ef")}
const AMOUNT_BANDS := {
	BLOOD_GEMS:[Vector2i(333,443),Vector2i(444,554),Vector2i(555,666)],
	SOULS:[Vector2i(10,19),Vector2i(20,29),Vector2i(30,40)]}

## Pick an inclusive amount with exact 10% and 1% upper tails and logarithmic falloff inside each band.
static func amount(rng: RandomNumberGenerator, kind: String, stage: int = 0) -> int:
	if kind not in [BLOOD_GEMS, SOULS]: return 0
	var tail: float = rng.randf()
	var band: Vector2i = AMOUNT_BANDS[kind][2 if tail < 0.01 else 1 if tail < 0.10 else 0]
	var lower: int = band.x
	var upper: int = band.y
	# Integrating 1/x gives a log curve; floor preserves every integer, including the maximum.
	var rolled: int = clampi(floori(exp(lerpf(log(float(lower)),log(float(upper+1)),rng.randf()))),lower,upper)
	return roundi(rolled*Balance.soul_chest_scale(stage)) if kind == SOULS else rolled

## Scale currency receipts from 1x at the minimum to 2x at the maximum; bonuses cap at 2x.
static func amount_scale(kind: String, value: int, stage: int = 0) -> float:
	if not AMOUNT_BANDS.has(kind): return 1.0
	var minimum: int = AMOUNT_BANDS[kind][0].x
	var maximum: int = AMOUNT_BANDS[kind][-1].y
	if kind == SOULS:
		minimum = roundi(minimum*Balance.soul_chest_scale(stage))
		maximum = roundi(maximum*Balance.soul_chest_scale(stage))
	return 1.0+clampf(float(value-minimum)/(maximum-minimum),0,1)
