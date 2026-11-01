extends RefCounted
## Matching-roll attacks belong to the character, separate from manually cast straight skills.
const PROFILES := {
	2: {"uses":2, "factor":1.0, "area":false, "burn":0},
	3: {"uses":1, "factor":3.0, "pip_base":1.0, "pip_factor":0.1, "area":false, "burn":2},
	4: {"uses":1, "factor":4.0, "pip_base":1.0, "pip_factor":0.1, "area":true, "burn":0},
	5: {"uses":5, "factor":4.0, "area":false, "burn":0},
	6: {"uses":6, "factor":8.0, "area":true, "burn":0},
}

static func profile(count: int) -> Dictionary:
	return PROFILES.get(count,PROFILES[2])

## Resolve each group's pip curve before ordinary combat modifiers and rounding.
static func damage_factor(count: int, face: int) -> float:
	var data: Dictionary = profile(count)
	return (float(data.get("pip_base",0.5))+float(data.get("pip_factor",0.05))*face)*float(data.factor)
