@tool
extends Control
class_name GdSpawnMainDockManager

@export var main_node: Control
@export var detach_button: Button
@export var help_button: Button

@export var editor_plugin: EditorPlugin

@export var spawn_manager: GdSpawnSpawnManager
@export var libraries_manager: GdSpawnLibrariesManager
@export var signal_routing: GdSpawnSignalRouting

var is_detached: bool = false

var detached_window: Window

func _enter_tree() -> void:
	spawn_manager.editor_plugin = editor_plugin

func _ready() -> void:

	detach_button.pressed.connect(on_detach_button_pressed)
	help_button.pressed.connect(on_help_button_pressed)


func on_detach_button_pressed():
	if is_detached:
		detached_window.remove_child(main_node)
		detached_window.queue_free()
		editor_plugin.attach_to_bottom_panel()
		is_detached = false
	else:
		detached_window = Window.new()
		main_node.reparent(detached_window)
		EditorInterface.popup_dialog_centered(detached_window, detached_window.get_contents_minimum_size())
		is_detached = true


func on_help_button_pressed():
	pass