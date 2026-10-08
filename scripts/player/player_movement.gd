class_name PlayerMovement
extends RefCounted

const SPEED: float = 5.0
const RUN_SPEED: float = 7.0
const CROUCH_SPEED: float = 2.0

const GRAVITY: float = 20.0
const JUMP_VELOCITY: float = 7.0

const SLIDE_SPEED: float = 10.0
const SLIDE_FRICTION: float = 6.0
const FLOOR_SNAP_LENGTH: float = 0.3


enum MovementState {
	IDLE,
	WALKING,
	RUNNING,
	CROUCHING,
	SLIDING
}


var player: CharacterBody3D
var stance: PlayerStance
var movement_state: MovementState = MovementState.IDLE

var original_floor_stop_on_slope: bool = true


func initialize(body: CharacterBody3D, player_stance: PlayerStance) -> void:
	player = body
	stance = player_stance

	original_floor_stop_on_slope = player.floor_stop_on_slope
	player.floor_snap_length = maxf(player.floor_snap_length, FLOOR_SNAP_LENGTH)
	update_crouching_pose()


func process_movement(delta: float) -> void:
	var grounded: bool = player.is_on_floor()
	var wants_to_jump: bool = Input.is_action_just_pressed("jump")
	var jumping: bool = grounded and wants_to_jump

	var input: Vector2 = get_movement_input()
	var direction: Vector3 = get_movement_direction(input)

	update_movement_state(input, grounded, jumping)

	player.floor_stop_on_slope = original_floor_stop_on_slope

	if movement_state == MovementState.SLIDING:
		player.floor_stop_on_slope = false

	if jumping:
		# Change vertical speed only.
		# Keep the horizontal momentum from the previous frame.
		player.velocity.y = JUMP_VELOCITY

	elif grounded:
		if movement_state == MovementState.SLIDING:
			process_ground_slide(delta)
		else:
			process_ground_movement(direction)

	else:
		# No ground friction or movement-speed replacement in the air.
		player.velocity.y -= GRAVITY * delta

	update_crouching_pose()

	player.move_and_slide()

	# Follow nearby slopes, but never snap during a jump.
	if grounded and not jumping:
		player.apply_floor_snap()

	finish_slide_if_slow()


func finish_slide_if_slow() -> void:
	# Check collision-adjusted velocity, including after landing.
	if movement_state == MovementState.SLIDING and player.is_on_floor():
		var floor_normal: Vector3 = player.get_floor_normal()
		var ground_velocity: Vector3 = player.velocity.slide(floor_normal)

		if ground_velocity.length() <= CROUCH_SPEED:
			movement_state = MovementState.CROUCHING
			player.floor_stop_on_slope = original_floor_stop_on_slope


func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func get_movement_direction(input: Vector2) -> Vector3:
	var direction: Vector3 = player.transform.basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0

	return direction.normalized()


func update_movement_state(input: Vector2, grounded: bool, jumping: bool) -> void:
	# Sliding stays active through jumps and falls.
	# The speed check after movement decides when it ends.
	if movement_state == MovementState.SLIDING:
		return

	# Keep the current state while airborne.
	if not grounded or jumping:
		return

	if movement_state == MovementState.RUNNING:
		if Input.is_action_just_pressed("crouch"):
			var horizontal_velocity: Vector3 = player.velocity
			horizontal_velocity.y = 0.0

			if horizontal_velocity.length() > CROUCH_SPEED:
				start_slide()
				return

	if Input.is_action_pressed("crouch"):
		movement_state = MovementState.CROUCHING
	elif Input.is_action_pressed("sprint") and input.length_squared() > 0.0:
		movement_state = MovementState.RUNNING
	elif input.length_squared() > 0.0:
		movement_state = MovementState.WALKING
	else:
		movement_state = MovementState.IDLE


func start_slide() -> void:
	var floor_normal: Vector3 = player.get_floor_normal()
	var ground_velocity: Vector3 = player.velocity.slide(floor_normal)

	if ground_velocity.length_squared() < 0.01:
		return

	# Give the slide an initial boost without reducing existing speed.
	var starting_speed: float = maxf(ground_velocity.length(), SLIDE_SPEED)

	player.velocity = ground_velocity.normalized() * starting_speed
	movement_state = MovementState.SLIDING


func process_ground_slide(delta: float) -> void:
	var floor_normal: Vector3 = player.get_floor_normal()

	# Keep movement parallel to the surface.
	var ground_velocity: Vector3 = player.velocity.slide(floor_normal)

	# Only the part of gravity along the slope affects slide speed.
	var gravity: Vector3 = Vector3.DOWN * GRAVITY
	var slope_gravity: Vector3 = gravity.slide(floor_normal)

	ground_velocity += slope_gravity * delta

	# Ground friction gradually removes momentum.
	ground_velocity = ground_velocity.move_toward(Vector3.ZERO, SLIDE_FRICTION * delta)

	player.velocity = ground_velocity


func process_ground_movement(direction: Vector3) -> void:
	var movement_speed: float = 0.0

	match movement_state:
		MovementState.WALKING:
			movement_speed = SPEED

		MovementState.RUNNING:
			movement_speed = RUN_SPEED

		MovementState.CROUCHING:
			movement_speed = CROUCH_SPEED

	# Align normal movement with the floor too.
	var floor_normal: Vector3 = player.get_floor_normal()
	var ground_direction: Vector3 = direction.slide(floor_normal).normalized()

	player.velocity = ground_direction * movement_speed


func update_crouching_pose() -> void:
	var is_crouching: bool = movement_state == MovementState.CROUCHING
	var is_sliding: bool = movement_state == MovementState.SLIDING

	stance.set_crouching(is_crouching or is_sliding)
