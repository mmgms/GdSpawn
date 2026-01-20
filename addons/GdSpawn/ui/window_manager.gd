@tool
extends Control
class_name GdSpawnMainDockManager

@export var detachable_node: Control
@export var detach_button: Button
@export var help_button: Button
@export var about_button: Button
@export var help_popup: PopupPanel


@export var editor_plugin: EditorPlugin

@export var spawn_manager: GdSpawnSpawnManager
@export var libraries_manager: GdSpawnLibrariesManager
@export var signal_routing: GdSpawnSignalRouting
@export var detached_window: Window
@export var window_panel: PanelContainer

@export var version_label: Label

var is_detached: bool = false


func _enter_tree() -> void:
	spawn_manager.editor_plugin = editor_plugin

func _ready() -> void:
	detached_window.hide()

	detach_button.pressed.connect(on_detach_button_pressed)
	help_button.pressed.connect(on_help_button_pressed)
	signal_routing.PluginDisabled.connect(on_plugin_disabled)
	detached_window.close_requested.connect(attach_to_dock)
	version_label.text = "GdSpawn %s" % get_plugin_version()


func get_plugin_version() -> String:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://addons/GdSpawn/plugin.cfg")
	if err != OK:
		push_error("Failed to load plugin.cfg")
		return ""

	return cfg.get_value("plugin", "version", "")



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
	help_popup.popup_centered(help_popup.get_contents_minimum_size())

func on_plugin_disabled():
	return
	if detached_window:
		detached_window.queue_free()