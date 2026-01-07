@tool
extends Popup
class_name GdSpawnDynamicPreviewPopup


@export var camera: Camera3D
@export var scene_parent: Node3D


@export var scene_name_label: Label
@export var close_button: Button
@export var update_thumbnail_button: Button


@export var scene_library_item: GdSpawnSceneLibraryItem
@export var asset_button: GdSpawnAssetButton


@export var orbit_sensitivity := 0.005
@export var zoom_sensitivity := 0.5
@export var min_distance := 1.5
@export var max_distance := 50.0

signal thumbnail_updated()

var pivot: Vector3 = Vector3.ZERO
var _distance := 10.0
var _yaw := 0.0
var _pitch := 0.0
var _orbiting := false

func _ready() -> void:
	close_button.pressed.connect(on_close)
	update_thumbnail_button.pressed.connect(on_update_thumbnail)


func on_close():
	queue_free()

func on_update_thumbnail():
	scene_library_item.custom_camera_position = camera.global_position - pivot
	scene_library_item.preview_mode = GdSpawnSceneLibraryItem.PreviewMode.Custom
	thumbnail_updated.emit()
	queue_free()

func _input(event):
	# Middle mouse button pressed/released
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = event.pressed
		
		# Zoom with mouse wheel
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-zoom_sensitivity)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(zoom_sensitivity)

	# Orbit when dragging middle mouse
	if event is InputEventMouseMotion and _orbiting:
		_yaw -= event.relative.x * orbit_sensitivity
		_pitch += event.relative.y * orbit_sensitivity
		
		# Clamp pitch to avoid flipping
		_pitch = clamp(_pitch, -PI / 2 + 0.01, PI / 2 - 0.01)
		
		update_camera_transform()

func zoom(amount: float):
	_distance = clamp(_distance + amount, min_distance, max_distance)
	update_camera_transform()

func update_camera_transform():
	var direction = Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	)
	
	camera.global_position = pivot + direction * _distance
	camera.look_at(pivot, Vector3.UP)


func set_library_item(_lib_item: GdSpawnSceneLibraryItem, _asset_button: GdSpawnAssetButton):
	asset_button = _asset_button
	scene_library_item = _lib_item
	for child in scene_parent.get_children():
		child.queue_free()
	
	var instanced_scene = scene_library_item.scene.instantiate()

	scene_parent.add_child(instanced_scene)

	await get_tree().process_frame

	var aabb = GdSpawnUtilities.calculate_spatial_bounds(instanced_scene)

	var max_size = max(aabb.size.x, aabb.size.y, aabb.size.z)

	pivot= aabb.get_center()

	initialize_yaw_pitch()

	scene_name_label.text = scene_library_item.scene.resource_path.get_file()

func initialize_yaw_pitch():
	# Initialize yaw/pitch from current transform
	camera.global_position = asset_button.get_preview_camera_position()
	var offset = camera.global_position - pivot
	_distance = offset.length()
	_yaw = atan2(offset.x, offset.z)
	_pitch = asin(offset.y / _distance)
	camera.look_at(pivot)