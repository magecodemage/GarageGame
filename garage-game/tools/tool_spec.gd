class_name ToolSpec
extends Resource

@export var tool_type: StringName = &"wrench"
@export_range(1, 100) var tool_size: int = 17
@export var usable: bool = true
@export_range(0.05, 20.0) var mass_kg: float = 0.35
