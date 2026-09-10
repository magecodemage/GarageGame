class_name FastenerSpec
extends Resource

@export var required_tool_type: StringName = &"wrench"
@export_range(1, 100) var required_tool_size: int = 17
@export_range(1, 20) var max_tightness: int = 4
