extends RefCounted
## Layout-independent meter coordinates. One reference pixel is 1/288 of the track.
const WIDTH := 288.0
const PERFECT_TOLERANCE := 4.0
const PERIOD := 2.4 / 0.9 # Ten percent slower across the whole timing curve.
const CENTER_EASING := 0.35
var elapsed: float = 0.0
var erratic: bool = false
var motion_rng := RandomNumberGenerator.new()
var segment_age: float = 0.0
var segment_duration: float = 0.2
var segment_from: float = 0.0
var segment_to: float = 1.0

func reset(stunned: bool = false) -> void:
	elapsed = 0.0
	erratic = stunned
	segment_age = 0.0
	if erratic:
		motion_rng.randomize() # Meter motion must never consume combat RNG.
		segment_from = motion_rng.randf()
		_next_segment()

func _next_segment() -> void:
	segment_to = motion_rng.randf()
	if absf(segment_to-segment_from) < 0.25: segment_to = 1.0-segment_from
	segment_duration = motion_rng.randf_range(0.10, 0.36)

func advance(delta: float) -> void:
	elapsed = fposmod(elapsed + maxf(0, delta), PERIOD)
	if erratic:
		segment_age += maxf(0, delta)
		while segment_age >= segment_duration:
			segment_age -= segment_duration
			segment_from = segment_to
			_next_segment()

func position_ratio() -> float:
	if erratic: return lerpf(segment_from, segment_to, clampf(segment_age/segment_duration,0,1))
	# Keep the same cycle, but soften the center acceleration: peak speed is 24% lower.
	var phase: float = fposmod(elapsed, PERIOD) / PERIOD
	var linear: float = 1.0 - absf(phase * 2.0 - 1.0)
	var eased: float = (1.0 - cos(phase * TAU)) * 0.5
	return lerpf(linear, eased, CENTER_EASING)

func sample() -> Dictionary:
	return sample_at(position_ratio())

static func sample_at(ratio: float) -> Dictionary:
	var distance: float = absf(clampf(ratio, 0, 1) - 0.5) * WIDTH
	var perfect: bool = distance <= PERFECT_TOLERANCE + 0.000001
	# Snap only the displayed position; the continuous clock still determines the hit.
	return {"position": 0.5 if perfect else clampf(ratio, 0, 1), "power": 1.0 if perfect else 1.0 - distance / (WIDTH * 0.5), "perfect": perfect}
