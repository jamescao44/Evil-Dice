extends RefCounted
## Layout-independent meter coordinates. One reference pixel is 1/288 of the track.
const WIDTH := 288.0
const PERFECT_TOLERANCE := 2.0
const PERIOD := 2.4
var elapsed: float = 0.0

func reset() -> void:
	elapsed = 0.0

func advance(delta: float) -> void:
	elapsed = fposmod(elapsed + maxf(0, delta), PERIOD)

func position_ratio() -> float:
	# Cosine easing: slow at the ends, fastest through the center, no frame stepping.
	return (1.0 - cos(elapsed * TAU / PERIOD)) * 0.5

func sample() -> Dictionary:
	return sample_at(position_ratio())

static func sample_at(ratio: float) -> Dictionary:
	var distance: float = absf(clampf(ratio, 0, 1) - 0.5) * WIDTH
	var perfect: bool = distance <= PERFECT_TOLERANCE + 0.000001
	# Snap only the displayed position; the continuous clock still determines the hit.
	return {"position": 0.5 if perfect else clampf(ratio, 0, 1), "power": 1.0 if perfect else 1.0 - distance / (WIDTH * 0.5), "perfect": perfect}
