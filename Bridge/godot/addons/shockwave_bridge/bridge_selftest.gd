## Headless self-test for the Godot half of the bridge.
##
##     godot --headless --path . --script addons/shockwave_bridge/bridge_selftest.gd
##     godot --headless --path . --script addons/shockwave_bridge/bridge_selftest.gd -- --vectors ../../Director/Bridge.Vectors.txt
##
## Three layers, cheapest first:
##
## 1. **conformance** — every case in `Bridge/Director/Bridge.Vectors.txt`, which
##    `tools/bridge_proto.py vectors` generates from the Python reference codec. Encode/decode,
##    message framing, literal flattening, kv-lists and path splitting must match byte for byte, so
##    "my port agrees with the oracle" is a fact rather than a hope.
## 2. **units** — the pieces with behaviour worth pinning: sanitising, allow-lists, float formatting,
##    config parsing, `gd:` property walking.
## 3. **integration** — two `BridgePeer`s wired through an in-memory transport, pumped in lockstep
##    like two 30 fps game loops: handshake, mirrored DELTAs, the replicated store in both
##    directions, allow-listed and denied writes, RPC, events, `list`, ping, duplicate frames, and
##    the file transport's torn-frame handling.
##
## No Director needed, no network, no display. Exit code 0 = all good.
extends SceneTree

const VECTORS_CANDIDATES := [
	"res://addons/shockwave_bridge/Bridge.Vectors.txt",
	"Bridge/Director/Bridge.Vectors.txt",
	"../Director/Bridge.Vectors.txt",
	"../../Bridge/Director/Bridge.Vectors.txt",
]
const CONFIG_CANDIDATES := [
	"res://Bridge.Data.txt",
	"Bridge/Director/Bridge.Data.txt",
	"../../Bridge/Director/Bridge.Data.txt",
]

var _checks := 0
var _failures := 0
var _section := ""
var _vectors_path := ""
var _loop_dir := ""


func _initialize() -> void:
	print("shockwave_bridge selftest (Godot %s)" % String(Engine.get_version_info().get("string", "?")))
	_vectors_path = _find(VECTORS_CANDIDATES)
	_run_wire()
	_run_lingo()
	_run_config()
	_run_vectors()
	_run_peer_integration()
	_run_files_transport()
	_run_binding()
	_cleanup()
	print("")
	if _failures == 0:
		print("all green: %d checks" % _checks)
		quit(0)
	else:
		print("%d of %d checks FAILED" % [_failures, _checks])
		quit(1)


# --------------------------------------------------------------------------------------------
# harness
# --------------------------------------------------------------------------------------------


func _cleanup() -> void:
	if _loop_dir.is_empty():
		return
	for filename in ["d2g.txt", "d2g.seq", "g2d.txt", "g2d.seq"]:
		var path := _loop_dir.path_join(filename)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(_loop_dir)


func section(name: String) -> void:
	_section = name
	print("\n--- %s ---" % name)


func check(name: String, condition: bool, detail := "") -> void:
	_checks += 1
	if condition:
		print("PASS  %s" % name)
		return
	_failures += 1
	print("FAIL  %s   <- %s" % [name, detail if not detail.is_empty() else "false"])


func _find(candidates: Array) -> String:
	for path in candidates:
		if FileAccess.file_exists(String(path)):
			return String(path)
		var globalized := ProjectSettings.globalize_path(String(path))
		if FileAccess.file_exists(globalized):
			return globalized
		var absolute := OS.get_executable_path().get_base_dir().path_join(String(path))
		if FileAccess.file_exists(absolute):
			return absolute
	return ""


static func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


# --------------------------------------------------------------------------------------------
# 1. wire codec, against the shared vectors
# --------------------------------------------------------------------------------------------


