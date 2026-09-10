class_name ElectricalComponent
extends Resource
## Fundação elétrica mínima, sem simulação de circuito.

@export var component_id: StringName = &""
@export var is_connected: bool = false
@export_range(0.0, 1.0) var condition: float = 1.0


func capture_state() -> Dictionary:
	return {"component_id": str(component_id), "is_connected": is_connected, "condition": condition}


func apply_state(data: Dictionary) -> void:
	is_connected = bool(data.get("is_connected", is_connected))
	condition = clampf(float(data.get("condition", condition)), 0.0, 1.0)


func validate_configuration(owner_name: String) -> PackedStringArray:
	var issues := PackedStringArray()
	if component_id.is_empty():
		issues.append("Componente elétrico sem ID em " + owner_name)
	return issues
