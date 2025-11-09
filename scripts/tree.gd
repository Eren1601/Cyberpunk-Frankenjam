extends Node2D
@export var is_spawner: bool = false
@export var _node_id: int = 0
@export var is_big_tree: bool = false

var node_id: int:
	get: return _node_id
	
var graph: RootGraph = null
var chopped := false

func _ready() -> void:
	graph = get_tree().get_root().find_child("RootGraph", true, false)
	if graph == null:
		push_warning("Tree.gd: RootGraph not found in scene.")
	if is_spawner:
		add_to_group("enemy_spawners")

func chop_down() -> void:
	if chopped: return
	chopped = true
	visible = false
	if graph:
		graph.set_node_enabled(node_id, false)
