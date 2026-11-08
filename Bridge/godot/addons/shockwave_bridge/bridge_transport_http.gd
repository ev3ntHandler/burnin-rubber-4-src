## `http` transport — PROTOCOL.md §7.2. The lowest-effort sub-millisecond option: Godot serves a
## minimal HTTP/1.1 responder on `127.0.0.1:7778` and Director keeps exactly one in-flight
## `getNetText` long-poll, re-arming the moment `netTextDone` fires. Push when there is something to
## push, zero bandwidth when there is not.
##
##     GET  /bridge/poll?ack=<n>&wait=<ms>   → 200 text/plain  batch (held at most wait ms)
##     POST /bridge/push                     body = batch      → 200 "ok"
##     GET  /bridge/state                    → 200 JSON mirror of the store (browser HUD/tooling)
##     GET  /bridge/handshake                → 200 "godot proto=1 caps=…"
##     GET  /bridge/reset                    → 200 "reset"  (drop queued traffic; what tools use)
##
## No threads, no `await`, nothing that can re-enter the scene tree: everything happens in `poll()`,
## once per frame, inside the peer's tick (§6). A held long-poll is just a socket with a deadline.
##
## Deliberately not a general HTTP server: it speaks the endpoints above, keeps connections alive,
## and 404s the rest. Never put this on a routable interface (§6).
class_name BridgeTransportHTTP
extends RefCounted

const MAX_REQUEST_BYTES := 2097152
const MAX_CONNECTIONS := 8
const MAX_QUEUED_LINES := 512
const MAX_CONNS_PER_FRAME := 16  # pipelined requests on one socket, bounded

var peer: BridgePeer = null
var host := "127.0.0.1"
var port := 7778
var wait_ms := 1500
var requests := 0
var held := 0
var expired := 0
var bad_requests := 0

var _server: TCPServer = null
var _connections: Array = []  # Array[BridgeHTTPConn]
var _incoming: Array = []
var _out_lines: Array = []


func setup(for_peer: BridgePeer, p_host: String, p_port: int, config: BridgeConfig = null) -> void:
	peer = for_peer
	if config == null and peer != null:
		config = peer.cfg
	if config != null:
		wait_ms = config.httpWaitMs
		port = p_port if p_port > 0 else config.httpPort
		host = p_host if not p_host.is_empty() else config.httpHost
	_server = TCPServer.new()
	var error := _server.listen(port, host)
	if error != OK and peer != null:
		peer.log_line("error", "http: cannot listen on %s:%d (%s)" % [host, port, error_string(error)])
	if peer != null:
		peer.transport = self


## Called by the peer once a frame. Answers any poll that now has traffic, then hands over whatever
## the peer pushed since the last poll.
func poll() -> Array:
	_service()
	if _incoming.is_empty():
		return []
	var lines := _incoming.duplicate()
	_incoming.clear()
	return lines


## Queued rather than written where produced, so there is one writer (the game loop) and one reader
## (the socket). If a poll is already open it is answered immediately — that is the sub-millisecond
## part: a command from Director travels while the movie is still waiting on the response.
func send(lines: Array) -> void:
	_out_lines.append_array(lines)
	_trim_outgoing()
	_answer_waiting()


func stop() -> void:
	for conn in _connections:
		conn.close()
	_connections.clear()
	_out_lines.clear()
	if _server != null and _server.is_valid():
		_server.stop()
	_server = null


func status() -> Dictionary:
	var open_polls := 0
	for conn in _connections:
		if conn.awaiting:
			open_polls += 1
	return {
		"transport": "http",
		"role": "server",
		"listen": "%s:%d" % [host, port],
		"requests": requests,
		"openPolls": open_polls,
		"held": held,
		"expired": expired,
		"open": _connections.size(),
		"queued": _out_lines.size(),
		"badRequests": bad_requests,
	}


# --------------------------------------------------------------------------------------------
# frame service
# --------------------------------------------------------------------------------------------


func _service() -> void:
	_accept_pending()
	var live: Array = []
	for conn in _connections:
		if _step_connection(conn):
			live.append(conn)
		else:
			conn.close()
	_connections = live
	_answer_waiting()
	_expire_waiting()


func _accept_pending() -> void:
	while _server != null and _server.is_valid() and _server.is_connection_available():
		if _connections.size() >= MAX_CONNECTIONS:
			break
		var client: Object = _server.take_connection()
		if client == null:
			break
		client.call("set_no_delay", true)
		var conn := BridgeHTTPConn.new()
		conn.sock = client
		_connections.append(conn)


