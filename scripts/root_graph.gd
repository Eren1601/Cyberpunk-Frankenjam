# scripts/RootGraph.gd
# Holds the logical graph of the root network. Nodes map 1:1 to trees in ForestLayer.

class_name RootGraph
extends Node

@export_group("Automated Connection Parameters")
@export var min_connect_radius := 200.0
@export var max_connect_radius := 300.0


class RootNode:
	var id: int
	var pos: Vector2
	var enabled: bool = true
	var is_spawner: bool = true
	var is_big_tree: bool = false

class RootEdge:
	var a_id: int
	var b_id: int
	var cost: float = 1.0

var nodes: Dictionary = {}            # id -> RootNode
var edges: Array[RootEdge] = []
var adj: Dictionary = {}              # id -> Array[[neighbor_id, cost]]

signal graph_changed
signal node_toggled(id: int, enabled: bool)

func add_node(id: int, pos: Vector2, is_spawner: bool = false, is_big_tree: bool = false) -> void:
	var n := RootNode.new()
	n.id = id
	n.pos = pos
	n.is_spawner = is_spawner
	n.is_big_tree = is_big_tree
	nodes[id] = n

func add_edge(a_id: int, b_id: int, cost := 1.0) -> void:
	var edge := RootEdge.new()
	edge.a_id = a_id
	edge.b_id = b_id
	edge.cost = cost
	edges.append(edge)
	if not adj.has(a_id):
		adj[a_id] = []
	adj[a_id].append([b_id, cost])
	if not adj.has(b_id):
		adj[b_id] = []
	adj[b_id].append([a_id, cost])
	emit_signal("graph_changed")

func set_node_enabled(id: int, enabled: bool) -> void:
	if nodes.has(id):
		nodes[id].enabled = enabled
		emit_signal("node_toggled", id, enabled)
		emit_signal("graph_changed")

func get_world_bounds() -> Rect2:
	# Computes world-space AABB from current node positions (for overlay scaling)
	if nodes.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var x_values: Array[float] = []
	var y_values: Array[float] = []
	for n in nodes.values():
		#if n.is_spawner:
			#print("skipped spawner in bounds calculation")
			#continue
		x_values.append(n.pos.x)
		y_values.append(n.pos.y)
	x_values.sort()
	y_values.sort()
	var minp := Vector2(x_values[0], y_values[0])
	var maxp := Vector2(x_values.back(), y_values.back())
	return Rect2(minp, maxp - minp)

func shortest_path(start_id: int, goal_id: int) -> Array[int]:
	# Simple A* on the node graph. Skips disabled nodes.
	if !nodes.has(start_id) or !nodes.has(goal_id):
		return []
	if !nodes[start_id].enabled or !nodes[goal_id].enabled:
		return []

	var open: Array[int] = []                  # open set of node ids
	var came_from: Dictionary[int, int] = {}   # child -> parent
	var g: Dictionary[int, float] = {}
	var f: Dictionary[int, float] = {}
	for id in nodes.keys():
		g[id] = INF
		f[id] = INF
	g[start_id] = 0.0
	f[start_id] = (nodes[start_id].pos - nodes[goal_id].pos).length()
	open.append(start_id)

	while !open.is_empty():
		var current: int = _pop_lowest_f(open, f)
		if current == goal_id:
			return _reconstruct_path(came_from, current)

		var neighbors: Array = adj.get(current, [])
		for pair in neighbors:
			# pair is [neighbor_id, cost]
			var nb: int = int(pair[0])
			var cost: float = float(pair[1])
			if !nodes[nb].enabled:
				continue
			var tentative: float = g[current] + cost
			if tentative < g[nb]:
				came_from[nb] = current
				g[nb] = tentative
				f[nb] = tentative + (nodes[nb].pos - nodes[goal_id].pos).length()
				if nb not in open:
					open.append(nb)
	return []
	
func _pop_lowest_f(open: Array[int], f: Dictionary[int, float]) -> int:
	var best_idx: int = 0
	var best_id: int = open[0]
	var best_val: float = f[best_id]
	for i in range(1, open.size()):
		var nid: int = open[i]
		var val: float = f[nid]
		if val < best_val:
			best_val = val
			best_idx = i
			best_id = nid
	open.remove_at(best_idx)
	return best_id

func _reconstruct_path(came_from: Dictionary, current: int) -> Array[int]:
	var path: Array[int] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

func clear_graph():
	nodes.clear()
	edges.clear()
	adj.clear()
	emit_signal("graph_changed")

