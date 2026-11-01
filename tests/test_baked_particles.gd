extends SceneTree
## Verify atlas playback, pause-aware emission and seamless sampling without campaign saves.
const Baked = preload("res://scripts/effects/baked_particles.gd")
const Emitter = preload("res://scripts/effects/baked_emitter.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Every frame is inside its atlas, and loop playback crosses the seam without a hold.
func run() -> void:
	for name in Baked.Library.CLIPS:
		var clip: Dictionary = Baked.Library.CLIPS[name]
		check(clip.frames.size() == roundi(clip.duration*60),"Complete 60 FPS clip: "+name)
		for frame in clip.frames:
			check(Rect2(Vector2.ZERO,Baked.Library.PAGES[frame[0]].get_size()).encloses(frame[1]),"Frame lies inside shared texture")
		check(Baked.frame_index(clip,-0.1) == -1,"Future frames stay hidden")
		if clip.loop:
			check(Baked.frame_index(clip,clip.duration) == 0,"Exact seam wraps to first frame")
			check(Baked.frame_index(clip,clip.duration-0.5/60) == clip.frames.size()-1,"No duplicate endpoint or extra hold")
			check(Baked.frame_index(clip,clip.duration+1.1/60) == 1,"Playback advances normally after seam")
		else: check(Baked.frame_index(clip,clip.duration) == -1,"One-shot tails expire")
	for kind in ["storm","beam"]:
		var emitter := Emitter.create(kind,7)
		Emitter.advance(emitter,1,false)
		check(emitter.packets.is_empty(),"Inactive emitter has no premature particles")
		for i in range(400): Emitter.advance(emitter,1.0/60,true)
		check(emitter.packets.size() >= 2 and emitter.packets.size() <= Emitter.MAX_PACKETS,"Continuous emission uses bounded sprites")
		var snapshot := emitter.duplicate(true)
		Emitter.advance(emitter,0,true)
		check(emitter == snapshot,"Pause leaves particle state unchanged")
		Emitter.advance(emitter,0.02,true)
		check(is_equal_approx(emitter.clock-snapshot.clock,0.02),"Slow motion advances the same battle clock")
		var serial: int = emitter.serial
		Emitter.advance(emitter,0.05,false)
		check(emitter.serial == serial and not emitter.packets.is_empty(),"Stopping preserves tails without new births")
		Emitter.advance(emitter,2,false)
		check(emitter.packets.is_empty(),"Residual particles expire fully")
		check(not snapshot.packets.is_empty(),"Duplicated spell tails do not share mutable state")
		Emitter.advance(emitter,30,true)
		check(emitter.packets.size() <= Emitter.MAX_PACKETS,"A long hitch cannot create a particle backlog")
	print("Baked particles: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