func _run_wire() -> void:
	section("wire")
	check("sanitize flattens TAB/CR/LF", BridgeWire.sanitize("a\tb\nc\rd") == "a b c d", BridgeWire.sanitize("a\tb\nc\rd"))
	check("build joins with TAB", BridgeWire.build("GET", ["a", 1]) == "GET\ta\t1")
	var parsed := BridgeWire.parse("RSP\t7\tget\tok\ti:5")
	check("parse splits verb and fields", parsed[0] == "RSP" and (parsed[1] as Array).size() == 4, str(parsed))
	check("parse drops a trailing CR", BridgeWire.parse("PING\t1\r")[0] == "PING")
	check("encode int", BridgeWire.encode(42) == "i:42")
	check("encode float always has a dot", BridgeWire.encode(2.0) == "f:2.0", BridgeWire.encode(2.0))
	check("encode bool", BridgeWire.encode(true) == "b:1" and BridgeWire.encode(false) == "b:0")
	check("encode null is VOID", BridgeWire.encode(null) == "n")
	check("encode symbol", BridgeWire.encode(StringName("Racing")) == "y:Racing", BridgeWire.encode(StringName("Racing")))
	check("encode Vector2 as point", BridgeWire.encode(Vector2(1.5, -2)) == "p:1.5,-2.0", BridgeWire.encode(Vector2(1.5, -2)))
	check("encode Vector3 as vector", BridgeWire.encode(Vector3(1, 2, 3)) == "v:1.0,2.0,3.0", BridgeWire.encode(Vector3(1, 2, 3)))
	check("encode Color scales to 0-255", BridgeWire.encode(Color(1, 0.5019608, 0)) == "c:255,128,0", BridgeWire.encode(Color(1, 0.5019608, 0)))
	check("encode Rect", BridgeWire.encode(Rect2(0, 0, 800, 450)) == "r:0.0,0.0,800.0,450.0", BridgeWire.encode(Rect2(0, 0, 800, 450)))
	var decoded := BridgeWire.decode("v:1,2,3")
	check("decode vector", decoded is Vector3 and decoded == Vector3(1, 2, 3), str(decoded))
	var color: Color = BridgeWire.decode("c:255,128,0")
	check("decode color divides by 255", is_equal_approx(color.r, 1.0) and is_equal_approx(color.g, 0.50196), str(color))
	check("decode unknown tag is an error value", BridgeWire.decode("z:boom") is BridgeError)
	check("decode_or_text survives junk", BridgeWire.decode_or_text("nonsense:thing") == "nonsense:thing")
	check("is_typed_text recognises wire text", BridgeWire.is_typed_text("i:5") and not BridgeWire.is_typed_text("5"))
	check("path namespace", BridgeWire.path_namespace("gGame.vehicles[3].kmh") == "gGame")
	check("path tail of an index", BridgeWire.path_tail("gGame.vehicles[3]") == "3", BridgeWire.path_tail("gGame.vehicles[3]"))
	check("path_child uses [n] for ints", BridgeWire.path_child("gGame.vehicles", 3) == "gGame.vehicles[3]")
	check("path_child uses .name for keys", BridgeWire.path_child("gGame", "Cash") == "gGame.Cash")
	check("bridge path detection", BridgeWire.is_bridge_path("bridge.x") and BridgeWire.is_bridge_path("gBridge.x") and not BridgeWire.is_bridge_path("gGame.x"))
	check("bridge key", BridgeWire.bridge_key("bridge.wantBoost") == "wantBoost")
	check("allow-list covers the subtree", BridgeWire.allowed("gGame.vehicles[1].kmh", ["gGame.vehicles"]))
	check("allow-list rejects siblings", not BridgeWire.allowed("gGameTraffic.x", ["gGame"]))
	check("allow-list rejects a bare sibling", not BridgeWire.allowed("gData", ["gGame"]))
	var lines := ["HELLO\tgodot\tG\t1\t0\tsnap", "PING\t1\t2"]
	check("batch text is LF-terminated", BridgeWire.lines_to_text(lines) == "HELLO\tgodot\tG\t1\t0\tsnap\nPING\t1\t2\n")
	check("batch parse drops blanks", BridgeWire.lines_from_text("A\t1\n\nB\t2\n").size() == 2)
	var utf8 := "PING\tпуть\n".to_utf8_buffer()
	var frame := BridgeNet.pack_frame(utf8)
	check("binary frame has exactly one header and payload", frame.size() == 4 + utf8.size() and frame.decode_u32(0) == utf8.size())
	var split := BridgeNet.split_lines(frame, true)
	check("binary frame decodes UTF-8", split[0] == ["PING\tпуть"] and (split[1] as PackedByteArray).is_empty(), str(split))
	var partial := BridgeNet.split_lines(frame.slice(0, frame.size() - 1), true)
	check("incomplete frame is retained", (partial[0] as Array).is_empty() and partial[1] == frame.slice(0, frame.size() - 1))
	check("URL encoding preserves UTF-8", BridgeNet.percent_decode(BridgeNet.percent_encode(utf8)) == "PING\tпуть\n")


# --------------------------------------------------------------------------------------------
# 2. Lingo literals
# --------------------------------------------------------------------------------------------


func _run_lingo() -> void:
	section("lingo literal")
	var props: Variant = BridgeLingo.parse("[#mass: 1200.5, #wheels: [1, 2, 3]]")
	check(
		"propList parses to a Dictionary with plain keys",
		typeof(props) == TYPE_DICTIONARY and is_equal_approx(props["mass"], 1200.5) and (props["wheels"] as Array).size() == 3,
		str(props)
	)
	var list: Variant = BridgeLingo.parse("[1, 2, 3]")
	check("list parses", list is Array and list[0] == 1, str(list))
	var mixed: Variant = BridgeLingo.parse('[#name: "Bullet350", #ok: TRUE, #nil: VOID, #sym: #Racing]')
	check(
		"typed members",
		mixed["name"] == "Bullet350" and mixed["ok"] == true and mixed["nil"] == null and mixed["sym"] == StringName("Racing"),
		str(mixed)
	)
	check("empty list", (BridgeLingo.parse("[]") as Array).is_empty())
	check("junk stays raw text", BridgeLingo.parse("[unterminated") is Array or BridgeLingo.parse("[unterminated") is String)
	check("prints floats keep the dot", BridgeLingo.prints(2.0) == "2.0", BridgeLingo.prints(2.0))
	check("prints symbols without quotes", BridgeLingo.prints(StringName("Racing")) == "#Racing")
	check("prints null as VOID", BridgeLingo.prints(null) == "VOID")
	check("prints bools as TRUE/FALSE", BridgeLingo.prints(true) == "TRUE" and BridgeLingo.prints(false) == "FALSE")
	var printed := BridgeLingo.prints({"mass": 1200.5, "wheels": [1, 2, 3]})
	check("prints propLists with #keys", printed == "[#mass: 1200.5, #wheels: [1, 2, 3]]", printed)
	var again: Variant = BridgeLingo.parse(printed)
	check("parse(printes(x)) keeps values", again["mass"] == 1200.5 and (again["wheels"] as Array)[2] == 3, str(again))
	check("quoted strings survive spaces", BridgeLingo.scalar('"Burnin Rubber 4"') == "Burnin Rubber 4")
	check("doubled quotes and backslashes", BridgeLingo.unquote('a""b\\c') == 'a"b\\c')
	check("tuples become Vector2", BridgeLingo.scalar("(1, 2)") == Vector2(1, 2))
	check("is_symbolic", BridgeLingo.is_symbolic("kmh_2") and not BridgeLingo.is_symbolic("2kmh") and not BridgeLingo.is_symbolic("a-b"))
	check("key_text prefers symbol form", BridgeLingo.key_text("kmh") == "#kmh" and BridgeLingo.key_text("a b") == '"a b"')


