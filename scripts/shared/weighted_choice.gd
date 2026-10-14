extends RefCounted
## Shared weighted draws. Zero/negative entries are excluded; callers own RNG.
static func pick(random: RandomNumberGenerator, weights: Array) -> int:
	var total: float = 0
	for weight in weights: total += maxf(0, float(weight))
	if total <= 0: return -1
	var cursor: float = random.randf() * total
	var last: int = -1
	for i in range(weights.size()):
		var weight: float = maxf(0, float(weights[i]))
		if weight <= 0: continue
		last = i
		cursor -= weight
		if cursor < 0: return i
	return last
