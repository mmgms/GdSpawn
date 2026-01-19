extends EditorNode3DGizmoPlugin


var gizmo_panel: GdSpawnPathEditToolBar

var undo_redo: EditorUndoRedoManager


class GdSpawnPathEditAction:
	var new_curve: Curve3D
	var old_curve: Curve3D
	var path3d: Node3D

	func do():
		if not path3d:
			return
		path3d.curve = new_curve
		path3d.update_gizmos()
		path3d._update()

	func undo():
		if not path3d:
			return
		path3d.curve = old_curve
		path3d.update_gizmos()
		path3d._update()

func _init():

	var handle_icon = EditorIconTexture2D.new()
	handle_icon.icon_name = "EditorPathSmoothHandle"
	var secondary_handle_icon = EditorIconTexture2D.new()
	handle_icon.icon_name = "EditorPathSharpHandle"

	# TODO: Replace hardcoded colors by a setting fetch
	create_material("primary", Color(1, 0.4, 0))
	create_material("secondary", Color(0.4, 0.7, 1.0))
	create_material("tertiary", Color(Color.STEEL_BLUE, 0.2))
	create_custom_material("primary_top", Color(1, 0.4, 0))
	create_custom_material("secondary_top", Color(0.4, 0.7, 1.0))
	create_custom_material("tertiary_top", Color(Color.STEEL_BLUE, 0.1))

	create_material("inclusive", Color(0.9, 0.7, 0.2, 0.15))
	create_material("exclusive", Color(0.9, 0.1, 0.2, 0.15))

	create_handle_material("default_handle")
	create_handle_material("primary_handle", false, handle_icon)
	create_handle_material("secondary_handle", false, secondary_handle_icon)

func create_custom_material(name: String, color := Color.WHITE):
	var material := StandardMaterial3D.new()
	material.set_blend_mode(StandardMaterial3D.BLEND_MODE_ADD)
	material.set_shading_mode(StandardMaterial3D.SHADING_MODE_UNSHADED)
	material.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	material.set_albedo(color)
	material.render_priority = 100

	add_material(name, material)

func _has_gizmo(node):
	return node is GdSpawnPath3D

func _get_gizmo_name():
	return "GdSpawnPath3DGizmo"

