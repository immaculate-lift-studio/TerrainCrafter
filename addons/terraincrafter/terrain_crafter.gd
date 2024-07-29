@icon("res://addons/terraincrafter/assets/icons/terraincrafter_node.png")
extends Node3D

@export_group("Dependencies")
@export var player: NodePath
@export var base_mesh_instance: MeshInstance3D
@export var chunks_node: Node3D
@export var noise: FastNoiseLite
@export_group("Generation")
@export var chunk_size: int = 2048
@export var render_distance: int = 5  # Increased render distance to reduce pop-in
@export var noise_amplitude: float = 650.0
@export var print_statistics: bool = true
@export_group("LOD")
@export var high_lod_distance: float = 2048.0  # Increased to keep high LOD farther away
@export var medium_lod_distance: float = 4096.0  # Increased to keep medium LOD farther away
@export var high_resolution: int = 64
@export var medium_resolution: int = 32
@export var low_resolution: int = 16

var chunks: Dictionary = {}
var player_node: Node3D
var chunks_to_create: Dictionary = {}
var create_chunk_timer: Timer
var max_chunks: int = 200  # Increased max chunks to handle larger render distance

var chunk_thread: Thread
var chunk_mutex: Mutex
var exit_thread: bool = false
var chunk_semaphore: Semaphore
var chunk_creation_timer: Timer

func _ready() -> void:
	player_node = get_node(player) as Node3D
	_generate_initial_chunks()
	create_chunk_timer = Timer.new()
	create_chunk_timer.wait_time = 0.2  
	create_chunk_timer.one_shot = false
	create_chunk_timer.connect("timeout", Callable(self, "_on_create_chunk_timeout"))
	add_child(create_chunk_timer)
	create_chunk_timer.start()

	# Initialize thread, mutex, and semaphore
	chunk_mutex = Mutex.new()
	chunk_semaphore = Semaphore.new()
	chunk_thread = Thread.new()
	chunk_thread.start(Callable(self, "_thread_create_chunks"))

	# Start a timer to signal the semaphore at regular intervals
	chunk_creation_timer = Timer.new()
	chunk_creation_timer.wait_time = 0.05 # Adjust the interval as needed
	chunk_creation_timer.one_shot = false
	chunk_creation_timer.connect("timeout", Callable(self, "_on_chunk_creation_timer_timeout"))
	add_child(chunk_creation_timer)
	chunk_creation_timer.start()

func _process(_delta: float) -> void:
	_update_chunks()

func _exit_tree() -> void:
	# Signal the thread to exit and wait for it to finish
	exit_thread = true
	chunk_semaphore.post()  # Ensure the thread can exit
	chunk_creation_timer.stop()
	create_chunk_timer.stop()
	
	chunk_thread.wait_to_finish()

func _on_create_chunk_timeout() -> void:
	if chunks_to_create.size() > 0 and chunks.size() < max_chunks:
		var chunk_pos: Vector2 = chunks_to_create.keys()[0]
		chunks_to_create.erase(chunk_pos)
		chunk_mutex.lock()
		chunks_to_create[chunk_pos] = true
		chunk_mutex.unlock()

func _on_chunk_creation_timer_timeout() -> void:
	chunk_semaphore.post()  # Signal the semaphore at regular intervals

func _generate_initial_chunks() -> void:
	var player_pos: Vector3 = player_node.global_transform.origin
	var start_x: int = int(player_pos.x / float(chunk_size)) - render_distance
	var start_z: int = int(player_pos.z / float(chunk_size)) - render_distance
	for x in range(start_x, start_x + 2 * render_distance + 1):
		for z in range(start_z, start_z + 2 * render_distance + 1):
			var chunk_pos: Vector2 = Vector2(x, z)
			chunks_to_create[chunk_pos] = true

