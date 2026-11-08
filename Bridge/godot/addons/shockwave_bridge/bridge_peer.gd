## The bridge state machine: PROTOCOL.md §4 (messages), §6 (gates), §8 (timing/ordering).
##
## A faithful port of `tools/bridge_peer.py`, which `tools/test_bridge.py` exercises against a mock
## Director over all three transports — so the behaviour here is not a guess, it is the same state
## machine in GDScript. The Lingo module is the third copy.
##
## Responsibilities:
## * mirror the peer's exposed state into `peer_store`, so reads never block (§4 SNAP/DELTA);
## * keep the replicated `bridge.*` store, which either side may read and write;
## * answer the peer's REQ lines, gated by the allow-lists in BridgeConfig;
## * turn one inbound batch into at most one reply batch, applied in the frame tick (§6).
##
## It never touches the engine. Everything engine-shaped goes through `runtime`, an object that
## implements `bridge_resolve / bridge_write / bridge_enumerate / bridge_call / bridge_event /
## bridge_eval / bridge_exec` (see `shockwave_bridge.gd`). That is what keeps this file testable
## headless, which is how `bridge_selftest.gd` runs it against itself.
class_name BridgePeer
extends RefCounted

signal value_changed(path: String, value: Variant)
signal status_changed(status: String)
signal peer_event(name: String, data: Dictionary)
signal peer_log(level: String, text: String)
signal peer_hello(role: String, peer_name: String, caps: Array)

const STATUS_UP := "up"
const STATUS_STALE := "stale"
const STATUS_DOWN := "down"

## Path roots the *Director* side owns (§5). A Godot peer must never echo these back, and vice
## versa — that single rule is what stops two mirrors from feeding each other forever.
const DIRECTOR_ROOTS := ["gGame", "gSystem", "gData", "gSound", "gBridge", "member", "sprite", "_movie", "_player", "_system"]

const MAX_POLL_PER_FRAME := 64

var cfg := BridgeConfig.new()
var role := "godot"
var peer_label := "Godot"
var caps: Array = ["snap", "sub", "event", "list", "write"]
var runtime: Object = null
var transport: Object = null
var verbose := false

var store := {}  # our half of the replicated bridge.* store
var peer_store := {}  # the mirror of whatever the peer exposes
var subscriptions := {}  # path -> rate (0 = every snapshot)
var pending := {}  # rid -> {op, sent_ms, callback}

var out_seq := 0
var in_seq := 0
var peer_ack := 0
var frame := 0
var status := STATUS_DOWN
var peer_ready := false
var peer_role := ""
var peer_name := ""
var peer_caps: Array = []
var peer_frame := 0
var peer_tms := 0
var latency_ms := 0.0
var last_seen_ms := 0

var stats := {
	"frames_out": 0, "frames_in": 0, "msgs_out": 0, "msgs_in": 0,
	"bytes_out": 0, "bytes_in": 0, "errors": 0, "dupes": 0, "torn": 0,
	"timeouts": 0, "denied": 0, "requests": 0, "replies": 0,
}

var _outbox: Array = []  # Array[Array[String]] — batches waiting for this frame's flush
var _dirty := {}
var _last_sent := {}
var _next_rid := 0
var _hello_sent := false
var _epoch_ms := 0


func _init() -> void:
	_epoch_ms = Time.get_ticks_msec()


# --------------------------------------------------------------------------------------------
# configuration
# --------------------------------------------------------------------------------------------


## `config` is a BridgeConfig, `p_role` is "godot" or "director". Call once, before `start()`.
func configure(config: BridgeConfig, p_role: String, p_caps: Array, label: String = "") -> void:
	cfg = config
	role = p_role
	caps = p_caps.duplicate()
	if not label.is_empty():
		peer_label = label
	if cfg.requestTimeoutMs <= 0:
		cfg.requestTimeoutMs = 2000


