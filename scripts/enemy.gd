extends Node2D

@export var current_node: int = 0
@export var goal_node: int = 0
@export var speed_px_per_s: float = 30.0  # movement in UI pixels per second

var graph: RootGraph                      # requires `class_name RootGraph` in RootGraph.gd
var overlay: Node                         # RootOverlay; we will call world_to_ui() via call()
var enemy_layer: Node2D                   # parent space for UI-local movement
var anim_sprite: AnimatedSprite2D

var path: Array[int] = []
var poly_ui_local: PackedVector2Array = PackedVector2Array()
var seg: int = 0
var seg_len: float = 0.0
var seg_t: float = 0.0  # 0..1 along current segment

func _ready() -> void:
	# Locate dependencies by name
	graph = get_tree().get_root().find_child("RootGraph", true, false)
	overlay = get_tree().get_root().find_child("RootOverlay", true, false)
	enemy_layer = get_tree().get_root().find_child("EnemyLayer", true, false)

	anim_sprite = $AnimatedSprite2D

	if graph == null or overlay == null:
		push_warning("MinimapEnemy: Missing RootGraph or RootOverlay.")
		queue_free()
		return

	# Ensure we live under EnemyLayer (create if missing)
	if enemy_layer == null:
		var ui := get_tree().get_root().find_child("UI", true, false)
		if ui == null:
			push_warning("MinimapEnemy: 'UI' CanvasLayer not found.")
			queue_free()
			return
		enemy_layer = Node2D.new()
		enemy_layer.name = "EnemyLayer"
		ui.add_child(enemy_layer)

	if get_parent() != enemy_layer:
		enemy_layer.add_child(self)

	anim_sprite.play()
	graph.connect("graph_changed", Callable(self, "_on_graph_changed"))
	_plan()
	_load_edge_poly_ui_local()
	if poly_ui_local.size() > 0:
		position = poly_ui_local[0]  # local to EnemyLayer

func _on_graph_changed() -> void:
	_plan()
	_load_edge_poly_ui_local()

func _process(delta: float) -> void:
	if poly_ui_local.size() < 2:
		return

	var remain: float = speed_px_per_s * delta
	while remain > 0.0 and seg < poly_ui_local.size() - 1:
		var a: Vector2 = poly_ui_local[seg]
		var b: Vector2 = poly_ui_local[seg + 1]

		if seg_len <= 0.0:
			seg_len = a.distance_to(b)
			seg_t = 0.0
			if seg_len <= 0.0001:
				seg += 1
				seg_len = 0.0
				continue

		var step: float = min(remain, seg_len * (1.0 - seg_t))
		var dt: float = step / seg_len
		seg_t += dt
		position = a.lerp(b, seg_t)  # LOCAL (EnemyLayer space)

		remain -= step

		if seg_t >= 0.9999:
			seg += 1
			seg_len = 0.0
			seg_t = 0.0

	if seg >= poly_ui_local.size() - 1:
		# advance path or finish
		if path.size() >= 2:
			current_node = path[1]
			path.pop_front()
			_load_edge_poly_ui_local()
		else:
			queue_free()

func _plan() -> void:
	path = graph.shortest_path(current_node, goal_node)

func _load_edge_poly_ui_local() -> void:
	poly_ui_local = PackedVector2Array()
	seg = 0
	seg_len = 0.0
	seg_t = 0.0
	if path.size() < 2:
		return

	var a_id: int = path[0]
	var b_id: int = path[1]
	# World-space polyline of the curved edge
	var poly_world: PackedVector2Array = graph.get_edge_polyline(a_id, b_id, 24)
	if poly_world.size() == 0:
		return

	# Map to UI and then to EnemyLayer local space
	for pw in poly_world:
		# overlay.world_to_ui(pw) is called via Variant; type the variable explicitly
		var p_ui: Vector2 = overlay.call("world_to_ui", pw)
		var p_local: Vector2 = enemy_layer.to_local(p_ui)
		poly_ui_local.append(p_local)
