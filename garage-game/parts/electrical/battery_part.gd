class_name BatteryPart
extends AutomotivePart

@export var voltage: float = 12.6
@export_range(0.0, 1.0) var charge: float = 1.0
@export var battery_positive_terminal: ElectricalComponent
@export var battery_negative_terminal: ElectricalComponent


func get_custom_state() -> Dictionary:
	return {"voltage": voltage, "charge": charge,
		"positive_terminal": battery_positive_terminal.capture_state(),
		"negative_terminal": battery_negative_terminal.capture_state()}


func apply_custom_state(data: Dictionary) -> void:
	voltage = float(data.get("voltage", voltage))
	charge = clampf(float(data.get("charge", charge)), 0.0, 1.0)
	battery_positive_terminal.apply_state(data.get("positive_terminal", {}))
	battery_negative_terminal.apply_state(data.get("negative_terminal", {}))


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if not battery_positive_terminal or not battery_negative_terminal:
		issues.append("Bateria sem os dois terminais: " + name)
	else:
		issues.append_array(battery_positive_terminal.validate_configuration(display_name))
		issues.append_array(battery_negative_terminal.validate_configuration(display_name))
	return issues
