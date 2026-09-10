class_name StarterMotorPart
extends AutomotivePart

@export var electrical: ElectricalComponent

var electrical_connected: bool:
	get: return electrical.is_connected if electrical else false
	set(value):
		if electrical:
			electrical.is_connected = value


func is_electrically_connected() -> bool:
	return electrical_connected


func get_custom_state() -> Dictionary:
	return {"electrical": electrical.capture_state()}


func apply_custom_state(data: Dictionary) -> void:
	electrical.apply_state(data.get("electrical", {}))


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if not electrical:
		issues.append("Motor de partida sem ElectricalComponent: " + name)
	else:
		issues.append_array(electrical.validate_configuration(display_name))
	return issues
