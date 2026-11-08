## The "Shockwave" bottom panel: a live view of the bridge, usable without running the game.
##
## Why it works in the editor: the dock owns its own `BridgePeer` on the `files` transport, pointed
## at the same mailbox folder the movie writes. Director pushes SNAP/DELTA frames whether or not
## Godot is playing, so you can watch `gGame` values move, and push `bridge.*` / allow-listed `set`
## writes back, while you are still in the editor. (For the `http`/`tcp` transports the dock stays
## read-only, because the running game owns those listeners — a second one would just fail to bind.)
##
## The command line is the same surface the Godot API offers, spelled the way the PROTOCOL does:
##     get gGame.Cash            set bridge.targetKmh=140.0        list gGame 1
##     watch gGame.kmh           unwatch gGame.kmh                 event BridgePause
##     call PutMessage {"message":"hi"}                             status | ping | reload
@tool
extends VBoxContainer

const Tick := 20.0

var peer: BridgePeer = null
var transport: BridgeTransportFiles = null
var config: BridgeConfig = null
var watched: Array = []

var _status_label: Label
var _mirror: TextEdit
var _output: TextEdit
var _entry: LineEdit
var _transport_button: OptionButton
var _autoload_button: Button
var _timer: Timer


func _ready() -> void:
	custom_minimum_size = Vector2(560, 260)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_start_watcher()
	_timer = Timer.new()
	_timer.wait_time = 1.0 / Tick
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()


func _exit_tree() -> void:
	if peer != null:
		peer.stop()


func _build_ui() -> void:
	var head := HBoxContainer.new()
	add_child(head)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_status_label)
	_autoload_button = Button.new()
	_autoload_button.text = "Install autoload"
	_autoload_button.tooltip_text = "Add ShockwaveBridge.gd as an autoload so the running game talks to the movie too."
	_autoload_button.pressed.connect(_install_autoload)
	head.add_child(_autoload_button)
	var reload := Button.new()
	reload.text = "Reload config"
	reload.tooltip_text = "Re-read Bridge.Data.txt (and re-detect the mailbox folder)."
	reload.pressed.connect(_start_watcher)
	head.add_child(reload)
	var selftest := Button.new()
	selftest.text = "Run selftest"
	selftest.tooltip_text = "Launch a headless Godot that runs addons/shockwave_bridge/bridge_selftest.gd."
	selftest.pressed.connect(_run_selftest)
	head.add_child(selftest)

	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_label("Transport (watcher)"))
	_transport_button = OptionButton.new()
	for index in range(3):
		_transport_button.add_item(["files", "http", "tcp"][index], index)
	_transport_button.tooltip_text = "files = read the shared mailbox (works in the editor). http/tcp need the running game to own the listener."
	row.add_child(_transport_button)
	_transport_button.item_selected.connect(func(index: int) -> void: _set_transport(index))
	row.add_child(_label("mailbox"))
	var path_button := Button.new()
	path_button.text = "res://BridgeData"
	path_button.tooltip_text = "Which folder to watch. Same 'root' key as Bridge.Data.txt."
	path_button.pressed.connect(_pick_dir)
	row.add_child(path_button)

	_mirror = _text_area(10, true)
	add_child(_mirror)
	_output = _text_area(4, true)
	add_child(_output)
	_entry = LineEdit.new()
	_entry.placeholder_text = "get gGame.Cash   ·   set bridge.boost=1   ·   list gGame 1   ·   status"
	_entry.text_submitted.connect(_on_command)
	add_child(_entry)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _text_area(lines: int, read_only: bool) -> TextEdit:
	var area := TextEdit.new()
	area.custom_minimum_size = Vector2(0, 18 * float(lines))
	area.editable = not read_only
	area.draw_tabs = true
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return area


# --------------------------------------------------------------------------------------------
# watcher
# --------------------------------------------------------------------------------------------


func _start_watcher() -> void:
	if peer != null:
		peer.stop()
	config = _load_config()
	peer = BridgePeer.new()
	peer.configure(config, "godot", ["snap", "sub", "event", "list"], "Godot (editor dock)")
	peer.verbose = false
	transport = BridgeTransportFiles.new()
	transport.setup(peer, _project_dir(), config)
	peer.transport = transport
	peer.start()
	for path in watched:
		peer.subscribe(path)
	if _autoload_button != null:
		_autoload_button.visible = not _has_autoload()


