@icon("res://addons/terraincrafter/assets/icons/ship_node.png")
extends CharacterBody3D

@export_group("Controls")
@export var turn_speed_base: float = 0.6 
@export var turn_acceleration: float = 2.5
@export var turn_rotation_intensity: float = 1.0
@export var pitch_speed_base: float = 0.5
@export var pitch_acceleration: float = 2.5
@export var pitch_rotation_intensity: float = 0.2
@export var level_speed: float = 2.0
@export var throttle_delta: float = 30.0
@export var acceleration_base: float = 50.0 
@export var decay_intensity: float = 0.5
@export var gravity_strength: float = 1500.0
@export_group("Aerodynamics")
@export var min_flight_speed: int = 0
@export var max_flight_speed: int = 150
@export var spool_time: float = 3.0 
@export var engine_on: bool = true
@export var ground_effect_altitude: float = 25.0 
@export var ground_effect_multiplier: float = 1.0
@export var ground_effect_transition_speed: float = 2.0
@export var lift_reduction_factor: float = 0.75  
@export var lift_transition_speed: float = 2.0
@export var anchor_slowdown_rate: float = 3.0  
@export_group("Landing")
@export var landing_speed_threshold: float = 50.0
@export var landing_gear_deployed: bool = false
@export var landing_gear_node: MeshInstance3D
@export var anchored: bool = false 
@export_group("Labels")
@export var speed_label: Label
@export var altitude_label: Label
@export var direction_label: Label
@export var engine_power_label: Label
@export var ground_effect_status_label: Label
@export var landing_status_label: Label
@export var gear_status_label: Label
@export var anchor_status_label: Label 

var engine_power: float = 0.0  
var forward_speed: float = 0.0
var target_speed: float = 0.0
var grounded: bool = false
var turn_input: float = 0.0
var pitch_input: float = 0.0
var turn_speed: float = 0.0  
var pitch_speed: float = 0.0  
var acceleration: float = 0.0  
var in_ground_effect: bool = false
var previous_altitude: float = 0.0  
var current_pitch_speed: float = 0.0
var current_turn_speed: float = 0.0
var current_ground_effect_multiplier: float = 0.0
var target_ground_effect_multiplier: float = 0.0
var ground_effect_transition_progress: float = 0.0
var current_lift_reduction: float = 1.0 
var anchor_available: bool = false 
var original_volume_db: float = 0.0 
var fade_out_time: float = 1.0
var fade_out_timer: float = 0.0

@export var ship_node: Node3D
@export var raycast: RayCast3D
@export var thruster_sound: AudioStreamPlayer

func _ready() -> void:
	if landing_gear_deployed:
		landing_gear_node.visible = true
	else:
		landing_gear_node.visible = false
		if anchored:
			target_speed = 0.0
			anchored = true
			update_anchor_state(0)
	update_hud()
	thruster_sound.play() 
	original_volume_db = thruster_sound.volume_db 

