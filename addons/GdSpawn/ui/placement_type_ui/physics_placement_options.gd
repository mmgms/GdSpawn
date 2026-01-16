@tool
extends PanelContainer
class_name GdSpawnPhysicsPlacementOptions

@export var drop_radius_spinbox: SpinBox
@export var drop_height_spinbox: SpinBox
@export var drop_interval_spinbox: SpinBox
@export var randomize_rotation_button: CheckBox
@export var out_of_bound_y_spinbox: SpinBox

@export var random_spawn_profile_parent: Control

@export var drop_gizmo_scene: PackedScene

@export var stop_sim_button: Button

signal add_scene_request(action: GdSpawnSpawnManager.GdSpawnAddScenesAction)
var random_spawn_profile: GdSpawnRandomSpawnProfile

class ShapeInfo:
	var shape: ConvexPolygonShape3D
	var transform: Transform3D

class GdSpawnPhysicsSpawnJob:
	var node: Node
	var owner: Node
	var gizmo: Node3D
	var current_simulated_rigid_bodies: Array

	var max_sim_time = 10.0
	var last_spawn_timestamp = 0.0
	var first_timestamp = 0.0


	var drop_height = 0.0
	var drop_radius = 0.0
	var drop_interval = 0.0
	var out_of_bounds_y = -10
	var min_y

	var randomize_rotation = true
	var weights: Array
	var scenes: Array

	var shapes_cache: Dictionary

	var rng: RandomNumberGenerator

	var force_stopped = false
	var force_erase = false
	var stopped = false
	var stop_scene_spawn = false

	var time_passed = 0.0

	func start():
		rng = RandomNumberGenerator.new()
		first_timestamp = 0.0
		last_spawn_timestamp = 0.0
		time_passed = 0.0
		min_y = gizmo.global_position.y + out_of_bounds_y
		spawn_new_scene()
		while not stopped:
			if force_erase:
				stopped = true
				for rb in current_simulated_rigid_bodies:
					rb.queue_free()
			await update()

		if stopped and not force_erase:
			if current_simulated_rigid_bodies.is_empty():
				return
			var action = GdSpawnSpawnManager.GdSpawnAddScenesAction.new()
			for rb in current_simulated_rigid_bodies:
				var packed_scene = rb.get_meta("scene")
				action.scenes.append(packed_scene)
				action.transforms.append(rb.global_transform)
				rb.queue_free()
			action.owner = owner
			node.add_scene_request.emit(action)

	func update():
		await node.get_tree().physics_frame
		if EditorInterface.get_edited_scene_root() != owner:
			return
			
		if force_stopped:
			stopped = true
			return

		if force_erase:
			stopped = true
			return

		time_passed += node.get_physics_process_delta_time()
		if not stop_scene_spawn:
			if time_passed - last_spawn_timestamp > drop_interval:
				last_spawn_timestamp = time_passed
				spawn_new_scene()

		stopped = true
		for rb in current_simulated_rigid_bodies:
			if not rb.sleeping:
				stopped = false
				break

		var rb_to_keep = []
		for rb in current_simulated_rigid_bodies:
			if rb.global_position.y > min_y:
				rb_to_keep.append(rb)
			else:
				rb.queue_free()

		current_simulated_rigid_bodies = rb_to_keep
		
		if current_simulated_rigid_bodies.size() <= 0:
			stopped = true
		
		if time_passed - first_timestamp > max_sim_time:
			stopped = true

	func spawn_new_scene():
		var scene_idx = rng.rand_weighted(weights)
		var sampled_scene = scenes[scene_idx]

		#generate rigid body collision
		var scene_root =  EditorInterface.get_edited_scene_root()
		var instanced_scene = sampled_scene.instantiate()

		scene_root.add_child(instanced_scene)

		var rigid_body = RigidBody3D.new()
		scene_root.add_child(rigid_body)

		var shapes = []
		if not shapes_cache.has(sampled_scene):
			_collect_collisions(instanced_scene, shapes)
			shapes_cache[sampled_scene] = shapes
		else:
			shapes = shapes_cache[sampled_scene]
		
		for shape_info in shapes:
			var collision_shape = CollisionShape3D.new()
			rigid_body.add_child(collision_shape)
			collision_shape.shape = shape_info.shape
			collision_shape.global_transform = shape_info.transform

		_freeze_scene_rbs(instanced_scene)
		instanced_scene.reparent(rigid_body)

		#reposition rigid body
		var center = gizmo.global_position + drop_height * Vector3.UP
		var angle = randf_range(0, 2 * PI)
		var radius = randf_range(0, drop_radius)
		var random_pos = center + Vector3(radius * cos(angle), 0, radius * sin(angle))
		rigid_body.global_position = random_pos
		if randomize_rotation:
			rigid_body.global_basis = GdSpawnUtilities.random_rotation()

		current_simulated_rigid_bodies.append(rigid_body)
		rigid_body.set_meta("scene", sampled_scene)

	func _collect_collisions(root: Node, shapes) -> void:
		
		# Only process MeshInstance3D nodes with a mesh
		if root is MeshInstance3D and root.mesh:
			var mesh_instance := root as MeshInstance3D

			# Generate convex shape from mesh
			var shape = mesh_instance.mesh.create_convex_shape()

			var coll_info = GdSpawnPhysicsPlacementOptions.ShapeInfo.new()
			coll_info.shape = shape
			coll_info.transform = mesh_instance.global_transform

			shapes.append(coll_info)

		if root is RigidBody3D or root is StaticBody3D:
	
			for coll_shape in root.get_children():
				if coll_shape is CollisionShape3D:
					var coll_info = GdSpawnPhysicsPlacementOptions.ShapeInfo.new()
					coll_info.shape = coll_shape.shape
					coll_info.transform = coll_shape.global_transform
					shapes.append(coll_info)

		for child in root.get_children():
			# Recurse first
			_collect_collisions(child, shapes)

	func _freeze_scene_rbs(root):
		if root is RigidBody3D:
			root.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			root.freeze = true
		
		for child in root.get_children():
			_freeze_scene_rbs(child)