func start() -> void:
	_hello_sent = false
	_epoch_ms = Time.get_ticks_msec()
	if transport != null and transport.has_method("start"):
		transport.call("start", self)


func stop() -> void:
	push_bye("stop")
	flush()
	if transport != null and transport.has_method("stop"):
		transport.call("stop")
	# Transports also hold their peer. Break that RefCounted cycle on stop.
	transport = null


## A transport calls this when a link (re)connects, so HELLO is re-greeted to whoever is now on the
## other end. Without it, a peer that was already "greeted" into a dead socket never says hello.
func reset_hello() -> void:
	_hello_sent = false


func uptime_ms() -> int:
	return Time.get_ticks_msec() - _epoch_ms


func capability(name: String) -> bool:
	return caps.has(name)


func log_line(level: String, text: String) -> void:
	if verbose or level == "warn" or level == "error":
		print("[bridge:%-6s %-5s] %s" % [role, level, text])
	peer_log.emit(level, text)


# --------------------------------------------------------------------------------------------
# outbound plumbing
# --------------------------------------------------------------------------------------------


func push(batch: Array) -> void:
	if batch.is_empty():
		return
	stats["msgs_out"] += batch.size()
	stats["bytes_out"] += _batch_bytes(batch)
	_outbox.append(batch)


func _batch_bytes(batch: Array) -> int:
	var total := 0
	for line in batch:
		total += String(line).length() + 1
	return total


## Everything queued this frame goes out as ONE batch. Merging is not an optimisation: the file
## transport publishes by replacing a single file, so two emits in one frame would lose the first.
func flush() -> int:
	if _outbox.is_empty():
		return 0
	var merged: Array = []
	for batch in _outbox:
		merged.append_array(batch)
	_outbox.clear()
	if transport != null and transport.has_method("send"):
		transport.call("send", merged)
	return merged.size()


func next_rid() -> int:
	_next_rid += 1
	return _next_rid


## Queued RPC: exactly one RSP (or a `timeout` error) resolves it.
func request(op: String, args: Array, callback: Callable = Callable()) -> int:
	var rid := next_rid()
	push([BridgeWire.build("REQ", [rid, op] + args)])
	pending[rid] = {"op": op, "sent_ms": uptime_ms(), "callback": callback}
	stats["requests"] += 1
	return rid


## Fire-and-forget: same ops as REQ, never answered. This is the cheap direction for writes.
func command(op: String, args: Array) -> void:
	push([BridgeWire.build("CMD", [next_rid(), op] + args)])


func push_bye(reason: String) -> void:
	push([BridgeWire.build("BYE", [BridgeWire.sanitize(reason), "i:0"])])


# --------------------------------------------------------------------------------------------
# the API the game code uses
# --------------------------------------------------------------------------------------------


## Read the mirrored copy. Never blocks, never allocates a request — this is the hot path a HUD or
## a Godot-side sim loop calls every frame.
func read_local(path: String, fallback: Variant = null) -> Variant:
	if peer_store.has(path):
		return peer_store[path]
	if BridgeWire.is_bridge_path(path):
		var key: String = BridgeWire.bridge_key(path)
		if store.has(key):
			return store[key]
	return fallback


## Local truth: `bridge.*` is *ours*, everything else is the mirror.
func read_path(path: String) -> Variant:
	if BridgeWire.is_bridge_path(path):
		var key: String = BridgeWire.bridge_key(path)
		if store.has(key):
			return store[key]
		return peer_store[path] if peer_store.has(path) else null
	return peer_store[path] if peer_store.has(path) else null


