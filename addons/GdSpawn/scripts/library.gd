@tool
extends Resource
class_name SceneLibrary


@export var name: String
@export var elements: Array[SceneLibraryItem]
@export var size: int = 96


@export var preview_mode: SceneLibraryItem.PreviewMode = SceneLibraryItem.PreviewMode.Default

func add_element(path: String):
	var scene = load(path)
	for element in elements:
		if element.scene == scene:
			return

	var item = SceneLibraryItem.new()
	item.scene = scene

	var preview = SceneTexture.new()
	preview.scene = scene


	elements.append(item)


func delete_element(element: SceneLibraryItem):
	elements.erase(element)