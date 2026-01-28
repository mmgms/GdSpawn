@tool
extends Resource
class_name GdSpawnSceneLibrary


@export var name: String
@export var elements: Array[GdSpawnSceneLibraryItem]
@export var size: int = 96


@export var preview_mode: GdSpawnSceneLibraryItem.PreviewMode = GdSpawnSceneLibraryItem.PreviewMode.Default

func add_element(path: String):
	var scene = load(path)
	for element in elements:
		if element.scene == scene:
			return

	var item = GdSpawnSceneLibraryItem.new()
	item.scene = scene

	elements.append(item)


func delete_element(element: GdSpawnSceneLibraryItem):
	elements.erase(element)