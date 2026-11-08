## Shockwave ⇄ Godot bridge — the half your game code talks to.
##
## Add it as an autoload named `ShockwaveBridge` (Project Settings → Globals → Autoload, or let the
## editor plugin do it) and it does two things:
##
## * **reads Director**: every path in `expose` in `Bridge/Director/Bridge.Data.txt` arrives in the
##   peer mirror as SNAP/DELTA, so `ShockwaveBridge.read_path("gGame.Cash")` is a dictionary lookup —
##   no round trip, nothing blocking, safe to call every frame from `_process`.
## * **writes Director**: `write_path("gGame.Cash", 999999)` becomes a `CMD set` in the next batch
##   and is applied inside the movie's own frame tick. Anything under `bridge.*` is replicated both
##   ways and always writable — that is the channel for your own custom data.
##
## Paths (PROTOCOL.md §5):
##     gGame.Cash                       mirrored Director state
##     gGame.CurrentVehicle.general.kmh nested propLists; list indices as [n]
##     bridge.<key>                       the replicated store, writable from both sides
##     gd:Player.hp                     a Godot property, once you bind() the node
##
## Security: reads come from a local mirror, writes into the game are refused unless the path is in
## the config's `write` list, `eval`/`exec` are off, and every transport binds to loopback by
## default — bridge traffic is unauthenticated (§6).
extends Node

signal bridge_event_raised(name: String, data: Dictionary)
signal director_value_changed(path: String, value: Variant)
signal status_changed(status: String)
signal bridge_log(level: String, text: String)
signal peer_greeted(role: String, peer_name: String, caps: Array)

## Sentinel for "the mirror has no such key", so a genuine `null`/VOID is still a value.
const MISSING := "\u0001__bridge_missing__"

## Where a relative `root` in the config file is resolved against. Empty = `user://`, i.e. the save
## dir. To talk to Director's mailbox directly, set `root` in Bridge.Data.txt to the movie folder
## (absolute) or point this at it.
@export var mailbox_base := ""
## Read the config from here if non-empty, else search the usual places.
@export_file("*.txt") var config_path := ""
@export var auto_start := true
## "" = whatever Bridge.Data.txt says; overrides it otherwise. The editor dock uses this.
@export var transport_override := ""
## Poll in `_physics_process` (deterministic, 60 Hz) rather than `_process` (one per drawn frame).
@export var physics_tick := true
## Node aliases Director may address as `gd:<alias>.<property>`, as `Alias=Node/Path`.
@export var bindings: Array[String] = []
## Seed values for the replicated store, as `key=literal` (e.g. `wantBoost=TRUE`, `hud=140.0`).
@export var initial_store: Array[String] = []

var peer := BridgePeer.new()
var config := BridgeConfig.new()
var transport: RefCounted = null
## alias -> Node. `gd:Player.hp` looks "Player" up here, then walks the property path.
var bound := {}

var _started := false
var _wired := false


func _init() -> void:
	name = "ShockwaveBridge"
	_wire_peer()


func _ready() -> void:
	if auto_start:
		start()


# --------------------------------------------------------------------------------------------
# lifecycle
# --------------------------------------------------------------------------------------------


## Load the config, build the transport, greet the peer. Idempotent — the editor dock's "Reload"
## button just calls this again, which is how you re-read Bridge.Data.txt without restarting Godot.
func start() -> bool:
	if _started:
		stop()
	config = load_config()
	if not transport_override.is_empty():
		config.transport = transport_override
	_wire_peer()
	var caps := ["snap", "sub", "event", "list", "write"]
	if config.allowEval:
		caps.append("eval")
	if config.allowExec:
		caps.append("exec")
	peer.configure(config, "godot", caps, "Godot %s" % String(Engine.get_version_info().get("string", "4")))
	peer.runtime = self
	_build_transport()
	peer.start()
	_apply_bindings()
	_seed_store()
	_started = true
	peer.log_line("info", "bridge up: %s" % config.summary())
	return true


func stop() -> void:
	if peer != null:
		peer.stop()
	transport = null
	_started = false


func _exit_tree() -> void:
	if _started:
		stop()


func restart() -> bool:
	stop()
	return start()


## Switch transports at runtime (the dock has buttons for this). The config file stays the source of
## truth; this only overrides it for the session.
func set_transport(name: String) -> void:
	transport_override = name
	start()


func is_running() -> bool:
	return _started


