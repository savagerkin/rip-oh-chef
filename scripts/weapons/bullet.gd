class_name Bullet
extends RigidBody3D

@export var lifetime: float = 5.0

var damage: float = 20.0
var shooter: Player
var max_bounces: int = 1
var bounce_damage_mult: float = 0.75

var bounce_count: int = 0
var finished: bool = false

func _enter_tree() -> void:
	set_multiplayer_authority(
		get_parent().get_multiplayer_authority()
	)
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not is_multiplayer_authority():
		freeze = true
		collision_layer = 0
		collision_mask = 0
		return
	
	if is_instance_valid(shooter):
		add_collision_exception_with(shooter)
	


	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _on_body_entered(body: Node) -> void:
	if finished:
		return

	if body is Player:
		finished = true
		body.take_damage.call_deferred(
			damage,
			get_multiplayer_authority()
		)
		
		queue_free()
		return

	if not body is StaticBody3D:
		finished = true
		queue_free()
		return

	if bounce_count >= max_bounces:
		finished = true
		queue_free()
		return

	bounce_count += 1
	damage *= bounce_damage_mult

	if is_instance_valid(shooter):
		call_deferred("remove_collision_exception_with", shooter)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not is_multiplayer_authority():
		return
	if state.linear_velocity.length_squared() < 0.0001:
		return

	var direction := state.linear_velocity.normalized()
	var up := Vector3.FORWARD

	if abs(direction.dot(up)) > 0.99:
		up = Vector3.RIGHT

	var body_transform := state.transform
	body_transform.basis = Basis.looking_at(direction, up)
	state.transform = body_transform
