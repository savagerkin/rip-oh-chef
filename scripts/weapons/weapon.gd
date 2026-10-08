class_name Weapon
extends Node3D

@export var damage: float = 20.0
@export var fire_rate: float = 0.2
@export var timer: Timer
@export var ray: RayCast3D
@export var ray_range: float = 100.0
@export var debug_tracer: MeshInstance3D
@export_range(0.0, 15.0, 0.1) var spread_degrees: float = 0.0
@export_range(0, 10, 1) var max_bounces: int = 0
@export_range(0.0, 10.0, 0.05) var bounce_damage_mult: float = 0.75

var shooter: Player


func _ready() -> void:
	ray.collide_with_areas = true
	timer.one_shot = true
	timer.wait_time = fire_rate

	ray.target_position = Vector3(ray_range, 0.0, 0.0)

	debug_tracer.mesh = ImmediateMesh.new()


func fire() -> void:
	if not begin_shot():
		return

	var original_position: Vector3 = ray.global_position
	var original_local_position: Vector3 = ray.position
	var original_target: Vector3 = ray.target_position

	var direction: Vector3 = get_shot_direction()

	var origin: Vector3 = original_position
	var remaining_range: float = ray_range
	var shot_damage: float = damage
	var points: PackedVector3Array = PackedVector3Array([origin])
	var original_exclude_parent: bool = ray.exclude_parent

	for bounce_index in range(max_bounces + 1):
		if remaining_range <= 0.0:
			break

		ray.global_position = origin
		ray.target_position = ray.to_local(origin + direction * remaining_range)
		ray.force_raycast_update()

		if not ray.is_colliding():
			points.append(origin + direction * remaining_range)
			break

		var hit_position: Vector3 = ray.get_collision_point()
		var hit_normal: Vector3 = ray.get_collision_normal()
		var target: Object = ray.get_collider()

		points.append(hit_position)
		remaining_range -= origin.distance_to(hit_position)

		if target is Player:
			target.take_damage(shot_damage, get_multiplayer_authority())
			break

		if target is not StaticBody3D:
			break

		if bounce_index == max_bounces:
			break

		if hit_normal.is_zero_approx():
			break

		direction = direction.bounce(hit_normal).normalized()

		if is_instance_valid(shooter):
			ray.remove_exception(shooter)
			ray.exclude_parent = false

		shot_damage *= bounce_damage_mult
		origin = hit_position + hit_normal * 0.01
		remaining_range -= 0.01

	ray.position = original_local_position
	ray.target_position = original_target
	ray.exclude_parent = original_exclude_parent

	if is_instance_valid(shooter):
		ray.add_exception(shooter)

	draw_debug_path(points)


# Draw the shot path briefly.
func draw_debug_path(points: PackedVector3Array) -> void:
	if points.size() < 2:
		return

	var debug_mesh: ImmediateMesh = ImmediateMesh.new()
	debug_tracer.mesh = debug_mesh

	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for index in range(points.size() - 1):
		debug_mesh.surface_add_vertex(debug_tracer.to_local(points[index]))
		debug_mesh.surface_add_vertex(debug_tracer.to_local(points[index + 1]))

	debug_mesh.surface_end()

	await get_tree().create_timer(0.1).timeout

	debug_mesh.clear_surfaces()


func initialize_shooter(player: Player, head_hitbox: Area3D) -> void:
	shooter = player
	ray.add_exception(shooter)

	if head_hitbox:
		ray.add_exception(head_hitbox)


func begin_shot() -> bool:
	if not timer.is_stopped():
		return false

	timer.start()
	return true


func get_shot_direction() -> Vector3:
	var spread: float = deg_to_rad(spread_degrees)
	var direction: Vector3 = Vector3.RIGHT

	direction = direction.rotated(Vector3.UP, randf_range(-spread, spread))
	direction = direction.rotated(Vector3.FORWARD, randf_range(-spread, spread))
	return (ray.global_basis * direction).normalized()
