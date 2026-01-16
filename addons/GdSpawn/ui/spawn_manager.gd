@tool
extends Node
class_name GdSpawnSpawnManager

@export var signal_routing: GdSpawnSignalRouting

@export var spawn_under_node_select: GdSpawnNodeSelect


@export var snap_options_parent: Control

@export var spawn_option_button: OptionButton
@export var spawn_option_parent: Control

@export var snap_enable: CheckBox
@export var snap_step: SpinBox
@export var snap_shift_step: SpinBox


@export var grid_offset_x: SpinBox
@export var grid_offset_z: SpinBox
@export var reset_grid_offset: Button
@export var match_selected_offset: Button


@export var spawn_node: Node = null

@export var grid_scene: PackedScene

var current_grid: GdSpawnGrid

enum GdSpawnPlacementMode {Plane, Surface, Curve, Physics}

var current_placement_mode: GdSpawnPlacementMode

@export var placement_mode_to_ui_scene: Dictionary[GdSpawnPlacementMode, PackedScene]
var placement_mode_to_ui: Dictionary[GdSpawnPlacementMode, Control]

var current_placement_mode_manager: Node
var undo_redo: EditorUndoRedoManager


var editor_plugin

var is_moving_plane = false

enum PlacementState {Normal, Paint, TransformLocalY}

var current_placement_state = PlacementState.Normal

class GdSpawnSnapInfo:
	var enabled: bool = false
	var step: float = 1.0
	var shift_step: float = 0.1
	var grid_offset: Vector2 = Vector2.ZERO


class GdSpawnAddScenesAction:
	var scene: PackedScene
	var scenes: Array[PackedScene]
	var transforms: Array
	var parent: Node3D
	var owner: Node
	var select_last: bool = false

	var added_instances: Array

	func do():
		added_instances = []
		if not parent:
			return

		for idx in transforms.size():
			var transform = transforms[idx]
			var instance
			if not scenes.is_empty():
				instance = scenes[idx].instantiate()
			else:
				instance = scene.instantiate()
			parent.add_child(instance, true)
			instance.global_transform = transform
			instance.owner = owner
			added_instances.append(instance)
		if select_last:
			EditorInterface.edit_node(added_instances[-1])
			
	func undo():
		for instance in added_instances:
			if instance:
				instance.queue_free()

		if select_last:
			EditorInterface.edit_node(EditorInterface.get_edited_scene_root())


class GdSpawnAddPathAction:
	var path_name: String
	var parent: Node3D
	var owner: Node

	var curve_profile: GdSpawnCurveSpawnProfile
	var curve_settings: GdSpawnCurveSpawnSettings

	var added_node = null

	func do():
		if not curve_profile or not curve_settings:
			return
		added_node = GdSpawnPath3D.new()
		added_node.name = path_name
		added_node.curve_spawn_profile = curve_profile
		added_node.curve_spawn_settings = curve_settings
		added_node.curve = Curve3D.new()
		parent.add_child(added_node, true)
		added_node.owner = owner
		EditorInterface.edit_node(added_node)


	func undo():
		if not curve_profile or not curve_settings:
			return
		if not added_node:
			return

		added_node.queue_free()


var current_snap_info = GdSpawnSnapInfo.new()

func _ready() -> void:

	snap_enable.toggled.connect(func(toggled): current_snap_info.enabled = toggled)
	snap_step.value_changed.connect(func(value): current_snap_info.step = value; update_gizmo_grid_snap())
	snap_shift_step.value_changed.connect(func(value): current_snap_info.shift_step = value)

	grid_offset_x.value_changed.connect(on_grid_offset_value_changed)
	grid_offset_z.value_changed.connect(on_grid_offset_value_changed)
	reset_grid_offset.pressed.connect(on_reset_grid_offset)
	match_selected_offset.pressed.connect(on_match_selected_offset)

	undo_redo = editor_plugin.get_undo_redo()

	var current_scene_root = EditorInterface.get_edited_scene_root()
	on_scene_change(current_scene_root)
	hide_grid()
	editor_plugin.scene_changed.connect(on_scene_change)
	spawn_under_node_select.node_changed.connect(on_spawn_node_selected)

	for key in GdSpawnPlacementMode.keys():
		spawn_option_button.add_item(key)

	spawn_option_button.item_selected.connect(on_spawn_option_selected)

	signal_routing.ItemSelect.connect(on_selected_item_changed)
	signal_routing.ItemPlacementBasisSet.connect(on_item_basis_set)
	signal_routing.GridTrasformChanged.connect(on_grid_transform_changed)
	signal_routing.PluginDisabled.connect(on_plugin_disabled)

	signal_routing.SpawnUnderNodeChanged.connect(on_spawn_under_node_changed)

	if spawn_option_parent.get_child_count() > 0:
		spawn_option_parent.get_child(0).queue_free()

	for placement_mode in placement_mode_to_ui_scene.keys():
		var ui_instance = placement_mode_to_ui_scene[placement_mode].instantiate()
		spawn_option_parent.add_child(ui_instance)
		ui_instance.signal_routing = signal_routing
		if ui_instance.has_signal("add_scene_request"):
			ui_instance.add_scene_request.connect(on_add_scene_request)

		if ui_instance.has_signal("add_path_request"):
			ui_instance.add_path_request.connect(on_add_path_request)
		placement_mode_to_ui[placement_mode] = ui_instance
	
	on_spawn_option_selected(0)


