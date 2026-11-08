## Shockwave <-> Godot bridge: wire protocol (PROTOCOL.md §1, §2, §4 kv-lists, §5 paths, §6 gates).
##
## GDScript port of `tools/bridge_proto.py`, which is the executable reference for the spec.
## Keep the three peers (Lingo, GDScript, Python) byte-compatible: same tags, same field order,
## same "no escaping" sanitising. If this file and PROTOCOL.md disagree, the doc is right.
class_name BridgeWire
extends RefCounted

const TAB := "\t"
const LF := "\n"
const KV_SEP := ";"
const PROTOCOL_VERSION := 1

## Tag order matches §2. `n` is VOID, which GDScript spells `null`.
const TAGS := "ifsbpyvqcrdln"

## Every typed value on the wire. Godot has no VOID object, so `null` carries both meanings
## ("the value is VOID" and "the path does not exist"); callers that care use Dictionary.has().
const VOID = null

# --------------------------------------------------------------------------------------------
# §1 framing
# --------------------------------------------------------------------------------------------


## Flatten anything that would break line/field framing. There is no escaping (§1) — a TAB in a
## string value arrives as a space, and that is the documented trade-off for a 30 Hz debug channel.
static func sanitize(text: String) -> String:
	if text.contains("\t") or text.contains("\n") or text.contains("\r"):
		return text.replace("\t", " ").replace("\r", " ").replace("\n", " ")
	return text


## One message = one line: `verb<TAB>field<TAB>field...`. Fields are already text.
static func build(verb: String, fields: Array = []) -> String:
	var parts: Array[String] = [sanitize(verb)]
	for field in fields:
		parts.append(sanitize(_text(field)))
	return TAB.join(parts)


## `line` -> `[verb, fields]`. Trailing empty fields are kept (§9).
static func parse(line: String) -> Array:
	var trimmed := line.trim_suffix("\r")
	if trimmed.is_empty():
		return ["", []]
	var parts := trimmed.split(TAB)
	var fields: Array = []
	for i in range(1, parts.size()):
		fields.append(parts[i])
	return [parts[0], fields]


# --------------------------------------------------------------------------------------------
# §2 typed values — encode
# --------------------------------------------------------------------------------------------


## Godot value -> `tag:payload`. Vector/Color/Rect map onto their Director equivalents, which is
## the whole point of the tag set: a Vector3 crosses as `v:x,y,z` and lands back as a #vector.
static func encode(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "n"
		TYPE_BOOL:
			return "b:1" if value else "b:0"
		TYPE_INT:
			return "i:%d" % value
		TYPE_FLOAT:
			return "f:" + ensure_float(text_float(value))
		TYPE_STRING:
			return "s:" + sanitize(value)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return "y:" + sanitize(String(value).trim_prefix("#"))
		TYPE_VECTOR2:
			return "p:%s,%s" % [ensure_float(text_float(value.x)), ensure_float(text_float(value.y))]
		TYPE_VECTOR3:
			return "v:%s,%s,%s" % [ensure_float(text_float(value.x)), ensure_float(text_float(value.y)), ensure_float(text_float(value.z))]
		TYPE_COLOR:
			return encode_color(value)
		TYPE_RECT2:
			return "r:%s,%s,%s,%s" % [
				ensure_float(text_float(value.position.x)), ensure_float(text_float(value.position.y)),
				ensure_float(text_float(value.end.x)), ensure_float(text_float(value.end.y)),
			]
		TYPE_ARRAY, TYPE_DICTIONARY:
			return "l:" + BridgeLingo.prints(value)
		_:
			return "s:" + sanitize(_text(value))


static func encode_color(color: Color) -> String:
	# Director's #color is 0-255 ints; Godot's Color is 0-1 floats. Round on the way out, /255 on
	# the way in — that is what §2 promises, and it keeps `c:255,0,0` readable in both engines.
	var a := int(round(color.a * 255.0))
	if a >= 255:
		return "c:%d,%d,%d" % [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0))]
	return "c:%d,%d,%d,%d" % [
		int(round(color.r * 255.0)), int(round(color.g * 255.0)),
		int(round(color.b * 255.0)), a,
	]


# --------------------------------------------------------------------------------------------
# §2 typed values — decode
# --------------------------------------------------------------------------------------------


