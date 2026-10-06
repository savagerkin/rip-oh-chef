class_name PlayerMovement
extends RefCounted

const SPEED := 5.0
const RUN_SPEED := 7.0
const CROUCH_SPEED := 2.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0


enum MovementState {
	IDLE,
	WALKING,
	RUNNING,
	CROUCHING,
	SLIDING
}


var player: CharacterBody3D
var collision_shape: CollisionShape3D
var body_mesh: MeshInstance3D
var head: Node3D
var crouching_height: float = 1.0
var standing_height: float = 2.0
var movement_state: MovementState = MovementState.IDLE


var capsule: CapsuleShape3D
var bottom_y: float
var original_height: float
var original_mesh_transform: Transform3D
var mesh_bottom: Vector3
var original_head_position: Vector3


func initialize() -> void:
	if collision_shape.shape is not CapsuleShape3D:
		return

	collision_shape.shape = collision_shape.shape.duplicate()
	capsule = collision_shape.shape as CapsuleShape3D
	original_height = capsule.height
	bottom_y = collision_shape.position.y - original_height * 0.5

	if body_mesh and body_mesh.mesh:
		original_mesh_transform = (
			player.global_transform.affine_inverse() * body_mesh.global_transform
		)
		var bounds := body_mesh.mesh.get_aabb()
		mesh_bottom = bounds.get_center()
		mesh_bottom.y = bounds.position.y

	if head:
		original_head_position = player.to_local(head.global_position)

	set_crouching(movement_state == MovementState.CROUCHING)


func process_movement(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY

	var input := get_movement_input()

	var direction := (
		player.transform.basis * Vector3(input.x, 0, input.y)
	).normalized()

	update_movement_state(input)
	handle_movement_state(direction)

	player.move_and_slide()


func get_movement_input() -> Vector2:
	return Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)


func update_movement_state(input: Vector2) -> void:
	if Input.is_action_pressed("crouch"):
		movement_state = MovementState.CROUCHING
	elif Input.is_action_pressed("sprint") and input.length() > 0:
		movement_state = MovementState.RUNNING
	elif input.length() > 0:
		movement_state = MovementState.WALKING
	else:
		movement_state = MovementState.IDLE


func handle_movement_state(direction: Vector3) -> void:
	match movement_state:
		MovementState.IDLE:
			player.velocity.x = 0.0
			player.velocity.z = 0.0
			set_crouching(false)
		MovementState.WALKING:
			player.velocity.x = direction.x * SPEED
			player.velocity.z = direction.z * SPEED
			set_crouching(false)
		MovementState.RUNNING:
			player.velocity.x = direction.x * RUN_SPEED
			player.velocity.z = direction.z * RUN_SPEED
			set_crouching(false)
		MovementState.CROUCHING:
			player.velocity.x = direction.x * CROUCH_SPEED
			player.velocity.z = direction.z * CROUCH_SPEED
			set_crouching(true)
		MovementState.SLIDING:
			pass


func set_crouching(crouching: bool) -> void:
	if capsule == null:
		return

	var target_height := crouching_height if crouching else standing_height
	capsule.height = maxf(target_height, capsule.radius * 2.0)
	collision_shape.position.y = bottom_y + capsule.height * 0.5

	if body_mesh and body_mesh.mesh:
		var mesh_transform := original_mesh_transform
		mesh_transform.basis.y = (
			original_mesh_transform.basis.y * capsule.height / original_height
		)
		mesh_transform.origin += (
			original_mesh_transform.basis * mesh_bottom
			- mesh_transform.basis * mesh_bottom
		)
		body_mesh.global_transform = player.global_transform * mesh_transform

	if head:
		head.global_position = player.to_global(
			original_head_position + Vector3(0.0, capsule.height - original_height, 0.0)
		)
