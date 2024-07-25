extends MeshInstance3D

@export var ship: NodePath  # Path to the ship node
@export var follow_height: float = 0.0  # Height at which the water should follow

func _ready():
	if ship == null:
		print("Please set the ship node path in the inspector")
		set_process(false)
		return

	set_process(true)

func _process(_delta):
	var ship_node = get_node(ship)
	if ship_node:
		var ship_position = ship_node.global_transform.origin
		global_transform.origin = Vector3(ship_position.x, follow_height, ship_position.z)
