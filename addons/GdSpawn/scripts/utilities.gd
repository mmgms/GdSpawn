class_name GdSpawnUtilities



static func calculate_spatial_bounds(scene_parent: Node3D, exclude_top_level_transform: bool=false):
	var bounds: AABB = AABB()

	var vis_instance = scene_parent as VisualInstance3D
	if vis_instance:
		bounds = vis_instance.get_aabb()

	for child in scene_parent.get_children():
		if child:
			var child_bounds = calculate_spatial_bounds(child)

			if bounds.size == Vector3() and scene_parent:
				bounds = child_bounds
			else:
				bounds = bounds.merge(child_bounds)

	if bounds.size == Vector3() and not scene_parent:
		bounds = AABB(Vector3(-0.2, -0.2, -0.2), Vector3(0.4, 0.4, 0.4))

	if not exclude_top_level_transform:
		bounds = scene_parent.transform * bounds
	

	return bounds


static func disable_collisions_recursive(root: Node) -> void:
	if root == null:
		return

	# Disable individual shapes if present
	if root is CollisionShape3D:
		root.disabled = true

	for child in root.get_children():
		disable_collisions_recursive(child)


static func random_rotation() -> Basis:
	var u1 = randf()
	var u2 = randf()
	var u3 = randf()

	var sqrt1_minus_u1 = sqrt(1.0 - u1)
	var sqrt_u1 = sqrt(u1)

	var q = Quaternion(
		sqrt1_minus_u1 * sin(TAU * u2),
		sqrt1_minus_u1 * cos(TAU * u2),
		sqrt_u1 * sin(TAU * u3),
		sqrt_u1 * cos(TAU * u3)
	)

	return Basis(q)