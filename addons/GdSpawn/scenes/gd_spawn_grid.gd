@tool
extends Node3D
class_name GdSpawnGrid

var max_extent: float = 300.0
@export var mesh_instance: MeshInstance3D

func update_transform(_transform):
	transform = _transform


func update_offset(_offset):
	mesh_instance.transform.origin = _offset

func update_grid_snap(grid_size: float) -> void:
	if grid_size <= 0.0:
		return

	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.clear_surfaces()

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var half_extent := max_extent * 0.5
	var line_count := int(ceil(half_extent / grid_size))

	for i in range(-line_count, line_count + 1):
		var z := i * grid_size
		immediate_mesh.surface_add_vertex(Vector3(-half_extent, 0, z))
		immediate_mesh.surface_add_vertex(Vector3( half_extent, 0, z))

	for j in range(-line_count, line_count + 1):
		var x := j * grid_size
		immediate_mesh.surface_add_vertex(Vector3(x, 0, -half_extent))
		immediate_mesh.surface_add_vertex(Vector3(x, 0,  half_extent))

	immediate_mesh.surface_end()

	mesh_instance.mesh = immediate_mesh


