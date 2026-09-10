class_name RadiatorPart
extends AutomotivePart

@export var coolant_capacity: float = 5.0
@export var coolant_amount: float = 5.0


func get_custom_state() -> Dictionary:
	return {"coolant_capacity": coolant_capacity, "coolant_amount": coolant_amount}


func apply_custom_state(data: Dictionary) -> void:
	coolant_capacity = maxf(0.0, float(data.get("coolant_capacity", coolant_capacity)))
	coolant_amount = clampf(float(data.get("coolant_amount", coolant_amount)), 0.0, coolant_capacity)
