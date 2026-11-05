extends RefCounted
## A handful of baked emission packets replace hundreds of independently updated sparks.
const Sprites = preload("res://scripts/effects/baked_particles.gd")
const INTERVALS := {"storm":0.35,"beam":0.4}
const VARIANTS := {"storm":3,"beam":2}
const TAILS := {"storm":0.7,"beam":1.15}
const MAX_PACKETS := 5

## Dictionary state survives spell-tail duplication without sharing mutable emitters.
static func create(kind: String, seed_value: int, intensity: float = 1.0) -> Dictionary:
	return {"kind":kind,"seed":posmod(seed_value,VARIANTS[kind]),"clock":0.0,"next":0.0,"serial":0,"emitting":false,"stopped_at":-1.0,"packets":[],"intensity":intensity}

## Stop adding packets immediately and bound the final fade by the original spark lifetime.
static func advance(state: Dictionary, delta: float, emitting: bool) -> void:
	var previous: float = state.clock
	state.clock += delta
	var duration: float = Sprites.Library.CLIPS[state.kind+"_0"].duration
	state.packets = state.packets.filter(func(p): return state.clock-p.born < duration)
	if emitting and not state.emitting:
		state.next = previous
		state.stopped_at = -1.0
	elif not emitting and state.emitting: state.stopped_at = previous
	state.emitting = emitting
	if state.stopped_at >= 0 and state.clock-state.stopped_at >= TAILS[state.kind]: state.packets.clear()
	if not emitting or delta <= 0: return
	# Jump over fully expired packets after a hitch rather than replaying stale births.
	var interval: float = INTERVALS[state.kind]/maxf(0.1,state.intensity)
	if state.clock-state.next > duration:
		var skipped: int = floori((state.clock-state.next-duration)/interval)
		state.next += skipped*interval
		state.serial += skipped
	while state.next < state.clock:
		if state.clock-state.next < duration:
			state.packets.append({"born":state.next,"variant":posmod(state.seed+state.serial,VARIANTS[state.kind])})
		state.next += interval
		state.serial += 1
	while state.packets.size() > MAX_PACKETS: state.packets.pop_front()

## Keep emission density, per-target variation, clipping and reduced-effects playback.
static func paint(canvas: CanvasItem, state: Dictionary, reduced: bool, at: Vector2 = Vector2.ZERO, scale: Vector2 = Vector2.ONE) -> void:
	var alpha: float = Sprites.AMBIENT_OPACITY*sqrt(state.intensity)
	if state.stopped_at >= 0:
		var tail: float = TAILS[state.kind]
		alpha *= 1.0-smoothstep(tail-0.2,tail,state.clock-state.stopped_at)
	for packet in state.packets:
		var light: bool = reduced or state.intensity < 0.75
		var name: String = ("light_" if light else "")+state.kind+"_%d" % (0 if light else packet.variant)
		Sprites.paint(canvas,name,state.clock-packet.born,at,scale,Color(1,1,1,alpha))