## `bridge.*` writes our replicated store and goes out with the next snapshot. Any other path is a
## write on the *peer*: fire-and-forget, because the peer's own DELTA brings the value back to us.
## Pass `want_reply` when you need the echo (permission errors, validation).
func write_local(path: String, value: Variant, want_reply := false) -> Variant:
	if BridgeWire.is_bridge_path(path):
		var key: String = BridgeWire.bridge_key(path)
		if value == null:
			store.erase(key)
		else:
			store[key] = value
		mark_dirty(path, value)
		return value
	if want_reply:
		return request("set", [BridgeWire.sanitize(path), BridgeWire.encode(value)])
	command("set", [BridgeWire.sanitize(path), BridgeWire.encode(value)])
	if owns(path):
		mark_dirty(path, value)
	return null


## Atomic multi-write: the peer applies the whole list in one of its frames.
func write_many(pairs: Dictionary) -> int:
	var chunks: Array[String] = []
	for path in pairs:
		chunks.append("%s=%s" % [BridgeWire.sanitize(String(path)), BridgeWire.encode(pairs[path])])
	return request("sets", [BridgeWire.sanitize(";".join(chunks))])


## `RSP <id> get ok <path> <value>` has two fields, so the callback has to unwrap and type the
## value. Director does the same in `BridgeRpcGet`. Keeping it here means no caller re-implements it.
func read_remote(path: String, callback: Callable = Callable()) -> int:
	if not callback.is_valid():
		return request("get", [BridgeWire.sanitize(path)])
	return request("get", [BridgeWire.sanitize(path)], _unwrap_value(callback))


static func _unwrap_value(callback: Callable) -> Callable:
	return func(payload: Variant) -> void:
		var value: Variant = payload
		if payload is Array and (payload as Array).size() >= 2:
			value = (payload as Array)[1]
		if value is BridgeError or typeof(value) != TYPE_STRING:
			callback.call(value)
			return
		callback.call(BridgeWire.decode_or_text(String(value)))


func subscribe(path: String, rate := 0) -> void:
	if subscriptions.has(path):
		return
	subscriptions[path] = rate
	command("sub", [BridgeWire.sanitize(path), rate])


func unsubscribe(path: String) -> void:
	if subscriptions.has(path):
		subscriptions.erase(path)
		command("unsub", [BridgeWire.sanitize(path)])


## Invoke a handler on the peer. Director side: `_movie.sendSprite(0, handler, target, dataList)`.
## Numeric sprite IDs and string aliases both travel as text; null means the default target.
func call_handler(handler: String, target: Variant = "", data: Variant = null, callback: Callable = Callable()) -> int:
	var target_text := ""
	match typeof(target):
		TYPE_NIL:
			pass
		TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			target_text = str(target)
		_:
			push_error("call_handler target must be an integer, string, or null")
			return -1
	var payload := "" if data == null else BridgeLingo.prints(data)
	return request("call", [BridgeWire.sanitize(handler), BridgeWire.sanitize(target_text), payload], callback)


## Fire-and-forget event into the peer's own event system (Director `event(0, #name)`).
func send_event(name: String, data: Dictionary = {}) -> void:
	out_seq += 1
	var pairs: Array = []
	for key in data:
		pairs.append([key, data[key]])
	push([BridgeWire.build("EVT", [out_seq, BridgeWire.sanitize(name), BridgeWire.encode_kv(pairs)])])


func list_paths(prefix: String, depth := 0, callback: Callable = Callable()) -> int:
	if not callback.is_valid():
		return request("list", [BridgeWire.sanitize(prefix), depth])
	return request("list", [BridgeWire.sanitize(prefix), depth], func(value: Variant) -> void:
		if value is BridgeError:
			callback.call(value)
		elif value is String:
			callback.call(BridgeWire.kv_to_dict(value))
		else:
			callback.call(value)
	)


func ping(callback: Callable = Callable()) -> int:
	return request("ping", [uptime_ms()], callback)


## Turn the mirror on/off and retune it at runtime; the peer applies the same settings to itself.
func set_snapshot(on: bool, rate := -1, mode := "") -> void:
	var new_rate := cfg.rate if rate < 0 else maxi(1, rate)
	var new_mode := cfg.snapshot if mode.is_empty() else mode
	cfg.rate = new_rate
	cfg.snapshot = new_mode
	if not on:
		subscriptions.clear()
		_dirty.clear()
		_last_sent.clear()
	command("snap", ["b:%d" % (1 if on else 0), new_rate, new_mode])


