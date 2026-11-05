extends RefCounted
## Character frames own release timing; effects never retime or skip actor poses.
const Sprite = preload("res://scripts/player/player_sprite.gd")
const FPS := Sprite.IDLE_FPS
const WALK_FIRST := 12
const WALK_FRAMES := 9
const CLIPS := {
	"pair":{"first":8,"launch":9,"impact":10,"last":11},
	"fireball":{"first":21,"launch":26,"impact":29,"last":29},
	"slash":{"first":31,"launch":43,"impact":48,"last":52},
	"storm":{"first":53,"launch":56,"impact":57,"loop_end":64,"last":67},
	"ultimate":{"first":68,"launch":76,"channel_end":89,"release":90,"impact":95,"loop_end":102,"last":107}
}
const EARLY_CLIPS := {
	"pair":{"first":9,"launch":14,"last":14,"idle_on_launch":true},
	"fireball":{"first":9,"launch":14,"last":14,"idle_on_launch":true},
	"slash":{"first":16,"launch":20,"impact":22,"last":23},
	"storm":{"first":24,"launch":28,"impact":32,"loop_end":36,"last":43},
	"ultimate":{"first":24,"launch":28,"impact":32,"loop_end":36,"last":43}
}
const EMOTES := [{"first":44,"last":64},{"first":44,"last":64},{"first":108,"last":133}]
var form := 2
var emote_age := -1.0
var action := ""
var phase := ""
var age := 0.0
var total_age := 0.0
var idle_age := 0.0
var walking := false
var walk_age := 0.0
var recovery_first := 0
var last_launch: Dictionary = {}
var projectile_bob_age := -1.0
const PROJECTILE_BOB_DURATION := 0.65
var firing_age := -1.0
const FIRING_DURATION := 0.42

## Clear a cast on restart, scene exit or a changed run token.
func reset() -> void:
	clear_action()
	total_age = 0; idle_age = 0; walking = false; walk_age = 0
	emote_age = -1; last_launch = {}
	projectile_bob_age = -1
	firing_age = -1

func clear_action() -> void:
	action = ""; phase = ""; age = 0

## Emotes override presentation only, so tapping never cancels combat or stalls a release.
func play_emote() -> void:
	emote_age = 0

func emoting() -> bool:
	return emote_age >= 0

## A form change swaps all atlas cues together, including an active emote.
func set_form(value: int) -> void:
	value = clampi(value,0,2)
	if value == form: return
	form = value
	firing_age = -1
	if emoting(): emote_age = 0

func clips() -> Dictionary:
	return CLIPS if form >= 2 else EARLY_CLIPS

func clip_data() -> Dictionary:
	return clips().get(action,{})

## Every character clip runs at the same cadence as idle, regardless of attack speed.
func begin(clip: String) -> void:
	action = clip if clips().has(clip) else "fireball"
	phase = "windup"; age = 0; total_age = 0
	projectile_bob_age = 0.0 if form < 2 and action in ["pair","fireball"] else -1.0

## Early projectile casts lift and settle the body without moving counters or retiming frames.
func projectile_bob(side: float, reduced: bool = false) -> float:
	if reduced or emoting() or form >= 2 or projectile_bob_age < 0: return 0.0
	var t: float = clampf(projectile_bob_age/PROJECTILE_BOB_DURATION,0,1)
	return -sin(t*PI)*side*(0.025 if form == 0 else 0.04)

## Squash, lift and gently rebound only the body, pivoting around its visible feet.
func firing_rect(rect: Rect2, reduced: bool = false) -> Rect2:
	if reduced or emoting() or firing_age < 0: return rect
	var t: float = clampf(firing_age/FIRING_DURATION,0,1)
	var pulse: float = sin(t*TAU)*(1-t)
	var size: Vector2 = rect.size*Vector2(1+0.08*pulse,1-0.10*pulse)
	var pivot := Vector2(0.5,Sprite.rest_bounds(form).end.y)
	var feet: Vector2 = rect.position+rect.size*pivot
	var lift := Vector2(0,-sin(t*PI)*rect.size.y*0.018)
	return Rect2(feet-size*pivot+lift,size)

