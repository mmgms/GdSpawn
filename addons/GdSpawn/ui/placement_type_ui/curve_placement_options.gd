@tool
extends PanelContainer



var signal_routing: GdSpawnSignalRouting

@export var spawn_profile_parent: Control
@export var spawn_profile: GdSpawnCurveSpawnProfile

func _ready() -> void:
	spawn_profile = GdSpawnCurveSpawnProfile.new()
	var props = get_property_list()
	var prop_to_edit
	for prop in props:
		if prop.name == "spawn_profile":
			prop_to_edit = prop
			break

	var editor_property = EditorInspector.instantiate_property_editor(self, \
		prop_to_edit.type, "spawn_profile", prop_to_edit.hint, prop_to_edit.hint_string, prop_to_edit.usage)
	spawn_profile_parent.add_child(editor_property)



func should_show_grid():
	return false