func send_log(level: String, text: String) -> void:
	push([BridgeWire.build("LOG", [level, BridgeWire.sanitize(text)])])


# --------------------------------------------------------------------------------------------
# snapshot building (§4 SNAP/DELTA, §8 ordering)
# --------------------------------------------------------------------------------------------


func owns(path: String) -> bool:
	if BridgeWire.is_bridge_path(path):
		return true
	if path.begins_with("gd:"):
		return role == "godot"
	var head := BridgeWire.path_namespace(path)
	if role == "director":
		return DIRECTOR_ROOTS.has(head)
	return not DIRECTOR_ROOTS.has(head)


func mark_dirty(path: String, value: Variant) -> void:
	if not owns(path):
		return
	_dirty[path] = value


## Subscribed paths whose value moved, plus anything local code flagged dirty this frame.
func collect_changes() -> Array:
	var pairs: Array = []
	for path in _dirty:
		pairs.append([path, _dirty[path]])
	_dirty.clear()
	for path in subscriptions:
		var value = resolve_path(path)
		if not _last_sent.has(path) or _last_sent[path] != value:
			pairs.append([path, value])
	return pairs


func resolve_path(path: String) -> Variant:
	if runtime != null and runtime.has_method("bridge_resolve"):
		return runtime.call("bridge_resolve", path)
	return null


func build_snapshot(batch: Array) -> void:
	## One DELTA (or SNAP) per frame: subscribed changes + our half of the replicated store.
	## Values received from the peer are never re-broadcast — that is `owns()`'s whole job.
	var pairs: Array = []
	var seen := {}
	if cfg.snapshot == "full":
		for path in subscriptions:
			var value = resolve_path(path)
			pairs.append([path, value])
			seen[path] = true
		for path in _dirty:
			if not seen.has(path):
				pairs.append([path, _dirty[path]])
		_dirty.clear()
	else:
		pairs = collect_changes()
		for pair in pairs:
			seen[pair[0]] = true
	for key in store:
		var path := "bridge." + String(key)
		if seen.has(path):
			continue
		var value = store[key]
		if _last_sent.has(path) and _last_sent[path] == value:
			continue
		pairs.append([path, value])
	var owned: Array = []
	for pair in pairs:
		if owns(pair[0]):
			owned.append(pair)
	if owned.is_empty():
		return
	for pair in owned:
		_last_sent[pair[0]] = pair[1]
	out_seq += 1
	var verb := "SNAP" if cfg.snapshot == "full" else "DELTA"
	batch.append(BridgeWire.build(verb, [out_seq, frame, uptime_ms(), in_seq, BridgeWire.encode_kv(owned)]))


func tick(new_frame := -1) -> void:
	frame = frame + 1 if new_frame < 0 else new_frame
	var rate := maxi(1, cfg.rate)
	if frame % rate == 0:
		var batch: Array = []
		build_snapshot(batch)
		if not batch.is_empty():
			stats["frames_out"] += 1
			push(batch)
	if not _hello_sent:
		_hello_sent = true
		push([BridgeWire.build("HELLO", [role, peer_label, BridgeWire.PROTOCOL_VERSION, out_seq, ",".join(PackedStringArray(caps))])])
	reap_timeouts()
	ingest_transport()


## One inbound batch per frame, applied in the tick — never from a callback (§6).
func ingest_transport() -> void:
	if transport == null or not transport.has_method("poll"):
		return
	# Drain the transport completely: a reply must not sit behind the snapshot lines that arrived in
	# the same frame. Order inside the batch is preserved, so §8 still holds.
	for _guard in range(MAX_POLL_PER_FRAME):
		var lines = transport.call("poll")
		if lines == null:
			return
		if not (lines is Array) or (lines as Array).is_empty():
			return
		feed(lines)
		flush()