## Combat waits for the actual authored release frame before creating an attack.
func ready() -> bool:
	return action.is_empty() or age*FPS+0.00001 >= clip_data().launch-clip_data().first

## Effects use this delay from release to the actor's impact/loop cue.
func impact_delay() -> float:
	var clip: Dictionary = clip_data()
	return float(clip.get("impact",clip.get("launch",0))-clip.get("launch",0))/FPS

## Fire once at the cue; early weak attacks immediately return to idle.
func launch() -> void:
	if action.is_empty(): return
	last_launch = {"frame":clip_data().launch,"action":action,"form":form}
	firing_age = 0
	if clip_data().get("idle_on_launch",false):
		clear_action(); idle_age = 0
	else:
		phase = "build"; age = 0

## Impact changes only the effect state, never the current actor frame or its clock.
func damage() -> void:
	if action in ["storm","ultimate"] and phase != "damage": firing_age = 0
	if not action.is_empty(): phase = "damage"

## Finish the current loop in sequence, then play the remaining recovery frames.
func finish() -> void:
	if action.is_empty() or not clip_data().has("loop_end") or phase == "recover": return
	recovery_first = action_frame_number()
	age = fposmod(age,1.0/FPS)
	phase = "recover"

## Idle, attacks, walking and emotes share one frame duration and battle slow motion.
func advance(delta: float, advancing: bool = false) -> void:
	if advancing and not walking: walk_age = 0
	elif advancing: walk_age += delta
	walking = advancing
	idle_age += delta
	if firing_age >= 0:
		firing_age += delta
		if firing_age >= FIRING_DURATION: firing_age = -1
	if projectile_bob_age >= 0:
		projectile_bob_age += delta
		if projectile_bob_age >= PROJECTILE_BOB_DURATION: projectile_bob_age = -1
	if emoting():
		emote_age += delta
		if emote_age*FPS >= EMOTES[form].last-EMOTES[form].first+1: emote_age = -1
	if action.is_empty(): return
	age += delta; total_age += delta
	var clip: Dictionary = clip_data()
	if phase == "recover":
		if recovery_first+floori(age*FPS+0.00001) > clip.last: clear_action()
	elif phase != "windup" and not clip.has("loop_end"):
		if clip.launch+floori(age*FPS+0.00001) > clip.last: clear_action()

## Sample the emote first while keeping the combat timeline alive underneath it.
func frame_number() -> int:
	if emoting(): return mini(EMOTES[form].last,EMOTES[form].first+floori(emote_age*FPS+0.00001))
	return action_frame_number()

## Walk and cast loops use elapsed time, never effect clocks or travel interpolation.
func action_frame_number() -> int:
	if action.is_empty():
		if walking and form >= 2: return WALK_FIRST+posmod(floori(walk_age*FPS+0.00001),WALK_FRAMES)
		return Sprite.idle_frame(idle_age,form)
	var clip: Dictionary = clip_data()
	var step: int = floori(age*FPS+0.00001)
	if phase == "windup": return mini(clip.launch,clip.first+step)
	if phase == "recover": return mini(clip.last,recovery_first+step)
	var frame: int = clip.launch+step
	if clip.has("loop_end") and frame >= clip.impact:
		return clip.impact+posmod(frame-clip.impact,clip.loop_end-clip.impact+1)
	return mini(clip.last,frame)

## Locate the emitting hand within the fixed cell, including the low slashing pose.
func hand_uv() -> Vector2:
	var frame: int = action_frame_number()
	if form < 2: return Vector2(0.76,0.53) if action == "slash" else Vector2(0.79,0.43)
	if frame >= 8 and frame <= 11: return Vector2(0.80,0.27) if frame in [9,10] else Vector2(0.84,0.40)
	if frame >= 31 and frame <= 52: return Vector2(0.86,0.80) if frame >= 38 else Vector2(0.84,0.48)
	if frame >= 95 and frame <= 102: return Vector2(0.83,0.65)
	if frame >= 76 and frame <= 89: return Vector2(0.71,0.16)
	return Vector2(0.84,0.40)
