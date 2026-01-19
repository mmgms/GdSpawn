@tool
extends EditorPlugin


var main_dock: GdSpawnMainDockManager

var layers_dock: GdSpawnLayersDock

var path_edit_panel: GdSpawnPathEditToolBar

const BASE_SETTING = "GdSpawn/Settings/"

const GdSpawnPath3DGizmo = preload("res://addons/GdSpawn/scripts/gizmos/path_gizmo.gd")

var gizmo_plugin = null

var last_object = null

func _enter_tree() -> void:

	#ui
	main_dock = preload("res://addons/GdSpawn/ui/MainDock.tscn").instantiate() as GdSpawnMainDockManager
	main_dock.editor_plugin = self


	layers_dock = preload("res://addons/GdSpawn/ui/LayersDock.tscn").instantiate() as GdSpawnLayersDock
	layers_dock.signal_routing = main_dock.signal_routing

	path_edit_panel = preload("res://addons/GdSpawn/ui/EditPathToolBar.tscn").instantiate() as GdSpawnPathEditToolBar


	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, path_edit_panel)
	path_edit_panel.visible = false


	add_control_to_bottom_panel(main_dock, "GdSpawn")
	add_control_to_dock(DOCK_SLOT_LEFT_BR, layers_dock)

	#custom types
	add_custom_type("GdSpawnLayer", "Node3D", preload("res://addons/GdSpawn/scripts/custom_nodes/layer.gd"), preload("res://addons/GdSpawn/icons/GdSpawnLayer.svg"))


	#gizmos
	gizmo_plugin = GdSpawnPath3DGizmo.new()
	add_node_3d_gizmo_plugin(gizmo_plugin)
	gizmo_plugin.gizmo_panel = path_edit_panel
	gizmo_plugin.undo_redo = get_undo_redo()

	#settings
	add_all_settings()

	update_from_settings()

	#signals
	project_settings_changed.connect(on_project_settings_changed)
	scene_changed.connect(func (root): main_dock.signal_routing.EditedSceneChanged.emit(root))
	scene_saved.connect(func (file): main_dock.signal_routing.SceneSaved.emit(file))
	EditorInterface.get_selection().selection_changed.connect(on_selection_change)
	on_selection_change()
	

func _exit_tree() -> void:
	#emit signals
	main_dock.signal_routing.PluginDisabled.emit()

	#remove gizmo
	if gizmo_plugin:
		remove_node_3d_gizmo_plugin(gizmo_plugin)
		gizmo_plugin = null

	#remove ui
	remove_control_from_bottom_panel(main_dock)
	remove_control_from_docks(layers_dock)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, path_edit_panel)

	#free ui
	layers_dock.free()
	main_dock.free()
	path_edit_panel.free()

	#remove custom type
	remove_custom_type("GdSpawnLayer")

var reset_transformation: InputEvent
var select_prev_asset: InputEvent
var place_and_select: InputEvent
var toggle_snapping: InputEvent
var displace_plane: InputEvent

var rotate_90x: InputEvent
var rotate_90y: InputEvent
var rotate_90z: InputEvent

var flipx: InputEvent
var flipy: InputEvent
var flipz: InputEvent

var select_xy: InputEvent
var select_xz: InputEvent
var select_yz: InputEvent

var show_tooltips = true


func on_selection_change():
	var selected = EditorInterface.get_selection().get_selected_nodes()
	path_edit_panel.selection_changed(selected)

func on_project_settings_changed():
	main_dock.signal_routing.ProjectSettingsChanged.emit()
	update_from_settings()

func update_from_settings():
	show_tooltips = ProjectSettings.get_setting(GdSpawnConstants.SHOW_TOOLTIPS)
	reset_transformation = ProjectSettings.get_setting(GdSpawnConstants.RESET_TRANSFORMATION)
	select_prev_asset = ProjectSettings.get_setting(GdSpawnConstants.SELECT_PREVIOUS_ASSET)
	place_and_select = ProjectSettings.get_setting(GdSpawnConstants.PLACE_AND_SELECT)
	toggle_snapping = ProjectSettings.get_setting(GdSpawnConstants.TOGGLE_SNAPPING)
	displace_plane = ProjectSettings.get_setting(GdSpawnConstants.DISPLACE_PLANE)

	rotate_90x = ProjectSettings.get_setting(GdSpawnConstants.ROTATE_90_X)
	rotate_90y = ProjectSettings.get_setting(GdSpawnConstants.ROTATE_90_Y)
	rotate_90z = ProjectSettings.get_setting(GdSpawnConstants.ROTATE_90_Z)

	flipx = ProjectSettings.get_setting(GdSpawnConstants.FLIP_X)
	flipy = ProjectSettings.get_setting(GdSpawnConstants.FLIP_Y)
	flipz = ProjectSettings.get_setting(GdSpawnConstants.FLIP_Z)

	select_xy = ProjectSettings.get_setting(GdSpawnConstants.SELECT_XY_PLANE)
	select_xz = ProjectSettings.get_setting(GdSpawnConstants.SELECT_XZ_PLANE)
	select_yz = ProjectSettings.get_setting(GdSpawnConstants.SELECT_YZ_PLANE)

	

