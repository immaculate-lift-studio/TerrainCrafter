extends CharacterBody3D

@export var min_flight_speed: int = 12
@export var max_flight_speed: int = 200
@export var turn_speed: float = 0.4
@export var pitch_speed: float = 0.3
@export var level_speed: float = 2.0
@export var throttle_delta: float = 50.0
@export var acceleration: float = 50.0

var forward_speed: float = 0.0
var target_speed: float = 0.0
var grounded: bool = false
var turn_input: float = 0.0
var pitch_input: float = 0.0

@onready var mesh: Node3D = $Ship
@onready var raycast: RayCast3D = $RayCast3D  # Reference to the RayCast3D node

# Reference to the HUD labels
@export var speed_label: Label
@export var altitude_label: Label
@export var direction_label: Label

func get_input(delta: float) -> void:
	if Input.is_action_pressed("throttle_up"):
		target_speed = min(forward_speed + throttle_delta * delta, max_flight_speed)
	if Input.is_action_pressed("throttle_down"):
		var limit: int = 0 if grounded else min_flight_speed
		target_speed = max(forward_speed - throttle_delta * delta, limit)

	turn_input = Input.get_axis("roll_right", "roll_left")
	if forward_speed <= 0.5:
		turn_input = 0.0

	pitch_input = 0.0
	if not grounded:
		pitch_input -= Input.get_action_strength("pitch_down")
	if forward_speed >= min_flight_speed:
		pitch_input += Input.get_action_strength("pitch_up")

func _physics_process(delta: float) -> void:
	get_input(delta)

	# Update transformation based on input
	transform.basis = transform.basis.rotated(transform.basis.x, pitch_input * pitch_speed * delta)
	transform.basis = transform.basis.rotated(Vector3.UP, turn_input * turn_speed * delta)

	if grounded:
		mesh.rotation.z = 0.0
	else:
		mesh.rotation.z = lerp(mesh.rotation.z, +turn_input, level_speed * delta)

	forward_speed = lerp(forward_speed, target_speed, acceleration * delta)
	velocity = -transform.basis.z * forward_speed

	if is_on_floor():
		grounded = true
	else:
		grounded = false
	move_and_slide()

	update_hud()

func update_hud() -> void:
	if speed_label:
		speed_label.text = str(round(forward_speed)) + " km/h"

	if altitude_label:
		if raycast.is_colliding():
			var altitude = raycast.get_collision_point().y - global_position.y
			altitude_label.text = str(round(-altitude)) + " m"  # Negative because the collision point is below the ship
		else:
			altitude_label.text = "N/A"

	if direction_label:
		var forward_vector = -transform.basis.z
		var direction = Vector3(forward_vector.x, 0, forward_vector.z).normalized()
		var angle = rad_to_deg(atan2(direction.x, direction.z))
		angle = fposmod(angle, 360)  # Ensure the angle is between 0 and 360
		direction_label.text = str(round(angle)) + "°"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
