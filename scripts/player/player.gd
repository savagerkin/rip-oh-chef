class_name Player
extends CharacterBody3D

signal died(player: Player)

const MOUSE_SENSITIVITY := 0.002

const Health = preload("uid://baj13oo0iqyx4")
const Movement = preload("uid://bo6uwu6yar1tl")

var movement : PlayerMovement = Movement.new()
var health_component : PlayerHealth = Health.new()

@export var health: float = 100.0:
	get:
		return health_component.health
	set(value):
		health_component.health = value


@export var head: Node3D
@export var eyes_mesh: MeshInstance3D
@export var camera: Camera3D
@export var weapon: Weapon
@export var health_bar: ProgressBar
@export var hud_health_bar: ProgressBar
@export var username: Label
@export var collison_shape: CollisionShape3D
@export var body_mesh: MeshInstance3D
@export var crouching_height: float = 1.0
@export var standing_height: float = 2.0
@export var head_hitbox: Area3D
@export var normal_fov: float = 75.0
@export var sprint_fov: float = 90.0
@export var fov_speed: float = 8.0
@export var sprint_lines: ColorRect

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
	movement.player = self
	movement.collision_shape = collison_shape
	movement.body_mesh = body_mesh
	movement.head = head
	movement.crouching_height = crouching_height
	movement.standing_height = standing_height
	movement.initialize()
	health_component.health_changed.connect(update_health_bars)
	if sprint_lines:
		sprint_lines.hide()
	health_bar.max_value = max_health
	health_bar.value = health

	var is_owner := is_multiplayer_authority()

	hud_health_bar.visible = is_owner
	if eyes_mesh:
		eyes_mesh.visible = not is_owner

	if is_owner:
		hud_health_bar.max_value = max_health
		hud_health_bar.value = health
		# Assignming my shooter in wepaon, and stopping myself form shooting myself ;)
		weapon.shooter = self
		weapon.ray.add_exception(self)
		if head_hitbox:
			weapon.ray.add_exception(head_hitbox)

	set_physics_process(true)
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
	movement.crouching_height = crouching_height
	movement.standing_height = standing_height

	if not is_multiplayer_authority():
		movement.set_crouching(
			movement_state == PlayerMovement.MovementState.CROUCHING
		)
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.is_action_pressed("shoot"):
		weapon.fire()

	movement.process_movement(delta)
	var sprinting := (
		Input.is_action_pressed("sprint")
		and Input.get_vector(
			"move_left", "move_right",
			"move_forward", "move_back"
		).length_squared() > 0.0
		and movement_state != PlayerMovement.MovementState.CROUCHING
	)
	if sprint_lines:
		sprint_lines.visible = sprinting
	var target_fov := sprint_fov if sprinting else normal_fov

	camera.fov = lerpf(
		camera.fov,
		target_fov,
		1.0 - exp(-fov_speed * delta)
	)


func update_health_bars(current_health: float) -> void:
	if health_bar:
		health_bar.value = current_health

	if hud_health_bar and is_multiplayer_authority():
		hud_health_bar.value = current_health


# Damage

func take_damage(
	damage: float,
	attacker_id: int = 0,
	from_death_plane: bool = false
) -> void:
	if is_multiplayer_authority():
		apply_damage(damage, attacker_id, from_death_plane)
		return

	request_damage.rpc_id(
		get_multiplayer_authority(),
		damage,
		attacker_id,
		from_death_plane
	)


@rpc("any_peer", "call_remote", "reliable")
func request_damage(
	damage: float,
	attacker_id: int = 0,
	from_death_plane: bool = false
) -> void:
	if not is_multiplayer_authority():
		return

	apply_damage(damage, attacker_id, from_death_plane)


func apply_damage(
	damage: float,
	attacker_id: int = 0,
	from_death_plane: bool = false
) -> void:
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

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1:
		return

	health_component.reset()
	velocity = Vector3.ZERO
	global_position = spawn_position
	
	last_attacker_id = 0
	died_to_death_plane = false