## The heartbeat. `_physics_process` is the default because it is already a fixed-step tick
## (60 Hz — raise `Engine.physics_ticks_per_second` for 240 Hz); `_process` tracks your frame rate
## instead, which is the better choice for a purely visual HUD.
func _physics_process(_delta: float) -> void:
	if physics_tick and _started:
		tick()


func _process(_delta: float) -> void:
	if not physics_tick and _started:
		tick()


## One frame of bridge: snapshot out, inbound batch in, flush. `peer.tick()` flushes what it read,
## and the second flush publishes this frame's DELTA — one transport write per frame is the whole
## cost model (§7.1).
func tick() -> void:
	peer.tick(Engine.get_frames_drawn())
	peer.flush()


func _wire_peer() -> void:
	if _wired:
		return
	_wired = true
	peer.value_changed.connect(_on_value_changed)
	peer.status_changed.connect(_on_status_changed)
	peer.peer_event.connect(_on_peer_event)
	peer.peer_log.connect(_on_peer_log)
	peer.peer_hello.connect(_on_peer_hello)


func _seed_store() -> void:
	for entry in initial_store:
		var equals := entry.find("=")
		if equals > 0:
			peer.store[entry.substr(0, equals).strip_edges()] = BridgeLingo.scalar(entry.substr(equals + 1).strip_edges())


func _apply_bindings() -> void:
	for entry in bindings:
		var equals := entry.find("=")
		if equals <= 0:
			continue
		var alias_name := entry.substr(0, equals).strip_edges()
		var node_path := entry.substr(equals + 1).strip_edges()
		var node := get_node_or_null(NodePath(node_path))
		if node == null:
			node = get_parent().get_node_or_null(NodePath(node_path)) if get_parent() != null else null
		if node == null:
			peer.log_line("warn", "binding %s: no node at %s" % [alias_name, node_path])
			continue
		bind_node(node, alias_name)


func load_config() -> BridgeConfig:
	var candidate := _config_file()
	if candidate.is_empty():
		# A missing file is a valid answer: default transport, default ports, nothing writable (§6).
		return BridgeConfig.new()
	return BridgeConfig.load_file(candidate)


## The same file the Director script and tools/*.py read — one config for both processes. Search
## order covers the three layouts people actually use: config at the project root, this repo's
## layout, or next to the Director movie.
func _config_file() -> String:
	if not config_path.is_empty():
		return config_path if not config_path.begins_with("res://") else ProjectSettings.globalize_path(config_path)
	var candidates := [
		"res://Bridge.Data.txt",
		"res://Bridge/Director/Bridge.Data.txt",
		"res://addons/shockwave_bridge/Bridge.Data.txt",
		"user://Bridge.Data.txt",
		ProjectSettings.globalize_path(OS.get_executable_path().get_base_dir()).path_join("Bridge.Data.txt"),
	]
	for path in candidates:
		if FileAccess.file_exists(path):
			return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	if FileAccess.file_exists("Bridge.Data.txt"):  # relative to the CWD: `godot --path .` runs
		return "Bridge.Data.txt"
	return ""


func _build_transport() -> void:
	var base := mailbox_base
	if base.is_empty():
		base = "user://"
	if base.begins_with("res://") or base.begins_with("user://"):
		base = ProjectSettings.globalize_path(base)
	match config.transport:
		"http":
			transport = BridgeTransportHTTP.new()
			transport.setup(peer, config.httpHost, config.httpPort, config)
		"tcp":
			transport = BridgeTransportTCP.new()
			transport.setup(peer, "server", config.tcpHost, config.tcpPort, config)
		_:
			# "files" is the default, and an unknown transport falls back to it rather than dying:
			# a typo in a config file must not stop the game from starting.
			transport = BridgeTransportFiles.new()
			transport.setup(peer, base, config)
	peer.transport = transport


# --------------------------------------------------------------------------------------------
# the API your scenes use
# --------------------------------------------------------------------------------------------


## Register a node so Director can address its properties as `gd:<alias>.<property>`.
## `bind_node(player, "Player")` makes `gd:Player.hp` reachable; writes still need `gd:Player.hp`
## (or the `gd:Player` subtree) in the config's `write` list.
func bind_node(node: Node, alias_name: String) -> void:
	if node == null or alias_name.is_empty():
		return
	bound[alias_name] = node
	var entry := "%s=%s" % [alias_name, node.name]
	if not bindings.has(entry):
		bindings.append(entry)


func unbind_node(alias_name: String) -> void:
	bound.erase(alias_name)