func get_input(delta: float) -> void:
	if Input.is_action_pressed("engine_toggle"):
		engine_on = not engine_on
	if Input.is_action_pressed("throttle_up") and not anchored:
		target_speed = min(forward_speed + throttle_delta * delta, max_flight_speed)
	if Input.is_action_pressed("throttle_down"):
		var limit: int = 0 if grounded else min_flight_speed
		target_speed = max(forward_speed - throttle_delta * delta, limit)
	if anchor_available and Input.is_action_just_pressed("anchor"):
		anchored = not anchored
		if anchored:
			target_speed = 0.0
	if forward_speed < landing_speed_threshold and not anchored:
		if Input.is_action_just_pressed("deploy_gear"):
			landing_gear_deployed = not landing_gear_deployed
			landing_gear_node.visible = landing_gear_deployed
	turn_input = Input.get_axis("roll_right", "roll_left")
	if forward_speed <= 0.5:
		turn_input = 0.0
	pitch_input = 0.0
	if not grounded:
		pitch_input -= Input.get_action_strength("pitch_down")
	if forward_speed >= min_flight_speed:
		pitch_input += Input.get_action_strength("pitch_up")

	var target_turn_speed = turn_input * turn_speed
	var target_pitch_speed = pitch_input * pitch_speed
	current_turn_speed = lerp(current_turn_speed, target_turn_speed, turn_acceleration * delta)
	current_pitch_speed = lerp(current_pitch_speed, target_pitch_speed, pitch_acceleration * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
		
func _physics_process(delta: float) -> void:
	get_input(delta)
	adjust_dynamic_speeds()
	apply_rotation(delta)
	update_forward_speed(delta)
	var current_altitude = global_position.y
	if raycast.is_colliding():
		in_ground_effect = abs(current_altitude - raycast.get_collision_point().y) < ground_effect_altitude
	else:
		in_ground_effect = false

	update_ground_effect_multiplier(delta)
	update_lift_reduction(delta)
	update_anchor_state(delta)
	velocity = calculate_forces(delta)
	if is_on_floor():
		grounded = true
	else:
		grounded = false
	move_and_slide()
	update_hud()
	update_thruster_sound(delta) 
	previous_altitude = current_altitude

func adjust_dynamic_speeds() -> void:
	turn_speed = turn_speed_base * engine_power
	pitch_speed = pitch_speed_base * engine_power
	acceleration = acceleration_base * engine_power
	if landing_gear_deployed:
		target_speed = min(target_speed, landing_speed_threshold)
		acceleration *= 0.5

func apply_rotation(delta: float) -> void:
	var exponent = 2.0  # Adjust this value to change the scaling behavior
	var scaled_turn_rotation_intensity = turn_rotation_intensity * pow(engine_power, exponent)
	var scaled_pitch_rotation_intensity = pitch_rotation_intensity * pow(engine_power, exponent)
	transform.basis = transform.basis.rotated(transform.basis.x, current_pitch_speed * delta)
	transform.basis = transform.basis.rotated(Vector3.UP, current_turn_speed * delta)
	if not grounded:

		ship_node.rotation.z = lerp(ship_node.rotation.z, turn_input * scaled_turn_rotation_intensity, level_speed * delta)
		ship_node.rotation.x = lerp(ship_node.rotation.x, pitch_input * scaled_pitch_rotation_intensity, level_speed * delta)

func update_forward_speed(delta: float) -> void:
	if anchored:
		forward_speed = lerp(forward_speed, 0.0, anchor_slowdown_rate * delta)
	elif engine_on:
		forward_speed = lerp(forward_speed, target_speed, acceleration * delta)
	else:
		var decay_factor = 1.0 - engine_power
		forward_speed = forward_speed * (1.0 - decay_intensity * decay_factor * delta)
		if forward_speed < min_flight_speed:
			forward_speed = min_flight_speed

func calculate_forces(delta: float) -> Vector3:
	var global_up = Vector3.UP
	var gravity_force = -global_up * gravity_strength * delta
	var hover_force = Vector3.ZERO
	if engine_on:
		engine_power += delta / spool_time
		if engine_power > 1.0:
			engine_power = 1.0
	else:
		engine_power -= delta / spool_time
		if engine_power < 0.0:
			engine_power = 0.0
	if engine_power > 0.0:
		hover_force = global_up * gravity_strength * engine_power * delta
		hover_force += global_up * gravity_strength * current_ground_effect_multiplier * delta
		hover_force *= current_lift_reduction  # Apply the current lift reduction factor
	return -transform.basis.z * forward_speed + gravity_force + hover_force

func update_ground_effect_multiplier(delta: float) -> void:
	if in_ground_effect:
		var altitude = raycast.get_collision_point().y - global_position.y
		if -altitude < ground_effect_altitude:
			var proximity_factor = pow(1.0 - (-altitude / ground_effect_altitude), 5)
			proximity_factor = clamp(proximity_factor, 0.0, 1.0)
			var speed_factor = clamp(forward_speed / max_flight_speed, 0.0, 1.0)
			target_ground_effect_multiplier = ground_effect_multiplier * proximity_factor * speed_factor
	else:
		target_ground_effect_multiplier = 0.0
	
	current_ground_effect_multiplier = lerp(current_ground_effect_multiplier, target_ground_effect_multiplier, ground_effect_transition_speed * delta)

func update_lift_reduction(delta: float) -> void:
	var target_lift_reduction = 1.0
	if landing_gear_deployed:
		target_lift_reduction = lift_reduction_factor
	current_lift_reduction = lerp(current_lift_reduction, target_lift_reduction, lift_transition_speed * delta)

func update_anchor_state(_delta: float) -> void:
	anchor_available = landing_gear_deployed and grounded
	if not anchor_available:
		anchored = false

func update_thruster_sound(delta: float) -> void:
	if engine_on:
		var speed_percentage: float = clamp(engine_power, 0.0, 1.0)
		var speed_factor: float = clamp(forward_speed / max_flight_speed, 0.0, 1.0)
		var pitch_scale: float = 0.4 + (0.6 * speed_factor)  # 80% from engine power, 20% from speed
		pitch_scale *= speed_percentage
		thruster_sound.pitch_scale = pitch_scale
		var volume_percentage: float = clamp(engine_power, 0.0, 1.0)
		var target_volume_db: float = linear_to_db(volume_percentage)
		if engine_power < 0.05:
			var fade_out_factor: float = (0.05 - engine_power) / 0.05
			target_volume_db = lerp(target_volume_db, -80.0, fade_out_factor)
		else:
			target_volume_db = linear_to_db(volume_percentage)
		thruster_sound.volume_db = target_volume_db
	else:
		thruster_sound.volume_db = lerp(thruster_sound.volume_db, -80.0, delta * 10.0)  # Smoothly fade out

func update_hud() -> void:
	if speed_label:
		speed_label.text = str(round(forward_speed)) + " km/h"
	if altitude_label:
		if raycast.is_colliding():
			var altitude = raycast.get_collision_point().y - global_position.y
			altitude_label.text = str(round(-altitude)) + " m"
		else:
			altitude_label.text = "N/A"
	if direction_label:
		var forward_vector = -transform.basis.z
		var direction = Vector3(forward_vector.x, 0, forward_vector.z).normalized()
		var angle = rad_to_deg(atan2(direction.x, direction.z))
		angle = fposmod(angle, 360)
		direction_label.text = str(round(angle)) + "°"
	if engine_power_label:
		engine_power_label.text = "Engine Power: " + str(int(engine_power * 100)) + "%"
	if ground_effect_status_label:
		if in_ground_effect:
			ground_effect_status_label.text = "Ground Effect: Active"
		else:
			ground_effect_status_label.text = "Ground Effect: Inactive"
	if landing_status_label:
		if forward_speed < landing_speed_threshold:
			landing_status_label.text = "Landing Possible"
		else:
			landing_status_label.text = "Landing Not Possible"
	if gear_status_label:
		if landing_gear_deployed:
			gear_status_label.text = "Gear Deployed"
		else:
			gear_status_label.text = "Gear Retracted"
	if anchor_status_label:
		if anchor_available:
			anchor_status_label.text = "Anchor Not Deployed"
		else:
			anchor_status_label.text = "Anchor Not Available"
		if anchored:
			anchor_status_label.text = "Anchor Deployed"