func _ready() -> void:
	# Optional: bootstrap from placed Tree nodes (hand-built level)
	# 1) Collect Tree nodes from ForestLayer/Trees and add as graph nodes
	# 2) Define edges manually here for now (edit this block per level)
	var trees_root := get_tree().get_root().find_child("Trees", true, false)
	if trees_root:
		for t in trees_root.get_children():
			if "node_id" in t:
				var tid: int = int(t.node_id)
				add_node(tid, (t as Node2D).global_position, t.is_spawner, t.is_big_tree)
			else:
				printerr("Tree has no node_ID")
		auto_connect_by_radius(min_connect_radius, max_connect_radius, 12345, -1, true)
	else:
		printerr("no Trees Node found")

func _has_edge(a_id: int, b_id: int) -> bool:
	for e in edges:
		if (e.a_id == a_id and e.b_id == b_id) or (e.a_id == b_id and e.b_id == a_id):
			return true
	return false

func _degree_of(nid: int) -> int:
	var d: int = 0
	for e in edges:
		if e.a_id == nid or e.b_id == nid:
			d += 1
	return d

func get_spawn_nodes() -> Array[int]:
	var out: Array[int] = []
	for id in nodes.keys():
		if nodes[id].enabled and nodes[id].is_spawner:
			out.append(id)
	return out
	
func set_active_spawn_nodes(active_node_ids: Array[int] ):
	for n in nodes:
		# wenn id von n die id von einem der array Einträge matcht, dann setze enabled auf true
		# setze alle anderen spawner nodes auf enabeled = false
		# redrawe, damit die farben der Kreise geupdated werden
		pass

func auto_connect_by_radius(min_r: float, max_r: float, seed: int = 12345, max_degree: int = -1, use_distance_cost: bool = true) -> void:
	# For each node, pick a random connection radius in [min_r, max_r].
	# Then connect all node pairs whose distance <= min(r_i, r_j),
	# respecting optional max_degree per node. Edge cost = distance or 1.0.
	if nodes.size() < 2:
		printerr("less than 2 Nodes")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var radii: Dictionary[int, float] = {}
	for id in nodes.keys():
		radii[id] = rng.randf_range(min_r, max_r)

	# Consider each unordered pair (i<j)
	var ids: Array[int] = []
	for id in nodes.keys():
		ids.append(id)
	ids.sort() # stable order ensures deterministic pairs for a given seed

	for i in range(ids.size() - 1):
		var a_id: int = ids[i]
		for j in range(i + 1, ids.size()):
			var b_id: int = ids[j]
			var pa: Vector2 = nodes[a_id].pos
			var pb: Vector2 = nodes[b_id].pos
			var d: float = pa.distance_to(pb)
			var r_thresh: float = min(radii[a_id], radii[b_id])
			if d <= r_thresh:
				if !_has_edge(a_id, b_id):
					if max_degree > 0 and (_degree_of(a_id) >= max_degree or _degree_of(b_id) >= max_degree):
						continue
					var cost: float = (d if use_distance_cost else 1.0)
					add_edge(a_id, b_id, cost)
 
	# Emit once at end to avoid repeated redraws if you prefer. Here add_edge already emits.
	emit_signal("graph_changed")

# Liefert eine gesampelte Bezier-Kurve zwischen zwei Nodes im Welt-Raum.
# Wird u. a. von RootOverlay für das Zeichnen und Gegnerbewegung genutzt.
func get_edge_polyline(a_id: int, b_id: int, steps: int = 24) -> PackedVector2Array:
	var result := PackedVector2Array()

	# Sicherstellen, dass beide Nodes existieren
	if !nodes.has(a_id) or !nodes.has(b_id):
		return result

	var pa: Vector2 = nodes[a_id].pos
	var pb: Vector2 = nodes[b_id].pos

	# Mitte und optionale Krümmung
	var mid: Vector2 = (pa + pb) * 0.5
	var ctrl_offset: Vector2 = Vector2.ZERO

	# Prüfen, ob Edge-Infos (ctrl_offset etc.) existieren
	for e in edges:
		if (e.a_id == a_id and e.b_id == b_id) or (e.a_id == b_id and e.b_id == a_id):
			if "ctrl_offset" in e:
				ctrl_offset = e.ctrl_offset
			break

	var p1: Vector2 = mid + ctrl_offset

	# Punkte entlang der quadratischen Bezier-Kurve generieren
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		var p: Vector2 = (u * u) * pa + (2.0 * u * t) * p1 + (t * t) * pb
		result.append(p)

	return result
