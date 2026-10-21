extends RefCounted
## Rectified sine: two crests per second, lingering at the top with no bottom rest.
static func scale_at(age: float) -> float:
	return 1.0+0.22*absf(sin(age*TAU))
