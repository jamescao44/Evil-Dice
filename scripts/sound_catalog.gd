extends RefCounted
## Audio IDs are source/clip; shared recordings have independent per-source files.
const FILES := {
	"item": ["bell.ogg", "bong_001.ogg", "book.ogg", "card_draw.wav", "click_001.ogg", "confirmation_002.ogg", "crash.ogg", "deck_flip.wav", "deck_flip2.wav", "drop_001.ogg", "pluck_001.ogg", "rumble.ogg"],
	"dice": ["bell.ogg", "bong_001.ogg", "click_001.ogg", "confirmation_002.ogg", "drop_001.ogg", "land.ogg", "magic_leak_loop.wav", "perfect.wav", "pluck_001.ogg", "roll.ogg", "rumble.ogg", "soft_sweep.wav"],
	"player": ["bell.ogg", "book.ogg", "confirmation_002.ogg", "crash.ogg", "drop_001.ogg", "hit.ogg", "rumble.ogg", "slash.ogg"],
	"enemy": ["bell.ogg", "chop.ogg", "crash.ogg", "slash.ogg"],
	"ui": ["book.ogg", "click_001.ogg", "confirmation_002.ogg", "error_004.ogg", "glitch_004.ogg", "maximize_008.ogg"],
}

static func load_streams() -> Dictionary:
	var streams: Dictionary = {}
	for source in FILES:
		for filename in FILES[source]:
			streams[source+"/"+filename.get_basename()] = load("res://assets/audio/"+source+"/"+filename)
	return streams
