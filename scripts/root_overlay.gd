# scripts/RootOverlay.gd
# ----------------------------------------------------------
# Draws the underground root network (graph) as an overlay.
# It scales and transforms world positions (tree nodes) into
# screen coordinates, and draws curved Bezier-like connections.
# ----------------------------------------------------------

extends Control
@export var canvas: CanvasLayer

@export var graph_path: NodePath
var graph: Node = null

var color_node_spawner_active: Color = Color(0.802, 0.192, 0.376, 1.0)
var color_node_spawner_inactive: Color = Color(0.361, 0.016, 0.045, 1.0)
var color_node_active: Color = Color(0.15, 0.558, 0.94, 1.0)
var color_node_disabled: Color = Color(0.12, 0.267, 0.405, 1.0)
var color_edges_active: Color = Color(0.53, 0.696, 0.89, 1.0)
var color_edges_disabled: Color = Color(0.25, 0.367, 0.5, 1.0)

# Cached world bounds for coordinate transformation
var world_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)

func _ready() -> void:
	graph = get_node_or_null(graph_path)
	if graph == null:
		graph = get_tree().get_root().find_child("RootGraph", true, false)

	if graph:
		graph.connect("graph_changed", Callable(self, "_on_graph_changed"))
		_on_graph_changed()
	else:
		printerr("RootOverlay: RootGraph not found. Set graph_path or name the node 'RootGraph'.")

	# Optional: start visible for debugging if you haven't set the Input Map yet
	visible = true

# Called whenever the graph changes (e.g. new nodes, edges, chopped trees)
func _on_graph_changed() -> void:
	if graph and graph.has_method("get_world_bounds"):
		world_rect = graph.call("get_world_bounds")
	queue_redraw()

# Converts world position to overlay position
func _world_to_ui(p: Vector2) -> Vector2:
	if world_rect.size.x == 0 or world_rect.size.y == 0:
		return Vector2.ZERO
	var rect_size := get_size()
	var scale := Vector2(rect_size.x / world_rect.size.x, rect_size.y / world_rect.size.y)
	return (p - world_rect.position) * scale

# ----------------------------------------------------------
# DRAWING
# ----------------------------------------------------------
func _process(delta: float) -> void:
	# Toggle logic; comment out if you want it always on
	if InputMap.has_action("show_map"):
		canvas.visible = Input.is_action_pressed("show_map")
	# Animate curves (wobble): redraw when visible
	if visible:
		queue_redraw()

func _draw() -> void:
	if graph == null:
		return

	# Draw edges (curvy Bezier-like lines)
	for e in graph.edges:
		var a = graph.nodes.get(e.a_id)
		var b = graph.nodes.get(e.b_id)
		if a == null or b == null:
			continue
		if !a.enabled or !b.enabled:
			continue
		var pa = _world_to_ui(a.pos)
		var pb = _world_to_ui(b.pos)
		_draw_root_curve(pa, pb)

	# Draw nodes
	for n in graph.nodes.values():
		var col: Color 
		if n.is_spawner:
			col = color_node_spawner_active if n.enabled else color_node_spawner_inactive
		else:
			col = color_node_active if n.enabled else color_node_disabled
		if n.is_big_tree:
			draw_circle(_world_to_ui(n.pos), 10.0, col) 
		else:
			draw_circle(_world_to_ui(n.pos), 5.0, col) 

# Draw a single curved root between two points
func _draw_root_curve(a: Vector2, b: Vector2) -> void:
	var dir: Vector2 = (b - a)
	var n: Vector2 = Vector2(-dir.y, dir.x).normalized()
	var mid: Vector2 = (a + b) * 0.5
	var length: float = max(dir.length(), 1.0)
	var wobble: float = 0.025 * length
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var offset: Vector2 = n * (sin(t + a.x * 0.01 + b.y * 0.01) * wobble)

	var p0: Vector2 = a
	var p1: Vector2 = mid + offset
	var p2: Vector2 = b

	var last: Vector2 = p0
	var steps: int = int(clamp(length / 10.0, 8.0, 64.0))
	for i in range(1, steps + 1):
		var tt: float = float(i) / steps
		var q: Vector2 = _bezier2(p0, p1, p2, tt)
		draw_line(last, q, color_edges_active, 1.5, false)
		last = q

# Quadratic Bezier interpolation helper
func _bezier2(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2
