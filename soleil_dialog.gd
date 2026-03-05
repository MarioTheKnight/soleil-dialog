@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_autoload_singleton("DialogManager", "res://addons/soleil_dialog/autoloads/dialog_manager.gd")
	print("SoleilDialog: Plugin enabled and Autoloads registered.")


func _exit_tree() -> void:
	remove_autoload_singleton("DialogManager")
	print("SoleilDialog: Plugin disabled and Autoloads removed.")
