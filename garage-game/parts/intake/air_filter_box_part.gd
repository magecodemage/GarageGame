class_name AirFilterBoxPart
extends AutomotivePart

@export_range(0.0, 1.0) var air_filter_condition: float = 1.0


func get_custom_state() -> Dictionary:
	return {"air_filter_condition": air_filter_condition}


func apply_custom_state(data: Dictionary) -> void:
	air_filter_condition = clampf(float(data.get("air_filter_condition", air_filter_condition)), 0.0, 1.0)
