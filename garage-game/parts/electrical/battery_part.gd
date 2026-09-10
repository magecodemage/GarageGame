class_name BatteryPart
extends AutomotivePart

signal battery_charge_changed(charge: float)

@export var voltage: float = 12.6
@export_range(0.0, 1.0) var charge: float = 1.0
@export var capacity: float = 60.0
@export var battery_positive_terminal: ElectricalComponent
@export var battery_negative_terminal: ElectricalComponent
@export var positive_terminal_fastener: Fastener
@export var negative_terminal_fastener: Fastener

var positive_connected: bool:
	get: return battery_positive_terminal.is_connected if battery_positive_terminal else false
	set(value): set_terminal_connected(true, value)
var negative_connected: bool:
	get: return battery_negative_terminal.is_connected if battery_negative_terminal else false
	set(value): set_terminal_connected(false, value)


func _ready() -> void:
	super._ready()
	for fastener in [positive_terminal_fastener, negative_terminal_fastener]:
		if fastener:
			fastener.set_active(true)
	if battery_positive_terminal:
		battery_positive_terminal.bind_fastener(positive_terminal_fastener)
	if battery_negative_terminal:
		battery_negative_terminal.bind_fastener(negative_terminal_fastener)


func get_voltage() -> float:
	voltage = clampf((10.5 + charge * 2.1) * lerpf(0.92, 1.0, condition), 0.0, 13.0)
	return voltage


func is_electrically_connected() -> bool:
	return battery_positive_terminal and battery_negative_terminal and (
		battery_positive_terminal.is_connected and battery_negative_terminal.is_connected)


func consume_energy(amp_hours: float) -> float:
	var previous := charge
	charge = clampf(charge - maxf(amp_hours, 0.0) / maxf(capacity, 0.01), 0.0, 1.0)
	get_voltage()
	if absf(previous - charge) >= 0.00001:
		battery_charge_changed.emit(charge)
	return previous - charge


func charge_battery(amp_hours: float) -> float:
	var previous := charge
	charge = clampf(charge + maxf(amp_hours, 0.0) / maxf(capacity, 0.01), 0.0, 1.0)
	get_voltage()
	if absf(previous - charge) >= 0.00001:
		battery_charge_changed.emit(charge)
	return charge - previous


func set_terminal_connected(positive: bool, connected: bool) -> void:
	var fastener := positive_terminal_fastener if positive else negative_terminal_fastener
	if fastener:
		fastener.set_tightness(fastener.max_tightness if connected else 0)
	else:
		var terminal := battery_positive_terminal if positive else battery_negative_terminal
		terminal.set_connected(connected)


func get_custom_state() -> Dictionary:
	return {"voltage": get_voltage(), "charge": charge, "capacity": capacity,
		"positive_terminal": battery_positive_terminal.capture_state(),
		"negative_terminal": battery_negative_terminal.capture_state()}


func apply_custom_state(data: Dictionary) -> void:
	voltage = float(data.get("voltage", voltage))
	charge = clampf(float(data.get("charge", charge)), 0.0, 1.0)
	capacity = maxf(float(data.get("capacity", capacity)), 0.1)
	battery_positive_terminal.apply_state(data.get("positive_terminal", {}))
	battery_negative_terminal.apply_state(data.get("negative_terminal", {}))


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if not battery_positive_terminal or not battery_negative_terminal:
		issues.append("Bateria sem os dois terminais: " + name)
	else:
		issues.append_array(battery_positive_terminal.validate_configuration(display_name))
		issues.append_array(battery_negative_terminal.validate_configuration(display_name))
	if capacity <= 0.0:
		issues.append("Bateria com capacidade inválida")
	return issues
