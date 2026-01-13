@tool
extends Path3D
class_name GdSpawnPath

@export var curve_spawn_profile: GdSpawnCurveSpawnProfile:
	set(value):
		curve_spawn_profile = value

@export var curve_spawn_settings: GdSpawnCurveSpawnSettings:
	set(value):
		curve_spawn_settings = value

@export_tool_button("Update", "Callable") var action = _update


func _update():
	if not curve_spawn_profile or not curve_spawn_settings:
		return

	var scene_to_aabb = {}
	var offset_along_curve = 0.0
	if curve_spawn_profile.elements.is_empty():
		return

	var rng = RandomNumberGenerator.new()
	var res = _get_scenes_and_weights()
	if res.is_empty():
		return

	var curve_length = curve.get_baked_length()

	if is_zero_approx(curve_length):
		return

	for child in get_children():
		child.queue_free()

	var weights = res.weights
	var scenes = res.scenes
	var elements = res.elements as Array[GdSpawnCurveSpawnProfileElement]

	while offset_along_curve < curve_length:
		var scene_idx = rng.rand_weighted(weights)
		var element = elements[scene_idx]
		var sampled_scene = scenes[scene_idx]

		var instanced_scene = sampled_scene.instantiate()
		add_child(instanced_scene, true)
		instanced_scene.owner = EditorInterface.get_edited_scene_root()

		var scene_aabb
		if scene_to_aabb.has(sampled_scene):
			scene_aabb = scene_to_aabb[sampled_scene]
		else:
			scene_aabb = GdSpawnUtilities.calculate_spatial_bounds(instanced_scene)
			if is_zero_approx(scene_aabb.get_shortest_axis_size()):
				scene_aabb = AABB(Vector3.ZERO, Vector3.ONE)
			scene_to_aabb[sampled_scene] = scene_aabb

		var object_transform = curve.sample_baked_with_rotation(offset_along_curve)

		var up_axis = element.get_up_axis()
		var forward_axis = element.get_forward_axis()

		var reorient_transform = Transform3D().looking_at(forward_axis, up_axis)

		instanced_scene.global_transform = global_transform * object_transform * reorient_transform
		
		offset_along_curve += get_forward_axis_size(element, scene_aabb)

func get_forward_axis_size(element:GdSpawnCurveSpawnProfileElement, aabb: AABB):
	match element.forward_axis:
		GdSpawnCurveSpawnProfileElement.Axis.Y:
			return aabb.size.y
		GdSpawnCurveSpawnProfileElement.Axis.X:
			return aabb.size.x
		GdSpawnCurveSpawnProfileElement.Axis.Z:
			return aabb.size.z
		_:
			return aabb.size.z


func _get_scenes_and_weights():
	var weights = []
	var scenes = []
	var used_elements = []

	for element in curve_spawn_profile.elements:
		if element.used and element.scene:
			weights.append(element.spawn_chance)
			scenes.append(element.scene)
			used_elements.append(element)

	var res = {}

	if weights.is_empty():
		return null

	res.weights = weights
	res.scenes = scenes
	res.elements = used_elements
	return res



