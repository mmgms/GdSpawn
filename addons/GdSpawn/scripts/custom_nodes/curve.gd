@tool
@icon("res://addons/GdSpawn/icons/GdSpawnPath3D.svg")
extends Node3D
class_name GdSpawnPath3D

@export_flags_3d_physics var collision_mask: int = GdSpawnConstants.DEFAULT_COLLISION_MASK

@export var curve_spawn_profile: GdSpawnCurveSpawnProfile:
	set(value):
		curve_spawn_profile = value
		_update()

@export var curve_spawn_settings: GdSpawnCurveSpawnSettings:
	set(value):
		curve_spawn_settings = value
		_update()

@export_tool_button("Update", "Callable") var action = _update

@export var curve: Curve3D


func _update():
	for child in get_children():
		child.queue_free()

	if not curve or not curve_spawn_profile or not curve_spawn_settings:
		return

	if curve_spawn_profile.elements.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	var res = _get_scenes_and_weights()
	if res == null:
		return

	var curve_length := curve.get_baked_length()
	if is_zero_approx(curve_length):
		return

	var weights = res.weights
	var scenes = res.scenes
	var elements = res.elements as Array[GdSpawnCurveSpawnProfileElement]

	var scene_to_aabb := {}
	var offset_along_curve := 0.0

	var space_state := get_world_3d().direct_space_state

	while offset_along_curve < curve_length:
		var scene_idx := rng.rand_weighted(weights)
		var element = elements[scene_idx]
		var sampled_scene = scenes[scene_idx]

		var instance = sampled_scene.instantiate()
		add_child(instance, true)
		instance.owner = EditorInterface.get_edited_scene_root()

		var scene_aabb: AABB
		if scene_to_aabb.has(sampled_scene):
			scene_aabb = scene_to_aabb[sampled_scene]
		else:
			scene_aabb = GdSpawnUtilities.calculate_spatial_bounds(instance)
			if is_zero_approx(scene_aabb.get_shortest_axis_size()):
				scene_aabb = AABB(Vector3.ZERO, Vector3.ONE)
			scene_to_aabb[sampled_scene] = scene_aabb

		var curve_xform := curve.sample_baked_with_rotation(offset_along_curve)

		var up_axis := element.get_up_axis()
		var forward_axis := element.get_forward_axis()

		var reorient := Transform3D().looking_at(forward_axis, up_axis)

		var final_transform := global_transform * curve_xform * reorient

		# ----------------------------
		# PROJECTION TO COLLIDERS
		# ----------------------------
		if element.projection_mode == GdSpawnCurveSpawnProfileElement.ProjectionMode.PROJECT_TO_COLLIDERS:
			var ray_origin := final_transform.origin
			var ray_dir = -(final_transform.basis * up_axis)
			var ray_length = 4096

			var query := PhysicsRayQueryParameters3D.create(
				ray_origin,
				ray_origin + ray_dir * ray_length,
				collision_mask
			)

			var hit := space_state.intersect_ray(query)
			if hit:
				final_transform.origin = hit.position

				if element.align_up_with_collision_normal:
					var normal = hit.normal.normalized()

					# World-space axes
					var basis := final_transform.basis
					var forward := (basis * forward_axis).normalized()
					var up := (basis * up_axis).normalized()

					# Project both vectors onto the plane perpendicular to forward
					var up_proj := (up - forward * up.dot(forward)).normalized()
					var normal_proj = (normal - forward * normal.dot(forward)).normalized()

					# If projection failed (edge case), skip
					if up_proj.length() > 0.001 and normal_proj.length() > 0.001:
						# Signed angle between projected up and projected normal
						var angle := up_proj.signed_angle_to(normal_proj, forward)

						# Rotate ONLY around forward axis
						final_transform.basis = basis.rotated(forward, angle)


		instance.global_transform = final_transform

		if curve_spawn_settings.avoid_overlaps:
			offset_along_curve += get_forward_axis_size(element, scene_aabb) + curve_spawn_settings.padding
		else:
			offset_along_curve += max(curve_spawn_settings.padding, 1.0)


func get_forward_axis_size(element: GdSpawnCurveSpawnProfileElement, aabb: AABB) -> float:
	match element.forward_axis:
		GdSpawnCurveSpawnProfileElement.Axis.X:
			return aabb.size.x
		GdSpawnCurveSpawnProfileElement.Axis.Y:
			return aabb.size.y
		GdSpawnCurveSpawnProfileElement.Axis.Z:
			return aabb.size.z
		_:
			return aabb.size.z


func _get_scenes_and_weights():
	var weights := []
	var scenes := []
	var used_elements := []

	for element in curve_spawn_profile.elements:
		if element.used and element.scene:
			weights.append(element.spawn_chance)
			scenes.append(element.scene)
			used_elements.append(element)

	if weights.is_empty():
		return null

	return {
		"weights": weights,
		"scenes": scenes,
		"elements": used_elements
	}



