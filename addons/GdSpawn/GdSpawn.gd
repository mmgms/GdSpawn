@tool
extends EditorPlugin


var main_dock: GdSpawnMainDockManager

const BASE_SETTING = "GdSpawn/Settings/"



func _enter_tree() -> void:

	main_dock = preload("res://addons/GdSpawn/ui/MainDock.tscn").instantiate() as GdSpawnMainDockManager
	main_dock.editor_plugin = self

	add_control_to_bottom_panel(main_dock, "GdSpawn")
	
	_add_setting("%sPreview Perspective" % BASE_SETTING, GdSpawnSceneLibraryItem.PreviewMode.Default, TYPE_INT, PROPERTY_HINT_ENUM,\
		", ".join(GdSpawnSceneLibraryItem.PreviewMode.keys().slice(0, -1)))


	project_settings_changed.connect(on_project_settings_changed)
	scene_changed.connect(func (root): main_dock.signal_routing.EditedSceneChanged.emit(root))


func _exit_tree() -> void:
	main_dock.signal_routing.PluginDisabled.emit()
	remove_control_from_bottom_panel(main_dock)
	main_dock.free()


func on_project_settings_changed():
	main_dock.signal_routing.ProjectSettingsChanged.emit()

func attach_to_bottom_panel():
	add_control_to_bottom_panel(main_dock, "GdSpawn")

func remove_from_bottom_panel():
	remove_control_from_bottom_panel(main_dock)

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


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:

	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_SPACE and main_dock.signal_routing.current_item_selected == null:
			if main_dock.signal_routing.last_item_selected == null:
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			main_dock.signal_routing.ItemSelect.emit(main_dock.signal_routing.last_item_selected)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if main_dock.signal_routing.current_item_selected == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var ctrl_pressed = false
		if Input.is_key_pressed(KEY_CTRL):
			ctrl_pressed = true

		var shift_pressed = false
		if Input.is_key_pressed(KEY_SHIFT):
			shift_pressed = true
		main_dock.spawn_manager.on_move(viewport_camera, event.position, ctrl_pressed, shift_pressed)
		return EditorPlugin.AFTER_GUI_INPUT_STOP


	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		main_dock.spawn_manager.on_press_start()
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		var alt_pressed = false
		if Input.is_key_pressed(KEY_ALT):
			alt_pressed = true
		main_dock.spawn_manager.on_confirm(alt_pressed)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

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
	