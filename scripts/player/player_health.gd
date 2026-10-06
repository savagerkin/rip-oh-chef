class_name PlayerHealth
extends RefCounted

signal health_changed(current_health: float)

var max_health: float = 100.0
var health: float = 100.0:
	set(value):
		health = value
		health_changed.emit(health)


func apply_damage(damage: float) -> void:
	health = clampf(health - damage, 0.0, max_health)


func reset() -> void:
	health = max_health
