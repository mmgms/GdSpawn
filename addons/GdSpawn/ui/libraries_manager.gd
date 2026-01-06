@tool
extends Node


@export var save_library_button: Button
@export var load_library_button: Button
@export var new_library_button: Button


@export var file_dialog: FileDialog

@export var libraries_container: TabContainer
@export var add_new_library_button: Button

@export var asset_palette_scene: PackedScene

@export var preview_size_slider: HSlider

@export var max_size: int = 128
@export var min_size: int = 64

enum SaveMode {Save, SaveAs}

var save_mode = SaveMode.Save


func _ready() -> void:
	save_library_button.pressed.connect(on_save_library)
	load_library_button.pressed.connect(on_load_library)
	new_library_button.pressed.connect(on_new_library)
	file_dialog.canceled.connect(on_cancelled)
	file_dialog.file_selected.connect(on_confirmed)

	preview_size_slider.value_changed.connect(on_preview_size_changed)

	libraries_container.get_tab_bar().select_with_rmb = true
	libraries_container.get_tab_bar().tab_rmb_clicked.connect(on_tab_clicked)

	libraries_container.tab_changed.connect(on_tab_changed)

	for child in libraries_container.get_children():
		child.queue_free()

	on_new_library()


func on_save_library(copy: bool = false):
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered()
	if copy:
		save_mode = SaveMode.SaveAs
		return
	save_mode = SaveMode.Save


func on_load_library():
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered()


func on_new_library():
	var library  = get_selected_library()
	if library and library.name.begins_with("[Empty]"):
		return
	var empty_library = SceneLibrary.new()
	empty_library.name = "[Empty]"
	var palette = asset_palette_scene.instantiate() as AssetPaletteManager
	libraries_container.add_child(palette)
	palette.set_library(empty_library)
	libraries_container.current_tab = libraries_container.get_child_count()-1
	preview_size_slider.set_value_no_signal(0.5)



func on_cancelled():
	file_dialog.hide()

func on_confirmed(path):
	if file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		load_library(path)
	else:
		if save_mode == SaveMode.Save:
			save_library(path)
		else:
			save_library(path, true)



func save_library(path: String, copy: bool=false):
	var library: SceneLibrary = (libraries_container.get_child(libraries_container.current_tab) as AssetPaletteManager).scene_library
	if copy:
		library = library.duplicate()
	library.name = path.get_file().get_basename()
	library.resource_path = path
	ResourceSaver.save(library, path)
	if not copy:
		libraries_container.get_child(libraries_container.current_tab).set_library(library)

func load_library(path):

	var library = load(path) as SceneLibrary
	for idx in libraries_container.get_children().size():
		var child = libraries_container.get_children()[idx]
		var asset_palette = child as AssetPaletteManager

		if asset_palette.scene_library == library:
			libraries_container.current_tab = idx
			return

	var current_asset_palette = (libraries_container.get_child(libraries_container.current_tab) as AssetPaletteManager)
	if current_asset_palette.scene_library.elements.is_empty():
		current_asset_palette.queue_free()

	
	var palette = asset_palette_scene.instantiate() as AssetPaletteManager
	libraries_container.add_child(palette)
	palette.set_library(library)
	libraries_container.current_tab = libraries_container.get_child_count()-1



func on_tab_clicked(tab):
	var library = (libraries_container.get_child(libraries_container.current_tab) as AssetPaletteManager).scene_library
	if library.name.begins_with("[Empty]"):
		return
	show_tab_contextual_menu(tab, library)

func show_tab_contextual_menu(tab, library):
	var options_menu := PopupMenu.new()
	var preview_options = create_preview_options(tab, library)
	options_menu.add_child(preview_options)

	var mouse_pos = DisplayServer.mouse_get_position()
	options_menu.add_icon_item(EditorIconTexture2D.new("Close"), "Close")
	options_menu.add_icon_item(EditorIconTexture2D.new("Save"), "Save As")
	options_menu.add_icon_item(EditorIconTexture2D.new("ShowInFileSystem"), "Show In FileSystem")
	options_menu.add_icon_item(EditorIconTexture2D.new("Reload"), "Reload All Previews")
	options_menu.add_icon_item(EditorIconTexture2D.new("Reload"), "Reset All Preview Perspective")
	options_menu.add_submenu_item("Preview Perspective", preview_options.name)
	options_menu.index_pressed.connect(func(index):
		match index:
			0: 
				libraries_container.get_child(tab).queue_free()
				if libraries_container.get_child_count() <= 1:
					on_new_library()
			1: 
				on_save_library(true)

			2:
				EditorInterface.select_file(library.resource_path)
			3:
				var selected_palette = get_selected_asset_palette()
				if not selected_palette:
					return
				selected_palette.update_previews()
			4:
				pass
				
			_: pass
	)
	EditorInterface.popup_dialog(options_menu, Rect2(mouse_pos, options_menu.get_contents_minimum_size()))


func create_preview_options(tab, library):
	var preview_options_menu := PopupMenu.new()
	preview_options_menu.name = "PreviewMenu"
	for option in SceneLibraryItem.PreviewMode.keys():
		preview_options_menu.add_icon_radio_check_item(null, option)
	
	#preview_options_menu.set_item_checked(item.preview_mode, true)
	#preview_options_menu.index_pressed.connect(func(index): on_preview_option_index_pressed(item, index, button))

	return preview_options_menu

func on_preview_option_index_pressed(item, index, button: AssetButton):
	if index == null: 
		return
	pass

func get_selected_asset_palette():
	if libraries_container.get_child_count() == 0:
		return null
	var library = (libraries_container.get_child(libraries_container.current_tab) as AssetPaletteManager)
	return library

func get_selected_library():
	if libraries_container.get_child_count() == 0:
		return null
	var library = (libraries_container.get_child(libraries_container.current_tab) as AssetPaletteManager).scene_library
	return library


func on_preview_size_changed(value):
	var size = min_size + int(value * (max_size - min_size))
	var selected_palette = get_selected_asset_palette()
	if not selected_palette:
		return
	selected_palette.update_size(size)


func on_tab_changed(_idx):
	var library = get_selected_library() as SceneLibrary
	
	if not library:
		return
	var slider_value = float(library.size - min_size)/(max_size-min_size)
	preview_size_slider.set_value_no_signal(slider_value)