func _load_config() -> BridgeConfig:
	for candidate in [
		"res://Bridge.Data.txt",
		"res://Bridge/Director/Bridge.Data.txt",
		"res://addons/shockwave_bridge/Bridge.Data.txt",
	]:
		if FileAccess.file_exists(candidate):
			return BridgeConfig.load_file(ProjectSettings.globalize_path(candidate))
	return BridgeConfig.new()


func _project_dir() -> String:
	return ProjectSettings.globalize_path("res://")


func _mailbox_dir() -> String:
	if transport != null:
		return transport.root_dir
	return _project_dir().path_join("BridgeData")


func _tick() -> void:
	if peer == null:
		return
	peer.tick(Engine.get_frames_drawn())
	peer.flush()
	_refresh_labels()


func _refresh_labels() -> void:
	if _status_label == null:
		return
	var stats: Dictionary = peer.stats
	_status_label.text = "Shockwave bridge — %s  |  mailbox %s  |  in %d  out %d  torn %d" % [
		peer.status_text(), _mailbox_dir(), stats["msgs_in"], stats["msgs_out"], stats["torn"]
	]
	var lines: Array[String] = []
	lines.append(";; mirrored from Director (%d keys, %d subscribed)" % [peer.peer_store.size(), peer.subscriptions.size()])
	var keys: Array = peer.peer_store.keys()
	keys.sort()
	for key in keys:
		lines.append("%s = %s" % [key, BridgeWire.render(peer.peer_store[key])])
	lines.append(";; replicated store (writable both ways)")
	var store_keys: Array = peer.store.keys()
	store_keys.sort()
	for key in store_keys:
		lines.append("bridge.%s = %s" % [key, BridgeWire.render(peer.store[key])])
	if _mirror.text != "\n".join(lines):
		_mirror.text = "\n".join(lines)


func _set_transport(index: int) -> void:
	match index:
		0:
			_start_watcher()
		_:
			_print("http/tcp are served by the running game, not the editor. Start the project with "
				+ "ShockwaveBridge as an autoload and point Director's Bridge.Data.txt at the same host:port.")


func _pick_dir() -> void:
	# A dialog would need an EditorFileDialog; the config file is the real control surface, so say so.
	_print("Set the mailbox folder with the `root` key in Bridge.Data.txt (absolute path recommended: "
		+ "point it at the Director movie's BridgeData folder). Then Reload config.")


# --------------------------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------------------------


func _on_command(text: String) -> void:
	_entry.text = ""
	var reply := _execute(text)
	_print("> " + text)
	if not reply.is_empty():
		_print(reply)


