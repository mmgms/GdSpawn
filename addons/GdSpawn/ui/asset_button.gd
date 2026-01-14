@tool
extends Button
class_name GdSpawnAssetButton


@export var texture_rect: TextureRect
@export var button_container: Container
@export var name_label: Label
@export var reset_local_transform_button: Button
@export var subviewport: SubViewport
@export var scene_parent: Node3D
@export var camera: Camera3D

var signal_routing: GdSpawnSignalRouting

@export var library: GdSpawnSceneLibrary
@export var library_item: GdSpawnSceneLibraryItem



signal left_clicked(library_item: GdSpawnSceneLibraryItem)
signal right_clicked(library_item: GdSpawnSceneLibraryItem)


const size_multiplier = 1.2

func _set_new_size(size):
	var viewport_size = Vector2i(size, size)

	subviewport.size = viewport_size
	self.custom_minimum_size = button_container.get_combined_minimum_size()

func set_library_item(_library_item, _scene_library, _signal_routing):
	signal_routing = _signal_routing

	library_item = _library_item
	library = _scene_library

	var size = _scene_library.size

	_set_new_size(size)
	update_preview()

	name_label.text = library_item.scene.resource_path.get_file().get_basename()
	signal_routing.ItemSelect.connect(on_item_select)
	signal_routing.ItemPlacementBasisSet.connect(on_item_basis_change)
	signal_routing.ProjectSettingsChanged.connect(on_proj_settings_change)


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	toggled.connect(on_toggled)

	reset_local_transform_button.pressed.connect(on_reset_local_transform)
	reset_local_transform_button.hide()

func on_proj_settings_change():
	if ProjectSettings.get_setting("GdSpawn/Settings/Preview Perspective") != last_global_preview_mode:
		update_preview()

func on_toggled(toggled_on):
	if not toggled_on:
		signal_routing.ItemSelect.emit(null)
		return
	
	signal_routing.ItemSelect.emit(library_item)
	

func on_item_select(item):
	if item == null or item != library_item:
		set_pressed_no_signal(false)
	if item == library_item:
		set_pressed_no_signal(true)


func on_reset_local_transform():
	library_item.item_placement_basis = Basis()
	reset_local_transform_button.hide()
	signal_routing.ItemPlacementBasisSet.emit(library_item)

func on_item_basis_change(item):
	if item != library_item:
		return
	if item.item_placement_basis.is_equal_approx(Basis.IDENTITY):
		reset_local_transform_button.hide()
	else:
		reset_local_transform_button.show()

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
	var aabb = GdSpawnUtilities.calculate_spatial_bounds(scene_parent.get_child(0))
	var aabb_center = aabb.get_center()
	var max_size = max(aabb.size.x, aabb.size.y, aabb.size.z)
	
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = _get_preview_camera_position(library, library_item, aabb)
	camera.look_at(aabb_center)

func get_preview_camera_position():
	var aabb = GdSpawnUtilities.calculate_spatial_bounds(scene_parent.get_child(0))
	var aabb_center = aabb.get_center()
	var max_size = max(aabb.size.x, aabb.size.y, aabb.size.z)
	
	return _get_preview_camera_position(library, library_item, aabb)

var last_global_preview_mode = 0

func _get_preview_camera_position(library: GdSpawnSceneLibrary, library_item: GdSpawnSceneLibraryItem, scene_aabb: AABB):
	var aabb_center = scene_aabb.get_center()
	var max_size = max(scene_aabb.size.x, scene_aabb.size.y, scene_aabb.size.z)

	var global_preview_mode = ProjectSettings.get_setting("GdSpawn/Settings/Preview Perspective") as GdSpawnSceneLibraryItem.PreviewMode
	last_global_preview_mode = global_preview_mode

	var final_preview_mode: GdSpawnSceneLibraryItem.PreviewMode

	if library_item.preview_mode == GdSpawnSceneLibraryItem.PreviewMode.Default:
		if library.preview_mode == GdSpawnSceneLibraryItem.PreviewMode.Default:
			if global_preview_mode == GdSpawnSceneLibraryItem.PreviewMode.Default:
				return aabb_center + Vector3.ONE.normalized() * max_size * size_multiplier
			final_preview_mode = global_preview_mode
		else:
			final_preview_mode = library.preview_mode
	else:
		final_preview_mode = library_item.preview_mode

	var position
	match final_preview_mode:
		GdSpawnSceneLibraryItem.PreviewMode.Top:
			position = aabb_center + Vector3.MODEL_TOP * max_size * size_multiplier
		GdSpawnSceneLibraryItem.PreviewMode.Bottom:
			position = aabb_center + Vector3.MODEL_BOTTOM * max_size * size_multiplier
		GdSpawnSceneLibraryItem.PreviewMode.Right:
			position = aabb_center + Vector3.RIGHT * max_size * size_multiplier
		GdSpawnSceneLibraryItem.PreviewMode.Left:
			position = aabb_center + Vector3.LEFT * max_size * size_multiplier
		GdSpawnSceneLibraryItem.PreviewMode.Front:
			position = aabb_center + Vector3.MODEL_FRONT * max_size * size_multiplier
		GdSpawnSceneLibraryItem.PreviewMode.Back:
			position = aabb_center + Vector3.MODEL_REAR * max_size * size_multiplier
		GdSpawnSceneLibraryItem.PreviewMode.Custom:
			position = aabb_center + library_item.custom_camera_position


	return position



func _get_drag_data(at_position: Vector2) -> Variant:
	var data = {}

	data.type = "files"
	data.files = [library_item.scene.resource_path]
	data.from = self

	return data