# --------------------------------------------------------------------------------------------
# 3. config file
# --------------------------------------------------------------------------------------------


func _run_config() -> void:
	section("config")
	var text := """// comment
-- another comment
transport\thttp
root\tMailbox
snapshot\tfull
rate\t2
verify\t0
httpPort\t7999
allowEval\tTRUE
expose\tgGame.Cash
expose\tgGame.Money
ignore\tgGame.scriptList
write\t\tgGame.Cash
alias\tkmh\tgGame.CurrentVehicle.general.kmh
hook\tBridgeConnected
"""
	var config := BridgeConfig.load_text(text)
	check("transport parsed", config.transport == "http", config.transport)
	check("root parsed", config.root == "Mailbox", config.root)
	check("snapshot mode", config.snapshot == "full", config.snapshot)
	check("rate is an int", config.rate == 2, str(config.rate))
	check("verify 0 is false", config.verify == false, str(config.verify))
	check("httpPort is an int", config.httpPort == 7999, str(config.httpPort))
	check("allowEval TRUE is true", config.allowEval == true, str(config.allowEval))
	check("repeatable key accumulates", config.expose.size() == 2, str(config.expose))
	check("ignore accumulates", config.ignore_paths.has("gGame.scriptList"), str(config.ignore_paths))
	check("write list uses the renamed field", config.write_paths.has("gGame.Cash"), str(config.write_paths))
	check("alias has two values", config.alias.get("kmh") == "gGame.CurrentVehicle.general.kmh", str(config.alias))
	check("hook without a handler is a pair", config.hooks.size() == 1 and config.hooks[0][1] == "", str(config.hooks))
	check("indented lines are skipped", BridgeConfig.load_text("\ttransport\thttp\n").transport == "files")
	check("unknown keys are ignored", BridgeConfig.load_text("nonsenseKey\twat\n").httpPort == 7778)
	check("read_patterns includes exposed heads", config.read_patterns().has("gGame"), str(config.read_patterns()))
	check("url is built", config.url() == "http://127.0.0.1:7999/bridge", config.url())
	check("resolved root joins a relative path", config.resolved_root("/tmp/movie") == "/tmp/movie/Mailbox", config.resolved_root("/tmp/movie"))
	config.root = "/abs/Mailbox"
	check("absolute root is left alone", config.resolved_root("/tmp/movie") == "/abs/Mailbox", config.resolved_root("/tmp/movie"))
	var defaults := BridgeConfig.new()
	check("defaults are offline-safe", defaults.transport == "files" and defaults.write_paths.is_empty() and defaults.allowEval == false)
	var path := _find(CONFIG_CANDIDATES)
	if path.is_empty():
		print("      (no Bridge.Data.txt on disk; skipped the real-file check)")
	else:
		var real := BridgeConfig.load_file(path)
		check("real config transport is known", ["files", "http", "tcp"].has(real.transport), real.transport)
		check("real config exposes the game state", real.expose.size() > 20, "%d entries" % real.expose.size())
		check("real config keeps eval off", real.allowEval == false)
		check("real config aliases kmh", String(real.alias.get("kmh", "")).length() > 0, str(real.alias))


# --------------------------------------------------------------------------------------------
# 4. the shared vector file
# --------------------------------------------------------------------------------------------


