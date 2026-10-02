extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const MOUSE_SENSITIVITY := 0.002

@onready var head: Node3D = $Node3D
@onready var camera: Camera3D = $Node3D/Camera3D


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	if is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_pressed("esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