var spawn_node_cache: Dictionary


func on_plugin_disabled():
	if preview_scene:
		preview_scene.queue_free()
	if current_grid:
		current_grid.queue_free()

	for scene in painted_instances_transform_history:
		scene.queue_free()

	painted_instances_transform_history.clear()

func on_scene_change(scene_root):
	if preview_scene:
		signal_routing.ItemSelect.emit(null)
		if is_moving_plane and current_placement_mode == GdSpawnPlacementMode.Plane:
			_cancel_move_plane()

	if current_grid:
		current_grid.queue_free()

	if spawn_node_cache.has(scene_root):
		change_spawn_node(spawn_node_cache[scene_root])
		add_or_update_grid(scene_root)
		spawn_under_node_select.set_node(spawn_node_cache[scene_root])
		return

	if not scene_root is Node3D:
		spawn_under_node_select.set_node(null)
		change_spawn_node(null)
		return

	change_spawn_node(scene_root)
	add_or_update_grid(scene_root)
	spawn_under_node_select.set_node(scene_root)
	hide_grid()


func on_spawn_under_node_changed(node):
	if not node:
		return
	change_spawn_node(node)
	spawn_node_cache[EditorInterface.get_edited_scene_root()] = node
	spawn_under_node_select.set_node(node)

func on_spawn_node_selected(node):
	change_spawn_node(node)
	spawn_node_cache[EditorInterface.get_edited_scene_root()] = node


func on_spawn_option_selected(idx):
	if current_placement_mode_manager:
		current_placement_mode_manager.on_exit()

	if (current_placement_mode == GdSpawnPlacementMode.Plane or current_placement_mode == GdSpawnPlacementMode.Surface)\
		 and idx > GdSpawnPlacementMode.Surface:
			if preview_scene:
				signal_routing.ItemSelect.emit(null)
				if is_moving_plane and current_placement_mode == GdSpawnPlacementMode.Plane:
					_cancel_move_plane()
	current_placement_mode = idx

	for child in spawn_option_parent.get_children():
		child.hide()
	current_placement_mode_manager = placement_mode_to_ui[current_placement_mode]

	current_placement_mode_manager.on_enter()
	current_placement_mode_manager.show()
	if not current_placement_mode_manager.should_show_grid():
		hide_grid()
	if current_placement_mode_manager.should_show_grid() and preview_scene:
		show_grid()

	if current_placement_mode == GdSpawnPlacementMode.Plane:
		snap_options_parent.show()
	else:
		snap_options_parent.hide()

	
func change_spawn_node(node):
	if not node:
		spawn_node = null
		return
	spawn_node = node

var preview_scene: Node3D = null
var current_selected_item = null
func on_selected_item_changed(item: GdSpawnSceneLibraryItem):
	current_selected_item = item
	if preview_scene:
		preview_scene.queue_free()

	if current_placement_mode == GdSpawnPlacementMode.Physics or current_placement_mode == GdSpawnPlacementMode.Curve:
		hide_grid()
		return

	if not item:
		hide_grid()
		return

	if not spawn_node:
		hide_grid()
		return

	if current_placement_mode_manager.should_show_grid():
		show_grid()

	preview_scene = item.scene.instantiate()
	spawn_node.add_child(preview_scene)
	GdSpawnUtilities.disable_collisions_recursive(preview_scene)
	EditorInterface.edit_node(spawn_node)

var mouse_pos_on_rotate_y_placement: Vector2
var preview_scene_transform_on_rotate_y_placement: Transform3D
var last_mouse_pos: Vector2
var viewport_camera = null
var painted_instances_transform_history: Array

