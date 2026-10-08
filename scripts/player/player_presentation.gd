class_name PlayerPresentation
extends RefCounted

var camera: Camera3D
var health_bar: ProgressBar
var hud_health_bar: ProgressBar
var eyes_mesh: MeshInstance3D
var sprint_lines: ColorRect


func initialize(
	player_camera: Camera3D,
	world_bar: ProgressBar,
	hud_bar: ProgressBar,
	eyes: MeshInstance3D,
	speed_lines: ColorRect
) -> void:
	camera = player_camera
	health_bar = world_bar
	hud_health_bar = hud_bar
	eyes_mesh = eyes
	sprint_lines = speed_lines


func configure_owner(is_owner: bool, max_health: float, current_health: float) -> void:
	if sprint_lines:
		sprint_lines.hide()

	health_bar.max_value = max_health
	health_bar.value = current_health
	hud_health_bar.visible = is_owner

	if eyes_mesh:
		eyes_mesh.visible = not is_owner

	if is_owner:
		hud_health_bar.max_value = max_health
		hud_health_bar.value = current_health
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func update_health(current_health: float, is_owner: bool) -> void:
	if health_bar:
		health_bar.value = current_health

	if hud_health_bar and is_owner:
		hud_health_bar.value = current_health


func update_camera(delta: float, sprinting: bool, normal_fov: float, sprint_fov: float, fov_speed: float) -> void:
	if sprint_lines:
		sprint_lines.visible = sprinting

	var target_fov: float = normal_fov
	if sprinting:
		target_fov = sprint_fov

	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-fov_speed * delta))
