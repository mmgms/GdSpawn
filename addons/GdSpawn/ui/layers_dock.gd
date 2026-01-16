@tool
extends PanelContainer
class_name GdSpawnLayersDock

@export var signal_routing: GdSpawnSignalRouting

@export var add_layer_button: Button
@export var layer_name_text_edit: LineEdit

@export var filter_line_edit: LineEdit

@export var batch_hide_button: Button
@export var batch_show_button: Button
@export var batch_delete_button: Button

@export var select_spawn_under: Button

@export var assign_to_layer: Button

@export var show_in_tree: Button

@export var trees_parent: Control


var current_tree: Tree

enum ButttonIds {Visibility, Delete}

var hide_icon: EditorIconTexture2D
var show_icon: EditorIconTexture2D
var delete_icon: EditorIconTexture2D

func _ready() -> void:
	hide_icon = EditorIconTexture2D.new()
	hide_icon.icon_name = "GuiVisibilityHidden"

	show_icon = EditorIconTexture2D.new()
	show_icon.icon_name = "GuiVisibilityVisible"

	delete_icon = EditorIconTexture2D.new()
	delete_icon.icon_name = "ImportFail"

	add_layer_button.pressed.connect(on_add_layer)
	signal_routing.EditedSceneChanged.connect(on_scene_changed)
	signal_routing.SceneSaved.connect(on_scene_saved)
	on_scene_changed(EditorInterface.get_edited_scene_root())

	batch_hide_button.pressed.connect(func (): on_batch_set_visibility_button(false))
	batch_show_button.pressed.connect(func (): on_batch_set_visibility_button(true))
	batch_delete_button.pressed.connect(on_batch_delete)

	select_spawn_under.pressed.connect(on_select_spawn_under)

	assign_to_layer.pressed.connect(on_assign_selected_to_layer)

	filter_line_edit.text_changed.connect(on_filter_text_changed)

	show_in_tree.pressed.connect(show_in_scene_tree)

func on_assign_selected_to_layer():
	if not current_tree:
		return

	var selected = current_tree.get_selected()
	if not selected:
		return

	var new_parent_node = selected.get_metadata(0)

	var selection = EditorInterface.get_selection()
	var nodes = selection.get_selected_nodes()

	for node in nodes:
		node.reparent(new_parent_node)

func show_in_scene_tree():
	if not current_tree:
		return

	var selected = current_tree.get_selected()
	if not selected:
		return

	EditorInterface.edit_node(selected.get_metadata(0))

func on_select_spawn_under():
	if not current_tree:
		return

	var selected = current_tree.get_selected()
	if not selected:
		return

	signal_routing.SpawnUnderNodeChanged.emit(selected.get_metadata(0))

	
func on_filter_text_changed(filter):
	if not current_tree:
		return

	_filter_item_recursive(current_tree.get_root(), filter.to_lower())

func _filter_item_recursive(item: TreeItem, filter: String) -> bool:
	if item == null:
		return false

	var matches := false

	# Check all columns
	if item.get_text(0).to_lower().contains(filter):
		matches = true

	# Check children
	var child := item.get_first_child()
	while child:
		var child_matches := _filter_item_recursive(child, filter)
		matches = matches or child_matches
		child = child.get_next()

	# Show parent if any child matches
	item.visible = (filter == "" or matches)

	# Expand matching branches
	if matches and filter != "":
		item.set_collapsed(false)

	return matches

func on_batch_set_visibility_button(visible: bool):
	if not current_tree:
		return
	
	var first_selected = current_tree.get_next_selected(null)
	if first_selected == null:
		return
	var next_selected = first_selected
	while next_selected:
		var node = next_selected.get_metadata(0)
		if node:
			if not visible:
				node.hide()
				next_selected.set_button(0, ButttonIds.Visibility, hide_icon)
			else:
				node.show()
				next_selected.set_button(0, ButttonIds.Visibility, show_icon)
		next_selected = current_tree.get_next_selected(next_selected)

func on_batch_delete():
	return

func on_scene_changed(scene_root):

	for child in trees_parent.get_children():
		child.queue_free()

	if scene_root == null:
		return

	if not scene_root is Node3D:
		return


	var tree = Tree.new()
	tree.select_mode = Tree.SELECT_MULTI
	populate_tree(scene_root, tree)
	connect_tree_signals(tree)

	trees_parent.add_child(tree)
	tree.show()
	current_tree = tree

func on_scene_saved(scene_file):
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root.scene_file_path == scene_file:
		on_scene_changed(scene_root)
	

func on_add_layer():
	var node_name = layer_name_text_edit.text
	if node_name.is_empty():
		return
	var layer = GdSpawnLayer.new()
	layer.name = node_name

	var current_selected = current_tree.get_selected()
	if not current_selected:
		current_selected = current_tree.get_root()

	var node = current_selected.get_metadata(0)

	var scene_root = EditorInterface.get_edited_scene_root()

	node.add_child(layer, true)
	layer.owner = scene_root

	current_tree.clear()
	populate_tree(scene_root, current_tree)

func connect_tree_signals(tree: Tree):
	tree.button_clicked.connect(on_tree_button_clicked)
	tree.item_edited.connect(on_item_edited)

func on_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int ):
	var node = item.get_metadata(0) as Node3D
	if not node:
		return
	if not mouse_button_index == MOUSE_BUTTON_LEFT:
		return
	if id == ButttonIds.Visibility:
		if node.visible:
			node.hide()
			item.set_button(0, ButttonIds.Visibility, hide_icon)
		else:
			node.show()
			item.set_button(0, ButttonIds.Visibility, show_icon)
	elif id == ButttonIds.Delete:
		delete_item(item)

func delete_item(item: TreeItem):
	var node = item.get_metadata(0)
	if not node:
		item.free()
		return
	var node_parent = node.get_parent()
	for child in node.get_children():
		child.reparent(node_parent)
	node.free()
	item.free()

	populate_tree(EditorInterface.get_edited_scene_root(), current_tree)


func on_item_edited():
	var item = current_tree.get_edited()
	var node = item.get_metadata(0) as Node
	if not node:
		return
	var new_node_name = item.get_text(0)
	node.name = new_node_name
	await get_tree().process_frame
	item.set_text(0, node.name)

func populate_tree(scene_root, tree: Tree):
	tree.columns = 1
	tree.clear()
	tree.hide_root = true

	var root = tree.create_item()
	root.set_metadata(0, scene_root)

	_add_nodes_recursive(scene_root, root)

	return tree


func _add_nodes_recursive(
	scene_node: Node,
	tree_parent: TreeItem,
) -> void:
	for child in scene_node.get_children():
		var child_tree_item: TreeItem = tree_parent

		# Only create a TreeItem if the node matches the type
		if child is GdSpawnLayer:
			child_tree_item = tree_parent.get_tree().create_item(tree_parent)

			child_tree_item.set_icon(0, preload("res://addons/GdSpawn/icons/GdSpawnLayer.svg"))
			child_tree_item.set_text(0, child.name)
			child_tree_item.set_editable(0, true)

			var visibility_icon = show_icon
			if not child.visible:
				visibility_icon = hide_icon
			child_tree_item.add_button(0, visibility_icon, ButttonIds.Visibility)
			child_tree_item.add_button(0, delete_icon, ButttonIds.Delete)

			child_tree_item.set_metadata(0, child)
			child_tree_item

		# Recurse even if the node itself wasn't added,
		# so deeper matching nodes are still included
		_add_nodes_recursive(child, child_tree_item)

	