func reap_timeouts() -> void:
	var now := uptime_ms()
	for rid in pending.keys():
		var item: Dictionary = pending[rid]
		if now - int(item["sent_ms"]) > cfg.requestTimeoutMs:
			pending.erase(rid)
			stats["timeouts"] += 1
			log_line("warn", "request timeout %s %s" % [item["op"], rid])
			if item["callback"].is_valid():
				item["callback"].call(BridgeError.make("timeout", String(item["op"])))
	update_status()


func update_status() -> void:
	var silence := 1000000000 if last_seen_ms == 0 else uptime_ms() - last_seen_ms
	var previous := status
	if not peer_ready:
		status = STATUS_DOWN
	elif silence > cfg.peerTimeoutMs * 5:
		status = STATUS_DOWN
	elif silence > cfg.peerTimeoutMs:
		status = STATUS_STALE
	else:
		status = STATUS_UP
	if previous != status:
		log_line("info", "status %s -> %s" % [previous, status])
		status_changed.emit(status)


# --------------------------------------------------------------------------------------------
# inbound
# --------------------------------------------------------------------------------------------


## Apply a batch in order and queue the single reply batch it generates. Returns the reply lines.
func feed(lines: Array) -> Array:
	var reply: Array = []
	for line in lines:
		var parsed := BridgeWire.parse(String(line))
		var verb: String = parsed[0]
		var fields: Array = parsed[1]
		if verb.is_empty():
			continue
		stats["msgs_in"] += 1
		stats["bytes_in"] += String(line).length() + 1
		last_seen_ms = uptime_ms()
		dispatch(verb, fields, reply)
	if not reply.is_empty():
		stats["replies"] += 1
		push(reply)
	return reply


func dispatch(verb: String, fields: Array, reply: Array) -> void:
	match verb:
		"SNAP", "DELTA":
			accept_snapshot(fields)
			return
		"EVT":
			if fields.size() >= 2:
				var data := BridgeWire.kv_to_dict(String(fields[2])) if fields.size() > 2 else {}
				on_event(String(fields[1]), data)
			return
		"HELLO":
			accept_hello(fields)
			return
		"BYE":
			peer_ready = false
			update_status()
			return
		"PING":
			reply.append(BridgeWire.build("PONG", [fields[0] if not fields.is_empty() else 0, uptime_ms()]))
			return
		"PONG":
			if fields.size() >= 2 and String(fields[1]).is_valid_int():
				latency_ms = float(uptime_ms() - int(fields[1]))
			return
		"LOG":
			log_line("peer", " ".join(PackedStringArray(fields)))
			return
		"REQ":
			if fields.size() < 2:
				return
			# exactly one RSP per REQ, ok or err, built in this same frame (§8)
			reply.append(rsp_line(fields[0], fields[1], handle_op(String(fields[1]), fields.slice(2))))
			return
		"CMD":
			if fields.size() < 2:
				return
			var outcome = handle_op(String(fields[1]), fields.slice(2))
			if outcome is BridgeError:
				log_line("warn", "cmd %s %s" % [fields[1], outcome])
			return
		"RSP":
			accept_rsp(fields)
			return
		_:
			# an unknown verb is answered by ignoring it (§9): a newer peer must not kill this one
			log_line("warn", "ignored unknown verb %s" % verb)