func bound_nodes() -> Array:
	var out: Array = []
	for alias_name in bound:
		out.append(alias_name)
	return out


## Read. Never blocks: `gGame.*`/`bridge.*` come from the mirror, `gd:` from the live object.
func read_path(path: String, fallback: Variant = null) -> Variant:
	var value = peer.read_local(_resolve_alias(path), MISSING)
	return fallback if _is_missing(value) else value


## Typed convenience reads for HUD code: numbers and text out of the mirror without casting.
func read_number(path: String, fallback := 0.0) -> float:
	var value = read_path(path, null)
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		TYPE_BOOL:
			return 1.0 if value else 0.0
		TYPE_STRING:
			return String(value).to_float()
	return fallback


func read_int(path: String, fallback := 0) -> int:
	var value = read_path(path, null)
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return int(value)
		TYPE_BOOL:
			return 1 if value else 0
		TYPE_STRING:
			return String(value).to_int()
	return fallback


func read_string(path: String, fallback := "") -> String:
	var value = read_path(path, null)
	if value == null:
		return fallback
	return BridgeWire.render(value)


## Write. `bridge.*` is always allowed (it is the bridge's own store); a Director path needs the
## config's `write` list; `gd:` writes go straight into the bound object. Pass `want_reply` to get
## the peer's echo (a BridgeError on denial) instead of last-write-wins.
func write_path(path: String, value: Variant, want_reply := false) -> Variant:
	var resolved := _resolve_alias(path)
	if resolved.begins_with("gd:"):
		return _assign_path(resolved, value)
	return peer.write_local(resolved, value, want_reply)


## Write your own data to the movie: it lands in the replicated store on both sides, and Director
## applies it to `gBridge.store` — which is where a Lingo script can read it with plain `item[]`.
func send_custom(key: String, value: Variant) -> Variant:
	return peer.write_local("bridge." + key, value)


func read_custom(key: String, fallback: Variant = null) -> Variant:
	var value = peer.read_local("bridge." + key, MISSING)
	return fallback if _is_missing(value) else value


## Short names from the config's `alias` lines (`kmh` → `gGame.CurrentVehicle.general.kmh`) so HUD
## code does not hard-code the game's object graph.
func _resolve_alias(path: String) -> String:
	if not path.contains(".") and not path.begins_with("gd:") and config.alias.has(path):
		return config.alias[path]
	return path


## Cold read from the peer instead of the mirror: one REQ/RSP round trip. For paths that are not in
## `expose`; `callback` receives the value or a BridgeError.
func request_read(path: String, callback := Callable()) -> int:
	return peer.read_remote(path, callback)


func request_many(paths: Array, callback := Callable()) -> int:
	return peer.request("gets", [BridgeWire.sanitize(";".join(PackedStringArray(paths)))], callback)


## Add a path to the other side's mirror list at runtime (Director's `expose` for the next frame).
func subscribe(path: String, rate := 0) -> void:
	peer.subscribe(_resolve_alias(path), rate)


func unsubscribe(path: String) -> void:
	peer.unsubscribe(_resolve_alias(path))


## Atomic multi-write: Director applies the lot inside one frame (§4 `sets`).
func write_many(pairs: Dictionary) -> int:
	return peer.write_many(pairs)


## Call one of the movie's handlers. Director runs `_movie.sendSprite(0, #handler, target, dataList)`
## and only handlers named in the config's `call` list are reachable. The reply comes to `callback`.
func call_director(handler: String, target := "", data: Variant = null, callback := Callable()) -> int:
	return peer.call_handler(handler, target, data, callback)


## Raise one of the movie's own events — the recommended way to *do* something in the game, because
## the `event` list in Bridge.Data.txt is the real allow-list of game actions.
func raise_director_event(name: String, data: Dictionary = {}) -> void:
	peer.send_event(name, data)


## Ask Director for a subtree (`gGame.CurrentVehicle`, depth 1): the cheapest way to discover what
## exists when you did not list it in `expose`.
func list_paths(prefix := "", depth := 1, callback := Callable()) -> int:
	return peer.list_paths(prefix, depth, callback)


## Turn the mirror on/off and retune the rate at runtime.
func set_snapshot(on: bool, rate := -1, mode := "") -> void:
	peer.set_snapshot(on, rate, mode)


func ping(callback := Callable()) -> int:
	return peer.ping(callback)


func status_text() -> String:
	return peer.status_text()


func peer_status() -> String:
	return peer.status


