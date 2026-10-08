class_name PlayerStance
extends RefCounted

var player: CharacterBody3D
var collision_shape: CollisionShape3D
var body_mesh: MeshInstance3D
var head: Node3D

var crouching_height: float = 1.0
var standing_height: float = 2.0

var capsule: CapsuleShape3D
var bottom_y: float
var original_height: float
var original_mesh_transform: Transform3D
var mesh_bottom: Vector3
var original_head_position: Vector3


func initialize(body: CharacterBody3D, collider: CollisionShape3D, mesh: MeshInstance3D, head_node: Node3D) -> void:
	player = body
	collision_shape = collider
	body_mesh = mesh
	head = head_node

	if collision_shape.shape is not CapsuleShape3D:
		return

	collision_shape.shape = collision_shape.shape.duplicate()
	capsule = collision_shape.shape as CapsuleShape3D

	original_height = capsule.height
	bottom_y = collision_shape.position.y - original_height * 0.5

	if body_mesh and body_mesh.mesh:
		original_mesh_transform = player.global_transform.affine_inverse() * body_mesh.global_transform

		var bounds: AABB = body_mesh.mesh.get_aabb()
		mesh_bottom = bounds.get_center()
		mesh_bottom.y = bounds.position.y

	if head:
		original_head_position = player.to_local(head.global_position)


func set_crouching(crouching: bool) -> void:
	if capsule == null:
		return

	var target_height: float = standing_height

	if crouching:
		target_height = crouching_height

	capsule.height = maxf(target_height, capsule.radius * 2.0)
	collision_shape.position.y = bottom_y + capsule.height * 0.5

	if body_mesh and body_mesh.mesh:
		var mesh_transform: Transform3D = original_mesh_transform
		mesh_transform.basis.y = original_mesh_transform.basis.y * capsule.height / original_height

		var original_bottom: Vector3 = original_mesh_transform.basis * mesh_bottom
		var resized_bottom: Vector3 = mesh_transform.basis * mesh_bottom

		mesh_transform.origin += original_bottom - resized_bottom
		body_mesh.global_transform = player.global_transform * mesh_transform

	if head:
		var height_offset: Vector3 = Vector3(0.0, capsule.height - original_height, 0.0)
		head.global_position = player.to_global(original_head_position + height_offset)