func accept_hello(fields: Array) -> void:
	peer_ready = true
	peer_role = String(fields[0]) if not fields.is_empty() else ""
	peer_name = String(fields[1]) if fields.size() > 1 else ""
	# HELLO also means "my frame counter has started over" (field 3 is the greeter's seq). A peer
	# that restarts while we keep running would otherwise be discarded as stale until its count
	# passed ours -- which is why the reference `read_frame` only skips an exact repeat (§4).
	var announced := int(fields[3]) if fields.size() > 3 and String(fields[3]).is_valid_int() else 0
	if announced < in_seq:
		in_seq = 0
		stats["dupes"] = 0
		if transport != null and transport.has_method("reset_inbound"):
			transport.call("reset_inbound")
	peer_caps = []
	if fields.size() > 4:
		for cap in String(fields[4]).split(","):
			if not cap.is_empty():
				peer_caps.append(cap)
	last_seen_ms = uptime_ms()
	stats["frames_in"] += 1
	update_status()
	peer_hello.emit(peer_role, peer_name, peer_caps)
	if not _hello_sent:  # the peer greeted us first: answer once
		_hello_sent = true
		push([BridgeWire.build("HELLO", [role, peer_label, BridgeWire.PROTOCOL_VERSION, out_seq, ",".join(PackedStringArray(caps))])])


func on_event(name: String, data: Dictionary) -> void:
	## An inbound EVT is the peer raising one of our events. The runtime's `bridge_event` is the
	## "do this to the game" hook; the signal is what the scene code listens to.
	peer_event.emit(name, data)
	if runtime != null and runtime.has_method("bridge_event"):
		runtime.call("bridge_event", name, data)


func accept_snapshot(fields: Array) -> void:
	if fields.is_empty() or not String(fields[0]).is_valid_int():
		return
	var seq := int(fields[0])
	if seq <= in_seq:
		stats["dupes"] += 1
		return  # never apply the same seq twice (§8): a replayed file frame is harmless
	in_seq = seq
	stats["frames_in"] += 1
	peer_frame = int(fields[1]) if fields.size() > 1 and String(fields[1]).is_valid_int() else 0
	peer_tms = int(fields[2]) if fields.size() > 2 and String(fields[2]).is_valid_int() else 0
	peer_ack = int(fields[3]) if fields.size() > 3 and String(fields[3]).is_valid_int() else peer_ack
	if fields.size() > 4:
		for pair in BridgeWire.decode_kv(String(fields[4])):
			apply_remote(String(pair[0]), pair[1])


func apply_remote(path: String, value: Variant, local_write := false) -> void:
	if BridgeWire.is_bridge_path(path):
		var key: String = BridgeWire.bridge_key(path)
		if value == null:
			store.erase(key)
		else:
			store[key] = value
		peer_store[path] = value
		_last_sent[path] = value
		value_changed.emit(path, value)
		return
	if local_write and runtime != null and runtime.has_method("bridge_write"):
		runtime.call("bridge_write", path, value)
	peer_store[path] = value
	_last_sent[path] = value
	value_changed.emit(path, value)


func accept_rsp(fields: Array) -> void:
	if fields.size() < 3 or not String(fields[0]).is_valid_int():
		return
	var rid := int(fields[0])
	if not pending.has(rid):
		stats["dupes"] += 1
		return
	var item: Dictionary = pending[rid]
	pending.erase(rid)
	var callback: Callable = item["callback"]
	if String(fields[2]) == "ok":
		var payload: Array = []
		for index in range(3, fields.size()):
			payload.append(BridgeWire.decode_or_text(String(fields[index])))
		if not callback.is_valid():
			return
		# one field is the value itself; several stay a list (§4)
		if payload.size() == 1:
			callback.call(payload[0])
		else:
			callback.call(payload)
		return
	stats["errors"] += 1
	if callback.is_valid():
		callback.call(BridgeError.make(
			String(fields[3]) if fields.size() > 3 else "error",
			String(fields[4]) if fields.size() > 4 else ""
		))


func rsp_line(rid: Variant, op: Variant, result: Variant) -> String:
	if result is BridgeError:
		return BridgeWire.build("RSP", [rid, op, "err", result.code, result.message])
	var fields: Array = [rid, op, "ok"]
	for value in result:
		fields.append(BridgeWire.sanitize(_field_text(value)))
	return BridgeWire.build("RSP", fields)