func _update_chunks() -> void:
	var player_pos = player_node.global_transform.origin
	var current_chunk_pos = Vector2(int(player_pos.x / chunk_size), int(player_pos.z / chunk_size))
	var removal_distance = render_distance + 3  # Added extra buffer

	# Identify and remove chunks too far away
	var chunks_to_remove = []
	for key in chunks.keys():
		if key.distance_to(current_chunk_pos) > removal_distance:
			chunks_to_remove.append(key)
	
	for key in chunks_to_remove:
		var chunk = chunks[key]
		if chunk.is_inside_tree():
			chunk.queue_free()
		chunks.erase(key)
		print("Removing chunk at: ", key)

	# Determine the range of chunks to consider for creation
	var start_x: int = int(current_chunk_pos.x) - render_distance
	var start_z: int = int(current_chunk_pos.y) - render_distance

	for x in range(start_x, start_x + 2 * render_distance + 1):
		for z in range(start_z, start_z + 2 * render_distance + 1):
			var chunk_pos: Vector2 = Vector2(x, z)
			if not chunks.has(chunk_pos) and not chunks_to_create.has(chunk_pos):
				chunks_to_create[chunk_pos] = true


func _get_lod_resolution(distance: float) -> int:
	if distance < high_lod_distance:
		return high_resolution
	elif distance < medium_lod_distance:
		return medium_resolution
	else:
		return low_resolution

func _create_chunk_data(chunk_pos: Vector2) -> Dictionary:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var uvs: PackedVector2Array = PackedVector2Array()

	var player_pos: Vector3 = player_node.global_transform.origin
	var distance: float = chunk_pos.distance_to(Vector2(player_pos.x / float(chunk_size), player_pos.z / float(chunk_size)))
	var resolution: int = _get_lod_resolution(distance)

	for x in range(resolution + 1):
		for z in range(resolution + 1):
			var world_x: float = chunk_pos.x * chunk_size + x * (chunk_size / float(resolution))
			var world_z: float = chunk_pos.y * chunk_size + z * (chunk_size / float(resolution))
			var height: float = noise.get_noise_2d(world_x, world_z) * noise_amplitude
			vertices.append(Vector3(x * (chunk_size / float(resolution)), height, z * (chunk_size / float(resolution))))
			uvs.append(Vector2(x / float(resolution), z / float(resolution)))

	for x in range(resolution):
		for z in range(resolution):
			var i: int = int(x * (resolution + 1) + z)
			indices.append(i)
			indices.append(i + resolution + 1)
			indices.append(i + 1)
			indices.append(i + 1)
			indices.append(i + resolution + 1)
			indices.append(i + resolution + 2)

	return {
		"chunk_pos": chunk_pos,
		"vertices": vertices,
		"indices": indices,
		"uvs": uvs,
		"resolution": resolution
	}

func _create_chunk(chunk_data: Dictionary) -> MeshInstance3D:
	if base_mesh_instance == null:
		print("Base mesh instance is not assigned.")
		return null

	var chunk: MeshInstance3D = base_mesh_instance.duplicate() as MeshInstance3D

	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = chunk_data["vertices"]
	arrays[Mesh.ARRAY_INDEX] = chunk_data["indices"]
	arrays[Mesh.ARRAY_TEX_UV] = chunk_data["uvs"]

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	chunk.mesh = mesh
	chunk.material_override = base_mesh_instance.material_override
	chunk.transform.origin = Vector3(chunk_data["chunk_pos"].x * chunk_size, 0, chunk_data["chunk_pos"].y * chunk_size)

	call_deferred("add_chunk_to_scene", chunk)

	chunk.create_trimesh_collision()
	if print_statistics:
		print("Chunk created at position: ", chunk.transform.origin)

	return chunk

func _thread_create_chunks() -> void:
	while not exit_thread:
		chunk_semaphore.wait()
		chunk_mutex.lock()
		if chunks_to_create.size() > 0 and chunks.size() < max_chunks:
			var chunk_pos: Vector2 = chunks_to_create.keys()[0]
			chunks_to_create.erase(chunk_pos)
			chunk_mutex.unlock()

			# Generate chunk data in the thread
			var chunk_data = _create_chunk_data(chunk_pos)

			# Add the chunk to the scene in the main thread
			chunk_mutex.lock()
			call_deferred("_create_chunk", chunk_data)
			chunk_mutex.unlock()
		else:
			chunk_mutex.unlock()

func add_chunk_to_scene(chunk: MeshInstance3D) -> void:
	chunks_node.add_child(chunk)
	chunks[Vector2(chunk.transform.origin.x / float(chunk_size), chunk.transform.origin.z / float(chunk_size))] = chunk
	if print_statistics:
		print("Chunk added to scene at position: ", chunk.transform.origin)
