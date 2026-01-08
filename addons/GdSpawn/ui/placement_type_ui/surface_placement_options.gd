@tool
extends PanelContainer

@export var align_to_surface_normal_check_box: CheckBox
@export var alignment_options_select: OptionButton

enum GdSpawnAligmentOptions {POS_Y, POS_Z, POS_X, NEG_Y, NEG_Z, NEG_X}

var current_alignment_option: GdSpawnAligmentOptions = GdSpawnAligmentOptions.POS_Y

var should_align_to_surface_normal: bool = false

var default_transform: Transform3D

func _ready() -> void:
	default_transform = Transform3D()
	alignment_options_select.item_selected.connect(on_aligment_option_selected)
	align_to_surface_normal_check_box.toggled.connect(func(toggled_on): should_align_to_surface_normal = toggled_on)
	populate_alignment_options()

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


func on_move(camera: Camera3D, mouse_pos: Vector2, current_snap_info: GdSpawnSpawnManager.GdSpawnSnapInfo) -> Transform3D:

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var	ray_dir = camera.project_ray_normal(mouse_pos)
	var space_state = camera.get_world_3d().direct_space_state

	var params = PhysicsRayQueryParameters3D.new()
	params.from = ray_origin
	params.to = ray_origin + ray_dir * 4096
	params.collision_mask = 0b1
	var result = space_state.intersect_ray(params)

	var new_transform = default_transform

	if result.is_empty():
		return new_transform

	new_transform.origin = result.position

	if should_align_to_surface_normal:
		var surface_normal = result.normal.normalized()
		var local_axis := _get_alignment_axis().normalized()

		var q := Quaternion(local_axis, surface_normal)
		var basis := Basis(q)
		basis = basis.scaled(new_transform.basis.get_scale())
		new_transform.basis = basis


	return new_transform

func on_rotate_y(shift_pressed):
	var deg_to_rotate = 90
	if shift_pressed:
		deg_to_rotate = 45
	default_transform = default_transform.rotated_local(Vector3.UP, deg_to_rad(deg_to_rotate))