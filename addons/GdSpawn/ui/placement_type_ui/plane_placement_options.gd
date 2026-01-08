@tool
extends PanelContainer


@export var plane_select: OptionButton

@export var position_along_normal_spin_box: SpinBox
@export var reset_position_along_normal: Button
@export var match_selected_posiiton_along_normal: Button


enum GdSpawnPlaneType {XZ, XY, YZ}

var current_plane_type: GdSpawnPlaneType = GdSpawnPlaneType.XZ

var current_plane: Plane

var current_position_along_normal: float = 0.0
var current_normal: Vector3 = Vector3.UP

var default_transform: Transform3D

func _ready() -> void:

	default_transform = Transform3D()

	current_plane = Plane(Vector3.UP)
	for key in GdSpawnPlaneType.keys():
		plane_select.add_item(key)

	plane_select.item_selected.connect(on_plane_type_selected)
	reset_position_along_normal.pressed.connect(func(): position_along_normal_spin_box.value = 0.0)
	match_selected_posiiton_along_normal.pressed.connect(on_match_selected_position_along_normal)

	position_along_normal_spin_box.value_changed.connect(on_position_along_normal_changed)

func on_match_selected_position_along_normal():
	var selection = EditorInterface.get_selection()
	if selection.get_selected_nodes().size() == 0:
		return

	var selected_node = selection.get_selected_nodes()[0]
	if not selected_node is Node3D:
		return

	position_along_normal_spin_box.value = current_plane.distance_to(selected_node.global_position)
	



func on_position_along_normal_changed(value):
	current_position_along_normal = value
	current_plane = Plane(current_normal, Vector3.ZERO + current_normal * current_position_along_normal)



func on_plane_type_selected(idx):
	current_plane_type = idx
	match current_plane_type:
		GdSpawnPlaneType.XZ:
			current_normal = Vector3.UP
		GdSpawnPlaneType.XY:
			current_normal = Vector3.BACK
		GdSpawnPlaneType.YZ:
			current_normal = Vector3.RIGHT

	current_plane = Plane(current_normal, Vector3.ZERO + current_normal * current_position_along_normal)

func on_move(camera: Camera3D, mouse_pos: Vector2, current_snap_info: GdSpawnSpawnManager.GdSpawnSnapInfo) -> Transform3D:
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)


	var intersection_point = current_plane.intersects_ray(ray_origin, ray_direction)

	var new_transform = default_transform

	if intersection_point != null:
		var final_position = intersection_point as Vector3
		if current_snap_info.enabled:
			intersection_point = intersection_point.snapped(Vector3.ONE * current_snap_info.step)
		new_transform.origin = intersection_point
		return new_transform
	return new_transform

func on_rotate_y(shift_pressed):
	var deg_to_rotate = 90
	if shift_pressed:
		deg_to_rotate = 45
	default_transform = default_transform.rotated_local(Vector3.UP, deg_to_rad(deg_to_rotate))