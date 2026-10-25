extends SceneTree
## Newline-delimited JSON transport; the Python launcher filters Godot's startup banner.
const Session = preload("res://scripts/testing/playtest_session.gd")

func _initialize() -> void:
	call_deferred("serve")

## Block on stdin only in this headless tool, never in the graphical game's scene tree.
func serve() -> void:
	var args := OS.get_cmdline_user_args()
	var session = Session.new(int(args[0]) if not args.is_empty() else 1)
	print("PLAYTEST_JSON "+JSON.stringify({"ok":true,"protocol":1,"seed":session.seed_value,"events":session.events,"state":session.snapshot()}))
	while true:
		var line := OS.read_string_from_stdin().strip_edges()
		if line.is_empty(): break
		var parser := JSON.new()
		if parser.parse(line) != OK or not parser.data is Dictionary:
			print("PLAYTEST_JSON "+JSON.stringify({"ok":false,"error":"Expected one JSON object per line."}))
			continue
		if parser.data.get("action","") == "quit": break
		print("PLAYTEST_JSON "+JSON.stringify(session.command(parser.data)))
	quit()
