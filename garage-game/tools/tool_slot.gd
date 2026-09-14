class_name ToolSlot
extends SnapSocket

@export var expected_tool_id: StringName = &""
@export var expected_tool_size: int = 17
var accessible: bool = true


func is_accessible() -> bool:
	return accessible


func is_compatible(item: Grabbable) -> bool:
	return item is Tool and item.tool_id == expected_tool_id and item.tool_size == expected_tool_size


func release_hint() -> String:
	return "[G] Guardar a chave"


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if expected_tool_id.is_empty() or expected_tool_size <= 0:
		issues.append("Slot sem ID de ferramenta/tamanho válido: " + name)
	return issues
