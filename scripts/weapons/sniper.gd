class_name Sniper
extends Weapon

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 60.0
@export var bullets: Node3D


func _ready() -> void:
	super._ready()
	bullets.top_level = true
	bullets.global_transform = Transform3D.IDENTITY


func fire() -> void:
	if not begin_shot():
		return

	var direction: Vector3 = get_shot_direction()
	var bullet: Bullet = bullet_scene.instantiate() as Bullet

	bullet.initialize(damage, shooter, max_bounces, bounce_damage_mult)

	bullet.position = bullets.to_local(ray.global_position)
	bullet.linear_velocity = direction * bullet_speed
	bullets.add_child(bullet, true)