func _get_handle_name(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> String:
	return "Path point"

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	var path3d: GdSpawnPath3D = gizmo.get_node_3d()
	return path3d.curve.duplicate()


func _redraw(gizmo):
	gizmo.clear()

	var path3d = gizmo.get_node_3d() as GdSpawnPath3D
	var curve = path3d.curve as Curve3D

	if not curve or curve.get_point_count() == 0:
		return

	# ------ Common stuff ------
	var points := curve.tessellate(4, 8)
	var points_2d := PackedVector2Array()
	for p in points:
		points_2d.push_back(Vector2(p.x, p.z))

	var line_material: StandardMaterial3D = get_material("primary_top", gizmo)
	var mesh_material: StandardMaterial3D = get_material("inclusive", gizmo)

	# ------ Main line along the path curve ------
	var lines := PackedVector3Array()
	var lines_count := points.size() - 1

	for i in lines_count:
		lines.append(points[i])
		lines.append(points[i + 1])

	gizmo.add_lines(lines, line_material)
	gizmo.add_collision_segments(lines)

	# ------ Draw handles ------
	var main_handles := PackedVector3Array()
	var in_out_handles := PackedVector3Array()
	var handle_lines := PackedVector3Array()
	var ids := PackedInt32Array() # Stays empty on purpose

	for i in curve.get_point_count():
		var point_pos = curve.get_point_position(i)
		var point_in = curve.get_point_in(i) + point_pos
		var point_out = curve.get_point_out(i) + point_pos

		handle_lines.push_back(point_pos)
		handle_lines.push_back(point_in)
		handle_lines.push_back(point_pos)
		handle_lines.push_back(point_out)

		in_out_handles.push_back(point_in)
		in_out_handles.push_back(point_out)
		main_handles.push_back(point_pos)

	gizmo.add_handles(main_handles, get_material("primary_handle", gizmo), ids)
	gizmo.add_handles(in_out_handles, get_material("secondary_handle", gizmo), ids, false, true)
	gizmo.add_lines(handle_lines, get_material("secondary_top", gizmo))

	


	var handles = PackedVector3Array()
	if curve:
		for idx in curve.point_count:
			handles.push_back(path3d.global_transform * curve.get_point_position(idx))

		gizmo.add_handles(handles, null, [])
	else:
		pass


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, \
	camera: Camera3D, screen_pos: Vector2):


	if not gizmo_panel.is_select_mode_enabled():
		return


	var path3d = gizmo.get_node_3d() as GdSpawnPath3D

	var curve = path3d.curve as Curve3D


	if not curve:
		return

	var curve_index := handle_id
	var previous_handle_position: Vector3

	if not secondary:
		previous_handle_position = curve.get_point_position(curve_index)
	else:
		curve_index = int(handle_id / 2)
		previous_handle_position = curve.get_point_position(curve_index)
		if handle_id % 2 == 0:
			previous_handle_position += curve.get_point_in(curve_index)
		else:
			previous_handle_position += curve.get_point_out(curve_index)

	var click_world_position := _intersect_with(path3d, camera, screen_pos, previous_handle_position)
	var point_local_position: Vector3 = path3d.get_global_transform().affine_inverse() * click_world_position

	if not secondary:
		# Main curve point moved
		curve.set_point_position(handle_id, point_local_position)
	else:
		# In out handle moved
		var mirror_angle = gizmo_panel.is_mirror_angle_enabled()
		var mirror_length = gizmo_panel.is_mirror_length_enabled()

		var point_origin = curve.get_point_position(curve_index)
		var in_out_position = point_local_position - point_origin
		var mirror_position = -in_out_position

		if handle_id % 2 == 0:
			curve.set_point_in(curve_index, in_out_position)
			if mirror_angle:
				if not mirror_length:
					mirror_position = curve.get_point_out(curve_index).length() * -in_out_position.normalized()
				curve.set_point_out(curve_index, mirror_position)
		else:
			curve.set_point_out(curve_index, in_out_position)
			if mirror_angle:
				if not mirror_length:
					mirror_position = curve.get_point_in(curve_index).length() * -in_out_position.normalized()
				curve.set_point_in(curve_index, mirror_position)

	path3d.update_gizmos()



func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var path3d: Node3D = gizmo.get_node_3d()

	if cancel:
		_edit_path(path3d, restore)
	else:
		undo_redo.create_action("Edit GdSpawn Path")
		undo_redo.add_undo_method(self, "_edit_path", path3d, restore)
		undo_redo.add_do_method(self, "_edit_path", path3d, path3d.curve.duplicate())
		undo_redo.commit_action()

	path3d.update_gizmos()
	path3d._update()