func _execute(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return ""
	var space := trimmed.find(" ")
	var verb := trimmed if space < 0 else trimmed.substr(0, space)
	var rest := "" if space < 0 else trimmed.substr(space + 1).strip_edges()
	match verb:
		"get":
			var value = peer.read_local(_alias(rest), BridgeNet.missing())
			if typeof(value) == TYPE_STRING and value == BridgeNet.missing():
				return "no mirror entry for %s (try: request %s)" % [rest, rest]
			return "%s = %s  (%s)" % [rest, BridgeWire.render(value), BridgeWire.encode(value)]
		"request":
			peer.read_remote(rest, func(result: Variant) -> void: _print("%s -> %s" % [rest, _show(result)]))
			return "REQ get %s queued (answered on the movie's next frame)" % rest
		"set":
			var equals := rest.find("=")
			if equals <= 0:
				return "usage: set <path>=<wirevalue>"
			var path := rest.substr(0, equals).strip_edges()
			var raw := rest.substr(equals + 1).strip_edges()
			peer.write_local(path, BridgeWire.decode_or_text(raw))
			return "CMD set %s -> %s" % [path, raw]
		"sets":
			var pairs := {}
			for chunk in rest.split(";"):
				var eq := chunk.find("=")
				if eq > 0:
					pairs[chunk.substr(0, eq).strip_edges()] = BridgeWire.decode_or_text(chunk.substr(eq + 1))
			peer.write_many(pairs)
			return "REQ sets with %d paths" % pairs.size()
		"watch":
			watched.append(rest)
			peer.subscribe(rest)
			return "subscribed %s" % rest
		"unwatch":
			watched.erase(rest)
			peer.unsubscribe(rest)
			return "unsubscribed %s" % rest
		"list":
			var parts := rest.split(" ")
			var depth := 1
			if parts.size() > 1 and parts[1].is_valid_int():
				depth = int(parts[1])
			peer.list_paths("" if parts.is_empty() else parts[0], depth, func(result: Variant) -> void:
				if typeof(result) == TYPE_DICTIONARY:
					var keys: Array = (result as Dictionary).keys()
					keys.sort()
					for key in keys:
						_print("  %s = %s" % [key, BridgeWire.render((result as Dictionary)[key])])
				else:
					_print("  %s" % _show(result))
			)
			return "REQ list %s depth %d" % [rest, depth]
		"event":
			peer.send_event(rest)
			return "EVT %s sent" % rest
		"call":
			var space2 := rest.find(" ")
			var handler := rest if space2 < 0 else rest.substr(0, space2)
			var payload := "" if space2 < 0 else rest.substr(space2 + 1)
			peer.call_handler(handler, "", BridgeLingo.parse(payload), func(result: Variant) -> void: _print("  -> %s" % _show(result)))
			return "REQ call %s" % handler
		"status":
			return "%s\n%s" % [peer.status_text(), JSON.stringify(peer.snapshot_state(), "  ")]
		"ping":
			peer.ping(func(result: Variant) -> void: _print("  pong %s" % _show(result)))
			return "REQ ping"
		"snap":
			peer.set_snapshot(rest != "off", -1, "")
			return "snapshot %s" % rest
		"reload":
			_start_watcher()
			return "reloaded"
		"help":
			return _help()
	return "unknown command: %s   (try: help)" % verb


func _alias(path: String) -> String:
	if config != null and not path.contains(".") and config.alias.has(path):
		return config.alias[path]
	return path


static func _show(value: Variant) -> String:
	if value is BridgeError:
		return "ERR %s" % value
	return BridgeWire.render(value)


func _print(text: String) -> void:
	if _output == null:
		print(text)
		return
	_output.text = _output.text + text + "\n"
	_output.scroll_vertical = _output.get_line_count() * _output.get_line_height()


func _help() -> String:
	return "\n".join(PackedStringArray([
		"get <path>              read the mirror (no round trip)",
		"request <path>          cold REQ/RSP read from the movie",
		"set <path>=<value>      CMD write; value is wire-typed (i:99, f:1.5, s:text, b:1, y:Sym)",
		"sets p=v;q=w            one atomic REQ with several writes",
		"watch <path>            ask for a path to be mirrored from now on",
		"list <prefix> <depth>   enumerate the far side",
		"call <handler> <lit>    invoke a movie handler (config `call` list)",
		"event <Name>            raise a movie event (config `event` list)",
		"snap off|on             stop/start the mirror",
		"status | ping | reload  bridge health",
	]))


# --------------------------------------------------------------------------------------------
# editor conveniences
# --------------------------------------------------------------------------------------------


func _has_autoload() -> bool:
	return ProjectSettings.has_setting("autoload/ShockwaveBridge")


## The dock does this itself rather than going through EditorPlugin, so it also works when the addon
## is merely present in the project. Equivalent to EditorPlugin.add_autoload_singleton(), plus the
## leading `*`, which is what makes the autoload load before the main scene.
func _install_autoload() -> void:
	if _has_autoload():
		_print("autoload ShockwaveBridge is already installed")
		return
	ProjectSettings.set_setting("autoload/ShockwaveBridge", "*res://addons/shockwave_bridge/shockwave_bridge.gd")
	var error := ProjectSettings.save()
	_autoload_button.visible = false
	if error == OK:
		_print("installed autoload ShockwaveBridge -> res://addons/shockwave_bridge/shockwave_bridge.gd")
	else:
		_print("could not save ProjectSettings (error %d); add the autoload by hand in "
			+ "Project > Project Settings > Globals > Autoload" % error)


func _run_selftest() -> void:
	var editor := OS.get_executable_path()
	var args := PackedStringArray([
		"--headless", "--path", _project_dir(),
		"--script", "res://addons/shockwave_bridge/bridge_selftest.gd",
	])
	var full := PackedStringArray([editor])
	full.append_array(args)
	_print("$ " + " ".join(PackedStringArray(full)))
	if not OS.has_method("execute"):
		_print("This build has no OS.execute; run the command above in a terminal.")
		return
	var out: Array[String] = []
	var code := OS.execute(editor, args, out, true)
	_print("".join(out) if not out.is_empty() else "(no output)")
	_print("exit %d" % code)
