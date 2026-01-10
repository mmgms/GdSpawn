@tool
extends Resource
class_name GdSpawnSceneLibraryItem


enum PreviewMode {Default, Front, Back, Top, Bottom, Left, Right, Custom}

@export var scene: PackedScene

@export var is_custom_preview: bool = false

@export var preview_mode: PreviewMode = PreviewMode.Default
@export var custom_camera_position: Vector3 = Vector3.ZERO

var item_placement_basis: Basis = Basis.IDENTITY