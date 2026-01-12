@tool
extends Control
class_name GdSpawnMainDockManager

@export var detachable_node: Control
@export var detach_button: Button
@export var help_button: Button
@export var about_button: Button


@export var editor_plugin: EditorPlugin

@export var spawn_manager: GdSpawnSpawnManager
@export var libraries_manager: GdSpawnLibrariesManager
@export var signal_routing: GdSpawnSignalRouting
@export var detached_window: Window
@export var window_panel: PanelContainer

var is_detached: bool = false


func _enter_tree() -> void:
	spawn_manager.editor_plugin = editor_plugin

func _ready() -> void:
	detached_window.hide()

	detach_button.pressed.connect(on_detach_button_pressed)
	help_button.pressed.connect(on_help_button_pressed)
	signal_routing.PluginDisabled.connect(on_plugin_disabled)
	detached_window.close_requested.connect(attach_to_dock)


func on_detach_button_pressed():

	var min_size = self.size
	
	detach_button.hide()
	detachable_node.reparent(window_panel)
	
	detached_window.popup_centered(min_size)
	is_detached = true


func attach_to_dock():
	detach_button.show()
	detached_window.hide()
	detachable_node.reparent(self)
	is_detached = false


func on_help_button_pressed():
	pass

func on_plugin_disabled():
	return
	if detached_window:
		detached_window.queue_free()