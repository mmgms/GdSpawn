@tool
extends PanelContainer

@export var drop_radius_spinbox: SpinBox
@export var drop_height_spinbox: SpinBox
@export var drop_interval_spinbox: SpinBox
@export var randomize_rotation_button: CheckBox
@export var out_of_bound_y_spinbox: SpinBox

@export var random_spawn_profile_parent: Control

@export var drop_gizmo_scene: PackedScene

@export var stop_sim_button: Button

@export var random_spawn_profile: GdSpawnRandomSpawnProfile


var signal_routing: GdSpawnSignalRouting:
	set(value):
		signal_routing = value
		signal_routing.EditedSceneChanged.connect(update_gizmo)
		signal_routing.PluginDisabled.connect(func(): if current_drop_gizmo: current_drop_gizmo.queue_free())

var current_drop_gizmo: GdSpawnDropCircle

func _ready() -> void:
	var props = get_property_list()
	var prop_to_edit
	for prop in props:
		if prop.name == "random_spawn_profile":
			prop_to_edit = prop
			break

	var editor_property = EditorInspector.instantiate_property_editor(self, \
		prop_to_edit.type, "random_spawn_profile", prop_to_edit.hint, prop_to_edit.hint_string, prop_to_edit.usage)
	random_spawn_profile_parent.add_child(editor_property)

	drop_height_spinbox.value_changed.connect(func(_x): update_gizmo_props())
	drop_radius_spinbox.value_changed.connect(func(_x): update_gizmo_props())
	update_gizmo(EditorInterface.get_edited_scene_root())
	current_drop_gizmo.hide_drop_circle()

	stop_sim_button.pressed.connect(on_stop_sim_button)

func on_enter():
	current_drop_gizmo.show_drop_circle(drop_radius_spinbox.value, drop_height_spinbox.value)


func on_exit():
	current_drop_gizmo.hide_drop_circle()


func on_stop_sim_button():
	pass


func update_gizmo(scene_root):
	if not scene_root:
		return
	if scene_root.has_node("GdSpawnDropCircle"):
		current_drop_gizmo = scene_root.get_node("GdSpawnDropCircle")
		return
	if current_drop_gizmo == null:
		current_drop_gizmo = drop_gizmo_scene.instantiate()
		scene_root.add_child(current_drop_gizmo)


func update_gizmo_props():
	current_drop_gizmo.update(drop_radius_spinbox.value, drop_height_spinbox.value)

func should_show_grid():
	return false


func on_move(camera: Camera3D, mouse_pos: Vector2, library_item: GdSpawnSceneLibraryItem, snap_step, snap_enable):
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var	ray_dir = camera.project_ray_normal(mouse_pos)
	var space_state = camera.get_world_3d().direct_space_state

	var params = PhysicsRayQueryParameters3D.new()
	params.from = ray_origin
	params.to = ray_origin + ray_dir * 4096
	var result = space_state.intersect_ray(params)

	if result.is_empty():
		return

	current_drop_gizmo.move_to(result.position)


func on_press():
	if not random_spawn_profile:
		return
	return {}


func on_release():
	return {}