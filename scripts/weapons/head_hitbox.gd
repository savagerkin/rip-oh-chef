class_name HeadHitbox
extends Area3D

@export var player: Player
@export var damage_multiplier: float = 1.5


func take_damage(damage: float) -> void:
	if player:
		player.take_damage(damage * damage_multiplier)
