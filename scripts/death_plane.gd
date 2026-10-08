extends Area3D


func _on_area_entered(_area: Area3D) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority():
		body.take_damage(body.max_health, 0, true)
