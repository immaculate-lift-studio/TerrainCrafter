extends Control

@export var debug_enabled: bool = true
@export var terrain_crafter_node: NodePath
@export var player: NodePath

var show_debug: bool = true

@onready var chunks_label: Label = $VBoxContainer/ChunksLabel
@onready var position_label: Label = $VBoxContainer/PositionLabel
@onready var fps_label: Label = $VBoxContainer/FPSLabel

func _ready():
	if terrain_crafter_node == null or player == null:
		print("Please set the terrain generator and player node paths in the inspector")
		set_process(false)
		return

	set_process(true)
	show_debug = debug_enabled
	self.visible = show_debug
	_update_debug_info()

func _process(_delta):
	if Input.is_action_just_pressed("toggle_debug"):
		show_debug = not show_debug
		self.visible = show_debug

	if show_debug:
		_update_debug_info()

func _update_debug_info():
	var terrain_node = get_node(terrain_crafter_node)
	var player_node = get_node(player)
	var chunks_count = terrain_node.chunks.size()
	chunks_label.text = "Chunks: %d" % chunks_count
	var player_position = player_node.global_transform.origin
	position_label.text = "Position: (%.2f, %.2f)" % [player_position.x, player_position.z]
	var fps = Engine.get_frames_per_second()
	var frame_time = 1.0 / fps
	fps_label.text = "FPS: %d (Frame Time: %.2f ms)" % [fps, frame_time * 1000.0]
