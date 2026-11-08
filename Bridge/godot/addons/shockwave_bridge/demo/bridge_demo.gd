## Runnable demo of the bridge, against the real Burnin' Rubber 4 movie. Build its UI in code so
## there is no second scene to keep in sync; `bridge_demo.tscn` only carries this script.
##
## What it demonstrates, in the order you tend to want it:
##   1. reading live `gGame` state every frame, from the mirror (no round trip);
##   2. a cold `request_read` of something the config does not expose;
##   3. writing allow-listed state back into the running movie;
##   4. the replicated store, for data the game has no variable for;
##   5. an autopilot that *drives* the car from Godot by writing the input flags;
##   6. `call_director` into a Lingo handler, and receiving the movie's events.
##
## Run it with the movie playing. `../../../../../Director/INSTALL.md` step 3 sets up the mailbox.
extends Node2D

const HOLD_LABELS := [
	["Scene", "gGame.Scene"],
	["Track", "gGame.Track"],
	["Race state", "gGame.RaceState"],
	["Cash", "gGame.Cash"],
	["Speed", "gGame.CurrentVehicle.general.kmh"],
	["Health", "gGame.CurrentVehicle.general.health"],
	["Nitro", "gGame.CurrentVehicle.general.nitro"],
	["Checkpoints", "gGame.CheckPoints.done"],
	["Paused", "gGame.pause"],
	["Iteration", "gGame.Iteration"],
]

var bridge: Node = null
var labels := {}
var status_label: Label
var log_label: Label
var target_label: Label
var autopilot := false
var target_kmh := 140.0  # the movie may write this as gd:Demo.target_kmh
var refresh_left := 0.0


func _ready() -> void:
	if not Engine.has_singleton("ShockwaveBridge"):
		_build_ui()
		status_label.text = "autoload missing"
		_log("Add res://addons/shockwave_bridge/shockwave_bridge.gd as an autoload named "
			+ "ShockwaveBridge (Project > Project Settings > Globals), or use the Shockwave dock's "
			+ "Install autoload button.")
		return
	bridge = get_node("/root/ShockwaveBridge")
	_build_ui()
	bridge.bind_node(self, "Demo")
	bridge.status_changed.connect(_on_status)
	bridge.bridge_event_raised.connect(_on_event)
	bridge.director_value_changed.connect(_on_value)
	bridge.bridge_log.connect(_on_bridge_log)
	_log("bridge bound as gd:Demo; mailbox at " + str(bridge.transport_status().get("out", "?")))


func _process(delta: float) -> void:
	if bridge == null:
		return
	for entry in HOLD_LABELS:
		var value = bridge.read_path(entry[1], null)
		labels[entry[0]].text = _pretty(value)
	target_label.text = "target %d km/h   %s" % [int(target_kmh), "ON" if autopilot else "off"]
	refresh_left -= delta
	if refresh_left <= 0.0:
		refresh_left = 1.0
		# a cold read, one per second, of a path that is not in the mirror at all
		bridge.request_read("gGame.CurrentVehicle.name", func(result: Variant) -> void:
			labels["Vehicle"].text = _pretty(result))
		var counts := bridge.stats()
		labels["Traffic"].text = "%d in / %d out  ·  %d torn  ·  %d denied" % [
			int(counts["msgs_in"]), int(counts["msgs_out"]), int(counts["torn"]), int(counts["denied"])
		]
	if autopilot:
		_drive()


# --------------------------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------------------------


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	status_label = _add_label(column, "status  —", 20)
	_add_separator(column)
	for entry in HOLD_LABELS + [["Vehicle", ""], ["Traffic", ""]]:
		var row := HBoxContainer.new()
		column.add_child(row)
		var key := Label.new()
		key.text = "%s:" % entry[0]
		key.custom_minimum_size = Vector2(110, 0)
		row.add_child(key)
		var value := Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value)
		labels[entry[0]] = value
	_add_separator(column)

	target_label = _add_label(column, "target —", 16)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_add_button(buttons, "pause movie", _on_pause)
	_add_button(buttons, "+1000 cash", _on_cash)
	_add_button(buttons, "boost", _on_boost)
	_add_button(buttons, "autopilot", _on_autopilot)
	_add_button(buttons, "say hello", _on_say_hello)
	_add_button(buttons, "what changed?", _on_probe)
	_add_separator(column)
	log_label = _add_label(column, "", 14)
	log_label.custom_minimum_size = Vector2(520, 90)


func _add_label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _add_separator(parent: Node) -> void:
	parent.add_child(HSeparator.new())


