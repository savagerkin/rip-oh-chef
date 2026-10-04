class_name Player
extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const MOUSE_SENSITIVITY := 0.002


@export var health: float = 100.0:
	set(value):
		health = value

		if health_bar:
			health_bar.value = health

var max_health: float = 100.0


@export var head: Node3D
@export var camera: Camera3D
@export var weapon: Weapon
@export var health_bar: ProgressBar
@export var username: Label
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	health_bar.max_value = max_health
	health_bar.value = health

	var is_owner := is_multiplayer_authority()

	set_physics_process(is_owner)
	set_process_input(is_owner)
	set_process_unhandled_input(is_owner)

	if is_owner:
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	load_username()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)

		head.rotation.x = clamp(
			head.rotation.x,
			deg_to_rad(-90),
			deg_to_rad(90)
		)


func _physics_process(delta: float) -> void:

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Shoot
	if Input.is_action_pressed("shoot"):
		weapon.fire()
	# Lock mouse
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var direction := (
		transform.basis * Vector3(input.x, 0, input.y)
	).normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	move_and_slide()

func load_username() -> void:
	username.text = Networking.get_username(
		get_multiplayer_authority()
	)

# Called by the weapon when this player gets hit.
func take_damage(damage: float) -> void:
	# If this machine owns this player, change health here.
	if is_multiplayer_authority():
		apply_damage(damage)
		return

	# Otherwise send the damage to the machine that owns this player.
	request_damage.rpc_id(
		get_multiplayer_authority(),
		damage
	)

# For now it teleports to the middle, and replaces ur health
func die() -> void:
	if health <= 0:
		health = max_health
		self.global_position = Vector3(0,10,0)
		print("Player ", name, " died")
		
		

# To change the health of the authority aka. do damage on them.
# We are telling the authority that they took damage, and change accordingly.
@rpc("any_peer", "call_remote", "reliable")
func request_damage(damage: float) -> void:
	if not is_multiplayer_authority():
		return

	apply_damage(damage)

func apply_damage(damage: float) -> void:
	health -= damage
	health = clamp(health, 0.0, max_health)

	print(
		"Player ",
		name,
		" took ",
		damage,
		" damage. Health: ",
		health
	)

	if health <= 0.0:
		die()