## Returns false when the socket should be dropped.
func _step_connection(conn: Object) -> bool:
	if conn.sock == null:
		return false
	conn.sock.call("poll")
	if not BridgeNet.is_stream_connected(conn.sock):
		return false
	var got: PackedByteArray = BridgeNet.take_available(conn.sock)
	if not got.is_empty():
		conn.buffer.append_array(got)
	if conn.buffer.size() > MAX_REQUEST_BYTES:
		bad_requests += 1
		return false
	for _guard in range(MAX_CONNS_PER_FRAME):
		if not conn.have_request:
			if not conn.parse_request():
				return not conn.broken
				# incomplete is normal mid-flight; `broken` means "not a bridge request"
			continue
		if conn.body_pending():
			if not conn.read_body():
				break
			continue
		if not conn.handled:
			_handle(conn)
			continue
		break
	return true


func _handle(conn: Object) -> void:
	requests += 1
	conn.handled = true
	var path: String = conn.path
	if path == "/bridge/push" and (conn.method == "POST" or conn.method == "GET"):
		# POST carries the batch as the body; GET carries it in `?b=`, percent-encoded. Director's
		# NetLingo can only issue a GET with `getNetText`, and a 1-frame batch fits in a URL with
		# room to spare, so both forms are accepted and mean the same thing (§7.2).
		var body: String = conn.body_text()
		if body.is_empty():
			body = BridgeNet.percent_decode(String(conn.query.get("b", "")))
		for line in BridgeWire.lines_from_text(body):
			_incoming.append(line)
		conn.reply("ok")
		if peer != null:
			peer.last_seen_ms = peer.uptime_ms()
			peer.update_status()
		conn.finish()
		return
	if conn.method == "GET" and path == "/bridge/handshake":
		var caps := ",".join(PackedStringArray(peer.caps)) if peer != null else ""
		var role_text := peer.role if peer != null else "godot"
		conn.reply("%s proto=%d caps=%s" % [role_text, BridgeWire.PROTOCOL_VERSION, caps])
		conn.finish()
		return
	if conn.method == "GET" and path == "/bridge/state":
		conn.reply(JSON.stringify(peer.snapshot_state() if peer != null else {}, "  "), "application/json")
		conn.finish()
		return
	if conn.method == "GET" and path == "/bridge/reset":
		_out_lines.clear()
		conn.reply("reset")
		conn.finish()
		return
	if conn.method == "GET" and path == "/bridge/poll":
		conn.wait_budget = int(conn.query.get("wait", str(wait_ms)))
		conn.ack_seen = int(conn.query.get("ack", "-1"))
		held += 1
		if not _out_lines.is_empty():
			_flush_to(conn)
		else:
			conn.awaiting = true  # answered by _answer_waiting() on a later frame, or expires
		return
	conn.reply_error(404, "unknown bridge endpoint: %s %s" % [conn.method, path])
	conn.finish()


## A held poll is answered as soon as there is a batch for it.
func _answer_waiting() -> void:
	if _out_lines.is_empty():
		return
	for conn in _connections:
		if conn.awaiting:
			_flush_to(conn)
			return  # one waiter per batch, so batch order stays unambiguous


func _flush_to(conn: Object) -> void:
	var payload := BridgeWire.lines_to_text(_out_lines)
	_out_lines.clear()
	conn.awaiting = false
	conn.reply(payload)
	conn.finish()


## …and answered empty when its own budget expires, so Director's client always makes progress and
## re-arms instead of stalling on a quiet bridge.
func _expire_waiting() -> void:
	for conn in _connections:
		if conn.awaiting and conn.expired():
			expired += 1
			conn.awaiting = false
			conn.reply("")
			conn.finish()


## Traffic nobody polled for must not grow forever; the file transport has the same property by
## construction (a batch replaces the file). Keep the newest, drop the oldest.
func _trim_outgoing() -> void:
	if _out_lines.size() > MAX_QUEUED_LINES:
		_out_lines = _out_lines.slice(_out_lines.size() - MAX_QUEUED_LINES)


# --------------------------------------------------------------------------------------------
# one connection's request state
# --------------------------------------------------------------------------------------------


