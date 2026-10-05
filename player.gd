class_name Player
extends CharacterBody3D

const SPEED := 5.0
const RUN_SPEED := 7.0
const CROUCH_SPEED := 2.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const MOUSE_SENSITIVITY := 0.002


enum MovementState {
	IDLE,
	WALKING,
	RUNNING,
	CROUCHING,
	SLIDING
}


@export var health: float = 100.0:
	set(value):
		health = value

		if health_bar:
			health_bar.value = health

		if hud_health_bar and is_multiplayer_authority():
			hud_health_bar.value = health


@export var head: Node3D
@export var camera: Camera3D
@export var weapon: Weapon
@export var health_bar: ProgressBar
@export var hud_health_bar: ProgressBar
@export var username: Label


var max_health: float = 100.0

var movement_state: MovementState = MovementState.IDLE

var steam_id: int = 0
var player_username: String = ""


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	health_bar.max_value = max_health
	health_bar.value = health

	var is_owner := is_multiplayer_authority()

	hud_health_bar.visible = is_owner

	if is_owner:
		hud_health_bar.max_value = max_health
		hud_health_bar.value = health

	set_physics_process(is_owner)
	set_process_input(is_owner)
	set_process_unhandled_input(is_owner)

	if is_owner:
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	load_username()


# Username

func load_username() -> void:
	if multiplayer.multiplayer_peer is not SteamMultiplayerPeer:
		player_username = "Player " + str(
			get_multiplayer_authority()
		)

		username.text = player_username
		return

	if steam_id <= 0:
		username.text = "Unknown"
		return

	player_username = Networking.get_username_from_steam_id(
		steam_id
	)

	if player_username == "Unknown":
		await get_tree().create_timer(0.5).timeout

		if is_inside_tree():
			load_username()

		return

	username.text = player_username


# Input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)

		head.rotation.x = clamp(
			head.rotation.x,
			deg_to_rad(-90),
			deg_to_rad(90)
		)


# Movement

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.is_action_pressed("shoot"):
		weapon.fire()

	var input := get_movement_input()

	var direction := (
		transform.basis * Vector3(input.x, 0, input.y)
	).normalized()

	update_movement_state(input)
	handle_movement_state(direction)

	move_and_slide()


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
			velocity.x = 0.0
			velocity.z = 0.0
			self.scale = Vector3(1,1,1)
		MovementState.WALKING:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			self.scale = Vector3(1,1,1)

		MovementState.RUNNING:
			velocity.x = direction.x * RUN_SPEED
			velocity.z = direction.z * RUN_SPEED

		MovementState.CROUCHING:
			velocity.x = direction.x * CROUCH_SPEED
			velocity.z = direction.z * CROUCH_SPEED
			self.scale = Vector3(1,0.5,1)
		MovementState.SLIDING:
			pass


# Damage

func take_damage(damage: float) -> void:
	if is_multiplayer_authority():
		apply_damage(damage)
		return

	request_damage.rpc_id(
		get_multiplayer_authority(),
		damage
	)


@rpc("any_peer", "call_remote", "reliable")
func request_damage(damage: float) -> void:
	if not is_multiplayer_authority():
		return

	apply_damage(damage)


func apply_damage(damage: float) -> void:
	health -= damage
	health = clamp(health, 0.0, max_health)

	print("Player ", name, " took ", damage," damage. Health: ", health)
	if health <= 0.0:
		die()


func die() -> void:
	if health <= 0:
		health = max_health
		self.global_position = Vector3(0, 10, 0)
		print("Player ", name, " died")
