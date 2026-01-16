@tool
extends EditorPlugin


var main_dock: GdSpawnMainDockManager

var layers_dock: GdSpawnLayersDock

const BASE_SETTING = "GdSpawn/Settings/"

const GdSpawnPath3DGizmo = preload("res://addons/GdSpawn/scripts/gizmos/path_gizmo.gd")

var gizmo_plugin = GdSpawnPath3DGizmo.new()

func _enter_tree() -> void:

	#add_node_3d_gizmo_plugin(gizmo_plugin)

	main_dock = preload("res://addons/GdSpawn/ui/MainDock.tscn").instantiate() as GdSpawnMainDockManager
	main_dock.editor_plugin = self


	layers_dock = preload("res://addons/GdSpawn/ui/LayersDock.tscn").instantiate() as GdSpawnLayersDock
	layers_dock.signal_routing = main_dock.signal_routing

	add_control_to_bottom_panel(main_dock, "GdSpawn")
	add_control_to_dock(DOCK_SLOT_LEFT_BR, layers_dock)

	add_custom_type("GdSpawnLayer", "Node3D", preload("res://addons/GdSpawn/scripts/custom_nodes/layer.gd"), preload("res://addons/GdSpawn/icons/GdSpawnLayer.svg"))


	project_settings_changed.connect(on_project_settings_changed)
	scene_changed.connect(func (root): main_dock.signal_routing.EditedSceneChanged.emit(root))
	scene_saved.connect(func (file): main_dock.signal_routing.SceneSaved.emit(file))

	add_all_settings()
	

func _exit_tree() -> void:

	#remove_node_3d_gizmo_plugin(gizmo_plugin)

	main_dock.signal_routing.PluginDisabled.emit()
	remove_control_from_bottom_panel(main_dock)
	remove_control_from_docks(layers_dock)
	layers_dock.free()
	main_dock.free()

	remove_custom_type("GdSpawnLayer")


func on_project_settings_changed():
	main_dock.signal_routing.ProjectSettingsChanged.emit()

func add_all_settings():
	#settings
	_add_setting(GdSpawnConstants.PREVIEW_PERSPECTIVE, GdSpawnSceneLibraryItem.PreviewMode.Default, TYPE_INT, PROPERTY_HINT_ENUM,\
		", ".join(GdSpawnSceneLibraryItem.PreviewMode.keys().slice(0, -1)))

	_add_setting(GdSpawnConstants.PREVIEW_ANGLE_HORIZONTAL, 20, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,360,1")
	
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



func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:

	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_SPACE and main_dock.signal_routing.current_item_selected == null:
			if main_dock.signal_routing.last_item_selected == null:
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			main_dock.signal_routing.ItemSelect.emit(main_dock.signal_routing.last_item_selected)
			return EditorPlugin.AFTER_GUI_INPUT_STOP


	if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var ctrl_pressed = false
		if Input.is_key_pressed(KEY_CTRL):
			ctrl_pressed = true

		var shift_pressed = false
		if Input.is_key_pressed(KEY_SHIFT):
			shift_pressed = true
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

		elif event.keycode == KEY_S:# rotate y
			local_axis_rotation(viewport_camera, Vector3.UP)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif event.keycode == KEY_A:# rotate x
			local_axis_rotation(viewport_camera, Vector3.RIGHT)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif event.keycode == KEY_D:# rotate z
			local_axis_rotation(viewport_camera, Vector3.FORWARD)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

		
		elif event.keycode == KEY_1:
			local_axis_flip(viewport_camera, Vector3.RIGHT)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif event.keycode == KEY_2:
			local_axis_flip(viewport_camera, Vector3.UP)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif event.keycode == KEY_3:
			local_axis_flip(viewport_camera, Vector3.BACK)
			return EditorPlugin.AFTER_GUI_INPUT_STOP


		elif event.keycode == KEY_G:
			main_dock.spawn_manager.on_move_plane_start()
			return EditorPlugin.AFTER_GUI_INPUT_STOP


		elif event.keycode == KEY_E:
			if Input.is_key_pressed(KEY_SHIFT):
				if main_dock.signal_routing.current_item_selected:
					main_dock.signal_routing.current_item_selected.item_placement_basis = Basis.IDENTITY
					main_dock.signal_routing.ItemPlacementBasisSet.emit(main_dock.signal_routing.current_item_selected)
					return EditorPlugin.AFTER_GUI_INPUT_STOP


	return EditorPlugin.AFTER_GUI_INPUT_PASS

func local_axis_rotation(camera, axis):
	var shift_pressed = false
	if Input.is_key_pressed(KEY_SHIFT):
		shift_pressed = true
	main_dock.spawn_manager.on_rotate(camera, shift_pressed, axis)

func local_axis_flip(camera, axis):
	main_dock.spawn_manager.on_flip(camera, axis)



func _handles(object):
	return object is Node3D
	


