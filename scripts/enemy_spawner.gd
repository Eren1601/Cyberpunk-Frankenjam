# scripts/EnemySpawner.gd
extends Node

signal minimap_spawn_requested(start_node: int, goal_node: int, speed_px_per_s: float)

@export var goal_node: int = 0
@export var enemy_speed_px: float = 80.0  # UI-Pixel pro Sekunde

# Wave timing
@export var wave_interval: float = 30.0          # seconds between waves
@export var spawn_spacing: float = 0.35          # seconds between spawns inside a wave

# Wave size & scaling
@export var enemies_per_wave: int = 3            # base number per wave
@export var wave_growth: int = 3                # how many more enemies each next wave
@export var max_spawn_locations: int = 2         # unique spawn nodes to pick per wave

# Randomness
@export var random_seed: int = -1                # -1 => random at runtime

# --- Runtime state ---
var graph: RootGraph
var rng := RandomNumberGenerator.new()

var current_wave: int = 1
var in_wave: bool = false
var wave_timer: float = 0.0
var spawn_timer: float = 0.0

var selected_spawn_nodes: Array[int] = []
var to_spawn_in_wave: int = 0
var spawn_index: int = 0   # cycles through selected locations

func _ready() -> void:
	# RNG init
	if random_seed < 0:
		rng.randomize()
	else:
		rng.seed = int(random_seed)

	# Find graph by name (no need to wire in inspector)
	graph = get_tree().get_root().find_child("RootGraph", true, false)
	if graph == null:
		push_warning("EnemySpawner: RootGraph not found. Name your graph node 'RootGraph'.")
		return

	# Optional: start immediately or wait for first interval
	_start_next_wave()

func _process(delta: float) -> void:
	if graph == null:
		printerr("graph is null")
		return

	if !in_wave:
		# between waves
		wave_timer += delta
		if wave_timer >= wave_interval:
			_start_next_wave()
	else:
		# inside wave
		if to_spawn_in_wave <= 0:
			_end_wave()
			return

		spawn_timer += delta
		if spawn_timer >= spawn_spacing:
			spawn_timer = 0.0
			_spawn_one_from_selection()

# --- Wave lifecycle ---

func _start_next_wave() -> void:
	# pick spawn locations for this wave
	selected_spawn_nodes = select_locations_for_next_wave()
	if selected_spawn_nodes.is_empty():
		# no valid spawn nodes -> postpone and try later
		in_wave = false
		wave_timer = 0.0
		return

	in_wave = true
	wave_timer = 0.0
	spawn_timer = 0.0
	spawn_index = 0
	to_spawn_in_wave = enemies_per_wave + (current_wave - 1) * wave_growth

func _end_wave() -> void:
	in_wave = false
	current_wave += 1
	wave_timer = 0.0
	spawn_timer = 0.0

# --- Selection & Spawning ---

func select_locations_for_next_wave() -> Array[int]:
	# Get all enabled spawn nodes from graph
	if !graph or !graph.has_method("get_spawn_nodes"):
		return []
	var candidates: Array[int] = graph.get_spawn_nodes()
	if candidates.is_empty():
		return []

	# Shuffle candidates deterministically per wave (so replays are stable if seeded)
	_shuffle_in_place(candidates)
	# Limit to max_spawn_locations (but at least 1)
	var k : int = max(1, max_spawn_locations)
	if candidates.size() > k:
		candidates.resize(k)
	print_debug(candidates)
	#TODO Spawner auf enabled setzen
		
	return candidates

func _spawn_one_from_selection() -> void:
	if graph == null or selected_spawn_nodes.is_empty():
		return
	var loc_id: int = selected_spawn_nodes[spawn_index % selected_spawn_nodes.size()]
	spawn_index += 1
	# Statt Szene: Signal an Overlay
	emit_signal("minimap_spawn_requested", loc_id, goal_node, enemy_speed_px)
	to_spawn_in_wave -= 1


func _shuffle_in_place(arr: Array[int]) -> void:
	# Fisher–Yates with RNG
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
