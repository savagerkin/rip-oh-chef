class_name Sniper
extends Weapon

@export var bullet_scene : PackedScene
@export var bullet_speed: float = 60.0
@export var bullets: Node3D

func _ready() -> void:
	super._ready()
	bullets.top_level = true
	bullets.global_transform = Transform3D.IDENTITY


func fire() -> void:
	if not timer.is_stopped():
		return

	timer.start()
	
	#Give it spread
	var spread := deg_to_rad(spread_degrees)
	var direction := Vector3.RIGHT

	direction = direction.rotated(
		Vector3.UP,
		randf_range(-spread, spread)
	)
	direction = direction.rotated(
		Vector3.FORWARD,
		randf_range(-spread, spread)
	)
		
	direction = (ray.global_basis * direction).normalized()
	var bullet := bullet_scene.instantiate() as Bullet
	
	bullet.damage = damage
	bullet.shooter = shooter
	bullet.max_bounces = max_bounces
	bullet.bounce_damage_mult = bounce_damage_mult

	bullet.position = bullets.to_local(ray.global_position)
	bullet.linear_velocity = direction * bullet_speed
	bullets.add_child(bullet, true)