func _field_text(value: Variant) -> String:
	## RSP fields are pre-formatted by the op (`encode`/`encode_kv` already ran), so a String is
	## passed through and only anything else is typed. Mirrors `Peer.rsp_line`.
	if typeof(value) == TYPE_STRING:
		return value
	return BridgeWire.encode(value)


# --------------------------------------------------------------------------------------------
# ops the peer may ask us to perform (§4 table)
# --------------------------------------------------------------------------------------------


func handle_op(op: String, args: Array) -> Variant:
	## Returns an Array of already-formatted RSP fields, or a BridgeError. GDScript has no
	## exceptions, so errors travel as values — which is how they look on the wire too.
	if op == "get":
		if args.is_empty():
			return BridgeError.make("badargs", "get <path>")
		var error := check_read(String(args[0]))
		if error != null:
			return error
		return [args[0], BridgeWire.encode(resolve_path(String(args[0])))]
	if op == "gets":
		var out: Array[String] = []
		for path in String(args[0] if not args.is_empty() else "").split(";"):
			if path.is_empty():
				continue
			if not BridgeWire.allowed(path, cfg.read_patterns()):
				stats["denied"] += 1
				out.append("%s=denied" % path)
				continue
			out.append("%s=%s" % [path, BridgeWire.encode(resolve_path(path))])
		return [";".join(out)]
	if op == "set":
		if args.size() < 2:
			return BridgeError.make("badargs", "set <path> <value>")
		var error := check_write(String(args[0]))
		if error != null:
			return error
		var value = BridgeWire.decode(String(args[1]))
		if value is BridgeError:
			return value
		apply_remote(String(args[0]), value, true)
		mark_dirty(String(args[0]), value)
		return [args[0], BridgeWire.encode(value)]
	if op == "sets":
		var out: Array[String] = []
		for chunk in String(args[0] if not args.is_empty() else "").split(";"):
			var equals := chunk.find("=")
			if equals <= 0:
				continue
			var path := chunk.substr(0, equals)
			var raw := chunk.substr(equals + 1)
			var error := check_write(path)
			if error != null:
				stats["denied"] += 1
				out.append("%s=denied" % path)
				continue
			var value = BridgeWire.decode_or_text(raw) if not raw.is_empty() else null
			apply_remote(path, value, true)
			mark_dirty(path, value)
			out.append("%s=%s" % [path, BridgeWire.encode(value)])
		return [";".join(out)]
	if op == "sub":
		if args.is_empty():
			return BridgeError.make("badargs", "sub <path>")
		var error := check_read(String(args[0]))
		if error != null:
			return error
		subscriptions[String(args[0])] = int(args[1]) if args.size() > 1 and String(args[1]).is_valid_int() else 0
		return [args[0], BridgeWire.encode(resolve_path(String(args[0])))]
	if op == "unsub":
		if not args.is_empty():
			subscriptions.erase(String(args[0]))
		return [args[0] if not args.is_empty() else ""]
	if op == "snap":
		var on := String(args[0] if not args.is_empty() else "b:1").ends_with("1")
		if args.size() > 1 and String(args[1]).is_valid_int():
			cfg.rate = maxi(1, int(args[1]))
		if args.size() > 2 and not String(args[2]).is_empty():
			cfg.snapshot = String(args[2])
		if not on:
			subscriptions.clear()
			_dirty.clear()
			_last_sent.clear()
		return ["b:%d" % (1 if on else 0), str(cfg.rate), cfg.snapshot]
	if op == "call":
		if args.is_empty():
			return BridgeError.make("badargs", "call <handler> [target] [literal]")
		if runtime == null or not runtime.has_method("bridge_call"):
			return BridgeError.make("unknownop", "call is not implemented by this peer")
		var data: Variant = null
		if args.size() > 2 and not String(args[2]).is_empty():
			data = BridgeLingo.parse(String(args[2]))
		var result = runtime.call("bridge_call", String(args[0]), String(args[1]) if args.size() > 1 else "", data)
		if result is BridgeError:
			return result
		return [BridgeWire.encode(result)]
	if op == "event":
		if args.is_empty():
			return BridgeError.make("badargs", "event <name> [kvlist]")
		var data := BridgeWire.kv_to_dict(String(args[1])) if args.size() > 1 else {}
		if runtime != null and runtime.has_method("bridge_event"):
			runtime.call("bridge_event", String(args[0]), data)
		peer_event.emit(String(args[0]), data)
		return ["b:1"]
	if op == "eval":
		if not (cfg.allowEval and capability("eval")):
			return BridgeError.make("disabled", "eval needs allowEval")
		if runtime == null or not runtime.has_method("bridge_eval"):
			return BridgeError.make("disabled", "eval is not implemented by this peer")
		return [BridgeWire.encode(runtime.call("bridge_eval", " ".join(PackedStringArray(args))))]
	if op == "exec":
		if not (cfg.allowExec and capability("exec")):
			return BridgeError.make("disabled", "exec needs allowExec")
		if runtime == null or not runtime.has_method("bridge_exec"):
			return BridgeError.make("disabled", "exec is not implemented by this peer")
		return [BridgeWire.encode(runtime.call("bridge_exec", "\n".join(PackedStringArray(args))))]
	if op == "list":
		var prefix := String(args[0]) if not args.is_empty() else ""
		var depth := int(args[1]) if args.size() > 1 and String(args[1]).is_valid_int() else 0
		if not prefix.is_empty() and not BridgeWire.allowed(prefix, cfg.read_patterns()):
			return BridgeError.make("denied", prefix)
		var out: Array[String] = []
		for pair in enumerate_paths(prefix, depth):
			out.append("%s=%s" % [pair[0], BridgeWire.encode(pair[1])])
		return [";".join(out)]
	if op == "ping":
		var sent := int(args[0]) if not args.is_empty() and String(args[0]).is_valid_int() else 0
		stats["replies"] += 1
		return [str(uptime_ms()), str(sent)]
	if op == "quit":
		push_bye("quit")
		return ["b:1"]
	return BridgeError.make("unknownop", op)