func add_all_settings():
	#settings
	_add_setting(GdSpawnConstants.PREVIEW_PERSPECTIVE, GdSpawnSceneLibraryItem.PreviewMode.Default, TYPE_INT, PROPERTY_HINT_ENUM,\
		", ".join(GdSpawnSceneLibraryItem.PreviewMode.keys().slice(0, -1)))

	_add_setting(GdSpawnConstants.PREVIEW_ANGLE_HORIZONTAL, 70, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,360,1")
	
	_add_setting(GdSpawnConstants.PREVIEW_ANGLE_VERTICAL, 20, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,360,1")

	_add_setting(GdSpawnConstants.SHIFT_ROTATION_STEP, 45, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,360,1")

	_add_setting(GdSpawnConstants.SHOW_TOOLTIPS, true, TYPE_BOOL)

	#shortcuts
	var reset_transform_event := InputEventKey.new()
	reset_transform_event.keycode = KEY_E
	reset_transform_event.shift_pressed = true
	_add_setting(GdSpawnConstants.RESET_TRANSFORMATION, reset_transform_event, TYPE_OBJECT)

	var prev_asset := InputEventKey.new()
	prev_asset.keycode = KEY_SPACE
	_add_setting(GdSpawnConstants.SELECT_PREVIOUS_ASSET, prev_asset, TYPE_OBJECT)
	
	var place_and_select := InputEventKey.new()
	place_and_select.keycode = KEY_ALT
	_add_setting(GdSpawnConstants.PLACE_AND_SELECT, place_and_select, TYPE_OBJECT)

	var toggle_snapping := InputEventKey.new()
	toggle_snapping.keycode = KEY_CTRL
	_add_setting(GdSpawnConstants.TOGGLE_SNAPPING, toggle_snapping, TYPE_OBJECT)

	var displace_plane := InputEventKey.new()
	displace_plane.keycode = KEY_G
	_add_setting(GdSpawnConstants.DISPLACE_PLANE, displace_plane, TYPE_OBJECT)

	var rotate_90x := InputEventKey.new()
	rotate_90x.keycode = KEY_A
	_add_setting(GdSpawnConstants.ROTATE_90_X, rotate_90x, TYPE_OBJECT)

	var rotate_90y := InputEventKey.new()
	rotate_90y.keycode = KEY_S
	_add_setting(GdSpawnConstants.ROTATE_90_Y, rotate_90y, TYPE_OBJECT)

	var rotate_90z := InputEventKey.new()
	rotate_90z.keycode = KEY_D
	_add_setting(GdSpawnConstants.ROTATE_90_Z, rotate_90z, TYPE_OBJECT)

	var flipx := InputEventKey.new()
	flipx.keycode = KEY_1
	_add_setting(GdSpawnConstants.FLIP_X, flipx, TYPE_OBJECT)

	var flipy := InputEventKey.new()
	flipy.keycode = KEY_2
	_add_setting(GdSpawnConstants.FLIP_Y, flipy, TYPE_OBJECT)
	
	var flipz := InputEventKey.new()
	flipz.keycode = KEY_3
	_add_setting(GdSpawnConstants.FLIP_Z, flipz, TYPE_OBJECT)


	var select_yz := InputEventKey.new()
	select_yz.keycode = KEY_Z
	_add_setting(GdSpawnConstants.SELECT_YZ_PLANE, select_yz, TYPE_OBJECT)

	var select_xz := InputEventKey.new()
	select_xz.keycode = KEY_X
	_add_setting(GdSpawnConstants.SELECT_XZ_PLANE, select_xz, TYPE_OBJECT)
	
	var select_xy := InputEventKey.new()
	select_xy.keycode = KEY_C
	_add_setting(GdSpawnConstants.SELECT_XY_PLANE, select_xy, TYPE_OBJECT)


func _add_setting(property_name: String, default: Variant, type = -1, hint = -1, hint_string = ""):
	
	if not ProjectSettings.has_setting(property_name):
		ProjectSettings.set_setting(property_name, default)

	if default is InputEvent:
		var old = ProjectSettings.get_setting(property_name)
		if not old.is_match(default):
			ProjectSettings.set_initial_value(property_name, default)
	else:
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



func attach_to_bottom_panel():
	add_control_to_bottom_panel(main_dock, "GdSpawn")

func remove_from_bottom_panel():
	remove_control_from_bottom_panel(main_dock)



func get_enum_hint_string(enum_dict):
	return ", ".join(enum_dict.keys())

func _forward_3d_draw_over_viewport(viewport_control: Control) -> void:
	if not show_tooltips:
		return

	var tooltips = main_dock.spawn_manager.get_tooltips()
	if tooltips.is_empty():
		return

	var text = ""
	for tooltip in tooltips:
		match tooltip:
			GdSpawnSpawnManager.Tooltip.ClickToPlace:
				text += "Click To Place\n"
				pass
			GdSpawnSpawnManager.Tooltip.TransformTooltip:
				text += "%s/%s/%s to rotate x/y/z\n" % [rotate_90x.as_text(), rotate_90y.as_text(), rotate_90z.as_text()]
				pass
			GdSpawnSpawnManager.Tooltip.ResetTransfom:
				text += "%s to reset transform\n" % [reset_transformation.as_text()]
				pass
			GdSpawnSpawnManager.Tooltip.DragToPaint:
				text += "Drag to Paint\n"
				pass
			GdSpawnSpawnManager.Tooltip.DragToRotateY:
				text += "Drag to rotate Y\n"
				pass
			GdSpawnSpawnManager.Tooltip.DragToPhysicsSpawn:
				text += "Drag to Physics Spawn\n"
				pass
			GdSpawnSpawnManager.Tooltip.EscToDeselect:
				text += "Esc to Deselect\n"
				pass
			GdSpawnSpawnManager.Tooltip.EscToCancelMovePlane:
				text += "Esc to Cancel Move Plane\n"
				pass
			GdSpawnSpawnManager.Tooltip.ClickToConfirmMovePlane:
				text += "Click to Confirm Move Plane\n"
				pass

	var font: Font = viewport_control.get_theme_default_font()
	var font_size: int = viewport_control.get_theme_default_font_size()
	var mouse_pos: Vector2 = viewport_control.get_local_mouse_position()

	viewport_control.draw_multiline_string(font, mouse_pos, text, 0, -1, font_size)
	


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if last_object is GdSpawnPath3D:
		return gizmo_plugin.forward_3d_gui_input(viewport_camera, event)

	if event.is_match(select_prev_asset) and main_dock.signal_routing.current_item_selected == null:
		if main_dock.signal_routing.last_item_selected == null:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		var should_stop = main_dock.spawn_manager.try_to_select_prev_scene(main_dock.signal_routing.last_item_selected)
		if should_stop:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS


	if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var ctrl_pressed = false
		if Input.is_key_pressed(toggle_snapping.keycode):
			ctrl_pressed = true

		var shift_pressed = false
		if Input.is_key_pressed(KEY_SHIFT):
			shift_pressed = true
		update_overlays()
		var should_stop = main_dock.spawn_manager.on_move(viewport_camera, event.position, ctrl_pressed, shift_pressed)
		if should_stop:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS


	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var should_stop = main_dock.spawn_manager.on_press_start()
		if should_stop:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		var alt_pressed = false
		if Input.is_key_pressed(KEY_ALT):
			alt_pressed = true
		var should_stop = main_dock.spawn_manager.on_confirm(alt_pressed)
		if should_stop:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	if main_dock.signal_routing.current_item_selected == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ESCAPE:# deselect
			main_dock.spawn_manager.on_cancel()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event.is_match(rotate_90y) and event.is_pressed():
		local_axis_rotation(viewport_camera, Vector3.UP)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event.is_match(rotate_90x) and event.is_pressed():
		local_axis_rotation(viewport_camera, Vector3.RIGHT)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event.is_match(rotate_90z) and event.is_pressed():
		local_axis_rotation(viewport_camera, Vector3.FORWARD)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event.is_match(select_xy) and event.is_pressed():
		var should_stop = main_dock.spawn_manager.try_to_select_plane(GdSpawnConstants.SELECT_XY_PLANE)
		if should_stop:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	
	if event.is_match(select_xz) and event.is_pressed():
		var should_stop = main_dock.spawn_manager.try_to_select_plane(GdSpawnConstants.SELECT_XZ_PLANE)
		if should_stop:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	
	if event.is_match(select_yz) and event.is_pressed():
		var should_stop = main_dock.spawn_manager.try_to_select_plane(GdSpawnConstants.SELECT_YZ_PLANE)
		if should_stop:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		
	if event.is_match(flipx) and event.is_pressed():
		local_axis_flip(viewport_camera, Vector3.RIGHT)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event.is_match(flipy) and event.is_pressed():
		local_axis_flip(viewport_camera, Vector3.UP)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event.is_match(flipz) and event.is_pressed():
		local_axis_flip(viewport_camera, Vector3.BACK)
		return EditorPlugin.AFTER_GUI_INPUT_STOP


	if event.is_match(displace_plane) and event.is_pressed():
		var should_stop = main_dock.spawn_manager.on_move_plane_start()
		if should_stop:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS


	if event.is_match(reset_transformation) and event.is_pressed():
		if main_dock.signal_routing.current_item_selected:
			main_dock.signal_routing.current_item_selected.item_placement_basis = Basis.IDENTITY
			main_dock.signal_routing.ItemPlacementBasisSet.emit(main_dock.signal_routing.current_item_selected)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS


	return EditorPlugin.AFTER_GUI_INPUT_PASS

func local_axis_rotation(camera, axis):
	var shift_pressed = false
	if Input.is_key_pressed(KEY_SHIFT):
		shift_pressed = true
	main_dock.spawn_manager.on_rotate(camera, shift_pressed, axis)

func local_axis_flip(camera, axis):
	main_dock.spawn_manager.on_flip(camera, axis)



func _handles(object):
	last_object = object
	return object is Node3D
	


