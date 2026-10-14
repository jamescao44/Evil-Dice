extends Control
## Browser regression: export an isolated test project with this scene as main.
const ChestAudio = preload("res://scripts/audio/chest_audio.gd")
var audio: Node
var report: Label
var pause_audio := false
var reproduce_old_bug := false
var failures := 0

func starts() -> int:
	return int(JavaScriptBridge.eval("window.audioStarts || 0"))

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
		window.audioStarts = 0;
		const nativeStart = AudioBufferSourceNode.prototype.start;
		AudioBufferSourceNode.prototype.start = function(...args) {
			window.audioStarts++;
			return nativeStart.apply(this, args);
		};
		""", true)
	audio = ChestAudio.new()
	add_child(audio)
	report = Label.new()
	report.position = Vector2(40,100)
	report.add_theme_font_size_override("font_size",22)
	add_child(report)
	var button := Button.new()
	button.text = "Run web audio regression"
	button.position = Vector2(40,30)
	button.size = Vector2(400,50)
	add_child(button)
	button.pressed.connect(func(): button.disabled = true; run())

func _process(_delta: float) -> void:
	audio.sync(false,pause_audio)
	if reproduce_old_bug:
		for voice in [audio.rolling,audio.payout]: voice.stream_paused = false

func note(message: String) -> void:
	report.text += message+"\n"
	print(message)

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	note(("PASS " if ok else "FAIL ")+message)

func run() -> void:
	# Positive control reproduces the old per-frame unpause on the web backend.
	reproduce_old_bug = true
	audio.reveal_count = 0
	audio.reveal(0)
	await get_tree().create_timer(3.5).timeout
	check(starts() > 30,"Old per-frame unpause reproduces repeated browser source starts")
	reproduce_old_bug = false
	audio.stop()
	for tier in [0,2]:
		var before := starts()
		audio.start_rolling(tier)
		await get_tree().create_timer(0.7).timeout
		check(starts()-before == 1,"Rolling advances without restarts (tier %d)" % tier)
		audio.stop()
		check(not audio.rolling.playing,"Rolling stops")
	for tier in [0,2,3]:
		var before := starts()
		audio.reveal_count = 0
		if tier == 3: audio.begin_ultra()
		else: audio.reveal(tier)
		await get_tree().create_timer(0.7).timeout
		check(starts()-before == 1,"Payout advances (tier %d)" % tier)
		await get_tree().create_timer(audio.payout.stream.get_length()+0.3).timeout
		check(not audio.payout.playing,"Payout ends once (tier %d)" % tier)
	audio.reveal_count = 0
	audio.reveal(2)
	await get_tree().create_timer(0.5).timeout
	pause_audio = true
	await get_tree().create_timer(0.3).timeout
	check(audio.payout.stream_paused,"Pause is applied")
	pause_audio = false
	await get_tree().create_timer(4.2).timeout
	check(not audio.payout.playing,"Resumed payout ends without looping")
	note("WEB AUDIO COMPLETE: %d failures" % failures)