func _edit_path(path3d: Node3D, restore: Curve3D) -> void:
	path3d.curve = restore.duplicate()
	path3d.update_gizmos()
	path3d._update()
	
	
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:

	var path3d = gizmo_panel.path_node as GdSpawnPath3D
	var curve = path3d.curve as Curve3D
	if not curve:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if not event is InputEventMouseButton:
		return EditorPlugin.AFTER_GUI_INPUT_PASS


	if not (event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if gizmo_panel.is_select_mode_enabled():
		return EditorPlugin.AFTER_GUI_INPUT_PASS


	var click_world_position := _intersect_with(path3d, viewport_camera, event.position)
	var point_local_position: Vector3 = path3d.get_global_transform().affine_inverse() * click_world_position

	var action = GdSpawnPathEditAction.new()
	action.old_curve = curve
	action.new_curve = curve.duplicate()
	action.path3d = path3d
	if gizmo_panel.is_create_mode_enabled():
		_add_point_to_curve(action.new_curve, point_local_position)
		undo_redo.create_action("Edit Path: %s" % path3d.name, 0, self)
		undo_redo.add_do_method(action, "do")
		undo_redo.add_undo_method(action, "undo")
		undo_redo.commit_action()

		path3d.update_gizmos()
		path3d._update()
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	elif gizmo_panel.is_delete_mode_enabled():
		_delete_closest_point(action.new_curve, point_local_position)
		undo_redo.create_action("Edit Path: %s" % path3d.name, 0, self)
		undo_redo.add_do_method(action, "do")
		undo_redo.add_undo_method(action, "undo")
		undo_redo.commit_action()

		path3d.update_gizmos()
		path3d._update()
		return EditorPlugin.AFTER_GUI_INPUT_STOP


	return EditorPlugin.AFTER_GUI_INPUT_PASS



func _intersect_with(path: Node3D, camera: Camera3D, screen_point: Vector2, handle_position_local = null) -> Vector3:
	# Get the ray data
	var from = camera.project_ray_origin(screen_point)
	var dir = camera.project_ray_normal(screen_point)
	var gt = path.get_global_transform()

	# Snap to collider enabled
	if gizmo_panel.is_snap_to_colliders_enabled():
		var space_state: PhysicsDirectSpaceState3D = path.get_world_3d().get_direct_space_state()
		var parameters := PhysicsRayQueryParameters3D.new()
		parameters.from = from
		parameters.to = from + (dir * 4096)
		var hit := space_state.intersect_ray(parameters)
		if not hit.is_empty():
			return hit.position

	# Default case (similar to the built in Path3D node)
	var origin: Vector3
	if handle_position_local:
		origin = gt * handle_position_local
	else:
		origin = path.get_global_transform().origin

	var plane = Plane(dir, origin)
	var res = plane.intersects_ray(from, dir)
	if res != null:
		return res

	return origin

func _add_point_to_curve(curve: Curve3D, pos: Vector3) -> void:
	var count := curve.get_point_count()

	# 0–1 points → just append
	if count < 2:
		curve.add_point(pos)
		return

	var segment_index := _get_closest_segment_index(curve, pos)

	var a := curve.get_point_position(segment_index)
	var b := curve.get_point_position((segment_index + 1) % count)
	var segment_distance := _distance_point_to_segment(pos, a, b)

	const SEGMENT_INSERT_DISTANCE := 1.0

	# Close enough → insert into segment
	if segment_distance <= SEGMENT_INSERT_DISTANCE:
		curve.add_point(pos, Vector3.ZERO, Vector3.ZERO, segment_index + 1)
		return

	# Not close to a segment
	if not curve.closed:
		var start_pos := curve.get_point_position(0)
		var end_pos := curve.get_point_position(count - 1)

		if pos.distance_to(start_pos) < pos.distance_to(end_pos):
			curve.add_point(pos, Vector3.ZERO, Vector3.ZERO, 0)
		else:
			curve.add_point(pos)
	else:
		# Closed curve → always insert into closest segment
		curve.add_point(pos, Vector3.ZERO, Vector3.ZERO, segment_index + 1)




func _delete_closest_point(curve: Curve3D, pos: Vector3) -> void:
	var count := curve.get_point_count()
	if count == 0:
		return

	var closest_idx := -1
	var closest_dist := INF

	for i in count:
		var d := curve.get_point_position(i).distance_to(pos)
		if d < closest_dist:
			closest_dist = d
			closest_idx = i

	# Optional safety: don’t delete if click is too far away
	const DELETE_DISTANCE := 0.5
	if closest_idx != -1 and closest_dist <= DELETE_DISTANCE:
		curve.remove_point(closest_idx)


func _get_closest_segment_index(curve: Curve3D, pos: Vector3) -> int:
	var count := curve.get_point_count()
	var closest_segment := 0
	var closest_dist := INF

	var segment_count := count
	if not curve.closed:
		segment_count = count - 1

	for i in segment_count:
		var a := curve.get_point_position(i)
		var b := curve.get_point_position((i + 1) % count)

		var d := _distance_point_to_segment(pos, a, b)
		if d < closest_dist:
			closest_dist = d
			closest_segment = i

	return closest_segment



func _distance_point_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clamp((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest = a + ab * t
	return p.distance_to(closest)