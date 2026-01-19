@tool
extends PanelContainer
class_name GdSpawnPathEditToolBar

@export var edit_button: Button
@export var add_button: Button
@export var delete_button: Button

@export var options_button: Button

@export var options_panel: PopupPanel

@export var mirror_angle_button: Button
@export var mirror_length_button: Button

@export var snap_to_colliders_button: Button

@export var closed_path_button: Button


var path_node: GdSpawnPath3D

func _ready() -> void:

	options_button.toggled.connect(_on_options_button_toggled)
	closed_path_button.toggled.connect(_on_closed_path_toggled)
	options_panel.close_requested.connect(func(): edit_button.button_pressed = true)


func is_select_mode_enabled():
	return edit_button.button_pressed


func is_create_mode_enabled():
	return add_button.button_pressed


func is_delete_mode_enabled():
	return delete_button.button_pressed


func is_snap_to_colliders_enabled():
	return snap_to_colliders_button.button_pressed


func is_mirror_angle_enabled():
	return mirror_angle_button.button_pressed

func is_mirror_length_enabled():
	return mirror_length_button.button_pressed




func _on_options_button_toggled(enabled: bool) -> void:
	if enabled:
		var popup_position := Vector2i(get_global_transform().origin)
		popup_position.y += size.y + 12
		options_panel.popup(Rect2i(popup_position, Vector2i.ZERO))
	else:
		options_panel.hide()


func selection_changed(selected: Array) -> void:
	if selected.is_empty():
		visible = false
		path_node = null
		return

	var node = selected[0]
	visible = node is GdSpawnPath3D
	if visible:
		path_node = node
		closed_path_button.button_pressed = node.curve.closed



func _on_closed_path_toggled(enabled: bool) -> void:
	if path_node and path_node.curve:
		path_node.curve.closed = enabled
		path_node.update_gizmos()
		path_node._update()
