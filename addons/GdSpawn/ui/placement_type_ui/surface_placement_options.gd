@tool
extends PanelContainer

@export var align_to_surface_normal_check_box: CheckBox
@export var alignment_options_select: OptionButton
@export var terrain_3d_node_select: GdSpawnNodeSelect

enum GdSpawnAligmentOptions {POS_Y, POS_Z, POS_X, NEG_Y, NEG_Z, NEG_X}

var current_alignment_option: GdSpawnAligmentOptions = GdSpawnAligmentOptions.POS_Y

var should_align_to_surface_normal: bool = false

var signal_routing: GdSpawnSignalRouting:
	set(val):
		signal_routing = val
		signal_routing.EditedSceneChanged.connect(on_scene_changed)


var terrain_3d_node: Node = null

func _ready() -> void:
	alignment_options_select.item_selected.connect(on_aligment_option_selected)
	align_to_surface_normal_check_box.toggled.connect(func(toggled_on): should_align_to_surface_normal = toggled_on)
	terrain_3d_node_select.node_changed.connect(on_terrain3d_node_changed)
	populate_alignment_options()


var root_to_terrain_3d_node_cache: Dictionary
func on_scene_changed(root):
	if root_to_terrain_3d_node_cache.has(root):
		terrain_3d_node = root_to_terrain_3d_node_cache[root]
		terrain_3d_node_select.set_node(terrain_3d_node)
		return

	terrain_3d_node_select.set_node(null)
	

func on_terrain3d_node_changed(node):
	terrain_3d_node = node
	root_to_terrain_3d_node_cache[EditorInterface.get_edited_scene_root()] = terrain_3d_node

func should_show_grid():
	return false

func populate_alignment_options() -> void:
	alignment_options_select.clear()

	var labels := {
		GdSpawnAligmentOptions.POS_Y: "+Y (Up)",
		GdSpawnAligmentOptions.NEG_Y: "-Y (Down)",
		GdSpawnAligmentOptions.POS_Z: "+Z (Forward)",
		GdSpawnAligmentOptions.NEG_Z: "-Z (Back)",
		GdSpawnAligmentOptions.POS_X: "+X (Right)",
		GdSpawnAligmentOptions.NEG_X: "-X (Left)",
	}

	for option in GdSpawnAligmentOptions.values():
		alignment_options_select.add_item(labels[option], option)


func on_aligment_option_selected(idx):
	current_alignment_option = idx

func _get_alignment_axis() -> Vector3:
	match current_alignment_option:
		GdSpawnAligmentOptions.POS_Y: return Vector3.UP
		GdSpawnAligmentOptions.NEG_Y: return Vector3.DOWN
		GdSpawnAligmentOptions.POS_Z: return Vector3.FORWARD
		GdSpawnAligmentOptions.NEG_Z: return Vector3.BACK
		GdSpawnAligmentOptions.POS_X: return Vector3.RIGHT
		GdSpawnAligmentOptions.NEG_X: return Vector3.LEFT
		_: return Vector3.UP


func on_move(camera: Camera3D, mouse_pos: Vector2, library_item: GdSpawnSceneLibraryItem, snap_step, snap_enable):

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var	ray_dir = camera.project_ray_normal(mouse_pos)
	var space_state = camera.get_world_3d().direct_space_state

	var params = PhysicsRayQueryParameters3D.new()
	params.from = ray_origin
	params.to = ray_origin + ray_dir * 4096
	params.collision_mask = 0b1
	var result = space_state.intersect_ray(params)

	var res = {}

	var local_object_transform = Transform3D()
	local_object_transform.basis = library_item.item_placement_basis

	if result.is_empty():
		result = get_terrain3d_intersection(camera, mouse_pos)

	if result.is_empty():
		res["object_transform"] = local_object_transform
		res["grid_offset"] = Vector3.ZERO
		return res

	var on_surface_transform = Transform3D()
	on_surface_transform.origin = result.position

	if should_align_to_surface_normal:
		var surface_normal = result.normal.normalized()
		var local_axis := _get_alignment_axis().normalized()

		var q := Quaternion(local_axis, surface_normal)
		var basis := Basis(q)
		on_surface_transform.basis = basis

	res["object_transform"] = on_surface_transform * local_object_transform

	return res


func get_terrain3d_intersection(camera, mouse_position):
	var res = {}

	if not terrain_3d_node:
		return res

	if not terrain_3d_node.has_method("get_intersection"):
		return res

	var from = camera.project_ray_origin(mouse_position)
	var to = from + camera.project_ray_normal(mouse_position) * 1000
	var direction = (to - from).normalized()
	var hit_position: Vector3 = terrain_3d_node.get_intersection(from, direction, false)
	var data = terrain_3d_node.data
	var normal = data.get_normal(hit_position)
	if is_nan(normal.x) or is_nan(normal.z) or is_nan(normal.y):
		return res

	res.position = hit_position
	res.normal = normal

	return res
