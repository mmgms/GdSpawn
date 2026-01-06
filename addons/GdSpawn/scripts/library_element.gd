@tool
extends Resource
class_name SceneLibraryItem


enum PreviewMode {Default, Front, Back, Top, Bottom, Left, Right}

@export var scene: PackedScene


@export var preview_mode: PreviewMode = PreviewMode.Default
@export var preview_info: PreviewInfo