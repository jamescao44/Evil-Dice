extends SceneTree
## Authored combo cues play once, unchanged, at alike and confirmed-skill boundaries.
const Chime = preload("res://scripts/dice/combination_audio.gd")
const Announcement = preload("res://scripts/effects/match_announcement.gd")
const Catalog = preload("res://scripts/audio/sound_catalog.gd")
const OneShot = preload("res://scripts/audio/one_shot_audio.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var checks := 0
var failures := 0

class Listener extends RefCounted:
	var view_phase := "resolving"
	var inspecting_enemy := -1
	var menu_open := false
	var muted := false
	var notes: Array = []
	func _menus_open() -> bool: return menu_open
	func _sound(clip: String, pitch: float = 1.0, volume: float = -15.0) -> void:
		if not muted: notes.append({"clip":clip,"pitch":pitch,"volume":volume})

class FormationListener extends Battle:
	var cues: Array = []
	func _sound(clip: String, pitch: float = 1.0, volume: float = -15.0) -> void:
		if clip.begins_with("dice/combos_"): cues.append({"clip":clip,"pitch":pitch,"volume":volume})
	# Stop at the successful formation boundary; animation timing is tested elsewhere.
	func _show_pending_skill(_animate: bool = true) -> void: pass

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## All five imported excerpts remain full-quality, non-looping and at their original pitch.
func recordings() -> void:
	var streams := Catalog.load_streams()
	var audio = OneShot.new(); root.add_child(audio)
	for count in range(2,7):
		var listener = Listener.new()
		Chime.play(count,listener._sound)
		check(listener.notes.size() == 1 and listener.notes[0].clip == "dice/combos_%d" % count,"Group size chooses exactly one authored cue")
		check(listener.notes[0].pitch == 1.0,"Recorded chords are never repitched or rescheduled")
		var stream: AudioStreamWAV = streams[listener.notes[0].clip]
		check(stream.stereo and stream.mix_rate == 48000 and stream.format == AudioStreamWAV.FORMAT_16_BITS,"Cue retains original stereo 48 kHz PCM")
		check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and is_equal_approx(stream.get_length(),0.75 if count <= 4 else 1.125),"Cue plays its own segment once without the next chord")
		var voice = audio.play(listener.notes[0].clip,stream,listener.notes[0].pitch,listener.notes[0].volume)
		check(voice.stream == stream and voice.pitch_scale == 1.0,"Actual playback preserves the authored recording and tempo")
	var listener = Listener.new()
	for count in [-1,0,1,7]: Chime.play(count,listener._sound)
	check(listener.notes.is_empty(),"Non-combinations cannot start a chord")
	await create_timer(0.1).timeout
	audio.clear(); audio.queue_free(); await process_frame

## Frame rate, menu transitions and text fading cannot create extra chord copies.
func callouts() -> void:
	var listener = Listener.new()
	var announcement = Announcement.new(); announcement.battle = listener
	for count in range(2,7):
		listener.notes.clear(); announcement.play(count)
		check(listener.notes.size() == 1 and listener.notes[0].clip == "dice/combos_%d" % count,"Alike callout starts its size's cue immediately")
		listener.menu_open = true; announcement._process(1)
		listener.menu_open = false; announcement._process(1.5)
		announcement.finish(); announcement._process(2)
		announcement.clear(); announcement._process(1)
		check(listener.notes.size() == 1,"Callout lifecycle does not replay or synthesize notes")
	listener.notes.clear(); listener.muted = true
	announcement.play(6); announcement._process(1)
	listener.muted = false; announcement._process(1)
	check(listener.notes.is_empty(),"Unmuting cannot release delayed notes")
	announcement.free()

## Only a successful confirmation plays the skill-length cue; previews stay editable and quiet.
func formations() -> void:
	var g = FormationListener.new(); root.add_child(g); g.set_process_input(false)
	for count in range(3,7):
		g._restart()
		for enemy in g.model.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
		g.model.roll_pool(false,[1,2,3,4,5,6]); g.view_phase = "ready"
		g.cues.clear()
		g.model.dice_turn.selected = [0,1]
		await g._form_selected_skill()
		check(g.cues.is_empty() and g.model.pending.is_empty(),"Invalid partial selections cannot play a formation chord")
		g.model.dice_turn.selected = range(count)
		for i in range(3): g.dice_selection._selection_changed(); g.dice_selection._refresh_preview()
		check(g.cues.is_empty(),"Preview refreshes do not replay the authored chord")
		await g._form_selected_skill()
		check(g.cues.size() == 1 and g.cues[0].clip == "dice/combos_%d" % count and g.cues[0].pitch == 1.0,"Confirming each straight plays the corresponding cue once")
		await g._form_selected_skill()
		check(g.cues.size() == 1,"Repeated confirmation cannot duplicate the chord")
	g.queue_free(); await process_frame

func run() -> void:
	await recordings()
	callouts()
	await formations()
	# Let the audio server release stopped voices before the tree exits.
	await create_timer(0.1).timeout
	print("Combination audio: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
