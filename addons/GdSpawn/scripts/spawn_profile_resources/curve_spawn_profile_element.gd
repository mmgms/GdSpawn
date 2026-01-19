@tool
extends Resource
class_name GdSpawnCurveSpawnProfileElement


enum Axis {X, Y, Z}

@export var scene: PackedScene

@export var used: bool = true
@export var spawn_chance: int = 1

@export var up_axis: Axis = Axis.Y
@export var invert_up_axis: bool = false

@export var forward_axis: Axis = Axis.Z
@export var invert_forward_axis: bool = false

enum ProjectionMode {
	NONE,
	PROJECT_TO_COLLIDERS
}

@export var projection_mode: ProjectionMode
@export var align_up_with_collision_normal: bool


func get_up_axis() -> Vector3:
	return _get_axis(up_axis, invert_up_axis)


func get_forward_axis() -> Vector3:
	return _get_axis(forward_axis, invert_forward_axis)


func _get_axis(axis_type: Axis, invert: bool):
	var temp_axis
	match axis_type:
		Axis.Y:
			temp_axis = Vector3.UP
		Axis.X:
			temp_axis = Vector3.RIGHT
		Axis.Z:
			temp_axis = Vector3.BACK
		_:
			temp_axis = Vector3.UP

	return temp_axis if not invert else (- temp_axis)
