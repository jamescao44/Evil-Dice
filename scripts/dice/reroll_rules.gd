extends RefCounted
## Accumulated unchanged single-die rerolls: every second match gets a different raw face.
const FACES := 6

static func guarantee_due(previous: int, rolled: int, same_count: int) -> bool:
	return previous == rolled and (same_count+1)%2 == 0

## Uniformly choose one of the other five faces before item/tarot corrections.
static func corrected_face(rng: RandomNumberGenerator, previous: int, rolled: int, same_count: int) -> int:
	if not guarantee_due(previous,rolled,same_count): return rolled
	var face: int = rng.randi_range(1,FACES-1)
	return face+1 if face >= previous else face

## Exact raw outcomes let the CLI forecast the same rule without sampling game RNG.
static func outcomes(previous: int, same_count: int) -> Array:
	var result: Array = []
	for rolled in range(1,FACES+1):
		var count: int = same_count+int(rolled == previous)
		if guarantee_due(previous,rolled,same_count):
			for face in range(1,FACES+1):
				if face != previous: result.append({"face":face,"same_count":count,"weight":1.0/(FACES*(FACES-1))})
		else: result.append({"face":rolled,"same_count":count,"weight":1.0/FACES})
	return result
