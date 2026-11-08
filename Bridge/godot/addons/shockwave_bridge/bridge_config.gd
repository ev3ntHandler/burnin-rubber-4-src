## Parser for `Bridge/Director/Bridge.Data.txt` — the single config file all three peers read.
##
## The format is Burnin' Rubber 4's own data-file idiom (see `Globals.txt` and the movie script
## `[M] Event Manager` → `AddToData`): TAB-separated `key<TAB>value`, `//` or `--` starts a
## comment, blank lines are ignored, a repeated key accumulates a list. Same file, three readers:
## Lingo `BridgeConfigParse()`, `tools/bridge_config.py`, and this.
##
## Field names differ from the file keys where GDScript would collide with an Object method
## (`write` → `write_paths`, `call` → `call_handlers`, …). The keys in the file never change.
class_name BridgeConfig
extends RefCounted

const LIST_KEYS := {
	"expose": "expose",
	"write": "write_paths",
	"call": "call_handlers",
	"event": "event_names",
	"ignore": "ignore_paths",
	"hook": "hooks",
}
const INT_KEYS := [
	"rate", "httpPort", "httpWaitMs", "tcpPort", "udpPort", "maxLines",
	"peerTimeoutMs", "requestTimeoutMs", "verify", "binary", "allowEval", "allowExec",
]
const BOOL_TRUE := ["1", "true", "yes", "on", "#t", "t"]

var transport := "files"
var root := "BridgeData"
var httpHost := "127.0.0.1"
var httpPort := 7778
var httpUrl := ""
var httpWaitMs := 1500
var httpPollFrameArms := true
var tcpHost := "127.0.0.1"
var tcpPort := 7777
var udpPort := 7779
var binary := false
var snapshot := "delta"
var rate := 1
var verify := true
var allowEval := false
var allowExec := false
var peerTimeoutMs := 2000
var requestTimeoutMs := 2000
var maxLines := 200

var expose: Array = []
var write_paths: Array = []
var call_handlers: Array = []
var event_names: Array = []
var ignore_paths: Array = []
var alias := {}
var hooks: Array = []  # [ [handler, event], … ]
var source := ""


static func load_text(text: String, path: String = "") -> BridgeConfig:
	var config := BridgeConfig.new()
	config.source = path
	config.parse(text)
	return config


## Reads the file from the project (or the Director folder next to the movie). Returns defaults,
## never an error — a missing config means "run the bridge with sane settings", not "crash".
static func load_file(path: String) -> BridgeConfig:
	if DirAccess.dir_exists_absolute(path):
		path = path.path_join("Bridge.Data.txt")
	if not FileAccess.file_exists(path):
		var empty := BridgeConfig.new()
		empty.source = path
		return empty
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var failed := BridgeConfig.new()
		failed.source = path
		return failed
	var config := load_text(file.get_as_text(), path)
	file.close()
	return config


func parse(text: String) -> void:
	for raw in text.replace("\r\n", "\n").split("\n"):
		var line := raw.rstrip("\r")
		var stripped := line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("//") or stripped.begins_with("--") or stripped[0] == "#":
			continue
		if raw.length() > 0 and (raw[0] == " " or raw[0] == "\t"):
			continue  # indented lines belong to the game's own block parsers, not to us
		var tab := line.find("\t")
		var key := line if tab < 0 else line.substr(0, tab)
		var value := "" if tab < 0 else line.substr(tab + 1)
		key = key.strip_edges()
		value = value.strip_edges()
		if key.is_empty():
			continue
		if key == "alias":
			var parts := line.split("\t")
			if parts.size() >= 3:
				alias[parts[1].strip_edges()] = parts[2].strip_edges()
			continue
		if LIST_KEYS.has(key):
			var field_name: String = LIST_KEYS[key]
			if key == "hook":
				var equals := value.find("=")
				if equals >= 0:
					hooks.append([value.substr(0, equals).strip_edges(), value.substr(equals + 1).strip_edges()])
				else:
					hooks.append([value.strip_edges(), ""])
			elif not value.is_empty():
				set(field_name, (get(field_name) as Array) + [value])
			continue
		match typeof(get(key)):
			TYPE_BOOL:
				set(key, BOOL_TRUE.has(value.to_lower()))
			TYPE_INT:
				set(key, _int(value, int(get(key))))
			TYPE_STRING:
				set(key, value)
			_:
				pass  # unknown keys are ignored on purpose: forward compatibility (§9)


## Roots the peer will answer `get` for: the game's globals plus every exposed path's head.
func read_patterns() -> Array:
	var patterns: Array = ["gGame", "gSystem", "gData", "gSound", "gBridge", "bridge", "gd"]
	for path in expose:
		var head := String(path).split("[")[0]
		if not patterns.has(head):
			patterns.append(head)
	return patterns


func url() -> String:
	if not httpUrl.is_empty():
		return httpUrl
	return "http://%s:%d/bridge" % [httpHost, httpPort]


func resolved_root(base: String) -> String:
	if root.begins_with("/") or (root.length() > 2 and root[1] == ":"):
		return root
	return base.path_join(root)


func summary() -> String:
	var parts: Array[String] = [
		"transport=%s" % transport,
		"root=%s" % root,
		"snapshot=%s rate=%d" % [snapshot, rate],
		"verify=%d" % (1 if verify else 0),
		"allowEval=%d" % (1 if allowEval else 0),
		"expose=%d" % expose.size(),
		"write=%d" % write_paths.size(),
		"alias=%d" % alias.size(),
	]
	if not source.is_empty():
		parts.append("config=%s" % source.get_file())
	return "  ".join(parts)


func to_dict() -> Dictionary:
	return {
		"transport": transport, "root": root, "httpHost": httpHost, "httpPort": httpPort,
		"httpUrl": httpUrl, "httpWaitMs": httpWaitMs, "tcpHost": tcpHost, "tcpPort": tcpPort,
		"udpPort": udpPort, "binary": binary, "snapshot": snapshot, "rate": rate, "verify": verify,
		"allowEval": allowEval, "allowExec": allowExec, "peerTimeoutMs": peerTimeoutMs,
		"requestTimeoutMs": requestTimeoutMs, "maxLines": maxLines, "expose": expose,
		"write_paths": write_paths, "call_handlers": call_handlers, "event_names": event_names,
		"ignore_paths": ignore_paths, "alias": alias, "hooks": hooks, "source": source,
	}


static func _int(value: String, fallback: int) -> int:
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return int(value.to_float())
	return fallback
