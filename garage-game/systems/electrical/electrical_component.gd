class_name ElectricalComponent
extends Resource
## Conexão elétrica lógica reutilizável; pode ser comandada por um Fastener.

signal connection_changed(connected: bool)

@export var component_id: StringName = &""
@export var is_connected: bool = false
@export_range(0.0, 1.0) var condition: float = 1.0

var _connection_fastener: Fastener


func bind_fastener(fastener: Fastener) -> void:
	_connection_fastener = fastener
	if fastener and not fastener.fastener_changed.is_connected(_on_fastener_changed):
		fastener.fastener_changed.connect(_on_fastener_changed)
	_sync_from_fastener()


func set_connected(value: bool) -> void:
	if _connection_fastener:
		_connection_fastener.set_tightness(_connection_fastener.max_tightness if value else 0)
	elif is_connected != value:
		is_connected = value
		connection_changed.emit(is_connected)


func capture_state() -> Dictionary:
	return {"component_id": str(component_id), "is_connected": is_connected, "condition": condition}


func apply_state(data: Dictionary) -> void:
	var previous := is_connected
	is_connected = bool(data.get("is_connected", is_connected))
	condition = clampf(float(data.get("condition", condition)), 0.0, 1.0)
	if previous != is_connected:
		connection_changed.emit(is_connected)


func validate_configuration(owner_name: String) -> PackedStringArray:
	var issues := PackedStringArray()
	if component_id.is_empty():
		issues.append("Componente elétrico sem ID em " + owner_name)
	return issues


func _on_fastener_changed(_fastener: Fastener) -> void:
	_sync_from_fastener()


func _sync_from_fastener() -> void:
	if not _connection_fastener:
		return
	var next_connected := _connection_fastener.tightness > 0
	if is_connected != next_connected:
		is_connected = next_connected
		connection_changed.emit(is_connected)
