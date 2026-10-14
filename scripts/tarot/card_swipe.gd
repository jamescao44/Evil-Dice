extends RefCounted
## Shared touch/mouse inertia, integrated analytically so frame rate changes do not alter travel.
var position: float = 0.0
var velocity: float = 0.0
var dragging: bool = false
var last_stamp: int = 0
const FRICTION := 5.5

func reset(value: float = 0.0) -> void:
	position = value
	velocity = 0
	dragging = false

func begin(stamp: int = Time.get_ticks_msec()) -> void:
	dragging = true
	velocity = 0
	last_stamp = stamp

func move(amount: float, stamp: int = Time.get_ticks_msec()) -> void:
	if is_zero_approx(amount): return
	var dt: float = clampf((stamp-last_stamp)/1000.0,1.0/120,0.1)
	position += amount
	velocity = lerpf(velocity,clampf(amount/dt,-30,30),0.65)
	last_stamp = stamp

func release(stamp: int = Time.get_ticks_msec()) -> void:
	dragging = false
	if stamp-last_stamp > 120: velocity = 0

func advance(delta: float, snap: bool = false) -> void:
	if dragging: return
	var decay: float = exp(-FRICTION*delta)
	position += velocity*(1-decay)/FRICTION
	velocity *= decay
	if snap and absf(velocity) < 0.45:
		position = lerpf(position,roundf(position),1-exp(-delta*12))
		if absf(position-roundf(position)) < 0.001: position = roundf(position); velocity = 0
