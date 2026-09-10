class_name CoolantSystem
extends VehicleRuntimeSystem

@export var coolant_amount: float = 5.2
@export var coolant_capacity: float = 5.5
@export var adequate_ratio: float = 0.55


func get_fill_ratio() -> float:
	return clampf(coolant_amount / maxf(coolant_capacity, 0.01), 0.0, 1.0)


func is_adequate() -> bool:
	return get_fill_ratio() >= adequate_ratio


func capture_state() -> Dictionary:
	return {"amount": coolant_amount, "capacity": coolant_capacity}


func apply_state(data: Dictionary) -> void:
	coolant_capacity = maxf(float(data.get("capacity", coolant_capacity)), 0.1)
	coolant_amount = clampf(float(data.get("amount", coolant_amount)), 0.0, coolant_capacity)


func validate_saved_state(data: Dictionary) -> String:
	if not SnapshotCodec.valid_number(data.get("amount")) or not SnapshotCodec.valid_number(data.get("capacity")):
		return "Estado de coolant inválido"
	if float(data["capacity"]) <= 0.0 or float(data["amount"]) < 0.0 or float(data["amount"]) > float(data["capacity"]):
		return "Valores de coolant fora dos limites"
	return ""


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if coolant_capacity <= 0.0 or coolant_amount < 0.0 or coolant_amount > coolant_capacity:
		issues.append("Configuração inválida de arrefecimento")
	return issues
