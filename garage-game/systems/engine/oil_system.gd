class_name OilSystem
extends VehicleRuntimeSystem

@export var oil_amount: float = 4.0
@export var oil_capacity: float = 4.5
@export_range(0.0, 1.0) var oil_condition: float = 1.0
@export var critical_oil_amount: float = 0.5
@export var engine_damage_rate: float = 0.002


func get_damage_per_second() -> float:
	if oil_amount >= critical_oil_amount:
		return 0.0
	var severity := 1.0 - clampf(oil_amount / maxf(critical_oil_amount, 0.01), 0.0, 1.0)
	return engine_damage_rate * severity * lerpf(1.5, 1.0, oil_condition)


func capture_state() -> Dictionary:
	return {"amount": oil_amount, "capacity": oil_capacity, "condition": oil_condition}


func apply_state(data: Dictionary) -> void:
	oil_capacity = maxf(float(data.get("capacity", oil_capacity)), 0.1)
	oil_amount = clampf(float(data.get("amount", oil_amount)), 0.0, oil_capacity)
	oil_condition = clampf(float(data.get("condition", oil_condition)), 0.0, 1.0)


func validate_saved_state(data: Dictionary) -> String:
	for key in ["amount", "capacity", "condition"]:
		if not SnapshotCodec.valid_number(data.get(key)):
			return "Estado de óleo inválido"
	if float(data["capacity"]) <= 0.0 or float(data["amount"]) < 0.0 or float(data["amount"]) > float(data["capacity"]) or float(data["condition"]) < 0.0 or float(data["condition"]) > 1.0:
		return "Valores de óleo fora dos limites"
	return ""


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if oil_capacity <= 0.0 or oil_amount < 0.0 or oil_amount > oil_capacity:
		issues.append("Configuração inválida de óleo")
	return issues
