## `files` transport — PROTOCOL.md §7.1. The default: no Xtra, no socket, no admin rights, works in
## the Director editor, in a projector, and on any OS.
##
## Mailbox layout, one directory shared by the two processes:
##
##     BridgeData/d2g.txt   director -> godot, one whole batch, rewritten every snapshot
##     BridgeData/d2g.seq   "<seq> <bytes> <lines>" written *after* d2g.txt  (the commit marker)
##     BridgeData/g2d.txt   godot -> director
##     BridgeData/g2d.seq
##
## The write order *is* the protocol: payload first (closed), then the tiny marker. A reader accepts
## a payload only when its LF count (and, for engines that can cheaply count UTF-8 bytes, its size)
## matches the marker, so a torn read self-heals on the next poll. No locks, neither side can block
## the other, and a peer that stops writing is noticed because `seq` stops advancing.
class_name BridgeTransportFiles
extends RefCounted

const OUT_NAME := {"director": "d2g.txt", "godot": "g2d.txt"}
const IN_NAME := {"director": "g2d.txt", "godot": "d2g.txt"}

var peer: BridgePeer = null
var root_dir := ""
var out_path := ""
var in_path := ""
var verify := true
var polls := 0
var writes := 0
var torn := 0
var last_in_seq := -1
var last_out_seq := 0

var _text := ""  # scratch buffer for the last payload read


## `base` is where a relative `config.root` is resolved against. Director passes `_movie.path`;
## Godot passes the project dir, or an absolute `root` in Bridge.Data.txt pointing at the movie's
## BridgeData folder — the usual setup when the two projects sit next to each other.
func setup(for_peer: BridgePeer, base: String, config: BridgeConfig = null) -> void:
	peer = for_peer
	var cfg := config if config != null else peer.cfg
	root_dir = cfg.resolved_root(base)
	out_path = root_dir.path_join(String(OUT_NAME.get(peer.role, "g2d.txt")))
	in_path = root_dir.path_join(String(IN_NAME.get(peer.role, "d2g.txt")))
	verify = cfg.verify
	DirAccess.make_dir_recursive_absolute(root_dir)


## Publish one batch. `out_seq` advances here because the seq is the reader's dedupe key (§8).
func send(lines: Array) -> void:
	if lines.is_empty():
		return
	var payload := ""
	for line in lines:
		payload += String(line) + BridgeWire.LF
	peer.out_seq += 1
	last_out_seq = peer.out_seq
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	if not _write(out_path, payload):
		return
	writes += 1
	_write_marker(payload)


func _write(path: String, payload: String) -> bool:
	# .tmp then rename: on NTFS, APFS and ext4 a rename is atomic, which is what makes the marker
	# meaningful — a reader can never observe a half-written payload.
	var temp := path + ".tmp"
	if not _write_raw(temp, payload):
		return false
	if DirAccess.rename_absolute(temp, path) == OK:
		return true
	# Windows can refuse to rename onto a file the peer happened to be opening. Rewriting in place
	# is still safe: the marker is published only once the payload is fully closed.
	return _write_raw(path, payload)


func _write_raw(path: String, payload: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		if peer != null:
			peer.log_line("error", "files: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(payload)
	file.flush()
	file.close()
	return true


func _write_marker(payload: String) -> void:
	var marker := FileAccess.open(_marker_for(out_path), FileAccess.WRITE)
	if marker == null:
		return
	# "<seq> <bytes> <lines>". `bytes` is the UTF-8 size (see §7.1: a reader that cannot count UTF-8
	# bytes verifies `lines` alone — that is what the Lingo side does). The optional 4th token
	# (crc32hex) is a writer's nicety; Godot and Director both skip it.
	marker.store_string("%d %d %d\n" % [last_out_seq, payload.to_utf8().size(), _count(payload, BridgeWire.LF)])
	marker.flush()
	marker.close()


## The newest intact frame newer than the last one applied, or `[]` for "nothing new" — which also
## covers "the writer was mid-write", a normal and self-healing outcome.
func poll() -> Array:
	polls += 1
	if not verify:
		return _read_unchecked()
	var marker := _read_marker(_marker_for(in_path))
	if marker.is_empty():
		return []
	var seq := int(marker[0])
	var size := int(marker[1])
	var line_count := int(marker[2])
	# Only an *exact* repeat means "already applied". A lower seq is the peer starting its counter
	# over after a restart (§7.1), and skipping everything below a stale high-water mark would ignore
	# that peer until its count passed the old one -- tens of thousands of frames of silence.
	if seq == last_in_seq:
		return []  # a replayed frame must never be applied twice (§8)
	if not _read_into(in_path):
		return []
	# Both witnesses, in the cheap order: LF count first (a partial write cannot satisfy it), then
	# the promised size. A Director writer can only count Lingo characters, not UTF-8 bytes, so
	# `size` is a minimum the payload must reach, not an equality -- `lines` is the exact witness
	# (§7.1). Shorter than promised means the write had not landed yet, and the next poll fixes it.
	if _count(_text, BridgeWire.LF) != line_count:
		_note_torn()
		return []
	if size >= 0 and _text.to_utf8().size() < size:
		_note_torn()
		return []
	last_in_seq = seq
	return BridgeWire.lines_from_text(_text)


## Drop the remembered inbound position. `BridgePeer.accept_hello` calls this when the peer's
## greeting arrives with a `seq` behind ours — i.e. the movie was re-run while Godot kept running —
## so a frame that happens to carry the same number as the stale high-water mark is not skipped.
func reset_inbound() -> void:
	last_in_seq = -1


## `verify = 0` peers tolerate a missing or lying marker: take every whole line, drop the tail.
func _read_unchecked() -> Array:
	if not _read_into(in_path):
		return []
	var parts := _text.split(BridgeWire.LF)
	parts.remove_at(parts.size() - 1)  # after the last LF there is nothing complete
	for index in range(parts.size() - 1, -1, -1):
		if parts[index].strip_edges().is_empty():
			parts.remove_at(index)
	return parts


func _read_into(path: String) -> bool:
	_text = ""
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	_text = file.get_as_text()
	file.close()
	return true


func _read_marker(path: String) -> Array:
	if not _read_into(path):
		return []
	var tokens := _text.strip_edges().split(" ")
	if tokens.size() < 3:
		return []
	var out: Array = []
	for index in range(3):
		if not String(tokens[index]).is_valid_int():
			return []
		out.append(int(tokens[index]))
	return out


func _note_torn() -> void:
	torn += 1
	if peer != null:
		peer.stats["torn"] += 1


func _marker_for(path: String) -> String:
	if path.ends_with(".txt"):
		return path.substr(0, path.length() - 4) + ".seq"
	return path + ".seq"


static func _count(haystack: String, needle: String) -> int:
	var total := 0
	var index := haystack.find(needle)
	while index >= 0:
		total += 1
		index = haystack.find(needle, index + 1)
	return total


func status() -> Dictionary:
	return {
		"transport": "files",
		"root": root_dir,
		"out": out_path.get_file(),
		"in": in_path.get_file(),
		"verify": verify,
		"writes": writes,
		"polls": polls,
		"torn": torn,
		"lastInSeq": last_in_seq,
	}
