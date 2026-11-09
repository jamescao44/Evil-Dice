extends RefCounted
## Each size uses its authored chord recording, shared by alike rolls and skill formation.
const VOLUME_DB := -8.0

static func clip_for_count(count: int) -> String:
	return "dice/combos_%d" % count if count >= 2 and count <= 6 else ""

## Play the complete cue once at its original pitch and tempo, without delaying combat.
static func play(count: int, emit: Callable) -> void:
	var clip := clip_for_count(count)
	if not clip.is_empty(): emit.call(clip,1.0,VOLUME_DB)
