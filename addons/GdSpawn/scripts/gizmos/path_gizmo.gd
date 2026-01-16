extends EditorNode3DGizmoPlugin


func _has_gizmo(node):
	return node is GdSpawnPath3D

func _get_gizmo_name():
	return "GdSpawnPath3DGizmo"


func _init():
	create_material("main", Color(1, 0, 0))
	create_handle_material("handles")


func _redraw(gizmo):
	var path3d = gizmo.get_node_3d() as GdSpawnPath3D

	var curve = path3d.curve as Curve3D

	if not curve:
		return
	gizmo.clear()


	var handles = PackedVector3Array()
	if curve:
		for idx in curve.point_count:
			handles.push_back(path3d.global_transform * curve.get_point_position(idx))

		gizmo.add_handles(handles, null, [])
	else:
		pass




func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, mouse_pos: Vector2):

	var path3d = gizmo.get_node_3d() as GdSpawnPath3D

	var curve = path3d.curve as Curve3D


	if not curve:
		return

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var	ray_dir = camera.project_ray_normal(mouse_pos)
	var space_state = camera.get_world_3d().direct_space_state

	var params = PhysicsRayQueryParameters3D.new()
	params.from = ray_origin
	params.to = ray_origin + ray_dir * 4096
	var result = space_state.intersect_ray(params)

	if not result:
		return

	var local_pos = path3d.global_transform.affine_inverse() * result.position
	if Input.is_key_pressed(KEY_SHIFT):
		return

	curve.set_point_position(handle_id, local_pos)

	
	