func on_move(camera: Camera3D, mouse_position: Vector2, ctrl_pressed, shift_pressed):
	viewport_camera = camera
	last_mouse_pos = mouse_position

	var step = current_snap_info.step
	if shift_pressed:
		step = current_snap_info.shift_step
	
	var snap_enabled = current_snap_info.enabled
	if ctrl_pressed:
		snap_enabled = false

	if not spawn_node:
		return false

	if current_placement_mode == GdSpawnPlacementMode.Physics:
		current_placement_mode_manager.on_move(camera, mouse_position, current_selected_item, step, snap_enabled)
		return true

	if current_placement_mode == GdSpawnPlacementMode.Curve:
		return false

	if not preview_scene:
		return false

	if current_placement_mode == GdSpawnPlacementMode.Plane and is_moving_plane:
		current_placement_mode_manager.on_move_along_plane_normal(camera, mouse_position, step, snap_enabled)
		var res = current_placement_mode_manager.on_move(camera, mouse_position, current_selected_item, step, snap_enabled)
		preview_scene.global_transform = res.object_transform
		return true

	if current_placement_state == PlacementState.Normal:


		var res = current_placement_mode_manager.on_move(camera, mouse_position, current_selected_item, step, snap_enabled)
		preview_scene.global_transform = res.object_transform

	elif current_placement_state == PlacementState.TransformLocalY:
		
		var current_diff = mouse_position - mouse_pos_on_rotate_y_placement

		if abs(current_diff.x) < 10:
			return true

		const ROTATE_SENSITIVITY := 0.01 

		preview_scene.global_transform = preview_scene_transform_on_rotate_y_placement.rotated_local(Vector3.UP, current_diff.x * ROTATE_SENSITIVITY)

	elif current_placement_state == PlacementState.Paint:
		var res = current_placement_mode_manager.on_move(camera, mouse_position, current_selected_item, step, true)
		var object_transform = res["object_transform"] as Transform3D

		if not check_can_place(spawn_node, current_selected_item.scene, object_transform):
			return true
		
		var instanced_scene = current_selected_item.scene.instantiate()
		spawn_node.add_child(instanced_scene, true)
		instanced_scene.global_transform = object_transform
		painted_instances_transform_history.append(instanced_scene)

	return true

	# if not current_grid:
	# 	return
	# current_grid.update_offset(res.grid_offset)

func check_can_place(root, packed_scene, transform):
	for child in root.get_children().slice(0, 1000):
		if child.scene_file_path == packed_scene.resource_path and child.global_transform.is_equal_approx(transform):
			return false
	
	return true
	

func on_item_basis_set(item: GdSpawnSceneLibraryItem):
	if not preview_scene:
		return
	var res = current_placement_mode_manager.on_move(viewport_camera, last_mouse_pos, current_selected_item, current_snap_info.step, false)
	preview_scene.global_transform = res.object_transform


func on_press_start():
	if not spawn_node:
		return false
	if current_placement_mode == GdSpawnPlacementMode.Physics:
		var consume_event = current_placement_mode_manager.on_press()
		return consume_event

	if current_placement_mode == GdSpawnPlacementMode.Curve:
		return false

	if not preview_scene:
		return false

	if is_moving_plane and current_placement_mode == GdSpawnPlacementMode.Plane:
		is_moving_plane = false
		if current_grid:
			current_grid.hide_line()
		return true



	if current_snap_info.enabled and current_placement_mode == GdSpawnPlacementMode.Plane:
		current_placement_state = PlacementState.Paint
		painted_instances_transform_history = []
		var instanced_scene = current_selected_item.scene.instantiate()
		spawn_node.add_child(instanced_scene, true)
		instanced_scene.global_transform = preview_scene.global_transform
		painted_instances_transform_history.append(instanced_scene)
		return true

	else:
		current_placement_state = PlacementState.TransformLocalY
		mouse_pos_on_rotate_y_placement = last_mouse_pos
		preview_scene_transform_on_rotate_y_placement = preview_scene.global_transform
		return true

func on_confirm(alt_pressed):
	if not spawn_node:
		return false

	if current_placement_mode == GdSpawnPlacementMode.Physics:
		var consume_event = current_placement_mode_manager.on_release()
		return consume_event

	if current_placement_mode == GdSpawnPlacementMode.Curve:
		return false

	if not preview_scene:
		return false


	if current_placement_state == PlacementState.TransformLocalY: 

		var action = GdSpawnAddScenesAction.new()
		action.parent = spawn_node
		action.transforms = [preview_scene.global_transform]
		action.owner = EditorInterface.get_edited_scene_root()
		action.scene = current_selected_item.scene

		if alt_pressed:
			action.select_last = true

		undo_redo.create_action("Place Scene: %s" % current_selected_item.scene.resource_path, 0, self)
		undo_redo.add_do_method(action, "do")
		undo_redo.add_undo_method(action, "undo")
		undo_redo.commit_action()


		current_placement_state = PlacementState.Normal

		return true

	else:
		var action = GdSpawnAddScenesAction.new()
		action.parent = spawn_node
		action.owner = EditorInterface.get_edited_scene_root()
		action.scene = current_selected_item.scene

		if alt_pressed:
			action.select_last = true

		for instanced in painted_instances_transform_history:
			action.transforms.append(instanced.global_transform)
			instanced.queue_free()

		painted_instances_transform_history.clear()

		undo_redo.create_action("Paint: %s" % current_selected_item.scene.resource_path, 0, self)
		undo_redo.add_do_method(action, "do")
		undo_redo.add_undo_method(action, "undo")
		undo_redo.commit_action()

		current_placement_state = PlacementState.Normal

		return true

