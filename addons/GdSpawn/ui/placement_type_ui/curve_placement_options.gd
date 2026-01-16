@tool
extends PanelContainer

@export var create_curve_button: Button
@export var curve_name_line_edit: LineEdit

var signal_routing: GdSpawnSignalRouting:
	set(value):
		signal_routing = value
		signal_routing.EditedSceneChanged.connect(on_scene_change)
		return


var current_curve_spawn_settings: GdSpawnCurveSpawnSettings
var current_curve_spawn_profile: GdSpawnCurveSpawnProfile

signal add_path_request(action: GdSpawnSpawnManager.GdSpawnAddPathAction)

func _ready() -> void:
	create_curve_button.pressed.connect(on_create_curve)

func on_create_curve():
	current_curve_spawn_profile = null
	update_spawn_profile(EditorInterface.get_edited_scene_root())

	if curve_name_line_edit.text.is_empty():
		return

	var action = GdSpawnSpawnManager.GdSpawnAddPathAction.new()
	action.path_name = curve_name_line_edit.text
	action.curve_profile = current_curve_spawn_profile
	action.curve_settings = current_curve_spawn_settings
	action.owner = EditorInterface.get_edited_scene_root() 
	add_path_request.emit(action)


func on_enter():
	current_curve_spawn_profile = null
	update_spawn_profile(EditorInterface.get_edited_scene_root())

func on_exit():
	on_cancel()


func should_show_grid():
	return false


func on_move(camera: Camera3D, mouse_pos: Vector2, library_item: GdSpawnSceneLibraryItem, snap_step, snap_enable):
	pass

func on_scene_change(root):
	current_curve_spawn_profile = null
	update_spawn_profile(root)

func on_press():
	pass


func on_release():
	pass



func on_cancel():
	pass



func update_spawn_profile(scene_root):
	if not scene_root:
		return
	if not current_curve_spawn_profile or not current_curve_spawn_settings:
		var matches = scene_root.find_children("*", "GdSpawn", false, true) 
		if matches.size() == 0:
			return
		var gdspawn_node = matches[0] as GdSpawn
		current_curve_spawn_profile = gdspawn_node.curve_spawn_profile
		current_curve_spawn_settings = gdspawn_node.curve_spawn_settings
