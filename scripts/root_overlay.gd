# scripts/RootOverlay.gd
# ----------------------------------------------------------
# Draws the underground root network (graph) as an overlay.
# It scales and transforms world positions (tree nodes) into
# screen coordinates, and draws curved Bezier-like connections.
# ----------------------------------------------------------
extends Control

class MinimapEnemyToken:
	var path: Array[int] = []                    # Node-ID-Pfad
	var seg: int = 0                             # aktueller Pfad-Index (zwischen path[seg] und path[seg+1])
	var poly: PackedVector2Array = PackedVector2Array()  # aktuelle Kanten-Polyline (world-space)
	var poly_i: int = 0                          # Index innerhalb der Polyline
	var pos_world: Vector2 = Vector2.ZERO        # aktuelle Weltposition
	var speed_ui: float = 20.0                   # Bewegungsgeschwindigkeit in UI-Pixeln/s
	var born_t: float = 0.0                      # für Blinken
	var color: Color = Color(0.9, 0.15, 0.15)

var tokens: Array[MinimapEnemyToken] = []

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
		_on_root_graph_changed()
	else:
		printerr("RootOverlay: RootGraph not found. Set graph_path or name the node 'RootGraph'.")

	# Optional: start visible for debugging if you haven't set the Input Map yet
	visible = true
	
	# Alle EnemySpawner finden und ihr Signal anbinden:
	var spawners := get_tree().get_nodes_in_group("enemy_spawners")
	for s in spawners:
		s.connect("minimap_spawn_requested", Callable(self, "_on_minimap_spawn_requested"))

# Converts world position to overlay position
func _world_to_ui(p: Vector2) -> Vector2:
	if world_rect.size.x == 0 or world_rect.size.y == 0:
		return Vector2.ZERO
	var rect_size := get_size()
	var scale := Vector2(rect_size.x / world_rect.size.x, rect_size.y / world_rect.size.y)
	return (p - world_rect.position) * scale

# Public helper so other nodes can convert world->ui
func world_to_ui(p: Vector2) -> Vector2:
	return _world_to_ui(p)

# Public helper for vectors (no translation)
func world_vec_to_ui(v: Vector2) -> Vector2:
	var rect_size: Vector2 = get_size()
	var sx : float = rect_size.x / max(world_rect.size.x, 1.0)
	var sy : float = rect_size.y / max(world_rect.size.y, 1.0)
	return Vector2(v.x * sx, v.y * sy)

# ----------------------------------------------------------
# DRAWING
# ----------------------------------------------------------
func _process(delta: float) -> void:
	#Toggle logic; comment out if you want it always on
	if InputMap.has_action("show_map"):
		canvas.visible = Input.is_action_pressed("show_map")
	# Animate curves (wobble): redraw when visible
	if visible:
		queue_redraw()
	
	_update_tokens(delta)

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
			
	# Draw Enemy (blinkende Punkte)
	var now_t: float = Time.get_ticks_msec() * 0.001
	for t in tokens:
		var p_ui: Vector2 = world_to_ui(t.pos_world)
		# Blink: 2 Hz, weiches Pulsieren
		var alpha: float = 0.35 + 0.65 * 0.5 * (1.0 + sin(4.0 * PI * 2.0 * (now_t - t.born_t)))
		var col := t.color
		col.a = clamp(alpha, 0.2, 1.0)
		draw_circle(p_ui, 3.0, col)
		# Optional: dünner dunkler Rand:
		#draw_arc(p_ui, 4.5, 0.0, TAU, 12, Color(0.15, 0.05, 0.05, col.a), 1.0, true)

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
	
func _update_tokens(delta: float) -> void:
	if tokens.is_empty():
		return

	# UI-Geschwindigkeit → world pro Segment variabel: wir gehen über UI-Länge der Polyline
	# Strategie: wir bewegen entlang der gespeicherten world-Polyline,
	# rechnen aber Schrittweite in UI-Pixeln, indem wir world-Segmente in UI umwandeln.
	var alive: Array[MinimapEnemyToken] = []
	for t in tokens:
		var remain_ui: float = t.speed_ui * delta
		while remain_ui > 0.0:
			if t.poly.size() < 2 or t.poly_i >= t.poly.size() - 1:
				# nächste Kante im Pfad
				t.seg += 1
				if t.seg >= t.path.size() - 1:
					# Ziel erreicht -> Token verschwindet
					t = null
					break
				t.poly = graph.get_edge_polyline(t.path[t.seg], t.path[t.seg + 1], 24)
				t.poly_i = 0
				if t.poly.size() == 0:
					t = null
					break

				if t == null:
					break

			var a_w: Vector2 = t.poly[t.poly_i]
			var b_w: Vector2 = t.poly[t.poly_i + 1]
			var a_ui: Vector2 = world_to_ui(a_w)
			var b_ui: Vector2 = world_to_ui(b_w)
			var seg_len_ui: float = a_ui.distance_to(b_ui)
			if seg_len_ui <= 0.0001:
				t.poly_i += 1
				continue

			var step_ui: float = min(remain_ui, seg_len_ui)
			var ratio: float = step_ui / seg_len_ui
			# Interpolation in *world*-Koordinaten anhand des UI-Ratios (ok, da linear)
			t.pos_world = a_w.lerp(b_w, ratio)
			remain_ui -= step_ui

			if step_ui >= seg_len_ui - 0.0001:
				t.poly_i += 1  # nächstes Segment

		if t != null:
			alive.append(t)

	tokens = alive


func _on_enemy_spawner_minimap_spawn_requested(start_node: int, goal_node: int, speed_px_per_s: float) -> void:
	if graph == null:
		return
	var path_ids: Array[int] = graph.shortest_path(start_node, goal_node)
	if path_ids.size() < 2:
		return
	var tok := MinimapEnemyToken.new()
	tok.path = path_ids
	tok.seg = 0
	tok.poly = graph.get_edge_polyline(path_ids[0], path_ids[1], 24)  # world-space Punkte
	tok.poly_i = 0	
	if tok.poly.size() > 0:
		tok.pos_world = tok.poly[0]
	
	tok.speed_ui = speed_px_per_s
	tok.born_t = Time.get_ticks_msec() * 0.001
	tokens.append(tok)


func _on_root_graph_changed() -> void:
	if graph and graph.has_method("get_world_bounds"):
		world_rect = graph.call("get_world_bounds")
	queue_redraw()
	