var signal_routing: GdSpawnSignalRouting:
	set(value):
		signal_routing = value
		signal_routing.EditedSceneChanged.connect(on_scene_change)
		signal_routing.PluginDisabled.connect(on_plugin_disabled)

var current_drop_gizmo: GdSpawnDropCircle

var all_rbs = []
var freeze_flags: Array[bool] = []

func _ready() -> void:
	drop_height_spinbox.value_changed.connect(func(_x): update_gizmo_props())
	drop_radius_spinbox.value_changed.connect(func(_x): update_gizmo_props())
	update_gizmo(EditorInterface.get_edited_scene_root())
	current_drop_gizmo.hide_drop_circle()

	stop_sim_button.pressed.connect(on_stop_sim_button)


func _get_all_rigid_bodies_3d_in_children(node: Node, array : Array):
	if node is RigidBody3D:
		array.append(node)
	for child in node.get_children():
		_get_all_rigid_bodies_3d_in_children(child,array)


var active = false
func on_enter():
	active = true
	all_rbs = []

	current_drop_gizmo.show_drop_circle(drop_radius_spinbox.value, drop_height_spinbox.value)

	_stop_rbs()
	PhysicsServer3D.set_active(true)


func on_exit():
	active = false
	_erase_pending_spawn_jobs()
	PhysicsServer3D.set_active(false)
	_restore_rbs()
	current_drop_gizmo.hide_drop_circle()


func on_plugin_disabled():
	_erase_pending_spawn_jobs()
	if current_drop_gizmo: 
		current_drop_gizmo.queue_free()
	PhysicsServer3D.set_active(false)
	_restore_rbs()

func on_stop_sim_button():
	if spawn_jobs.size() == 0:
		return

	_commit_pending_spawn_jobs()

func on_scene_change(scene_root):
	if current_drop_gizmo:
		current_drop_gizmo.queue_free()
	update_gizmo(scene_root)

	if active:
		_erase_pending_spawn_jobs()
		_restore_rbs()
		PhysicsServer3D.set_active(false)
		_stop_rbs()
		PhysicsServer3D.set_active(true)
		current_drop_gizmo.show_drop_circle(drop_radius_spinbox.value, drop_height_spinbox.value)
	else:
		current_drop_gizmo.hide_drop_circle()


func _stop_rbs():
	_get_all_rigid_bodies_3d_in_children(EditorInterface.get_edited_scene_root(), all_rbs)
	for rb in all_rbs:
		if rb:
			freeze_flags.append(rb.freeze)
			rb.freeze = true

func _restore_rbs():
	for i in all_rbs.size():
		if all_rbs[i]:
			all_rbs[i].freeze = freeze_flags[i]

func _commit_pending_spawn_jobs():
	for spawn_job in spawn_jobs:
		if spawn_job:
			spawn_job.force_stopped = true

func _erase_pending_spawn_jobs():
	for spawn_job in spawn_jobs:
		if spawn_job and not spawn_job.stopped:
			spawn_job.force_erase = true

func update_gizmo(scene_root):
	if not scene_root:
		return

	if not scene_root is Node3D:
		return

	if scene_root.has_node("GdSpawnDropCircle"):
		current_drop_gizmo = scene_root.get_node("GdSpawnDropCircle")
		return

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

var current_spawn_job: GdSpawnPhysicsSpawnJob
var spawn_jobs: Array

func on_press():
	update_random_spawn_profile()
	if not random_spawn_profile:
		return false

	#pick scene
	var res = _get_scenes_and_weights()
	if res.is_empty():
		return false

	var weights = res.weights
	var scenes = res.scenes

	var spawn_job = GdSpawnPhysicsSpawnJob.new()

	spawn_job.node = self
	spawn_job.owner = EditorInterface.get_edited_scene_root()
	spawn_job.gizmo = current_drop_gizmo
	spawn_job.weights = res.weights
	spawn_job.scenes = res.scenes
	spawn_job.drop_interval = drop_interval_spinbox.value
	spawn_job.drop_radius = drop_radius_spinbox.value
	spawn_job.drop_height = drop_height_spinbox.value
	spawn_job.randomize_rotation = randomize_rotation_button.button_pressed
	spawn_job.out_of_bounds_y = out_of_bound_y_spinbox.value

	spawn_job.start()

	spawn_jobs.append(spawn_job)
	return true

	

func on_release():
	if spawn_jobs.size() == 0:
		return false

	spawn_jobs[-1].stop_scene_spawn = true
	return true


func update_random_spawn_profile():
	if not random_spawn_profile:
		var scene_root = EditorInterface.get_edited_scene_root()
		var matches = scene_root.find_children("*", "GdSpawn", false, true) 
		if matches.size() == 0:
			return
		var gdspawn_node = matches[0] as GdSpawn
		random_spawn_profile = gdspawn_node.random_spawn_profile



func _get_scenes_and_weights():
	var weights = []
	var scenes = []
	var used_elements = []

	for element in random_spawn_profile.elements:
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




