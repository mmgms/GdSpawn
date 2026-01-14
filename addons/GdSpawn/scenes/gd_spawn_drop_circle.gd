@tool
extends MeshInstance3D
class_name GdSpawnDropCircle


func show_drop_circle(radius, drop_height):
	if not mesh:
		generate_mesh(radius, drop_height)

	show()

func update(radius, drop_height):
	generate_mesh(radius, drop_height)


func generate_mesh(radius: float, drop_height: float):
	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.clear_surfaces()

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var segments := 64
	var angle_step := TAU / segments

	# Circle at y = 0
	for i in segments:
		var angle_a := i * angle_step
		var angle_b := (i + 1) * angle_step

		var p1 := Vector3(
			cos(angle_a) * radius,
			drop_height,
			sin(angle_a) * radius
		)

		var p2 := Vector3(
			cos(angle_b) * radius,
			drop_height,
			sin(angle_b) * radius
		)

		immediate_mesh.surface_add_vertex(p1)
		immediate_mesh.surface_add_vertex(p2)

	# Vertical line from center downward
	immediate_mesh.surface_add_vertex(Vector3.ZERO)
	immediate_mesh.surface_add_vertex(Vector3(0, drop_height, 0))

	immediate_mesh.surface_end()

	mesh = immediate_mesh



func hide_drop_circle():
	hide()


func move_to(position):
	global_position = position