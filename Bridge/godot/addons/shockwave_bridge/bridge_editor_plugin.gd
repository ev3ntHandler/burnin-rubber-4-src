## Editor entry point: installs the bottom-panel dock and offers the autoload.
##
## The addon works with *no* editor integration at all — add `shockwave_bridge.gd` as an autoload
## called `ShockwaveBridge` and it runs. The dock is there because watching a movie's state while
## you are still in the editor is the fastest way to find out what you want to expose.
@tool
extends EditorPlugin

const AUTOLOAD_NAME := "ShockwaveBridge"
const AUTOLOAD_PATH := "res://addons/shockwave_bridge/shockwave_bridge.gd"
const DOCK := preload("res://addons/shockwave_bridge/bridge_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = DOCK.new()
	add_control_to_bottom_panel(_dock, "Shockwave")
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		# Ask once, and only in a project that can actually take the autoload.
		call_deferred("_offer_autoload")


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null


func _offer_autoload() -> void:
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Add %s as an autoload so the running game talks to the movie?" % AUTOLOAD_NAME
	confirm.title = "Shockwave Bridge"
	confirm.confirmed.connect(_install_autoload)
	editor_interface.get_base_control().add_child(confirm)
	confirm.popup_centered()


func _install_autoload() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	ProjectSettings.save()
	print("Shockwave Bridge: autoload %s -> %s installed" % [AUTOLOAD_NAME, AUTOLOAD_PATH])
