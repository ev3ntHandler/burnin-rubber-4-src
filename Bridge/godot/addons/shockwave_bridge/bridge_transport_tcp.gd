## `tcp` transport — PROTOCOL.md §7.3. Godot is normally the server (`127.0.0.1:7777`); Director
## reaches it through a socket Xtra, and `tools/mock_director.py` speaks it natively, which is how
## the protocol is tested without Director. `mode = "client"` lets Godot dial out instead, for when
## the movie is the host or a relay sits in between.
##
## Newline-delimited batches, ordered by the stream, so no `.seq` marker is needed. `binary = true`
## switches to `u32 length · batch` framing, which skips the LF scan and suits length-delimited Xtras.
##
## All socket work happens in `poll()`, i.e. inside the peer's frame tick — never in a callback, so
## no inbound message can re-enter the engine mid-frame (§6).
class_name BridgeTransportTCP
extends RefCounted

const MAX_WRITE_ATTEMPTS := 8

var peer: BridgePeer = null
var mode := "server"  # "server" listens, "client" dials
var host := "127.0.0.1"
var port := 7777
var binary := false
var retry_ms := 1000
var clients := 0
var attempts := 0
var dropped := 0

var _server: TCPServer = null
var _client: Object = null  # StreamPeerTCP, accepted or dialed
var _incoming: Array = []
var _read_buffer := PackedByteArray()
var _write_buffer := PackedByteArray()
var _last_try := -1000000


func setup(for_peer: BridgePeer, p_mode: String, p_host: String, p_port: int, config: BridgeConfig = null) -> void:
	peer = for_peer
	mode = p_mode
	if config == null and peer != null:
		config = peer.cfg
	if config != null:
		port = p_port if p_port > 0 else config.tcpPort
		binary = config.binary
		host = p_host if not p_host.is_empty() else config.tcpHost
	if mode == "server":
		bind()
	if peer != null:
		peer.transport = self


## Loopback by default, on purpose (§6): anything that can open this port can run Lingo in the
## movie. Set an explicit address in the config to expose it on the LAN.
func bind() -> int:
	if mode != "server":
		return OK
	_server = TCPServer.new()
	var error := _server.listen(port, host)
	if error != OK and peer != null:
		peer.log_line("error", "tcp: cannot listen on %s:%d (%s)" % [host, port, error_string(error)])
	return error


## One call per frame: accept, read everything, write what is owed, hand over the messages.
func poll() -> Array:
	if mode == "server":
		_accept_pending()
	else:
		_ensure_client()
	_service_stream()
	if _incoming.is_empty():
		return []
	var lines := _incoming.duplicate()
	_incoming.clear()
	return lines


func _accept_pending() -> void:
	var fresh: Object = BridgeNet.accept_one(_server)
	if fresh == null:
		return
	clients += 1
	if BridgeNet.is_stream_connected(_client):
		_client.call("disconnect_from_host")  # one client at a time; the newest wins
	_client = fresh
	_read_buffer = PackedByteArray()
	if peer != null:
		peer.reset_hello()  # HELLO may have been greeted to nobody while we were not connected


func _ensure_client() -> bool:
	if BridgeNet.is_stream_connected(_client):
		return true
	if Time.get_ticks_msec() - _last_try < retry_ms:
		return false  # retry_ms is a floor on reconnect churn, not on latency
	_last_try = Time.get_ticks_msec()
	attempts += 1
	var candidate := StreamPeerTCP.new()
	candidate.set_no_delay(true)
	if candidate.connect_to_host(host, port) != OK:
		return false
	_client = candidate
	_read_buffer = PackedByteArray()
	if peer != null:
		peer.reset_hello()
		peer.log_line("info", "tcp: connecting to %s:%d" % [host, port])
	return true


## Drain the socket. A partial line stays in `_read_buffer` — dropping it would glue the next
## segment's first half onto nothing and corrupt that message forever.
func _service_stream() -> void:
	if _client == null:
		return
	_client.call("poll")
	if not BridgeNet.is_stream_connected(_client):
		_drop_link()
		return
	var got: PackedByteArray = BridgeNet.take_available(_client)
	if not got.is_empty():
		_read_buffer.append_array(got)
	if _read_buffer.is_empty():
		return
	var split := BridgeNet.split_lines(_read_buffer, binary)
	for line in split[0]:
		_incoming.append(line)
	_read_buffer = split[1]
	if _read_buffer.size() > BridgeNet.MAX_PENDING_BYTES:
		dropped += 1  # unbounded garbage (or a peer that will not flush): restart the stream
		_drop_link()
	_flush_write_buffer()


func send(lines: Array) -> void:
	if lines.is_empty():
		return
	var payload := BridgeWire.lines_to_text(lines).to_utf8_buffer()
	_write_buffer.append_array(BridgeNet.pack_frame(payload) if binary else payload)
	if _write_buffer.size() > BridgeNet.MAX_PENDING_BYTES:
		# Keeping a subset would break framing, so drop the link: the reconnect re-sends HELLO and
		# nothing is ever silently corrupted. The peer's own DELTA makes the next frame consistent.
		dropped += 1
		_write_buffer = PackedByteArray()
		_drop_link()
		return
	_flush_write_buffer()


## `put_partial_data` tells us exactly how much the kernel took, which is the only way to keep the
## unwritten tail instead of tearing it (see bridge_net.gd).
func _flush_write_buffer() -> void:
	if _write_buffer.is_empty():
		return
	if not BridgeNet.is_stream_connected(_client):
		return
	for _attempt in range(MAX_WRITE_ATTEMPTS):
		var result: Array = _client.call("put_partial_data", _write_buffer)
		var written := int(result[1]) if result.size() > 1 else 0
		if written <= 0:
			var error := int(result[0])
			if error != OK and error != ERR_UNAVAILABLE and error != ERR_BUSY:
				_drop_link()
				return
			return  # kernel buffer full: the remainder goes out next frame
		_write_buffer = _write_buffer.slice(written)
		if _write_buffer.is_empty():
			return


func _drop_link() -> void:
	if _client != null and BridgeNet.is_stream_connected(_client):
		_client.call("disconnect_from_host")
	_client = null
	_read_buffer = PackedByteArray()
	# _write_buffer survives on purpose: the next connect flushes it, so a blip costs latency and
	# never a lost command.


func stop() -> void:
	_drop_link()
	if _server != null and _server.is_valid():
		_server.stop()
	_server = null


func pending_bytes() -> int:
	return _write_buffer.size()


func status() -> Dictionary:
	return {
		"transport": "tcp",
		"role": mode,
		"listen": "%s:%d" % [host, port] if mode == "server" else "",
		"target": "%s:%d" % [host, port] if mode == "client" else "",
		"connected": BridgeNet.is_stream_connected(_client),
		"clients": clients,
		"attempts": attempts,
		"binary": binary,
		"pendingBytes": _write_buffer.size(),
		"dropped": dropped,
	}