class BridgeHTTPConn:
	extends RefCounted

	const HEAD_MAX := 16384

	var sock: Object = null
	var buffer := PackedByteArray()  # bytes received but not consumed yet
	var have_request := false
	var handled := false
	var awaiting := false  # an open long-poll, waiting for traffic
	var broken := false  # not a bridge request at all: drop the socket
	var keep_alive := true
	var method := ""
	var path := ""
	var query := {}
	var body_start := 0
	var body_length := 0
	var body := PackedByteArray()
	var wait_budget := 1500
	var ack_seen := -1
	var opened_at := 0

	## The header terminator is found by *bytes*: a String index is a UTF-32 code-point offset and
	## would slice a multi-byte body in half. True when a complete header was consumed.
	func parse_request() -> bool:
		var index := _find_header_end()
		if index < 0:
			if buffer.size() > HEAD_MAX:
				broken = true  # 16 KiB without a header terminator: not our client
			return false
		var head := buffer.slice(0, index).get_string_from_utf8()
		buffer = buffer.slice(index + 4)  # everything after CRLFCRLF belongs to the body
		var lines := head.split("\r\n")
		var parts: PackedStringArray = String(lines[0]).split(" ")
		if parts.size() < 2:
			broken = true
			return false
		method = parts[0]
		var target := parts[1]
		var qmark := target.find("?")
		if qmark >= 0:
			path = target.substr(0, qmark)
			query = parse_query(target.substr(qmark + 1))
		else:
			path = target
			query = {}
		var headers := {}
		for line_index in range(1, lines.size()):
			var colon := lines[line_index].find(":")
			if colon > 0:
				headers[String(lines[line_index]).substr(0, colon).to_lower()] = String(lines[line_index]).substr(colon + 1).strip_edges()
		body_length = int(headers.get("content-length", "0"))
		keep_alive = String(headers.get("connection", "")).to_lower() != "close"
		body = PackedByteArray()
		have_request = true
		handled = false
		awaiting = false
		opened_at = Time.get_ticks_msec()
		return true

	## Byte offset of the first CRLFCRLF, or -1.
	func _find_header_end() -> int:
		var size := buffer.size()
		if size < 4:
			return -1
		var i := 0
		while i + 3 < size:
			if buffer[i] == 13 and buffer[i + 1] == 10 and buffer[i + 2] == 13 and buffer[i + 3] == 10:
				return i
			i += 1
		return -1

	func body_pending() -> bool:
		return have_request and body.size() < body_length

	## `false` means "still arriving" — a POST body split across segments is ordinary on loopback.
	func read_body() -> bool:
		var take := mini(body_length - body.size(), buffer.size())
		if take <= 0:
			return false
		body.append_array(buffer.slice(0, take))
		buffer = buffer.slice(take)
		return true

	func body_text() -> String:
		return body.get_string_from_utf8()

	## Long-poll deadline. `awaiting` is only ever set for /bridge/poll.
	func expired() -> bool:
		return awaiting and Time.get_ticks_msec() - opened_at > wait_budget

	## Ready for the next request on this kept-alive socket. `buffer` is left alone: it may already
	## hold the start of the next pipelined request.
	func finish() -> void:
		have_request = false
		handled = false
		awaiting = false
		method = ""
		path = ""
		query = {}
		body = PackedByteArray()
		body_length = 0

	func reply(payload: String, content_type := "text/plain; charset=utf-8") -> void:
		respond(payload.to_utf8_buffer(), 200, "OK", content_type)

	func reply_error(code: int, message: String) -> void:
		respond(message.to_utf8_buffer(), code, "Not Found" if code == 404 else "Error", "text/plain; charset=utf-8")

	## put_data queues into Godot's own send buffer and goes out on the next poll(). If that buffer
	## were ever full the response would be lost — which is fine here, because the client's netText
	## times out and re-arms, and §8 keeps the bridge idempotent.
	func respond(data: PackedByteArray, code: int, label: String, content_type: String) -> void:
		if sock == null:
			return
		var head := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: %s\r\n\r\n" % [
			code, label, content_type, data.size(), "keep-alive" if keep_alive else "close"
		]
		var out := head.to_utf8_buffer()
		out.append_array(data)
		sock.call("put_data", out)

	func close() -> void:
		if sock != null:
			sock.call("disconnect_from_host")
			sock = null

	static func parse_query(text: String) -> Dictionary:
		var out := {}
		for chunk in text.split("&"):
			var equals := chunk.find("=")
			if equals <= 0:
				continue
			out[percent_decode(chunk.substr(0, equals))] = percent_decode(chunk.substr(equals + 1))
		return out

	## `%XX` and `+`, nothing more: Director percent-encodes TAB/LF because getNetText URLs cannot
	## carry raw tabs (§7.2), and that is the only escaping this transport has.
	static func percent_decode(text: String) -> String:
		if not text.contains("%") and not text.contains("+"):
			return text
		var bytes := PackedByteArray()
		var index := 0
		while index < text.length():
			var char := text[index]
			if char == "%" and index + 2 < text.length():
				var value := _hex_value(text.substr(index + 1, 2))
				if value >= 0:
					bytes.append(value)
					index += 3
					continue
			if char == "+":
				bytes.append(32)
				index += 1
				continue
			bytes.append_array(char.to_utf8_buffer())
			index += 1
		return bytes.get_string_from_utf8()

	static func _hex_value(text: String) -> int:
		if text.length() != 2:
			return -1
		var total := 0
		for i in range(2):
			var code := text.unicode_at(i)
			var digit := -1
			if code >= 48 and code <= 57:
				digit = code - 48
			elif code >= 65 and code <= 70:
				digit = code - 55
			elif code >= 97 and code <= 102:
				digit = code - 87
			if digit < 0:
				return -1
			total = total * 16 + digit
		return total
