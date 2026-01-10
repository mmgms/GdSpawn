@tool
extends Control
class_name  GdSpawnAssetPaletteManager

@export var match_selected_button: Button

@export var asset_previews_cotainer: Container
@export var scene_library: GdSpawnSceneLibrary

@export var search_field: LineEdit

@export var asset_button_scene: PackedScene

@export var dynamic_preview_popup_scene: PackedScene

var button_group: ButtonGroup

var signal_routing: GdSpawnSignalRouting

func _ready() -> void:
	button_group = ButtonGroup.new()
	button_group.allow_unpress = true
	match_selected_button.pressed.connect(on_match_selected_pressed)
	search_field.text_changed.connect(on_search_text_changed)

func set_library(_scene_library: GdSpawnSceneLibrary, _signal_routing: GdSpawnSignalRouting):
	signal_routing = _signal_routing
	scene_library = _scene_library
	name = scene_library.name
	refresh_children()


func refresh_children():
	for child in asset_previews_cotainer.get_children():
		child.queue_free()

	for element in scene_library.elements:
		var asset_button = asset_button_scene.instantiate() as GdSpawnAssetButton
		asset_previews_cotainer.add_child(asset_button)
		asset_button.set_library_item(element, scene_library, signal_routing)
		asset_button.right_clicked.connect(func(item): show_asset_menu(item, asset_button))
		#asset_button.button_group = button_group


func update_previews():
	for child in asset_previews_cotainer.get_children():
		(child as GdSpawnAssetButton).update_preview()

func save_library():
	if scene_library.name.begins_with("[Empty]"):
		return
	
	ResourceSaver.save(scene_library)

func on_match_selected_pressed():
	var selection = EditorInterface.get_selection()
	if selection.get_selected_nodes().size() == 0:
		return
	
	var selected_node = selection.get_selected_nodes()[0]
	if not selected_node is Node3D:
		return

	var scene_path = selected_node.scene_file_path
	if not scene_path or scene_path.is_empty():
		return
	
	for child in asset_previews_cotainer.get_children():
		var asset_button = child as GdSpawnAssetButton
		if asset_button.library_item.scene.resource_path == scene_path:
			asset_button.set_pressed(true)
			return


func on_search_text_changed(text):
	if text == "":
		for child in asset_previews_cotainer.get_children():
			child.show()

		return

	for child in asset_previews_cotainer.get_children():
		var asset_button = child as GdSpawnAssetButton
		if not asset_button.name_label.text.to_lower().contains(text.to_lower()):
			asset_button.hide()
		else:
			asset_button.show()



func _can_drop_data(at_position, data):
	if data is Dictionary:
		var type = data["type"]
		var files_or_dirs = type == "files_and_dirs" || type == "files"
		return files_or_dirs and data.has("files")
	return false	
	
func _drop_data(at_position, data):
	var dirs: PackedStringArray = data["files"]
	add_assets_or_folders(dirs)



func add_assets_or_folders(files: PackedStringArray):
	for file in files:
		add_asset(file, "")
		
func add_asset(path: String, folder_path: String):
	scene_library.add_element(path)
	refresh_children()
	save_library()


func show_asset_menu(item: GdSpawnSceneLibraryItem, button: GdSpawnAssetButton):
	var options_menu := PopupMenu.new()
	var preview_options = create_preview_options(item, button)
	options_menu.add_child(preview_options)
	var mouse_pos = DisplayServer.mouse_get_position()
	options_menu.add_icon_item(EditorIconTexture2D.new("File"), "Open")
	options_menu.add_icon_item(EditorIconTexture2D.new("Remove"), "Remove")
	options_menu.add_icon_item(EditorIconTexture2D.new("ShowInFileSystem"), "Show In FileSystem")
	options_menu.add_icon_item(EditorIconTexture2D.new("Reload"), "Reload Preview")
	options_menu.add_icon_item(null, "Open Dynamic Preview")
	options_menu.add_submenu_item("Preview Perspective", preview_options.name)
	options_menu.index_pressed.connect(func(index):
		match index:
			0: 
				EditorInterface.open_scene_from_path(item.scene.resource_path)
				EditorInterface.set_main_screen_editor("3D")
			1: 
				if button.pressed:
					signal_routing.ItemSelect.emit(null)
				scene_library.delete_element(item)
				save_library()
				refresh_children()
			2: 
				EditorInterface.select_file(item.scene.resource_path)
			3:
				button.update_preview()
			4: 
				open_dynamic_preview(item, button)
			_: pass
	)
	EditorInterface.popup_dialog(options_menu, Rect2(mouse_pos, options_menu.get_contents_minimum_size()))

func create_preview_options(item, button: GdSpawnAssetButton):
	var preview_options_menu := PopupMenu.new()
	preview_options_menu.name = "PreviewMenu"
	for option in GdSpawnSceneLibraryItem.PreviewMode.keys():
		preview_options_menu.add_icon_radio_check_item(null, option)
	
	preview_options_menu.set_item_checked(item.preview_mode, true)
	preview_options_menu.index_pressed.connect(func(index): on_preview_option_index_pressed(item, index, button))

	return preview_options_menu

func on_preview_option_index_pressed(item, index, button: GdSpawnAssetButton):
	if index == null: 
		return

	var prev_camera_position = button.get_preview_camera_position() 
	item.preview_mode = index
	if item.preview_mode == GdSpawnSceneLibraryItem.PreviewMode.Custom and item.custom_camera_position.is_zero_approx():
		item.custom_camera_position = prev_camera_position

	button.update_preview()
	save_library()	

func update_size(size):
	scene_library.size = size
	save_library()
	for child in asset_previews_cotainer.get_children():
		var asset_button = child as GdSpawnAssetButton
		asset_button.update_size(size)


func open_dynamic_preview(item: GdSpawnSceneLibraryItem, button: GdSpawnAssetButton):
	var dynamic_preview_popup = dynamic_preview_popup_scene.instantiate() as GdSpawnDynamicPreviewPopup

	var mouse_pos = DisplayServer.mouse_get_position()
	
	EditorInterface.popup_dialog(dynamic_preview_popup, Rect2(mouse_pos-Vector2i(0, +200), dynamic_preview_popup.get_contents_minimum_size()))#dynamic_preview_popup.get_contents_minimum_size()

	dynamic_preview_popup.set_library_item(item, button)
	dynamic_preview_popup.thumbnail_updated.connect(func (): save_library(); button.update_preview())
