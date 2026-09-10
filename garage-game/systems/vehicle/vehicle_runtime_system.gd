class_name VehicleRuntimeSystem
extends Node
## Base persistente para sistemas do veículo que não são peças físicas.

@export var system_id: StringName = &""


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("vehicle_runtime_systems")


func get_persistent_id() -> StringName:
	return system_id


func capture_state() -> Dictionary:
	return {}


func apply_state(_data: Dictionary) -> void:
	pass


func normalize_after_load() -> void:
	pass


func validate_saved_state(data: Dictionary) -> String:
	return "" if data is Dictionary else "Estado inválido: " + str(system_id)


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if system_id.is_empty():
		issues.append("Sistema do veículo sem ID: " + name)
	return issues
