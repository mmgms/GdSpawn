@tool
extends PanelContainer


@export var plane_select: OptionButton


enum GdSpawnPlaneType {XZ, XY, YZ}

var current_plane_type: GdSpawnPlaneType = GdSpawnPlaneType.XZ

var current_plane: Plane

func _ready() -> void:

	current_plane = Plane(Vector3.UP)
	for key in GdSpawnPlaneType.keys():
		plane_select.add_item(key)

	plane_select.item_selected.connect(on_plane_type_selected)


func on_plane_type_selected(idx):
	current_plane_type = idx

func on_move(camera: Camera3D, mouse_pos: Vector2, current_snap_info: GdSpawnSpawnManager.GdSpawnSnapInfo) -> Vector3:
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)


	var intersection_point = current_plane.intersects_ray(ray_origin, ray_direction)


	if intersection_point != null:
		var final_position = intersection_point as Vector3
		if current_snap_info.enabled:
			intersection_point = intersection_point.snapped(Vector3.ONE * current_snap_info.step)
		return intersection_point
	return Vector3()