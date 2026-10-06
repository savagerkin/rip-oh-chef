class_name Weapon
extends Node3D

@export var damage: float = 20.0
@export var fire_rate: float = 0.2
@export var timer: Timer
@export var ray: RayCast3D
@export var ray_range: float = 100.0
@export var debug_tracer: MeshInstance3D


func _ready() -> void:
	ray.collide_with_areas = true
	timer.one_shot = true
	timer.wait_time = fire_rate

	ray.target_position = Vector3(ray_range, 0.0, 0.0)

	debug_tracer.mesh = ImmediateMesh.new()


func fire() -> void:
	if not timer.is_stopped():
		return

	ray.force_raycast_update()

	var end_position := ray.target_position

	if ray.is_colliding():
		var target := ray.get_collider()
		end_position = ray.to_local(ray.get_collision_point())
		
		if target is HeadHitbox:
			target.take_damage(damage)
		elif target is Player:
			target.take_damage(damage)
		
	draw_debug_ray(end_position)

	print("Shot for ", damage)

	timer.start()

# Debug draw shoot line
func draw_debug_ray(end_position: Vector3) -> void:
	var debug_mesh := debug_tracer.mesh as ImmediateMesh

	debug_mesh.clear_surfaces()

	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	debug_mesh.surface_add_vertex(ray.position)
	debug_mesh.surface_add_vertex(ray.position + end_position)

	debug_mesh.surface_end()

	await get_tree().create_timer(0.1).timeout

	debug_mesh.clear_surfaces()
