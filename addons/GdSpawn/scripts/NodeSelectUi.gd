@tool
extends Control
class_name GdSpawnNodeSelect

signal node_changed(node)

@export var match_selected_button: Button
@export var node_type: String
@export var label: Label
@export var texture_rect: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	match_selected_button.pressed.connect(on_match_selected)


func on_match_selected():
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.size() == 0:
		return

	if selected_nodes[0].is_class(node_type):
		label.text = selected_nodes[0].name
		node_changed.emit(selected_nodes[0])
		change_node_icon("Node3D")

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data.type == "nodes" and data.nodes.size() == 1:
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:

	var node = EditorInterface.get_edited_scene_root().get_node(data.nodes[0])

	if not node.is_class(node_type):
		return

	node_changed.emit(node)
	label.text = node.name
	change_node_icon("Node3D")


func set_node(node):
	if node == null:
		label.text = "No node selected"
		change_node_icon("Warning")
		return
	label.text = node.name
	change_node_icon("Node3D")


func change_node_icon(name):
	var icon = EditorIconTexture2D.new()
	icon.icon_name = name
	texture_rect.texture = icon
	texture_rect.hide()
	texture_rect.show()