## `tag:payload` -> Godot value. Returns a `BridgeError` on an unknown tag or malformed payload
## (GDScript has no exceptions, so errors travel as values; the caller turns them into `RSP err`).
static func decode(text: String) -> Variant:
	if text == "n":
		return null
	if text.length() < 2 or text[1] != ":":
		return BridgeError.make("badtype", text)
	var tag := text[0]
	var payload := text.substr(2)
	match tag:
		"i":
			if not payload.is_valid_int():
				return BridgeError.make("badtype", text)
			return payload.to_int()
		"f":
			if not payload.is_valid_float():
				return BridgeError.make("badtype", text)
			return payload.to_float()
		"s":
			return payload
		"b":
			return payload == "1"
		"y":
			return StringName(payload)
		"p":
			var parts := payload.split(",")
			if parts.size() < 2:
				return BridgeError.make("badtype", text)
			return Vector2(parts[0].to_float(), parts[1].to_float())
		"v":
			var parts := payload.split(",")
			if parts.size() < 3:
				return BridgeError.make("badtype", text)
			return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
		"q":
			var parts := payload.split(",")
			if parts.size() < 4:
				return BridgeError.make("badtype", text)
			return Quaternion(parts[0].to_float(), parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
		"c":
			var parts := payload.split(",")
			if parts.size() < 3:
				return BridgeError.make("badtype", text)
			var a := 255.0
			if parts.size() > 3:
				a = parts[3].to_float()
			return Color(
				parts[0].to_float() / 255.0,
				parts[1].to_float() / 255.0,
				parts[2].to_float() / 255.0,
				a / 255.0
			)
		"r":
			var parts := payload.split(",")
			if parts.size() < 4:
				return BridgeError.make("badtype", text)
			return Rect2(
				Vector2(parts[0].to_float(), parts[1].to_float()),
				Vector2(parts[2].to_float() - parts[0].to_float(), parts[3].to_float() - parts[1].to_float())
			)
		"d":
			return payload.to_float()
		"l":
			return BridgeLingo.parse(payload)
	return BridgeError.make("badtype", tag)


## Like `decode`, but never fails: a debug channel must not die on data it does not understand.
static func decode_or_text(text: String) -> Variant:
	var value := decode(text)
	if value is BridgeError:
		return text
	return value


# --------------------------------------------------------------------------------------------
# §4 key=value lists (SNAP / DELTA / EVT / RSP payloads)
# --------------------------------------------------------------------------------------------


## `pairs` is an Array of [path, value] arrays. A value that is already `tag:payload` text is
## passed through untouched — that is how pre-formatted RSP fields stay cheap.
static func encode_kv(pairs: Array) -> String:
	var chunks: Array[String] = []
	for pair in pairs:
		var value = pair[1]
		if not is_typed_text(value):
			value = encode(value)
		chunks.append("%s=%s" % [sanitize(_text(pair[0])), value])
	return KV_SEP.join(chunks)


## True when `value` is already a `tag:payload` string, so callers can pre-format hot-path values
## (the Lingo side does exactly this, because it produces the text natively).
static func is_typed_text(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := String(value)
	return text.length() > 1 and text[1] == ":" and TAGS.find(text[0]) >= 0


## -> Array of [path, value]. `;` cannot appear in a key, so one split is the whole parser.
static func decode_kv(text: String) -> Array:
	var pairs: Array = []
	if text.is_empty():
		return pairs
	for chunk in text.split(KV_SEP):
		var index := chunk.find("=")
		if index <= 0:
			continue
		pairs.append([chunk.substr(0, index), decode_or_text(chunk.substr(index + 1))])
	return pairs


static func kv_to_dict(text: String) -> Dictionary:
	var out := {}
	for pair in decode_kv(text):
		out[pair[0]] = pair[1]
	return out


# --------------------------------------------------------------------------------------------
# batches — a batch is simply an Array[String] of messages (§1)
# --------------------------------------------------------------------------------------------


static func lines_to_text(lines: Array) -> String:
	if lines.is_empty():
		return ""
	var parts: Array[String] = []
	for line in lines:
		parts.append(String(line))
	return LF.join(parts) + LF


## Split a received frame into messages, dropping blank lines and a torn final fragment.
static func lines_from_text(text: String) -> Array:
	var out: Array = []
	for line in text.split(LF):
		if not line.strip_edges().is_empty():
			out.append(line)
	return out


# --------------------------------------------------------------------------------------------
# §5 paths, §6 allow-lists
# --------------------------------------------------------------------------------------------


static func path_namespace(path: String) -> String:
	var head := path.split(".")[0]
	var bracket := head.find("[")
	if bracket >= 0:
		head = head.substr(0, bracket)
	return head.strip_edges()


static func path_parent(path: String) -> String:
	if path.ends_with("]") and path.contains("["):
		return path.substr(0, path.rfind("["))
	var dot := path.rfind(".")
	return path.substr(0, dot) if dot >= 0 else ""


static func path_tail(path: String) -> String:
	if path.ends_with("]") and path.contains("["):
		return path.substr(path.rfind("[") + 1, path.length() - path.rfind("[") - 2).strip_edges()
	var dot := path.rfind(".")
	return path.substr(dot + 1) if dot >= 0 else path


## int keys become `[n]` (Director list indices), everything else `.name` (propList keys).
static func path_child(path: String, key: Variant) -> String:
	if path.is_empty():
		return _text(key)
	if typeof(key) == TYPE_INT:
		return "%s[%d]" % [path, key]
	return "%s.%s" % [path, key]


## A pattern authorises itself and its whole subtree: `gGame.vehicles` allows `gGame.vehicles[3].kmh`.
static func allowed(path: String, patterns: Array) -> bool:
	for raw in patterns:
		var pattern := _text(raw).strip_edges()
		if pattern.is_empty():
			continue
		if path == pattern:
			return true
		if path.begins_with(pattern + ".") or path.begins_with(pattern + "["):
			return true
	return false


static func is_bridge_path(path: String) -> bool:
	return path.begins_with("bridge.") or path.begins_with("gBridge.")


## `bridge.wantBoost` / `gBridge.wantBoost` -> `wantBoost`, the key inside the replicated store.
static func bridge_key(path: String) -> String:
	var dot := path.find(".")
	return path.substr(dot + 1) if dot >= 0 else path


# --------------------------------------------------------------------------------------------
# number formatting
# --------------------------------------------------------------------------------------------


## Float -> text in the form Director's `value()` reads back as a #float (it must contain `.` or
## `e`), and in the form Python's `repr()` produced for the shared test vectors.
static func text_float(value: Variant) -> String:
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return "0.0"
	var text := String.num(number)
	# Godot and Python agree on the mantissa; only exponent spelling can differ ("1e-06" is what
	# both want, but "1e+308" can come out as "1e308" depending on the build).
	if text.contains("e") and not text.contains("."):
		text = text.replace("e", ".0e")
	return text


static func ensure_float(text: String) -> String:
	if text.contains(".") or text.contains("e"):
		return text
	return text + ".0"


## Canonical display form — matches `bridge_proto.render()`, which is what the vectors compare.
static func render(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "VOID"
		TYPE_BOOL:
			return "TRUE" if value else "FALSE"
		TYPE_STRING_NAME:
			return "#" + String(value)
		TYPE_COLOR:
			return "color(%d, %d, %d, %d)" % [
				int(round(value.r * 255.0)), int(round(value.g * 255.0)),
				int(round(value.b * 255.0)), int(round(value.a * 255.0))
			]
		TYPE_VECTOR2:
			return "point(%s, %s)" % [trim_number(value.x), trim_number(value.y)]
		TYPE_VECTOR3:
			return "vector(%s, %s, %s)" % [trim_number(value.x), trim_number(value.y), trim_number(value.z)]
		TYPE_RECT2:
			return "rect(%s, %s, %s, %s)" % [
				trim_number(value.position.x), trim_number(value.position.y),
				trim_number(value.end.x), trim_number(value.end.y)
			]
		TYPE_ARRAY:
			var items: Array[String] = []
			for item in value:
				items.append(render(item))
			return "[" + ", ".join(items) + "]"
		TYPE_DICTIONARY:
			var entries: Array[String] = []
			for key in value:
				entries.append("%s=%s" % [render(key), render(value[key])])
			return "{" + ", ".join(entries) + "}"
		TYPE_FLOAT:
			return trim_number(value)
	return _text(value)


## Integers print without a decimal point, like Python's `repr` of an integral float.
static func trim_number(value: Variant) -> String:
	var number := float(value)
	if number == float(int(number)) and absf(number) < 9.0e15:
		return "%d" % int(number)
	return text_float(number)


static func _text(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return ""
		TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return "#" + String(value)
	return str(value)