func _run_vectors() -> void:
	section("conformance vectors")
	if _vectors_path.is_empty():
		check("Bridge.Vectors.txt found", false, "run: python3 tools/bridge_proto.py vectors")
		return
	check("Bridge.Vectors.txt found", true, _vectors_path)
	var records := _read_records(_vectors_path)
	var counts := {}
	for kind in records:
		counts[kind] = (records[kind] as Array).size()
	check("all five record kinds present", counts.size() == 5, str(counts))

	for record in records["value"]:
		if record.size() < 2:
			continue
		var note := String(record[0])
		var wire := String(record[1])
		var value = BridgeWire.decode(wire)
		var encoded := BridgeWire.encode(value)
		var matches := encoded == wire
		if wire.begins_with("f:") and encoded.begins_with("f:"):
			matches = float(encoded.substr(2)) == float(wire.substr(2))
		check("value %s" % note, matches, "%s -> %s" % [wire, encoded])
		if record.size() > 2:
			var rendered := String(record[2])
			check("render %s" % note, _render_matches(BridgeWire.render(value), rendered), "%s vs %s" % [BridgeWire.render(value), rendered])

	for record in records["message"]:
		if record.size() < 4:
			continue
		var mnote := String(record[0])
		var verb := String(record[1])
		var count := int(String(record[2]))
		var line := String(record[3])
		var rebuilt := BridgeWire.build(verb, BridgeWire.parse(line)[1])
		check("message %s" % mnote, rebuilt == line and (BridgeWire.parse(line)[1] as Array).size() == count, rebuilt)

	for record in records["literal"]:
		if record.size() < 3:
			continue
		var lnote := String(record[0])
		var flat := _flatten(BridgeLingo.parse(String(record[1])), "")
		check("literal %s" % lnote, "|".join(flat) == String(record[2]), "%s  vs  %s" % ["|".join(flat), String(record[2])])

	for record in records["kv"]:
		if record.size() < 2:
			continue
		var knote := String(record[0])
		var text := String(record[1])
		check("kv %s" % knote, BridgeWire.encode_kv(BridgeWire.decode_kv(text)) == text, BridgeWire.encode_kv(BridgeWire.decode_kv(text)))

	for record in records["path"]:
		if record.size() < 4:
			continue
		var path := String(record[0])
		var got := "%s\t%s\t%s" % [BridgeWire.path_namespace(path), BridgeWire.path_parent(path), BridgeWire.path_tail(path)]
		var want := "%s\t%s\t%s" % [String(record[1]), String(record[2]), String(record[3])]
		check("path %s" % path, got == want, "%s  vs  %s" % [got, want])


## Compare canonical renderings, tolerating float formatting differences between engines: the wire
## is text, but a *value* is what must agree.
func _render_matches(got: String, want: String) -> bool:
	if got == want:
		return true
	if got.is_valid_float() and want.is_valid_float():
		return absf(got.to_float() - want.to_float()) <= absf(want.to_float()) * 1e-9 + 1e-12
	return false


## Port of `bridge_proto.flatten()`: every leaf of a parsed literal as `path=wiretext`, Lingo indices
## 1-based because that is what both engines hand to `value()` / `getProp()`.
func _flatten(node: Variant, prefix: String) -> Array:
	var out: Array = []
	_flatten_into(node, prefix, out)
	return out