func on_add_scene_request(action: GdSpawnAddScenesAction):
	action.parent = spawn_node

	undo_redo.create_action("Scenes Added", 0, self)
	undo_redo.add_do_method(action, "do")
	undo_redo.add_undo_method(action, "undo")
	undo_redo.commit_action()

func on_add_path_request(action: GdSpawnAddPathAction):
	action.parent = spawn_node

	undo_redo.create_action("Path Added: %s" % action.path_name, 0, self)
	undo_redo.add_do_method(action, "do")
	undo_redo.add_undo_method(action, "undo")
	undo_redo.commit_action()


func on_cancel():

	if current_placement_mode == GdSpawnPlacementMode.Physics:
		return

	if current_placement_mode == GdSpawnPlacementMode.Curve:
		return

	if current_placement_state != PlacementState.Normal:
		return

	if is_moving_plane and current_placement_mode == GdSpawnPlacementMode.Plane:
		_cancel_move_plane()
		return

	signal_routing.ItemSelect.emit(null)


func _cancel_move_plane():
	is_moving_plane = false
	current_placement_mode_manager.on_move_plane_cancel()
	if current_grid:
		current_grid.hide_line()


func on_rotate(camera: Camera3D, shift_pressed, axis=Vector3.UP):
	if not preview_scene:
		return

	if not current_selected_item:
		return

	var rotation_amount = 90
	if shift_pressed:
		rotation_amount = 45
	
	current_selected_item.item_placement_basis = current_selected_item.item_placement_basis.rotated(axis, deg_to_rad(rotation_amount))
	signal_routing.ItemPlacementBasisSet.emit(current_selected_item)

	var res = current_placement_mode_manager.on_move(camera, last_mouse_pos, current_selected_item, current_snap_info.step, false)
	preview_scene.global_transform = res.object_transform


func on_flip(camera: Camera3D, axis=Vector3.UP):
	if not preview_scene:
		return

	if not current_selected_item:
		return

	var final_scale = axis
	final_scale *= -1

	if is_zero_approx(final_scale.x):
		final_scale.x = 1.0
	if is_zero_approx(final_scale.y):
		final_scale.y = 1.0
	if is_zero_approx(final_scale.z):
		final_scale.z = 1.0
	
	current_selected_item.item_placement_basis = current_selected_item.item_placement_basis.scaled(final_scale)
	signal_routing.ItemPlacementBasisSet.emit(current_selected_item)

	var res = current_placement_mode_manager.on_move(camera, last_mouse_pos, current_selected_item, current_snap_info.step, false)
	preview_scene.global_transform = res.object_transform


func on_grid_offset_value_changed(_value):
	current_snap_info.grid_offset = Vector2(grid_offset_x.value, grid_offset_z.value)

func on_reset_grid_offset():
	grid_offset_x.value = 0.0
	grid_offset_z.value = 0.0

func on_match_selected_offset():
	var selection = EditorInterface.get_selection()
	if selection.get_selected_nodes().size() == 0:
		return
	
	var selected_node = selection.get_selected_nodes()[0]
	if not selected_node is Node3D:
		return

func add_or_update_grid(scene_root):

	if not scene_root:
		return

	if not scene_root is Node3D:
		return

	if scene_root is GdSpawnGrid:
		return
	
	if scene_root.has_node("GdSpawnGrid"):
		current_grid = scene_root.get_node("GdSpawnGrid")
		return

	var grid_instance = grid_scene.instantiate()
	scene_root.add_child(grid_instance)
	grid_instance.name = "GdSpawnGrid"
	current_grid = grid_instance
	current_grid.update_grid_snap(current_snap_info.step)


func update_gizmo_grid_snap():
	if not current_grid:
		return
	current_grid.update_grid_snap(current_snap_info.step)

func show_grid():
	if not current_grid:
		return
	current_grid.show()


func hide_grid():
	if not current_grid:
		return
	current_grid.hide()

func on_grid_transform_changed(transform):
	if not current_grid:
		return
	
	current_grid.update_transform(transform)


func on_move_plane_start():
	if current_placement_mode == GdSpawnPlacementMode.Plane:
		is_moving_plane = true
		current_placement_mode_manager.on_move_plane_start()
		if current_grid:
			current_grid.show_line()