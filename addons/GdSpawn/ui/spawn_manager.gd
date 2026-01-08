@tool
extends Node
class_name GdSpawnSpawnManager

@export var libraries_manager: GdSpawnLibrariesManager
@export var spawn_under_label: GdSpawnSpawnUnderLabel
@export var spawn_under_choose_selected_button: Button

@export var spawn_option_button: OptionButton
@export var spawn_option_parent: Control

@export var snap_enable: CheckBox
@export var snap_step: SpinBox
@export var snap_shift_step: SpinBox


@export var spawn_node: Node

enum GdSpawnPlacementMode {Plane, Surface}

var current_placement_mode: GdSpawnPlacementMode

@export var placement_mode_to_ui_scene: Dictionary[GdSpawnPlacementMode, PackedScene]
var placement_mode_to_ui: Dictionary[GdSpawnPlacementMode, Control]

var current_placement_mode_manager: Node
var undo_redo: EditorUndoRedoManager

var node_history: Array

var editor_plugin

class GdSpawnSnapInfo:
	var enabled: bool = false
	var step: float = 1.0
	var shift_step: float = 0.1

var current_snap_info = GdSpawnSnapInfo.new()

func _ready() -> void:

	snap_enable.toggled.connect(func(toggled): current_snap_info.enabled = toggled)
	snap_step.value_changed.connect(func(value): current_snap_info.step = value)
	snap_shift_step.value_changed.connect(func(value): current_snap_info.shift_step = value)
	undo_redo = editor_plugin.get_undo_redo()

	change_spawn_node(EditorInterface.get_edited_scene_root())
	editor_plugin.scene_changed.connect(func (scene_root): change_spawn_node(scene_root))
	spawn_under_label.node_changed.connect(func (node): change_spawn_node(node))

	for key in GdSpawnPlacementMode.keys():
		spawn_option_button.add_item(key)

	spawn_option_button.item_selected.connect(on_spawn_option_selected)

	spawn_under_choose_selected_button.pressed.connect(on_choose_selected)

	libraries_manager.selected_item_changed.connect(on_selected_item_changed)

	if spawn_option_parent.get_child_count() > 0:
		spawn_option_parent.get_child(0).queue_free()

	for placement_mode in placement_mode_to_ui_scene.keys():
		var ui_instance = placement_mode_to_ui_scene[placement_mode].instantiate()
		spawn_option_parent.add_child(ui_instance)
		placement_mode_to_ui[placement_mode] = ui_instance
	
	on_spawn_option_selected(0)


func on_spawn_option_selected(idx):
	current_placement_mode = idx

	for child in spawn_option_parent.get_children():
		child.hide()
	current_placement_mode_manager = placement_mode_to_ui[current_placement_mode]
	current_placement_mode_manager.show()


func on_choose_selected():
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.size() == 0:
		return
	
	change_spawn_node(selected_nodes[0])

	
func change_spawn_node(node):
	if not node:
		return
	spawn_node = node
	spawn_under_label.text = spawn_node.name

var preview_scene = null
func on_selected_item_changed(item: GdSpawnSceneLibraryItem):
	if preview_scene:
		preview_scene.queue_free()
	if not item:
		return

	if not spawn_node:
		return

	preview_scene = item.scene.instantiate()
	spawn_node.add_child(preview_scene)
	EditorInterface.edit_node(spawn_node)


func on_move(camera: Camera3D, mouse_position: Vector2):
	if not preview_scene:
		return
	var new_transform = current_placement_mode_manager.on_move(camera, mouse_position, current_snap_info, preview_scene.global_transform)
	preview_scene.global_transform = new_transform

func on_confirm():
	var instanced_scene = libraries_manager.current_selected_scene_library_item.scene.instantiate()

	undo_redo.create_action("Place Scene: %s" % libraries_manager.current_selected_scene_library_item.scene.resource_path)
	undo_redo.add_do_method(self, "_do_placement", instanced_scene, spawn_node, preview_scene.global_transform)
	undo_redo.add_undo_method(self, "_undo_placement", spawn_node)
	undo_redo.commit_action()

	#TODO clear history when plugin disabled

func _do_placement(new_node, root: Node3D, transform: Transform3D):
	root.add_child(new_node, true)
	new_node.global_transform = transform
	new_node.owner = EditorInterface.get_edited_scene_root()
	node_history.push_front(new_node)

func on_rotate_y():
	if not preview_scene:
		return
		
	preview_scene.rotate_y(deg_to_rad(90))

func _undo_placement(root: Node3D):
	var last_added = node_history.pop_front()
	root.remove_child(last_added)

func on_cancel():
	preview_scene.queue_free()
	libraries_manager.deselect()
