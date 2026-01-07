@tool
extends Button
class_name AssetButton


@export var texture_rect: TextureRect
@export var button_container: Container

@export var name_label: Label



@export var subviewport: SubViewport
@export var scene_parent: Node3D
@export var camera: Camera3D


@export var library: SceneLibrary
@export var library_item: SceneLibraryItem



signal left_clicked(library_item: SceneLibraryItem)
signal right_clicked(library_item: SceneLibraryItem)


const size_multiplier = 1.3

func _set_new_size(size):
	var viewport_size = Vector2i(size, size)

	subviewport.size = viewport_size
	self.custom_minimum_size = button_container.get_combined_minimum_size()

func set_library_item(_library_item, _scene_library):
	library_item = _library_item
	library = _scene_library

	var size = _scene_library.size

	_set_new_size(size)
	update_preview()

	name_label.text = library_item.scene.resource_path.get_file().get_basename()


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	toggled.connect(func(_a): left_clicked.emit(library_item))



func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_clicked.emit(library_item)

func update_preview():
	for child in scene_parent.get_children():
		child.queue_free()
	
	var scene_instance = library_item.scene.instantiate()
	scene_parent.add_child(scene_instance)

	await get_tree().process_frame

	setup_preview_scene()
	subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func update_size(size):
	_set_new_size(size)
	update_preview()


func setup_preview_scene():
	var aabb = Utilities.calculate_spatial_bounds(scene_parent.get_child(0))
	var aabb_center = aabb.get_center()
	var max_size = max(aabb.size.x, aabb.size.y, aabb.size.z)
	
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = _get_preview_camera_position(library, library_item, aabb)
	camera.look_at(aabb_center)

func get_preview_camera_position():
	var aabb = Utilities.calculate_spatial_bounds(scene_parent.get_child(0))
	var aabb_center = aabb.get_center()
	var max_size = max(aabb.size.x, aabb.size.y, aabb.size.z)
	
	return _get_preview_camera_position(library, library_item, aabb)



func _get_preview_camera_position(library: SceneLibrary, library_item: SceneLibraryItem, scene_aabb: AABB):
	var aabb_center = scene_aabb.get_center()
	var max_size = max(scene_aabb.size.x, scene_aabb.size.y, scene_aabb.size.z)

	var global_preview_mode = ProjectSettings.get_setting("GdSpawn/Settings/Preview Perspective") as SceneLibraryItem.PreviewMode

	var final_preview_mode: SceneLibraryItem.PreviewMode

	if library_item.preview_mode == SceneLibraryItem.PreviewMode.Default:
		if library.preview_mode == SceneLibraryItem.PreviewMode.Default:
			if global_preview_mode == SceneLibraryItem.PreviewMode.Default:
				return aabb_center + Vector3.ONE.normalized() * max_size * size_multiplier
			final_preview_mode = global_preview_mode
		else:
			final_preview_mode = library.preview_mode
	else:
		final_preview_mode = library_item.preview_mode

	var position
	match final_preview_mode:
		SceneLibraryItem.PreviewMode.Top:
			position = aabb_center + Vector3.MODEL_TOP * max_size * size_multiplier
		SceneLibraryItem.PreviewMode.Bottom:
			position = aabb_center + Vector3.MODEL_BOTTOM * max_size * size_multiplier
		SceneLibraryItem.PreviewMode.Right:
			position = aabb_center + Vector3.RIGHT * max_size * size_multiplier
		SceneLibraryItem.PreviewMode.Left:
			position = aabb_center + Vector3.LEFT * max_size * size_multiplier
		SceneLibraryItem.PreviewMode.Front:
			position = aabb_center + Vector3.MODEL_FRONT * max_size * size_multiplier
		SceneLibraryItem.PreviewMode.Back:
			position = aabb_center + Vector3.MODEL_REAR * max_size * size_multiplier
		SceneLibraryItem.PreviewMode.Custom:
			position = aabb_center + library_item.custom_camera_position


	return position