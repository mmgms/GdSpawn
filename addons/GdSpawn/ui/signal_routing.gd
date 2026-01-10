@tool
extends Node
class_name GdSpawnSignalRouting


signal ItemPlacementBasisSet(item: GdSpawnSceneLibraryItem)

# also deselect when item null
signal ItemSelect(item: GdSpawnSceneLibraryItem)

signal GridTrasformChanged(transform: Transform3D)


var last_item_selected = null

func _ready() -> void:
	ItemSelect.connect(on_item_select)


func on_item_select(item):
	last_item_selected = item