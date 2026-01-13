@tool
extends PanelContainer


@export var spawn_profile: Control

var signal_routing: GdSpawnSignalRouting


func should_show_grid():
	return false

