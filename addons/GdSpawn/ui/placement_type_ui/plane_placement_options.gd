@tool
extends PanelContainer


@export var plane_select: OptionButton

@export var revert_offset_button: Button
@export var match_offset_button: Button
@export var x_offset_spinbox: SpinBox
@export var y_offset_spinbox: SpinBox
@export var z_offset_spinbox: SpinBox

@export var revert_rotation_button: Button
@export var match_rotation_button: Button
@export var rotation_spin_box: SpinBox


enum GdSpawnPlaneType {XZ, XY, YZ}

var current_plane_type: GdSpawnPlaneType = GdSpawnPlaneType.XZ


var current_grid_transform: Transform3D

var current_object_transform: Transform3D

var signal_routing: GdSpawnSignalRouting


func _ready() -> void:


	plane_select.clear()
	for key in GdSpawnPlaneType.keys():
		plane_select.add_item(key)

	plane_select.item_selected.connect(on_plane_type_selected)
	
	revert_rotation_button.pressed.connect(on_revert_rotation)
	match_rotation_button.pressed.connect(on_match_selected_rotation)
	rotation_spin_box.value_changed.connect(on_grid_rotation_changed)

	revert_offset_button.pressed.connect(on_revert_offset)
	match_offset_button.pressed.connect(on_match_selected_offset)
	x_offset_spinbox.value_changed.connect(on_local_grid_offset_changed)
	y_offset_spinbox.value_changed.connect(on_local_grid_offset_changed)
	z_offset_spinbox.value_changed.connect(on_local_grid_offset_changed)

func on_revert_rotation():
	rotation_spin_box.value = 0.0
	on_grid_rotation_changed(0.0)

func on_revert_offset():
	x_offset_spinbox.value = 0.0
	y_offset_spinbox.value = 0.0
	z_offset_spinbox.value = 0.0
	on_local_grid_offset_changed(null)

func on_local_grid_offset_changed(_x):
	current_grid_transform.origin.x = x_offset_spinbox.value
	current_grid_transform.origin.y = y_offset_spinbox.value
	current_grid_transform.origin.z = z_offset_spinbox.value

	signal_routing.GridTrasformChanged.emit(get_plane_transform())

func on_grid_rotation_changed(value):
	current_grid_transform.basis = Basis().rotated(Vector3.UP, deg_to_rad(value))
	signal_routing.GridTrasformChanged.emit(get_plane_transform())



func get_plane_transform() -> Transform3D:
	var basis := current_grid_transform.basis
	var origin := current_grid_transform.origin

	var plane_basis: Basis

	match current_plane_type:
		GdSpawnPlaneType.XZ:
			# Plane normal = Y
			plane_basis = Basis(
				basis.x,   # X axis
				basis.y,   # normal
				basis.z    # Z axis
			)

		GdSpawnPlaneType.XY:
			# Plane normal = Z
			plane_basis = Basis(
				basis.x,
				basis.z,   # normal
				-basis.y
			)

		GdSpawnPlaneType.YZ:
			# Plane normal = X
			plane_basis = Basis(
				basis.y,   # normal
				-basis.x,
				basis.z
			)

	return Transform3D(plane_basis.orthonormalized(), origin)

func get_selected_node():
	var selection = EditorInterface.get_selection()
	if selection.get_selected_nodes().size() == 0:
		return null

	var selected_node = selection.get_selected_nodes()[0]
	if not selected_node is Node3D:
		return null

	return selected_node

func on_match_selected_offset():
	var selected = get_selected_node()
	if not selected:
		return

	x_offset_spinbox.value = selected.global_position.x
	y_offset_spinbox.value = selected.global_position.y
	z_offset_spinbox.value = selected.global_position.z
	on_local_grid_offset_changed(null)
	
	
func on_match_selected_rotation():
	var selected = get_selected_node() as Node3D
	if not selected:
		return

	rotation_spin_box.value = selected.global_rotation_degrees.y
	on_grid_rotation_changed(rotation_spin_box.value)

	

func on_plane_type_selected(idx):
	current_plane_type = idx

	signal_routing.GridTrasformChanged.emit(get_plane_transform())

func on_move(camera: Camera3D, mouse_pos: Vector2, current_snap_info: GdSpawnSpawnManager.GdSpawnSnapInfo, library_item: GdSpawnSceneLibraryItem):
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	var current_plane = make_plane_from_transform(current_grid_transform, current_plane_type)
	var plane_transform = get_plane_transform()


	var res = {}
	var local_object_transform = Transform3D()
	local_object_transform.basis = library_item.item_placement_basis

	var intersection_point = current_plane.intersects_ray(ray_origin, ray_direction)
	if intersection_point == null:
		res["object_transform"] = local_object_transform
		res["grid_offset"] = Vector3.ZERO
		return res

	var local_hit = current_grid_transform.affine_inverse() * intersection_point

	var snapped_hit = local_hit.snapped(Vector3.ONE * current_snap_info.step)
	if current_snap_info.enabled:
		local_hit = snapped_hit

	var local_hit_transform = Transform3D(Basis.IDENTITY, local_hit)


	res["object_transform"] = current_grid_transform * local_hit_transform * local_object_transform
	res["grid_offset"] = plane_transform.inverse() * snapped_hit


	return res



func make_plane_from_transform(transform: Transform3D, plane_type: GdSpawnPlaneType) -> Plane:
	var normal: Vector3

	match plane_type:
		GdSpawnPlaneType.XZ:
			normal = transform.basis.y
		GdSpawnPlaneType.XY:
			normal = transform.basis.z
		GdSpawnPlaneType.YZ:
			normal = transform.basis.x

	return Plane(normal.normalized(), transform.origin)

