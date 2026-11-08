## Shared socket plumbing for the `tcp` and `http` transports (PROTOCOL.md §7.2, §7.3).
##
## Two rules, both learned the hard way by the Python reference:
## * **Drain, don't nibble.** A peer polls once per frame, so every poll must consume everything the
##   socket will give up. Delivering one message per frame would put an RPC reply a frame behind
##   every snapshot line queued in front of it.
## * **Never `put_data` and hope.** A non-blocking write can accept part of a buffer. Anything not
##   accepted is kept and retried, so a batch is either fully written or still pending — a torn
##   line on the wire would desynchronise the LF framing for every message after it.
class_name BridgeNet
extends RefCounted

## Sentinel for "the store has no such key", so a genuine null/VOID still counts as a value. One
## definition shared by the dock, the selftest and the autoload.
## URL codec, because Director's NetLingo can only issue a GET: over `http` the Director half
## sends its whole batch as `%`-escaped query text (§7.2). Godot 4 has no public decoder, and the
## subset that matters here is small enough to own.
static func percent_decode(text: String) -> String:
	var out := PackedByteArray()
	var bytes := text.to_utf8()
	var index := 0
	while index < bytes.size():
		var byte := bytes[index]
		if byte == 37 and index + 2 < bytes.size():
			var high := _hex_value(bytes[index + 1])
			var low := _hex_value(bytes[index + 2])
			if high >= 0 and low >= 0:
				out.append(high * 16 + low)
				index += 3
				continue
		if byte == 43:  # `+` means space in query text
			out.append(32)
			index += 1
			continue
		out.append(byte)
		index += 1
	return out.get_string_from_utf8()


static func percent_encode(bytes: PackedByteArray) -> String:
	var out := ""
	for index in range(bytes.size()):
		var byte := bytes[index]
		if byte >= 48 and byte <= 57 or byte >= 65 and byte <= 90 or byte >= 97 and byte <= 122:
			out += char(byte)
		elif byte == 45 or byte == 46 or byte == 95 or byte == 126:
			out += char(byte)
		else:
			out += "%%%02X" % byte
	return out


static func _hex_value(byte: int) -> int:
	if byte >= 48 and byte <= 57:
		return byte - 48
	if byte >= 65 and byte <= 70:
		return byte - 55
	if byte >= 97 and byte <= 102:
		return byte - 87
	return -1


static func missing() -> String:
	return "\x00__bridge_missing__"


const MAX_READ_PER_FRAME := 64  # bounded: a chatty peer cannot starve the frame loop
const MAX_PENDING_BYTES := 262144


## Everything readable right now, in one lump. `peer` may be a StreamPeerTCP.
static func take_available(peer: Object) -> PackedByteArray:
	var out := PackedByteArray()
	if peer == null:
		return out
	for _guard in range(MAX_READ_PER_FRAME):
		var available: int = peer.call("get_available_bytes")
		if available <= 0:
			break
		var chunk: Array = peer.call("get_partial_data", mini(available, 65536))
		# get_partial_data returns [error, PackedByteArray]
		if int(chunk[0]) != OK or (chunk[1] as PackedByteArray).is_empty():
			break
		out.append_array(chunk[1])
		if out.size() >= MAX_PENDING_BYTES:
			break
	return out


## Complete LF-terminated messages from a byte buffer: `[lines, rest]`. With `binary` the buffer is
## a sequence of `u32 length · bytes` frames instead (§7.3).
static func split_lines(buffer: PackedByteArray, binary := false) -> Array:
	if binary:
		return _split_frames(buffer)
	# Scan the bytes, not a decoded String: Godot String indices count UTF-32 code points, so
	# slicing the PackedByteArray by a String index would cut a multi-byte value in half.
	var lines: Array = []
	var start := 0
	var index := 0
	var size := buffer.size()
	while index < size:
		if buffer[index] == 10:  # LF
			if index > start:
				var raw := buffer.slice(start, index).get_as_text().trim_suffix("\r")
				if not raw.strip_edges().is_empty():
					lines.append(raw)
			start = index + 1
		index += 1
	return [lines, buffer.slice(start)]


static func _split_frames(buffer: PackedByteArray) -> Array:
	var lines: Array = []
	var index := 0
	while buffer.size() - index >= 4:
		var size := buffer.decode_u32(index)
		if size > MAX_PENDING_BYTES:
			break  # nonsense header: leave it, the caller will drop the link
		if buffer.size() - index - 4 < size:
			break
		var text := buffer.slice(index + 4, index + 4 + size).get_as_text()
		for line in text.split("\n"):
			if not String(line).strip_edges().is_empty():
				lines.append(line.trim_suffix("\r"))
		index += 4 + size
	return [lines, buffer.slice(index)]


## `u32 length · batch bytes` — the optional binary framing of §7.3.
static func pack_frame(payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4 + payload.size())
	out.encode_u32(0, payload.size())
	out.append_array(payload)
	return out


## Connect / accept one new connection. `server` is a TCPServer; returns a StreamPeerTCP or null.
static func accept_one(server: TCPServer) -> Object:
	if server == null or not server.is_valid():
		return null
	if not server.is_connection_available():
		return null
	var client: StreamPeerTCP = server.take_connection()
	if client == null:
		return null
	client.call("set_no_delay", true)
	return client


static func is_connected(peer: Object) -> bool:
	if peer == null:
		return false
	# STATUS_CONNECTED == 2 on StreamPeerTCP
	return int(peer.call("get_status")) == 2
