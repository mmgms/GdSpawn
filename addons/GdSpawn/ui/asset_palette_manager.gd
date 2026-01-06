@tool
extends Control
class_name  AssetPaletteManager

@export var match_selected_button: Button

@export var asset_previews_cotainer: Container
@export var scene_library: SceneLibrary

@export var search_field: LineEdit

@export var asset_button_scene: PackedScene


func _ready() -> void:
	match_selected_button.pressed.connect(on_match_selected_pressed)
	search_field.text_changed.connect(on_search_text_changed)

func set_library(_scene_library: SceneLibrary):
	scene_library = _scene_library
	name = scene_library.name
	refresh_children()


func refresh_children():
	for child in asset_previews_cotainer.get_children():
		child.queue_free()

	for element in scene_library.elements:
		var asset_button = asset_button_scene.instantiate() as AssetButton
		asset_previews_cotainer.add_child(asset_button)
		asset_button.set_library_item(element, scene_library.size)
		asset_button.right_clicked.connect(func(item): show_asset_menu(item, asset_button))

func update_previews():
	for child in asset_previews_cotainer.get_children():
		(child as AssetButton).update_preview()

func save_library():
	if scene_library.name.begins_with("[Empty]"):
		return
	
	ResourceSaver.save(scene_library)

func on_match_selected_pressed():
	pass


func on_search_text_changed(text):
	if text == "":
		for child in asset_previews_cotainer.get_children():
			child.show()

		return

	for child in asset_previews_cotainer.get_children():
		var asset_button = child as AssetButton
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


func show_asset_menu(item: SceneLibraryItem, button: AssetButton):
	var options_menu := PopupMenu.new()
	var preview_options = create_preview_options(item, button)
	options_menu.add_child(preview_options)
	var mouse_pos = DisplayServer.mouse_get_position()
	options_menu.add_icon_item(EditorIconTexture2D.new("File"), "Open")
	options_menu.add_icon_item(EditorIconTexture2D.new("Remove"), "Remove")
	options_menu.add_icon_item(EditorIconTexture2D.new("ShowInFileSystem"), "Show In FileSystem")
	options_menu.add_icon_item(EditorIconTexture2D.new("Reload"), "Reload Preview")
	
	options_menu.add_submenu_item("Preview Perspective", preview_options.name)
	options_menu.index_pressed.connect(func(index):
		match index:
			0: 
				EditorInterface.open_scene_from_path(item.scene.resource_path)
				EditorInterface.set_main_screen_editor("3D")
			1: 
				scene_library.delete_element(item)
				save_library()
				refresh_children()
			2: 
				EditorInterface.select_file(item.scene.resource_path)
			3:
				button.update_preview()
			_: pass
	)
	EditorInterface.popup_dialog(options_menu, Rect2(mouse_pos, options_menu.get_contents_minimum_size()))

func create_preview_options(item, button: AssetButton):
	var preview_options_menu := PopupMenu.new()
	preview_options_menu.name = "PreviewMenu"
	for option in SceneLibraryItem.PreviewMode.keys():
		preview_options_menu.add_icon_radio_check_item(null, option)
	
	preview_options_menu.set_item_checked(item.preview_mode, true)
	preview_options_menu.index_pressed.connect(func(index): on_preview_option_index_pressed(item, index, button))

	return preview_options_menu

func on_preview_option_index_pressed(item, index, button: AssetButton):
	if index == null: 
		return
	item.preview_mode = index
	button.update_preview()
	save_library()	

func update_size(size):
	scene_library.size = size
	save_library()
	for child in asset_previews_cotainer.get_children():
		var asset_button = child as AssetButton
		asset_button.update_size(size)
