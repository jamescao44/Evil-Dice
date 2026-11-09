extends RefCounted
## Shared gentle enlarge-and-rock gesture for related dice and set items.
const DURATION := 1.15
const GAP := 0.15
const REST := 0.65

## Return extra scale, tilt and glow strength, settling exactly at either end.
static func sample(age: float, reduced: bool = false) -> Vector3:
	if age < 0 or age >= DURATION: return Vector3.ZERO
	var t: float = age/DURATION
	var envelope: float = smoothstep(0.0,0.18,t)*(1.0-smoothstep(0.80,1.0,t))
	return Vector3(0 if reduced else 0.10*envelope,0 if reduced else sin(t*TAU*2)*0.12*envelope,envelope)
