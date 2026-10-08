class_name Player
extends CharacterBody3D

signal died(player: Player)

const MOUSE_SENSITIVITY: float = 0.002

const Health = preload("uid://baj13oo0iqyx4")
const Movement = preload("uid://bo6uwu6yar1tl")
const Stance = preload("res://scripts/player/player_stance.gd")
const Presentation = preload("res://scripts/player/player_presentation.gd")

# Components
var movement: PlayerMovement = Movement.new()
var health_component: PlayerHealth = Health.new()
var stance: PlayerStance = Stance.new()
var presentation: PlayerPresentation = Presentation.new()

@export var health: float = 100.0:
	get:
		return health_component.health
	set(value):
		health_component.health = value


@export_group("Scene References")

@export_subgroup("Body")
@export var head: Node3D
@export var eyes_mesh: MeshInstance3D
@export var collison_shape: CollisionShape3D
@export var body_mesh: MeshInstance3D
@export var head_hitbox: Area3D

@export_subgroup("Camera and Weapon")
@export var camera: Camera3D
@export var weapon: Weapon

@export_subgroup("UI")
@export var health_bar: ProgressBar
@export var hud_health_bar: ProgressBar
@export var username: Label
@export var sprint_lines: ColorRect


@export_group("Movement")
@export var crouching_height: float = 1.0
@export var standing_height: float = 2.0


@export_group("Camera Settings")
@export var normal_fov: float = 75.0
@export var sprint_fov: float = 90.0
@export var fov_speed: float = 8.0


@export_group("")

# Player state
var last_attacker_id: int = 0
var died_to_death_plane: bool = false


var max_health: float:
	get:
		return health_component.max_health
	set(value):
		health_component.max_health = value

@export var movement_state: int:
	get:
		return movement.movement_state
	set(value):
		movement.movement_state = value

var steam_id: int = 0
var player_username: String = ""


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	initialize_components()

	var is_owner: bool = is_multiplayer_authority()
	presentation.configure_owner(is_owner, max_health, health)

	if is_owner:
		weapon.initialize_shooter(self, head_hitbox)

	set_physics_process(true)
	set_process_input(is_owner)
	set_process_unhandled_input(is_owner)

	load_username()


func initialize_components() -> void:
	stance.crouching_height = crouching_height
	stance.standing_height = standing_height
	stance.initialize(self, collison_shape, body_mesh, head)
	movement.initialize(self, stance)

	presentation.initialize(camera, health_bar, hud_health_bar, eyes_mesh, sprint_lines)
	health_component.health_changed.connect(update_health_bars)


# Username
func load_username() -> void:
	if multiplayer.multiplayer_peer is not SteamMultiplayerPeer:
		player_username = "Player " + str(get_multiplayer_authority())

		username.text = player_username
		return

	if steam_id <= 0:
		username.text = "Unknown"
		return

	player_username = Networking.get_username_from_steam_id(steam_id)

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

		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))


# Movement
func _physics_process(delta: float) -> void:
	stance.crouching_height = crouching_height
	stance.standing_height = standing_height

	if not is_multiplayer_authority():
		movement.update_crouching_pose()
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.is_action_pressed("shoot"):
		weapon.fire()

	movement.process_movement(delta)

	update_camera_effects(delta)


func update_camera_effects(delta: float) -> void:
	var movement_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprint_pressed: bool = Input.is_action_pressed("sprint")
	var is_moving: bool = movement_input.length_squared() > 0.0
	var is_crouching: bool = movement_state == PlayerMovement.MovementState.CROUCHING
	var sprinting: bool = sprint_pressed and is_moving and not is_crouching

	presentation.update_camera(delta, sprinting, normal_fov, sprint_fov, fov_speed)


func update_health_bars(current_health: float) -> void:
	presentation.update_health(current_health, is_multiplayer_authority())


# Damage
func take_damage(damage: float, attacker_id: int = 0, from_death_plane: bool = false) -> void:
	if is_multiplayer_authority():
		apply_damage(damage, attacker_id, from_death_plane)
		return

	request_damage.rpc_id(get_multiplayer_authority(), damage, attacker_id, from_death_plane)


@rpc("any_peer", "call_remote", "reliable")
func request_damage(damage: float, attacker_id: int = 0, from_death_plane: bool = false) -> void:
	if not is_multiplayer_authority():
		return

	apply_damage(damage, attacker_id, from_death_plane)


func apply_damage(damage: float, attacker_id: int = 0, from_death_plane: bool = false) -> void:
	if health <= 0.0:
		return

	last_attacker_id = attacker_id
	died_to_death_plane = from_death_plane

	health_component.apply_damage(damage)

	print("Player ", name, " took ", damage, " damage. Health: ", health)

	if health <= 0.0:
		die()


func die() -> void:
	if health <= 0 and is_multiplayer_authority():
		print("Player ", name, " died")
		died.emit(self)


@rpc("any_peer", "call_remote", "reliable")
func respawn_at(spawn_position: Vector3) -> void:
	if not is_multiplayer_authority():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1:
		return

	health_component.reset()
	velocity = Vector3.ZERO
	global_position = spawn_position

	last_attacker_id = 0
	died_to_death_plane = false
