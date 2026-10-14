extends RefCounted
## Layout-independent meter coordinates. One reference pixel is 1/288 of the track.
const WIDTH := 288.0
const PERFECT_HALF_WINDOW := 0.030 # Seconds on either side of a center crossing.
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
	return normal_position_at(elapsed)

static func normal_position_at(time: float) -> float:
	# Keep the same cycle, but soften the center acceleration: peak speed is 24% lower.
	var phase: float = fposmod(time, PERIOD) / PERIOD
	var linear: float = 1.0 - absf(phase * 2.0 - 1.0)
	var eased: float = (1.0 - cos(phase * TAU)) * 0.5
	return lerpf(linear, eased, CENTER_EASING)

static func perfect_tolerance_pixels() -> float:
	# Derive the visible zone from the timing rule, so it cannot drift from judgment.
	return (normal_position_at(PERIOD / 4.0 + PERFECT_HALF_WINDOW) - 0.5) * WIDTH

func sample() -> Dictionary:
	# Stun deliberately disrupts the normal crossing schedule; keep judging its
	# random marker against the same visible zone rather than an invisible clock.
	if erratic: return sample_at(position_ratio())
	var time: float = fposmod(elapsed, PERIOD)
	var error: float = minf(absf(time - PERIOD / 4.0), absf(time - PERIOD * 3.0 / 4.0))
	return _sample(position_ratio(), error <= PERFECT_HALF_WINDOW + 0.000000001)

static func sample_at(ratio: float) -> Dictionary:
	var distance: float = absf(clampf(ratio, 0, 1) - 0.5) * WIDTH
	return _sample(ratio, distance <= perfect_tolerance_pixels() + 0.000001)

static func _sample(ratio: float, perfect: bool) -> Dictionary:
	var distance: float = absf(clampf(ratio, 0, 1) - 0.5) * WIDTH
	# Draw the continuous position even inside the timing window.
	return {"position": clampf(ratio, 0, 1), "power": 1.0 if perfect else 1.0 - distance / (WIDTH * 0.5), "perfect": perfect}
