class_name AlternatorPart
extends AutomotivePart

@export var belt_connected: bool = false
@export var electrical: ElectricalComponent

var electrical_connected: bool:
	get: return electrical.is_connected if electrical else false
	set(value):
		if electrical:
			electrical.is_connected = value


func get_custom_state() -> Dictionary:
	return {"belt_connected": belt_connected, "electrical": electrical.capture_state()}


func apply_custom_state(data: Dictionary) -> void:
	belt_connected = bool(data.get("belt_connected", belt_connected))
	electrical.apply_state(data.get("electrical", {}))


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if not electrical:
		issues.append("Alternador sem ElectricalComponent: " + name)
	else:
		issues.append_array(electrical.validate_configuration(display_name))
	return issues