func stats() -> Dictionary:
	return peer.stats.duplicate(true)


func transport_status() -> Dictionary:
	if transport != null and transport.has_method("status"):
		return transport.call("status")
	return {}


func snapshot() -> Dictionary:
	return peer.snapshot_state()


## The whole mirror, for a debug overlay. Read-only copy: mutating it does nothing to the bridge.
func mirror() -> Dictionary:
	return peer.peer_store.duplicate(true)


func store() -> Dictionary:
	return peer.store.duplicate(true)


func peer_ready() -> bool:
	return peer.peer_ready


func is_live() -> bool:
	return peer.status == BridgePeer.STATUS_UP


# --------------------------------------------------------------------------------------------
# runtime hooks BridgePeer calls (the engine half of the port)
# --------------------------------------------------------------------------------------------


func bridge_resolve(path: String) -> Variant:
	if BridgeWire.is_bridge_path(path):
		var key: String = BridgeWire.bridge_key(path)
		if peer.store.has(key):
			return peer.store[key]
		return peer.peer_store[path] if peer.peer_store.has(path) else null
	if path.begins_with("gd:"):
		return _walk_path(path)
	# Everything else is Director's truth, held here as a mirror.
	return peer.peer_store[path] if peer.peer_store.has(path) else null


func bridge_write(path: String, value: Variant) -> bool:
	if BridgeWire.is_bridge_path(path):
		var key: String = BridgeWire.bridge_key(path)
		if value == null:
			peer.store.erase(key)
		else:
			peer.store[key] = value
		return true
	if path.begins_with("gd:"):
		return not _is_missing(_assign_path(path, value))
	return false


func bridge_enumerate(prefix: String, depth: int) -> Array:
	var out: Array = []
	if prefix.begins_with("gd:"):
		_collect(prefix, _walk_path(prefix), depth, out)
		return out
	for key in peer.peer_store:
		if prefix.is_empty() or String(key).begins_with(prefix):
			out.append([key, peer.peer_store[key]])
	for key in peer.store:
		out.append(["bridge." + String(key), peer.store[key]])
	return out


## Godot has no `sendSprite`, so a "handler" is a method on a bound node (or on this node when the
## target is empty), gated by the same config `call` list the Director side honours.
func bridge_call(handler: String, target: String, data: Variant) -> Variant:
	if not config.call_handlers.is_empty() and not config.call_handlers.has(handler):
		return BridgeError.make("denied", "handler %s is not in the call allow-list" % handler)
	var receiver: Object = self if target.is_empty() else bound.get(target, null)
	if receiver == null or not is_instance_valid(receiver):
		return BridgeError.make("notfound", "no bound node named %s" % target)
	if not receiver.has_method(handler):
		return BridgeError.make("notfound", handler)
	var args: Array = []
	match typeof(data):
		TYPE_NIL:
			pass
		TYPE_ARRAY:
			args = data
		_:
			args = [data]
	return receiver.callv(handler, args)


## The Godot counterpart of Director's `event(0, #name)` dispatch through gData[#Events]: a bound
## node that implements `on_<EventName>` (or the bare name) gets called, and every scene can watch
## the signal.
func bridge_event(name: String, data: Dictionary) -> void:
	bridge_event_raised.emit(name, data)
	var method := "on_" + name.to_snake_case()
	for alias_name in bound:
		var node: Object = bound[alias_name]
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method(method):
			node.callv(method, [] if data.is_empty() else [data])
		elif node.has_method(name):
			node.callv(name, [] if data.is_empty() else [data])


## There is no `eval` in GDScript and this bridge will not add one. What is safe and useful: the
## expression is read as a *path*, so Director can probe a bound node without an `expose` entry.
## Arbitrary code execution stays a Director-side capability (§6).
func bridge_eval(expression: String) -> Variant:
	var trimmed := expression.strip_edges()
	if trimmed.begins_with("gd:") or BridgeWire.is_bridge_path(trimmed) or trimmed.begins_with("gGame."):
		if not BridgeWire.allowed(trimmed, config.read_patterns()):
			return BridgeError.make("denied", trimmed)
		return bridge_resolve(trimmed)
	return BridgeError.make("disabled", "Godot has no eval; pass a path, or use call/event")


func bridge_exec(_statements: String) -> Variant:
	return BridgeError.make("disabled", "exec is Director-only; use sets/event from Godot")


# --------------------------------------------------------------------------------------------
# gd: path walking
# --------------------------------------------------------------------------------------------


