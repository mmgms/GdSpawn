@tool
extends Label
class_name GdSpawnSpawnUnderLabel

signal node_changed()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data.type == "nodes" and data.nodes.size() == 1:
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:

	var node = EditorInterface.get_edited_scene_root().get_node(data.nodes[0])
	text = node.name
	node_changed.emit(node)