func _add_button(parent: Node, text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	parent.add_child(button)


func _pretty(value: Variant) -> String:
	if value == null:
		return "—"
	if value is Array or value is Dictionary:
		return str(value)
	if typeof(value) == TYPE_FLOAT:
		return "%.1f" % value
	return String(value)


func _log(text: String) -> void:
	print("[bridge demo] ", text)
	if log_label != null:
		var lines := log_label.text.split("\n")
		lines.append(text)
		while lines.size() > 6:
			lines.remove_at(0)
		log_label.text = "\n".join(PackedStringArray(lines))


# --------------------------------------------------------------------------------------------
# 1-2: reading (see _process, which reads the mirror every frame with no round trip)
# --------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------
# 2b: the keyboard, so the demo is drivable while the movie window has focus
# --------------------------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	## F1 pause, F2 cash, F3 "what changed?". Deliberately the same three calls the buttons make: a
	## key, a button and a signal all end at the same write_path/read_path, which is the point.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			_on_pause()
		KEY_F2:
			_on_cash()
		KEY_F3:
			_on_probe()
		_:
			return
	get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------------------------
# 3: writing allow-listed game state
# --------------------------------------------------------------------------------------------


func _on_pause() -> void:
	var paused = bridge.read_int("gGame.pause", 0)
	# write_path returns the value the movie echoed back, or a BridgeError when the path is not on
	# the movie's `write` allow-list. Either way the game does not break.
	var reply = bridge.write_path("gGame.pause", 0 if int(paused) == 1 else 1, true)
	_log("gGame.pause -> %s (was %s)" % [str(reply), str(paused)])


func _on_cash() -> void:
	var reply = bridge.write_path("gGame.Cash", bridge.read_int("gGame.Cash", 0) + 1000, true)
	_log("gGame.Cash +1000 -> %s" % str(reply))


# --------------------------------------------------------------------------------------------
# 4: the replicated store, for data the game has no variable for
# --------------------------------------------------------------------------------------------


func _on_boost() -> void:
	var want = bridge.read_custom("wantBoost", false)
	bridge.send_custom("wantBoost", not bool(want))
	_log("bridge.wantBoost = %s (the movie reads it with BridgeGet(\"bridge.wantBoost\"))" % str(not bool(want)))


func _on_autopilot() -> void:
	autopilot = not autopilot
	if not autopilot:
		bridge.write_many({
			"gGame.CurrentVehicle.Input.forward": 0,
			"gGame.CurrentVehicle.Input.brake": 0,
		})
	_log("autopilot %s — holding %d km/h by writing the movie's input flags" % ["on" if autopilot else "off", int(target_kmh)])


## 5: drive the car by pushing the same input flags the game's own input handler sets. Nothing here
## knows about the game's physics: it just reads kmh and writes the pedals, once per frame.
func _drive() -> void:
	var kmh := bridge.read_number("gGame.CurrentVehicle.general.kmh", 0.0)
	var error := target_kmh - kmh
	var forward := 1
	var brake := 0
	if error < -4.0:
		forward = 0
		brake = 1
	bridge.write_many({
		"gGame.CurrentVehicle.Input.forward": forward,
		"gGame.CurrentVehicle.Input.brake": brake,
	})


# --------------------------------------------------------------------------------------------
# 6: into the movie, and back
# --------------------------------------------------------------------------------------------


func _on_say_hello() -> void:
	# `PutMessage` is in the movie's `call` list, and writes to its own Message window member.
	bridge.call_director("PutMessage", 0, {"message": "hello from Godot", "level": 0},
		func(result: Variant) -> void: _log("PutMessage returned %s" % str(result)))


func _on_probe() -> void:
	# Cold reads of a subtree: what the movie has, at this depth, right now.
	bridge.list_paths("gGame.CurrentVehicle.general", 1, func(result: Variant) -> void:
		if result is Dictionary:
			var keys: Array = (result as Dictionary).keys()
			keys.sort()
			for key in keys:
				_log("  %s = %s" % [key, str((result as Dictionary)[key])])
		else:
			_log("list: %s" % str(result))
	)


func _on_status(status: String) -> void:
	status_label.text = "status  %s  ·  %s" % [status, bridge.peer_status()]
	_log("status: " + status)


func _on_event(name: String, data: Dictionary) -> void:
	_log("movie event %s %s" % [name, str(data)])


func _on_value(path: String, value: Variant) -> void:
	if String(path).begins_with("bridge."):
		_log("store %s = %s" % [path, str(value)])


func _on_bridge_log(level: String, text: String) -> void:
	if level != "trace":
		_log("%s: %s" % [level, text])


## Called on this node when the movie raises `Demo...` events, because the node is bound. Kept
## separate from the signal so both routes are visible in the demo.
func bridge_event(name: String, data: Dictionary) -> void:
	_log("bridge_event on node: %s %s" % [name, str(data)])