func _is_missing(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and value == MISSING


func _walk_path(path: String) -> Variant:
	var segments := _path_segments(path)
	if segments.is_empty():
		return null
	var root: Object = bound.get(segments[0], null)
	if root == null or not is_instance_valid(root):
		return null
	return _walk_into(root, segments.slice(1))


## Dictionaries, Arrays, Objects and nested bound nodes all walk the same way, which is what makes
## `gd:Game.hud.speedLabel` work on a plain Dictionary as well as on a Node with sub-objects.
func _walk_into(current: Variant, segments: PackedStringArray) -> Variant:
	var node := current
	for segment in segments:
		var key := String(segment)
		if key.is_empty():
			continue
		if typeof(node) == TYPE_DICTIONARY:
			if not (node as Dictionary).has(key):
				return null
			node = (node as Dictionary)[key]
			continue
		if node is Array:
			if not key.is_valid_int():
				return null
			var index := int(key)
			if index < 0 or index >= (node as Array).size():
				return null
			node = (node as Array)[index]
			continue
		if node is Object:
			if not is_instance_valid(node) or not _has_property(node, key):
				return null
			node = (node as Object).get(key)
			continue
		var component := _component_get(node, key)
		if _is_missing(component):
			return null
		node = component
		continue
	return node


## `gd:Player.speed[0]`, `gd:Panel.rect[2]`, `gd:Sprite.modulate[3]`. Godot's math types are not
## Objects, so there is no property to read; this is the component form, and the numbering matches
## the wire types (§2): a color is 0-255 ints like `c:`, and a rect's 2 and 3 are its END
## coordinates like `r:` -- not `size`, which is what `Rect2[2]` would have handed back.
static func _component_get(node: Variant, key: String) -> Variant:
	if not key.is_valid_int():
		return MISSING
	var index := int(key)
	match typeof(node):
		TYPE_VECTOR2:
			if index < 0 or index > 1:
				return MISSING
			return node.x if index == 0 else node.y
		TYPE_VECTOR3:
			if index < 0 or index > 2:
				return MISSING
			if index == 0:
				return node.x
			if index == 1:
				return node.y
			return node.z
		TYPE_COLOR:
			if index < 0 or index > 3:
				return MISSING
			var channel := 0.0
			match index:
				0:
					channel = node.r
				1:
					channel = node.g
				2:
					channel = node.b
				_:
					channel = node.a
			return int(round(channel * 255.0))
		TYPE_RECT2:
			if index < 0 or index > 3:
				return MISSING
			match index:
				0:
					return node.position.x
				1:
					return node.position.y
				2:
					return node.end.x
				_:
					return node.end.y
	return MISSING


static func _component_count(node: Variant) -> int:
	match typeof(node):
		TYPE_VECTOR2:
			return 2
		TYPE_VECTOR3:
			return 3
		TYPE_COLOR, TYPE_RECT2:
			return 4
	return 0


static func _has_property(object: Object, key: String) -> bool:
	for property in object.get_property_list():
		if String(property["name"]) == key:
			return true
	return false


## Assign the last segment. Returns MISSING (and logs) when the path does not resolve, so callers can
## tell "set to null" from "nothing was set".
func _assign_path(path: String, value: Variant) -> Variant:
	var segments := _path_segments(path)
	if segments.size() < 2:
		peer.log_line("warn", "gd: write needs at least one property: %s" % path)
		return MISSING
	var leaf := String(segments[segments.size() - 1])
	var root: Object = bound.get(segments[0], null)
	if root == null or not is_instance_valid(root):
		peer.log_line("warn", "gd: nothing bound as %s" % segments[0])
		return MISSING
	var parent := _walk_into(root, segments.slice(1, segments.size() - 1))
	if typeof(parent) == TYPE_DICTIONARY:
		(parent as Dictionary)[leaf] = value
		return value
	if parent is Array and leaf.is_valid_int():
		var index := int(leaf)
		if index >= 0 and index < (parent as Array).size():
			(parent as Array)[index] = value
			return value
		return MISSING
	if parent is Object and is_instance_valid(parent):
		if not _has_property(parent, leaf):
			return MISSING
		(parent as Object).set(leaf, value)
		return value
	# A component of a math type cannot be assigned through the walk, because reading
	# `Player.speed` hands back a copy: the owner, the property, and the new whole value have to
	# be assembled together, which is why this branch reaches one segment further back.
	if segments.size() >= 3 and _component_count(parent) > 0:
		var owner: Variant = _walk_into(root, segments.slice(1, segments.size() - 2))
		if owner is Object and is_instance_valid(owner):
			var holder := String(segments[segments.size() - 2])
			var rebuilt := _component_with(parent, leaf, value)
			if not _is_missing(rebuilt):
				(owner as Object).set(holder, rebuilt)
				return value
	peer.log_line("warn", "gd: cannot write %s" % path)
	return MISSING


## The value with one component replaced, in wire units (color channels 0-255, rect 2/3 as end
## coordinates) so `gd:Sprite.modulate[0] = 255` and `c:255,0,0` mean the same thing.
static func _component_with(node: Variant, key: String, value: Variant) -> Variant:
	if not key.is_valid_int():
		return MISSING
	var index := int(key)
	if index < 0 or index >= _component_count(node):
		return MISSING
	var number := float(value)
	match typeof(node):
		TYPE_VECTOR2:
			if index == 0:
				return Vector2(number, node.y)
			return Vector2(node.x, number)
		TYPE_VECTOR3:
			var parts := [node.x, node.y, node.z]
			parts[index] = number
			return Vector3(parts[0], parts[1], parts[2])
		TYPE_COLOR:
			var channels := [node.r, node.g, node.b, node.a]
			channels[index] = clamp(number / 255.0, 0.0, 1.0)
			return Color(channels[0], channels[1], channels[2], channels[3])
		TYPE_RECT2:
			var left: float = node.position.x
			var top: float = node.position.y
			var right: float = node.end.x
			var bottom: float = node.end.y
			match index:
				0:
					left = number
				1:
					top = number
				2:
					right = number
				_:
					bottom = number
			return Rect2(left, top, right - left, bottom - top)
	return MISSING


## `gd:Game.hud.speedLabel` -> ["Game", "hud", "speedLabel"]; `gd:List[3]` -> ["List", "3"].
func _path_segments(path: String) -> PackedStringArray:
	var body := path.substr(3) if path.begins_with("gd:") else path
	var out := PackedStringArray()
	for segment in body.split("."):
		var bracket := segment.find("[")
		if bracket < 0:
			out.append(segment)
			continue
		out.append(segment.substr(0, bracket))
		var close := segment.find("]", bracket)
		var index := segment.substr(bracket + 1, (close if close > bracket else segment.length()) - bracket - 1)
		if not index.is_empty():
			out.append(index)
	return out


## Depth-first enumeration, same shape as `BridgePeer.enumerate` in the reference: `depth 0` lists
## the direct children only, `-1`/anything else walks everything.
func _collect(prefix: String, node: Variant, depth: int, out: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for key in (node as Dictionary):
			var child := BridgeWire.path_child(prefix, key)
			var value = (node as Dictionary)[key]
			if (typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY) and depth != 0:
				_collect(child, value, maxi(0, depth - 1) if depth > 0 else 0, out)
			else:
				out.append([child, value])
		return
	if node is Array:
		for index in range((node as Array).size()):
			out.append([BridgeWire.path_child(prefix, index), (node as Array)[index]])
		return
	if node is Object and node != null and is_instance_valid(node):
		for property in (node as Object).get_property_list():
			var usage: int = property["usage"]
			if not (usage & PROPERTY_USAGE_STORAGE) or not (usage & PROPERTY_USAGE_DEFAULT):
				continue
			var name := String(property["name"])
			if name.is_empty() or name == "script" or name.begins_with("metadata"):
				continue
			out.append(["%s.%s" % [prefix, name], (node as Object).get(name)])
		return
	out.append([prefix, node])


# --------------------------------------------------------------------------------------------
# peer signal forwarding
# --------------------------------------------------------------------------------------------


func _on_value_changed(path: String, value: Variant) -> void:
	director_value_changed.emit(path, value)


func _on_status_changed(status: String) -> void:
	status_changed.emit(status)


func _on_peer_event(name: String, data: Dictionary) -> void:
	# `bridge_event_raised` already fired from bridge_event(); this is the log line for watchers.
	bridge_log.emit("info", "EVT %s %s" % [name, str(data)])


func _on_peer_log(level: String, text: String) -> void:
	bridge_log.emit(level, text)


func _on_peer_hello(role: String, greeter: String, caps: Array) -> void:
	peer_greeted.emit(role, greeter, caps)
	bridge_log.emit("info", "HELLO from %s (%s) caps=%s" % [role, greeter, ", ".join(PackedStringArray(caps))])
