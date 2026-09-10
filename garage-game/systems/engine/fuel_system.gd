class_name FuelSystem
extends VehicleRuntimeSystem

signal fuel_changed(amount: float)

@export var fuel_amount: float = 20.0
@export var fuel_capacity: float = 40.0
@export var fuel_type: StringName = &"gasoline"
@export var idle_consumption_lph: float = 0.8
@export var maximum_consumption_lph: float = 12.0


func consume(delta: float, rpm: float, max_rpm: float) -> float:
	if fuel_amount <= 0.0:
		return 0.0
	var ratio := clampf(rpm / maxf(max_rpm, 1.0), 0.0, 1.0)
	var liters: float = lerpf(idle_consumption_lph, maximum_consumption_lph, ratio) * delta / 3600.0
	var previous := fuel_amount
	fuel_amount = clampf(fuel_amount - liters, 0.0, fuel_capacity)
	if absf(previous - fuel_amount) >= 0.0001:
		fuel_changed.emit(fuel_amount)
	return previous - fuel_amount


func add_fuel(liters: float) -> float:
	var previous := fuel_amount
	fuel_amount = clampf(fuel_amount + maxf(liters, 0.0), 0.0, fuel_capacity)
	if not is_equal_approx(previous, fuel_amount):
		fuel_changed.emit(fuel_amount)
	return fuel_amount - previous


func has_fuel() -> bool:
	return fuel_amount > 0.001


func capture_state() -> Dictionary:
	return {"amount": fuel_amount, "capacity": fuel_capacity, "type": str(fuel_type)}


func apply_state(data: Dictionary) -> void:
	fuel_capacity = maxf(float(data.get("capacity", fuel_capacity)), 0.1)
	fuel_amount = clampf(float(data.get("amount", fuel_amount)), 0.0, fuel_capacity)
	fuel_type = StringName(data.get("type", fuel_type))
	fuel_changed.emit(fuel_amount)


func validate_saved_state(data: Dictionary) -> String:
	for key in ["amount", "capacity"]:
		if not SnapshotCodec.valid_number(data.get(key)):
			return "Estado de combustível inválido"
	if float(data["capacity"]) <= 0.0 or float(data["amount"]) < 0.0 or float(data["amount"]) > float(data["capacity"]):
		return "Valores de combustível fora dos limites"
	return ""


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if fuel_capacity <= 0.0 or fuel_amount < 0.0 or fuel_amount > fuel_capacity:
		issues.append("Configuração inválida de combustível")
	return issues