func enumerate_paths(prefix: String, depth: int) -> Array:
	if runtime != null and runtime.has_method("bridge_enumerate"):
		return runtime.call("bridge_enumerate", prefix, depth)
	return []


func check_read(path: String) -> BridgeError:
	if BridgeWire.allowed(path, cfg.read_patterns()):
		return null
	stats["denied"] += 1
	return BridgeError.make("denied", path)


func check_write(path: String) -> BridgeError:
	if BridgeWire.is_bridge_path(path):
		return null  # the replicated store is always writable from either side
	if not capability("write") or cfg.write_paths.is_empty():
		stats["denied"] += 1
		return BridgeError.make("disabled", "no write allow-list on this peer")
	if BridgeWire.allowed(path, cfg.write_paths):
		return null
	stats["denied"] += 1
	return BridgeError.make("denied", path)


func status_text() -> String:
	return "%s peer=%s(%s) frame=%d peerFrame=%d seq=%d peerSeq=%d latency=%.2fms in=%d out=%d" % [
		status, peer_role, peer_name, frame, peer_frame, out_seq, in_seq,
		latency_ms, stats["msgs_in"], stats["msgs_out"]
	]


func snapshot_state() -> Dictionary:
	return {
		"role": role,
		"status": status,
		"peer": peer_name,
		"peerRole": peer_role,
		"frame": frame,
		"peerFrame": peer_frame,
		"seq": out_seq,
		"peerSeq": in_seq,
		"latencyMs": latency_ms,
		"subscriptions": subscriptions.keys(),
		"stats": stats,
		"store": store,
		"peerStore": peer_store,
	}
