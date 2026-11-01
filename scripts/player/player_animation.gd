extends RefCounted
## Presentation-only cast states; combat explicitly owns launch, impact and loop release.
const Sprite = preload("res://scripts/player/player_sprite.gd")
const FPS := 30.0
const CLIPS := {
	"pair":{"first":8,"launch":11,"impact":12,"last":13},
	"fireball":{"first":23,"launch":28,"impact":31,"last":31},
	"slash":{"first":33,"launch":45,"impact":50,"last":54,"damage_speed":0.7},
	"storm":{"first":55,"launch":58,"impact":59,"loop_end":66,"recover":67,"last":69},
	"ultimate":{"first":70,"launch":78,"channel_end":91,"release":92,"impact":97,"loop_end":104,"recover":105,"last":109}
}
var action := ""
var phase := ""
var age := 0.0
var total_age := 0.0
var idle_age := 0.0
var rate := 1.0
var build_duration := 0.0
var walking := false
var fx_clock: Dictionary = {}

## Clear a cast on restart, scene exit or a changed run token.
func reset() -> void:
	action = ""; phase = ""; age = 0; total_age = 0; idle_age = 0
	fx_clock = {}; walking = false

## Select the authored range without coupling future characters to combat coefficients.
func begin(clip: String, speed: float = 1.0) -> void:
	action = clip if CLIPS.has(clip) else "fireball"
	phase = "windup"; age = 0; total_age = 0; rate = maxf(0.1,speed)
	fx_clock = {}

## A short windup reaches the precise release frame before the effect is spawned.
func ready() -> bool:
	return action.is_empty() or age*FPS*rate >= CLIPS[action].launch-CLIPS[action].first

## Share an authored effect's actual clock; generic projectiles use the same world-time delta.
func launch(seconds: float, clock: Dictionary = {}) -> void:
	phase = "build"; age = 0; build_duration = seconds; fx_clock = clock

## The first real impact starts the damaging pose, never a guessed wall-clock timer.
func damage() -> void:
	if action.is_empty(): return
	phase = "damage"; age = 0

## Exit a sustained pose only after combat has finished its damage sequence.
func finish() -> void:
	if action.is_empty(): return
	phase = "recover"; age = 0; fx_clock = {}

## Advance with battle slow-motion; frozen characters and modal pages pass no delta.
func advance(delta: float, advancing: bool = false) -> void:
	walking = advancing
	idle_age += delta
	if action.is_empty(): return
	age += delta; total_age += delta
	if phase == "recover":
		var clip: Dictionary = CLIPS[action]
		if age*FPS*rate*clip.get("damage_speed",1.0) >= clip.last-clip.get("recover",clip.impact)+1:
			action = ""; phase = ""; fx_clock = {}

## Sample each authored pose, keeping UI anchors independent of frame bounds.
func frame_number() -> int:
	if action.is_empty(): return 14+posmod(floori(idle_age*Sprite.WALK_FPS),9) if walking else Sprite.idle_frame(idle_age)
	var clip: Dictionary = CLIPS[action]
	var elapsed: float = fx_clock.get("age",age) if phase in ["build","damage"] else age
	var step: int = floori(elapsed*FPS*rate*clip.get("damage_speed",1.0))
	match phase:
		"windup":
			if action == "ultimate" and ready(): return clip.launch+posmod(floori((age-(clip.launch-clip.first)/(FPS*rate))*18*rate),14)
			return mini(clip.launch-1,clip.first+floori(age*FPS*rate))
		"build":
			if action == "ultimate":
				var release_time: float = (clip.impact-clip.release)/(FPS*rate)
				if elapsed >= build_duration-release_time: return mini(96,92+floori(maxf(0,elapsed-build_duration+release_time)*FPS*rate))
				return 78+posmod(floori(elapsed*18*rate),14)
			if action == "storm": return 58
			return mini(clip.impact-1,clip.launch+floori(clampf(elapsed/maxf(0.001,build_duration),0,1)*(clip.impact-clip.launch)))
		"damage":
			if clip.has("loop_end"): return clip.impact+posmod(floori(elapsed*20*rate),clip.loop_end-clip.impact+1)
			return mini(clip.last,clip.impact+step)
		"recover": return mini(clip.last,clip.get("recover",clip.impact)+step)
	return clip.first

## Locate the emitting hand within the fixed cell, including the low slashing pose.
func hand_uv() -> Vector2:
	var frame: int = frame_number()
	if frame >= 8 and frame <= 13: return Vector2(0.80,0.27) if frame >= 10 and frame <= 12 else Vector2(0.84,0.40)
	if frame >= 33 and frame <= 54: return Vector2(0.86,0.80) if frame >= 40 else Vector2(0.84,0.48)
	if frame >= 97 and frame <= 104: return Vector2(0.83,0.65)
	if frame >= 78 and frame <= 91: return Vector2(0.71,0.16)
	return Vector2(0.84,0.40)
