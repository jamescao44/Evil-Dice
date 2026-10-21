extends RefCounted
## Cosmetic-only rolling paths and frame phases, independent of gameplay RNG.
const Art = preload("res://scripts/dice/dice_art.gd")
var start := Vector2.ZERO
var control_a := Vector2.ZERO
var control_b := Vector2.ZERO
var start_frame: int = 0
var frame_direction: int = 1
var frames_per_second: float = 32
var spin_turns: int = 1
var tilt: float = 0
var seconds: float = 1
var power: float = 0
var arena_center := Vector2.ZERO
var arena_radius: float = 64
var bounce_points := PackedVector2Array()
var bounce_times := PackedFloat32Array()
const SNAP_START := 0.84

## Randomize once per throw; sampling stays smooth at any render frame rate.
func begin(rng: RandomNumberGenerator, resting: Vector2, center: Vector2, radius: float, roll_seconds: float, strength: float = 0, perfect: bool = false) -> void:
	start = resting
	seconds = roll_seconds
	power = 1.0 if perfect else clampf(strength,0,1)
	arena_center = center
	arena_radius = radius
	start_frame = rng.randi_range(0,Art.ROLL_COUNT-1)
	frame_direction = -1 if rng.randf() < 0.5 else 1
	frames_per_second = rng.randf_range(30,38)+power*16
	spin_turns = (rng.randi_range(1,2)+roundi(power*3))*(-1 if rng.randf() < 0.5 else 1)
	tilt = rng.randf_range(-0.3,0.3)
	var direction: float = -1 if rng.randf() < 0.5 else 1
	var angle: float = (resting-center).angle()
	var excursion: float = direction*rng.randf_range(0.7,1.3)
	# Broad arcs scatter across the ring instead of collapsing six dice at its center.
	control_a = center+Vector2.from_angle(angle+excursion*0.65)*radius*rng.randf_range(0.65,0.75)
	control_b = center+Vector2.from_angle(angle+excursion)*radius*rng.randf_range(0.58,0.72)
	bounce_points = PackedVector2Array([start])
	bounce_times = PackedFloat32Array([0.0])
	for i in range(2+roundi(power*3)):
		angle += direction*rng.randf_range(2.2,3.9)
		bounce_points.append(center+Vector2.from_angle(angle)*radius*rng.randf_range(0.57,0.73))
		bounce_times.append(bounce_times[-1]+rng.randf_range(0.65,1.35))
	var total: float = bounce_times[-1]
	for i in range(1,bounce_times.size()): bounce_times[i] /= total

## Strong throws ricochet across the arena, then rapidly snap back before revealing.
func position_at(progress: float) -> Vector2:
	var p := clampf(progress,0,1)
	var gentle := start.bezier_interpolate(control_a,control_b,start,smoothstep(0,1,p))
	var energetic: Vector2
	if p >= SNAP_START:
		energetic = bounce_points[-1].lerp(start,smoothstep(0,1,(p-SNAP_START)/(1-SNAP_START)))
	else:
		var travel := p/SNAP_START
		var segment := 0
		while segment < bounce_points.size()-2 and travel > bounce_times[segment+1]: segment += 1
		var phase := inverse_lerp(bounce_times[segment],bounce_times[segment+1],travel)
		energetic = bounce_points[segment].lerp(bounce_points[segment+1],phase)
		energetic.y -= sin(phase*PI)*arena_radius*0.12
		energetic = arena_center+(energetic-arena_center).limit_length(arena_radius*0.88)
	return gentle.lerp(energetic,power*power)

## Complete whole rotations and gently ease upright for the landing face.
func rotation_at(progress: float) -> float:
	var t: float = clampf(progress,0,1)
	var gentle := 1-pow(1-t,2.2)
	var rapid := t/SNAP_START*0.9 if t < SNAP_START else lerpf(0.9,1.0,smoothstep(0,1,(t-SNAP_START)/(1-SNAP_START)))
	return spin_turns*TAU*lerpf(gentle,rapid,power)+sin(t*PI)*tilt

## Every moving frame stays in the supplied seven-frame animation strip.
func frame_at(progress: float) -> int:
	var step: int = floori(maxf(0,progress)*seconds*frames_per_second)
	return Art.ROLL_FIRST+posmod(start_frame+step*frame_direction,Art.ROLL_COUNT)
