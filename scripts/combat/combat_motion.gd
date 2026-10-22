extends RefCounted
## Cosmetic actor movement. Targets use combat event IDs; the city (-2) stays fixed.
const HIT_DURATION := 0.26
const HIT_PUSH := 0.045
const BLOCK_DURATION := 0.38
const GROWTH_POSES := [Vector2.ONE,Vector2(0.94,1.12),Vector2(1.08,0.91),Vector2(1.06,1.06),Vector2.ONE]
const GROWTH_TIMES := [0.0,0.18,0.36,0.65,1.0]
var hits: Dictionary = {}
var blocked: Dictionary = {}
var attacks: Dictionary = {}
const ATTACK_DURATION := 0.32

## Brief upward hop and soft landing for an actor launching an attack.
func attack(target: int) -> void:
	if target >= -1: attacks[target] = 0.0

func attack_bob(target: int, side: float, reduced: bool = false) -> float:
	if reduced or not attacks.has(target): return 0.0
	return -sin(PI*attacks[target]/ATTACK_DURATION)*clampf(side*0.035,3,9)

static func growth_scale(progress: float, reduced: bool = false) -> Vector2:
	if reduced: return Vector2.ONE
	var time: float = clampf(progress,0,1)
	for i in range(1,GROWTH_TIMES.size()):
		if time <= GROWTH_TIMES[i]:
			return GROWTH_POSES[i-1].lerp(GROWTH_POSES[i],smoothstep(GROWTH_TIMES[i-1],GROWTH_TIMES[i],time))
	return Vector2.ONE

func clear() -> void:
	hits.clear()
	blocked.clear()
	attacks.clear()

func hit(target: int, strength: float = 1.0) -> void:
	if target >= -1: hits[target] = {"age":0.0,"strength":strength}

func skip(target: int) -> void:
	if target >= 0: blocked[target] = 0.0

func advance(delta: float) -> void:
	for target in attacks.keys():
		attacks[target] += delta
		if attacks[target] >= ATTACK_DURATION: attacks.erase(target)
	for target in hits.keys():
		hits[target].age += delta
		if hits[target].age >= HIT_DURATION: hits.erase(target)
	for target in blocked.keys():
		blocked[target] += delta
		if blocked[target] >= BLOCK_DURATION: blocked.erase(target)

func offset(target: int, side: float, clock: float, cannot_act: bool = false, reduced: bool = false) -> float:
	if reduced or target < -1: return 0.0
	var amount: float = 0.0
	if hits.has(target):
		var age: float = hits[target].age
		var pulse: float = smoothstep(0,HIT_PUSH,age) if age < HIT_PUSH else 1.0-smoothstep(HIT_PUSH,HIT_DURATION,age)
		amount = pulse*clampf(side*0.06,3,11)*hits[target].strength*(-1 if target == -1 else 1)
	elif target >= 0 and (cannot_act or blocked.has(target)):
		var time: float = blocked[target] if blocked.has(target) else clock+target*0.13
		var fade: float = 1.0-blocked[target]/BLOCK_DURATION if blocked.has(target) else 0.7
		amount = sin(time*TAU*8)*clampf(side*0.025,2,5)*fade
	return amount
