extends Node
## One watcher per local play session, independent of scenes and battle state.
const INTERVAL := 0.35
var _elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameText.initialize()
	set_process(OS.has_feature("editor"))

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < INTERVAL: return
	_elapsed = 0
	GameText.reload_translations()
