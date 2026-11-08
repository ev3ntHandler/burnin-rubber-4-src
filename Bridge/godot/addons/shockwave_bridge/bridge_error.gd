## A protocol error, carried as a *value* instead of an exception (GDScript has none).
##
## On the wire it becomes `RSP <id> <op> err <code> <message>` (§4). Codes are the ones the spec
## lists: unknownop, badargs, nopath, denied, disabled, notfound, error, timeout, badtype.
class_name BridgeError
extends RefCounted

const CODES := ["unknownop", "badargs", "nopath", "denied", "disabled", "notfound", "error", "timeout", "badtype", "badframe"]

var code: String = "error"
var message: String = ""


static func make(code: String, message: String = "") -> BridgeError:
	var error := BridgeError.new()
	error.code = code
	error.message = message
	return error


func is_error() -> bool:
	return true


## True when `value` is anything the peers treat as "no value": GDScript null, the string "VOID"
## and Director's VOID, which arrives as an empty #void tag.
static func is_void(value: Variant) -> bool:
	return value == null


func _to_string() -> String:
	if message.is_empty():
		return code
	return "%s: %s" % [code, message]