func _flatten_into(node: Variant, prefix: String, out: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for key in (node as Dictionary):
			var name := String(key).trim_prefix("#")
			_flatten_into((node as Dictionary)[key], BridgeWire.path_child(prefix, name), out)
		return
	if node is Array:
		for index in range((node as Array).size()):
			_flatten_into((node as Array)[index], BridgeWire.path_child(prefix, index + 1), out)
		return
	out.append("%s=%s" % [prefix if not prefix.is_empty() else "root", BridgeWire.encode(node)])


## The TAB vector file, read the way the game reads its own data files. `message` records embed a
## whole protocol line, so their TABs are rejoined from field 3 (see write_compat_vectors' docstring).
func _read_records(path: String) -> Dictionary:
	var out := {"value": [], "message": [], "literal": [], "kv": [], "path": []}
	for raw in _read_text(path).split("\n"):
		var line := raw.trim_suffix("\r")
		if line.strip_edges().is_empty() or line.strip_edges().begins_with("#"):
			continue
		var fields := line.split("\t")
		var kind := String(fields[0])
		if not out.has(kind):
			continue
		var record: Array = Array(fields.slice(1))
		if kind == "message" and record.size() > 4:
			record = record.slice(0, 3) + ["\t".join(PackedStringArray(record.slice(3)))]
		(out[kind] as Array).append(record)
	return out


# --------------------------------------------------------------------------------------------
# 5. two peers, in memory, pumped in lockstep
# --------------------------------------------------------------------------------------------


func _run_peer_integration() -> void:
	section("peer integration")
	var director_config := BridgeConfig.new()
	director_config.transport = "files"
	director_config.expose = ["gGame.Cash", "gGame.kmh", "gGame.RaceState", "gGame.pos"]
	director_config.write_paths = ["gGame.Cash", "gGame.Input"]
	var godot_config := BridgeConfig.new()
	godot_config.write_paths = ["bridge"]

	var director := BridgePeer.new()
	var game := FakeGame.new()
	director.configure(director_config, "director", ["snap", "sub", "event", "list", "write", "call"], "Director (selftest)")
	director.runtime = game
	var godot := BridgePeer.new()
	godot.configure(godot_config, "godot", ["snap", "sub", "event", "list", "write"], "Godot (selftest)")
	var d_link := BridgeLoopback.new()
	var g_link := BridgeLoopback.new()
	d_link.pair_with(g_link)
	g_link.pair_with(d_link)
	director.transport = d_link
	godot.transport = g_link
	director.start()
	godot.start()
	# The Director peer subscribes to what its config exposes, exactly like the Lingo module does.
	for path in director_config.expose:
		director.subscriptions[path] = 0
	game.set_notify(director)

	var pump := func(frames: int) -> void:
		for _frame in range(frames):
			director.tick()
			director.flush()
			godot.tick()
			godot.flush()

	pump.call(4)
	check("handshake both ways", godot.peer_ready and director.peer_ready, godot.status_text() + " | " + director.status_text())
	check("roles recorded", godot.peer_role == "director" and director.peer_role == "godot", "%s/%s" % [godot.peer_role, director.peer_role])
	check("caps exchanged", godot.peer_caps.has("call"), str(godot.peer_caps))
	check("mirrored int", godot.read_local("gGame.Cash") == 1000, str(godot.peer_store))
	check("mirrored float", is_equal_approx(float(godot.read_local("gGame.kmh", 0.0)), 187.5), str(godot.read_local("gGame.kmh")))
	var state: Variant = godot.read_local("gGame.RaceState")
	check("mirrored symbol", state == StringName("Racing"), str(state))
	check("mirrored vector", godot.read_local("gGame.pos") == Vector3(1, 2, 3), str(godot.read_local("gGame.pos")))

	# a game change shows up in one frame, because the sender only sends what moved
	game.set_value("gGame.Cash", 1234)
	pump.call(2)
	check("delta on change", godot.read_local("gGame.Cash") == 1234, str(godot.read_local("gGame.Cash")))
	var before: int = godot.stats["frames_in"]
	pump.call(3)
	check("idle is silent (no echo storm)", godot.stats["frames_in"] == before, "%d -> %d" % [before, godot.stats["frames_in"]])

	# replicated store, both directions
	godot.write_local("bridge.wantBoost", true)
	pump.call(3)
	check("bridge store godot -> director", director.store.get("wantBoost") == true, str(director.store))
	director.write_local("bridge.lap", 3)
	pump.call(3)
	check("bridge store director -> godot", godot.store.get("lap") == 3, str(godot.store))

	# RPC
	var got_value: Array = []
	godot.read_remote("gGame.Money", func(value: Variant) -> void: got_value.append(value))
	pump.call(4)
	check("REQ/RSP get", got_value.size() == 1 and int(got_value[0]) == 50000, str(got_value))

	var denied: Array = []
	godot.request("get", ["gSecret.stuff"], func(value: Variant) -> void: denied.append(value))
	pump.call(4)
	check("read outside allow-list denied", denied.size() == 1 and denied[0] is BridgeError, str(denied))

	var written: Array = []
	godot.write_local("gGame.Cash", 999999, true)
	pump.call(4)
	check("allowed write reaches the game", int(game.game["Cash"]) == 999999, str(game.game["Cash"]))
	godot.write_local("gGame.UPStatistics.money", 5, true)
	pump.call(4)
	check("denied write is refused", int(game.game["UPStatistics"]["money"]) != 5, str(game.game["UPStatistics"]))

	var called: Array = []
	godot.call_handler("PutMessage", "", {"message": "hello from godot"}, func(value: Variant) -> void: called.append(value))
	pump.call(4)
	check("call reaches a handler", game.log_lines.size() == 1 and String(game.log_lines[0]).contains("hello from godot"), str(game.log_lines))
	check("call reply", called.size() == 1 and String(called[0]).contains("hello"), str(called))
	var numeric_call: Array = []
	godot.call_handler("PutMessage", 0, {"message": "numeric target"}, func(value: Variant) -> void: numeric_call.append(value))
	pump.call(4)
	check("numeric sprite target reaches the peer as text", game.last_call_target == "0" and numeric_call.size() == 1, str(game.last_call_target))
	var named_call: Array = []
	godot.call_handler("PutMessage", "Player", {"message": "named target"}, func(value: Variant) -> void: named_call.append(value))
	pump.call(4)
	check("string call target remains unchanged", game.last_call_target == "Player" and named_call.size() == 1, str(game.last_call_target))

	godot.send_event("BridgePause", {"reason": "selftest"})
	pump.call(3)
	check("EVT raises on the far side", game.paused == true, str(game.paused))
	godot.send_event("BridgeResume")
	pump.call(3)
	check("EVT resumes", game.paused == false, str(game.paused))

	var listed: Array = []
	godot.list_paths("bridge", 1, func(value: Variant) -> void: listed.append(value))
	pump.call(4)
	check("list enumerates the far store", listed.size() == 1 and listed[0] is Dictionary and listed[0].has("bridge.wantBoost"), str(listed))

	var pong: Array = []
	godot.ping(func(value: Variant) -> void: pong.append(value))
	pump.call(4)
	check("ping answered", pong.size() == 1, str(pong))

	# duplicate frames must not be applied twice
	var dupes_before: int = godot.stats["dupes"]
	var replay: Array = ["DELTA\t1\t1\t1\t1\tgGame.Cash=i:77"]
	godot.feed(replay)
	godot.feed(replay)
	pump.call(1)
	check("a replayed seq is ignored", godot.stats["dupes"] >= dupes_before + 1, str(godot.stats))

	# unknown verbs are tolerated, not fatal
	godot.feed(["GARBAGE\t1"])
	check("unknown verb tolerated", godot.peer_ready)

	# timeouts resolve pending requests as errors
	var timed: Array = []
	d_link.mute(true)
	var timed_id := godot.request("get", ["gGame.Cash"], func(value: Variant) -> void: timed.append(value))
	godot.cfg.requestTimeoutMs = 1
	# Age the request deterministically; the loop may otherwise finish within one millisecond.
	godot.pending[timed_id]["sent_ms"] = godot.uptime_ms() - 2
	for _frame in range(4):
		godot.tick()
		godot.flush()
	d_link.mute(false)
	check("pending request times out", timed.size() == 1 and timed[0] is BridgeError and (timed[0] as BridgeError).code == "timeout", str(timed))

	# snapshot control
	godot.set_snapshot(false)
	pump.call(2)
	check("snapshot off clears the far subscriptions", director.subscriptions.is_empty() or director.cfg.rate >= 1, str(director.subscriptions))
	godot.set_snapshot(true, 2)
	pump.call(3)
	check("snapshot on retunes the rate", godot.cfg.rate == 2, str(godot.cfg.rate))

	# one transport write per frame, whatever the peer queued
	var writes_before := d_link.sent_batches
	for _frame in range(5):
		director.tick()
		director.flush()
	check("one batch per frame", d_link.sent_batches - writes_before <= 5, "%d writes" % (d_link.sent_batches - writes_before))
	game.set_notify(null)
	director.runtime = null
	director.stop()
	godot.stop()


## The "movie" for the integration test: a flat propList-shaped Dictionary, an allow-listed write
## target, and two callable handlers — the same shapes `mock_director.py` simulates.
class FakeGame:
	extends RefCounted

	var game := {
		"Cash": 1000,
		"Money": 50000,
		"kmh": 187.5,
		"RaceState": StringName("Racing"),
		"pos": Vector3(1, 2, 3),
		"Input": {"forward": 0, "brake": 0},
		"UPStatistics": {"money": 0},
	}
	var log_lines: Array = []
	var last_call_target := ""
	var paused := false
	var notifier: BridgePeer = null

	func set_notify(peer: BridgePeer) -> void:
		notifier = peer

	func set_value(path: String, value: Variant) -> void:
		var key := path.trim_prefix("gGame.")
		game[key] = value
		if notifier != null:
			notifier.mark_dirty(path, value)

	func bridge_resolve(path: String) -> Variant:
		if BridgeWire.is_bridge_path(path):
			return notifier.store[BridgeWire.bridge_key(path)] if notifier != null and notifier.store.has(BridgeWire.bridge_key(path)) else null
		if not path.begins_with("gGame."):
			return null
		var key := path.trim_prefix("gGame.")
		var current: Variant = game
		for segment in key.split("."):
			if typeof(current) == TYPE_DICTIONARY and (current as Dictionary).has(segment):
				current = (current as Dictionary)[segment]
				continue
			return null
		return current

	func bridge_write(path: String, value: Variant) -> bool:
		if not BridgeWire.allowed(path, ["gGame.Cash", "gGame.Money", "gGame.Input"]):
			return false
		var key := String(path).trim_prefix("gGame.")
		var segments := key.split(".")
		var target: Variant = game
		for index in range(segments.size() - 1):
			if typeof(target) == TYPE_DICTIONARY and (target as Dictionary).has(segments[index]):
				target = (target as Dictionary)[segments[index]]
				continue
			return false
		if typeof(target) != TYPE_DICTIONARY:
			return false
		(target as Dictionary)[segments[segments.size() - 1]] = value
		return true

	func bridge_enumerate(prefix: String, _depth: int) -> Array:
		var result: Array = []
		if notifier != null:
			for key in notifier.store:
				var path := "bridge." + str(key)
				if prefix.is_empty() or path.begins_with(prefix):
					result.append([path, notifier.store[key]])
		return result

	func bridge_call(handler: String, target: String, data: Variant) -> Variant:
		last_call_target = target
		match handler:
			"PutMessage":
				var text := "message?"
				if typeof(data) == TYPE_DICTIONARY:
					text = String((data as Dictionary).get("message", ""))
				log_lines.append(text)
				return text
			"ResetGame":
				game["Cash"] = 1000
				return 1
		return BridgeError.make("notfound", handler)

	func bridge_event(name: String, _data: Dictionary) -> void:
		if name == "BridgePause":
			paused = true
		elif name == "BridgeResume":
			paused = false


## In-memory transport: what makes the integration test deterministic (no threads, no timers), which
## is why the Python harness needs naps and this one does not.
class BridgeLoopback:
	extends RefCounted

	var peer: BridgePeer = null
	var other: BridgeLoopback = null
	var sent_batches := 0
	var sent_lines := 0
	var dropped := 0
	var _muted := false
	var _inbox: Array = []

	func pair_with(partner: BridgeLoopback) -> void:
		other = partner

	func mute(state: bool) -> void:
		_muted = state

	func start(for_peer: BridgePeer) -> void:
		peer = for_peer

	func stop() -> void:
		other = null
		peer = null

	func send(lines: Array) -> void:
		sent_batches += 1
		sent_lines += lines.size()
		if other == null or _muted:
			dropped += 1
			return
		other._inbox.append_array(lines)

	func poll() -> Array:
		if _inbox.is_empty():
			return []
		var lines := _inbox.duplicate()
		_inbox.clear()
		return lines


# --------------------------------------------------------------------------------------------
# 6. the file transport, on the real filesystem
# --------------------------------------------------------------------------------------------


func _run_files_transport() -> void:
	section("files transport")
	_loop_dir = ProjectSettings.globalize_path("user://bridge_selftest_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_loop_dir)

	var sender_cfg := BridgeConfig.new()
	sender_cfg.root = _loop_dir
	sender_cfg.verify = true
	var sender := BridgePeer.new()
	sender.configure(sender_cfg, "director", ["snap"], "selftest-sender")
	var reader_cfg := BridgeConfig.new()
	reader_cfg.root = _loop_dir
	reader_cfg.verify = true
	var reader := BridgePeer.new()
	reader.configure(reader_cfg, "godot", ["snap"], "selftest-reader")

	var out_link := BridgeTransportFiles.new()
	out_link.setup(sender, _loop_dir, sender_cfg)
	var in_link := BridgeTransportFiles.new()
	in_link.setup(reader, _loop_dir, reader_cfg)
	sender.transport = out_link
	reader.transport = in_link
	sender.start()
	reader.start()

	check("mailbox files named per role", out_link.out_path.ends_with("d2g.txt") and in_link.in_path.ends_with("d2g.txt"), "%s / %s" % [out_link.out_path, in_link.in_path])

	var batch := ["SNAP\t1\t10\t10\t0\tgGame.Cash=i:4242"]
	out_link.send(batch)
	var got := in_link.poll()
	check("whole batch arrives", got.size() == 1 and String(got[0]) == batch[0], str(got))
	check("poll again is empty", in_link.poll().is_empty())

	# a payload whose size no longer matches its marker must be refused, and the same frame must be
	# picked up as soon as it is whole again — self-healing is the entire error model of §7.1.
	out_link.send(["SNAP\t2\t11\t11\t0\tgGame.Cash=i:1"])
	var marker_path := out_link.out_path.trim_suffix(".txt") + ".seq"
	var payload_path := out_link.out_path
	var original := _read_text(payload_path)
	var liar := FileAccess.open(payload_path, FileAccess.WRITE)
	if liar != null:
		liar.store_string(original + "LIES\n")
		liar.close()
	var torn_before := in_link.torn
	check("a torn payload is refused", in_link.poll().is_empty() and in_link.torn == torn_before + 1, "torn=%d" % in_link.torn)
	var repair := FileAccess.open(payload_path, FileAccess.WRITE)
	if repair != null:
		repair.store_string(original)
		repair.close()
	check("the same frame is picked up once repaired", in_link.poll().size() == 1, "self-healing is the whole error model")

	# an empty write must not be published at all (no batch, no new marker)
	var seq_before := out_link.last_out_seq
	out_link.send([])
	check("an empty batch is not published", out_link.last_out_seq == seq_before)

	# The restart rule (§4, §7.1, §8): whoever starts over begins its seq again, so the frame a
	# restarted peer writes next carries a *lower* number than the reader's high-water mark. Treating
	# "lower" as "stale" is the bug — the reader then ignores that peer until its count catches up,
	# which is the "re-ran the game and Godot stopped getting data" report. Push the reader's memory
	# far ahead, then send one honest greeting-plus-snapshot from seq 1 and see whether it lands.
	reader.in_seq = 4000
	out_link.send(["HELLO\tdirector\tselftest-sender\t1\t1\tsnap", "SNAP\t1\t8\t8\t4000\tgGame.Cash=i:91"])
	reader.ingest_transport()
	check(
		"a restarted peer's lower seq is applied, not discarded",
		int(reader.peer_store.get("gGame.Cash", -1)) == 91,
		str(reader.peer_store.get("gGame.Cash"))
	)
	check(
		"HELLO re-armed the reader's frame gate too",
		reader.in_seq == 1 and reader.transport.last_in_seq == out_link.last_out_seq,
		"in_seq=%d gate=%d" % [reader.in_seq, reader.transport.last_in_seq]
	)
	out_link.send(["SNAP\t2\t9\t9\t4000\tgGame.Cash=i:92"])
	reader.ingest_transport()
	check("the new session then continues normally", int(reader.peer_store.get("gGame.Cash", -1)) == 92, str(reader.peer_store.get("gGame.Cash")))
	# the re-arm must not have cost us the dedupe: a *second* frame carrying snapshot seq 2 (a new
	# marker seq, so this is the "batch read twice while the file was replaced" case of §8) stays one
	out_link.send(["SNAP\t2\t10\t10\t4000\tgGame.Cash=i:93"])
	reader.ingest_transport()
	check(
		"a repeated snapshot seq is still applied once, after the re-arm too",
		int(reader.peer_store.get("gGame.Cash", -1)) == 92,
		str(reader.peer_store.get("gGame.Cash"))
	)
	sender.stop()
	reader.stop()


# --------------------------------------------------------------------------------------------
# 7. the autoload's `gd:` binding, on a real node
# --------------------------------------------------------------------------------------------


func _run_binding() -> void:
	section("gd: binding")
	var script: GDScript = load("res://addons/shockwave_bridge/shockwave_bridge.gd")
	if script == null:
		check("shockwave_bridge.gd loads", false)
		return
	var bridge := script.new() as Node
	bridge.set("auto_start", false)
	root.add_child(bridge)
	var node_script: GDScript = _dummy_script()
	if node_script == null:
		check("dummy script compiles", false)
		return
	var target := node_script.new() as Node
	target.set_name("Player")
	target.set("hp", 100)
	target.set("score", 0)
	target.set("speed", Vector2(1.5, 0))
	root.add_child(target)
	bridge.call("bind_node", target, "Player")

	check("read a bound property", int(bridge.call("bridge_resolve", "gd:Player.hp")) == 100, str(bridge.call("bridge_resolve", "gd:Player.hp")))
	check("missing property reads null", bridge.call("bridge_resolve", "gd:Player.nope") == null)
	check("unbound alias reads null", bridge.call("bridge_resolve", "gd:Nobody.hp") == null)
	var assigned: Variant = bridge.call("_assign_path", "gd:Player.score", 250)
	check("write a bound property", int(target.get("score")) == 250, str(target.get("score")))
	check("write reports the value it set", assigned == 250, str(assigned))
	check("write to a bad path reports failure", typeof(bridge.call("_assign_path", "gd:Player.nope.x", 1)) == TYPE_STRING)
	var vec: Variant = bridge.call("bridge_resolve", "gd:Player.speed")
	check("typed as Vector2 through the wire", vec == Vector2(1.5, 0), str(vec))
	check("encode a bound Vector2 as a point", BridgeWire.encode(vec) == "p:1.5,0.0", BridgeWire.encode(vec))
	check("path segments split indices", (bridge.call("_path_segments", "gd:List[3].x") as PackedStringArray)[1] == "3")

	# value-type components: math types are not Objects, so `gd:Player.speed[0]` needs its own
	# access -- and the numbering has to match the wire types, which is the part a port gets wrong
	check("vector component reads", float(bridge.call("bridge_resolve", "gd:Player.speed[0]")) == 1.5, str(bridge.call("bridge_resolve", "gd:Player.speed[0]")))
	check("color component reads as 0-255 like c:", int(bridge.call("bridge_resolve", "gd:Player.tint[0]")) == 255, str(bridge.call("bridge_resolve", "gd:Player.tint[0]")))
	check("color alpha component", int(bridge.call("bridge_resolve", "gd:Player.tint[3]")) == 255, str(bridge.call("bridge_resolve", "gd:Player.tint[3]")))
	check("rect component 2 is the END x, not size", int(bridge.call("bridge_resolve", "gd:Player.panel[2]")) == 110, str(bridge.call("bridge_resolve", "gd:Player.panel[2]")))
	check("out-of-range component reads null", bridge.call("bridge_resolve", "gd:Player.speed[5]") == null)
	check("named component reads null (index only)", bridge.call("bridge_resolve", "gd:Player.speed[x]") == null)
	bridge.call("_assign_path", "gd:Player.speed[1]", 4.0)
	check("vector component writes through the owner", target.get("speed") == Vector2(1.5, 4.0), str(target.get("speed")))
	bridge.call("_assign_path", "gd:Player.tint[1]", 128)
	var tint_after: Color = target.get("tint")
	check("color component write divides by 255", int(round(tint_after.g * 255.0)) == 128, str(tint_after))
	bridge.call("_assign_path", "gd:Player.panel[3]", 80.0)
	check("rect end write keeps position and re-derives size", (target.get("panel") as Rect2) == Rect2(10, 20, 100, 60), str(target.get("panel")))

	# `call` from the peer side: a method on a bound node, gated by the config's call list
	var cfg: BridgeConfig = bridge.get("config")
	cfg.call_handlers = ["take_damage"]
	var peer: BridgePeer = bridge.get("peer")
	# Exercise the exact public signature used by the demo, not only the lower-level peer API.
	var call_id: Variant = bridge.call("call_director", "PutMessage", 0, {"message": "hello from Godot", "level": 0}, Callable())
	var queued: Array = peer.get("_outbox")
	var request: Array = BridgeWire.parse(String(queued.back()[0])) if not queued.is_empty() else []
	var fields: Array = request[1] if request.size() > 1 else []
	check("call_director accepts integer target and sends 0", typeof(call_id) == TYPE_INT and int(call_id) > 0 and fields.size() == 5 and fields[2] == "PutMessage" and fields[3] == "0", str(request))
	peer.pending.clear()
	queued.clear()
	peer.runtime = bridge
	var result: Variant = bridge.call("bridge_call", "take_damage", "Player", 25)
	check("call reaches a bound node method", int(target.get("hp")) == 75, "hp=%s result=%s" % [str(target.get("hp")), str(result)])
	result = bridge.call("bridge_call", "forbidden", "Player", 1)
	check("call outside the allow-list is denied", result is BridgeError and (result as BridgeError).code == "denied", str(result))
	bridge.call("bridge_event", "SelfTestEvent", {"a": "s:1"})
	check("bridge_event lands on a bound node", target.has_meta("self_test_seen") and target.get_meta("self_test_seen") == true)
	target.queue_free()
	bridge.queue_free()


## A throwaway script so the binding test has a node with real script properties *and* a real method
## to be called into. Written as source and compiled at runtime: nothing here depends on project files.
func _dummy_script() -> GDScript:
	var lines := [
		"extends Node2D",
		"var hp := 100",
		"var score := 0",
		"var speed := Vector2.ZERO",
		"var tint := Color(1.0, 0.5, 0.0, 1.0)",
		"var panel := Rect2(10, 20, 100, 50)",
		"",
		"func take_damage(amount) -> void:",
		"	hp = hp - int(amount)",
		"	set_meta(%sself_test_seen%s, true)" % [char(34), char(34)],
		"",
		"func on_self_test_event(data) -> void:",
		"	set_meta(%sself_test_seen%s, true)" % [char(34), char(34)],
	]
	var script := GDScript.new()
	script.source_code = "\n".join(PackedStringArray(lines)) + "\n"
	if script.reload() != OK:
		return null
	return script
