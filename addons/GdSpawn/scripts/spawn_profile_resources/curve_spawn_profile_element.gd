@tool
extends Resource
class_name GdSpawnCurveSpawnProfileElement


enum Axis {X, Y, Z}

@export var scene: PackedScene

@export var used: bool = true
@export var spawn_chance: int = 1

@export var up_axis: Axis = Axis.Y

@export var forward_axis: Axis = Axis.Z


func get_up_axis() -> Vector3:
	match up_axis:
		Axis.Y:
			return Vector3.UP
		Axis.X:
			return Vector3.RIGHT
		Axis.Z:
			return Vector3.BACK
		_:
			return Vector3.UP



func get_forward_axis() -> Vector3:
	match forward_axis:
		Axis.Y:
			return Vector3.UP
		Axis.X:
			return Vector3.RIGHT
		Axis.Z:
			return Vector3.BACK
		_:
			return Vector3.UP
