## Lingo list literal (§3) — the one nested payload type on the wire.
##
## Director parses this text natively with `value()`, so the Lingo side needs no code at all here;
## this file is the Godot half of the contract. Subset: `[a, b]`, `[#key: v]`, numbers, "strings",
## #symbols, TRUE/FALSE/VOID. Anything unparseable comes back as the raw string rather than an
## error, because a debug channel that dies on data is worse than one that shows odd data.
class_name BridgeLingo
extends RefCounted


static func parse(text: String) -> Variant:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return null
	var out := _parse_item(trimmed, 0)
	var value = out[0]
	if value is BridgeError:
		return text  # never fatal, see the header
	return value


## Godot value -> Lingo literal text. Rules from §3: propList keys are always `#symbol:`, strings
## are double quoted with `"`/`\` escaped, floats always carry a `.` so Director's `value()` does
## not silently turn them into integers.
static func prints(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "VOID"
		TYPE_BOOL:
			return "TRUE" if value else "FALSE"
		TYPE_INT:
			return "%d" % value
		TYPE_FLOAT:
			return BridgeWire.ensure_float(BridgeWire.text_float(value))
		TYPE_STRING_NAME:
			return "#" + String(value)
		TYPE_STRING:
			var text := String(value)
			# A string that Director would re-parse as something else stays quoted (the default),
			# so round-tripping through value() is safe.
			return quote(text)
		TYPE_VECTOR2:
			return "%s, %s" % [BridgeWire.trim_number(value.x), BridgeWire.trim_number(value.y)]
		TYPE_VECTOR3:
			return "%s, %s, %s" % [
				BridgeWire.trim_number(value.x), BridgeWire.trim_number(value.y), BridgeWire.trim_number(value.z)
			]
		TYPE_COLOR:
			return "color(%d, %d, %d)" % [
				int(round(value.r * 255.0)), int(round(value.g * 255.0)), int(round(value.b * 255.0))
			]
		TYPE_RECT2:
			return "%s, %s, %s, %s" % [
				BridgeWire.trim_number(value.position.x), BridgeWire.trim_number(value.position.y),
				BridgeWire.trim_number(value.end.x), BridgeWire.trim_number(value.end.y)
			]
		TYPE_ARRAY:
			var items: Array[String] = []
			for item in value:
				items.append(prints(item))
			return "[" + ", ".join(items) + "]"
		TYPE_DICTIONARY:
			var entries: Array[String] = []
			for key in value:
				entries.append("%s: %s" % [key_text(key), prints(value[key])])
			return "[" + ", ".join(entries) + "]"
	return quote(BridgeWire.sanitize(_plain(value)))


## One Lingo string literal. Director has no backslash escapes, so a quote inside a string is
## DOUBLED -- that is the only form `value()` can read back, and the reason `\` stays untouched
## here (§3). A writer that escaped with `\"` would produce text Director cannot parse.
static func quote(text: String) -> String:
	## One Lingo string literal: a quote inside it is DOUBLED, and a backslash stays a
	## backslash, because Director has no backslash escapes -- value() cannot read an
	## escaped quote (spec 3). Chr(34) instead of a quote character here for the same reason.
	return Chr(34) + text.replace(Chr(34), Chr(34) + Chr(34)) + Chr(34)


## A Dictionary key: symbol form when it can be one (Director writes propLists as `#key: value`),
## quoted string otherwise.
static func key_text(key: Variant) -> String:
	match typeof(key):
		TYPE_STRING_NAME:
			return "#" + String(key)
		TYPE_INT:
			return "%d" % key
	var text := _plain(key)
	if text.begins_with("#"):
		return "#" + text.substr(1)
	if is_symbolic(text):
		return "#" + text
	return quote(text)


static func is_symbolic(text: String) -> bool:
	if text.is_empty():
		return false
	var first := text[0]
	if not (first == "_" or (first >= "a" and first <= "z") or (first >= "A" and first <= "Z")):
		return false
	for i in range(text.length()):
		var char := text[i]
		var ok := char == "_" or (char >= "a" and char <= "z") or (char >= "A" and char <= "Z") or (char >= "0" and char <= "9")
		if not ok:
			return false
	return true


# --------------------------------------------------------------------------------------------
# reader
# --------------------------------------------------------------------------------------------


## Returns `[value, next_index]`. `_parse_item`/`_parse_list` mirror `_Scanner` in bridge_proto.py
## exactly: same tolerance for nesting, quotes and stray whitespace.
static func _parse_item(text: String, index: int) -> Array:
	index = _skip_ws(text, index)
	if index >= text.length():
		return [BridgeError.make("badliteral", "expected value at %d" % index), index]
	if text[index] == "[":
		return _parse_list(text, index)
	var start := index
	while index < text.length() and text[index] != "," and text[index] != "]":
		if text[index] == '"':
			index += 1
			while index < text.length():
				if text[index] == '"':
					if index + 1 < text.length() and text[index + 1] == '"':
						index += 2  # `""` is one quote character, not the end of the string
						continue
					break
				if text[index] == "\\":
					index += 1
				index += 1
		index += 1
	var token := text.substr(start, index - start).strip_edges()
	if token.is_empty():
		return [BridgeError.make("badliteral", "empty item at %d" % start), index]
	return [scalar(token), index]


static func _parse_list(text: String, index: int) -> Array:
	index += 1  # consume '['
	index = _skip_ws(text, index)
	if index < text.length() and text[index] == "]":
		return [[], index + 1]
	var items: Array = []
	var props := {}
	var is_props := false
	while true:
		var start := index
		var depth := 0
		while index < text.length():
			var char := text[index]
			if char == "[":
				depth += 1
			elif char == "]":
				if depth == 0:
					break
				depth -= 1
			elif char == "," and depth == 0:
				break
			elif char == '"' and depth == 0:
				index += 1
				while index < text.length() and text[index] != '"':
					if text[index] == "\\":
						index += 1
					index += 1
			index += 1
		var chunk := text.substr(start, index - start).strip_edges()
		var key := split_key(chunk)
		if key[1] == ":":
			if not is_props:
				is_props = true
				items = []
			props[_plain(key[0]).trim_prefix("#")] = _value_of(chunk, int(key[2]))
		else:
			if is_props:
				# mixed literal: Director would have made this a list of values; keep it a list
				is_props = false
				props = {}
			items.append(_value_of(chunk, 0))
		if index >= text.length():
			return [BridgeError.make("badliteral", "unterminated list"), index]
		if text[index] == "]":
			index += 1
			break
		index += 1  # consume ','
	if is_props:
		return [props, index]
	return [items, index]


## `[` chunk -> recurse into the literal parser, otherwise read one scalar. `offset` is where the
## value starts inside the chunk when the chunk was `#key: value`.
static func _value_of(chunk: String, offset: int) -> Variant:
	var body := chunk.substr(offset).strip_edges() if offset > 0 else chunk
	if body.begins_with("["):
		var out := _parse_item(body, 0)
		return out[0]
	return scalar(body)


## `#mass: 1200` -> `[mass, ":", index_after_colon]`; a plain item -> `[null, "", 0]`.
static func split_key(chunk: String) -> Array:
	if chunk.is_empty() or chunk[0] == "[":
		return [null, "", 0]
	if chunk.length() > 1 and chunk[0] == '"' and chunk[chunk.length() - 1] == '"':
		return [null, "", 0]
	var depth := 0
	var index := 0
	while index < chunk.length():
		var char := chunk[index]
		if char == "[":
			depth += 1
		elif char == "]":
			depth -= 1
		elif char == '"' and depth == 0:
			index += 1
			while index < chunk.length() and chunk[index] != '"':
				if chunk[index] == "\\":
					index += 1
				index += 1
		elif char == ":" and depth == 0:
			return [scalar(chunk.substr(0, index).strip_edges()), ":", index + 1]
		index += 1
	return [null, "", 0]


## One Lingo scalar. Also used directly by the selftest, and by `set` when Godot hands the bridge a
## value the movie will read back with `value()`.
static func scalar(token: String) -> Variant:
	var text := token.strip_edges()
	var upper := text.to_upper()
	if upper == "VOID":
		return null
	if upper == "TRUE":
		return true
	if upper == "FALSE":
		return false
	if text.begins_with("#"):
		return StringName(text.substr(1))
	if text.length() >= 2 and text[0] == '"' and text[text.length() - 1] == '"':
		return unquote(text.substr(1, text.length() - 2))
	if text.begins_with("(") and text.ends_with(")"):
		var parts := text.substr(1, text.length() - 2).split(",")
		if parts.size() == 2:
			return Vector2(parts[0].to_float(), parts[1].to_float())
		if parts.size() == 3:
			return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text  # §3: unparseable stays raw text, never an error


static func unquote(text: String) -> String:
	var out := ""
	var index := 0
	while index < text.length():
		var char := text[index]
		if char == "\\" and index + 1 < text.length():
			var next := text[index + 1]
			match next:
				"n":
					out += "\n"
				"t":
					out += "\t"
				_:
					out += next
			index += 2
			continue
		out += char
		index += 1
	return out


static func _skip_ws(text: String, index: int) -> int:
	while index < text.length():
		var char := text[index]
		if char != " " and char != "\t" and char != "\r" and char != "\n":
			return index
		index += 1
	return index


static func _plain(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return ""
		TYPE_STRING_NAME:
			return String(value)
		TYPE_STRING:
			return value
	return String(value)
