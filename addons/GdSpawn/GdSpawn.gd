@tool
extends EditorPlugin


var main_dock: Control

const BASE_SETTING = "GdSpawn/Settings/"


func _enter_tree() -> void:

	main_dock = preload("res://addons/GdSpawn/ui/MainDock.tscn").instantiate()

	add_control_to_bottom_panel(main_dock, "GdSpawn")
	_add_setting("%sPreview Perspective" % BASE_SETTING, SceneLibraryItem.PreviewMode.Default, TYPE_INT, PROPERTY_HINT_ENUM,\
		get_enum_hint_string(SceneLibraryItem.PreviewMode) )


func _exit_tree() -> void:
	
	remove_control_from_bottom_panel(main_dock)
	main_dock.free()



func _add_setting(property_name: String, default: Variant, type = -1, hint = -1, hint_string = ""):
	if not ProjectSettings.has_setting(property_name):
		ProjectSettings.set_setting(property_name, default)
	ProjectSettings.set_initial_value(property_name, default)

	if type != -1:
		var property_info = {
			"name": property_name,
			"type": type,
		}
		if hint != -1:
			property_info["hint"] = hint
			property_info["hint_string"] = hint_string

		ProjectSettings.add_property_info(property_info)



func get_enum_hint_string(enum_dict):
	return ", ".join(enum_dict.keys())

