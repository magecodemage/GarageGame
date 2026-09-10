class_name AutomotivePart
extends Grabbable
## A base original agora distingue encaixe de fixação.

signal part_installed(part: AutomotivePart, socket: Node3D)
signal part_removed(part: AutomotivePart)
signal state_changed(state: State)

enum State { FREE, HELD, PLACED, PARTIALLY_FASTENED, FASTENED }

@export var part_id: StringName = &""
@export var part_type: StringName = &"generic"
@export var compatible_socket_types: Array[StringName] = []
@export var required_fasteners: int = 0
@export_range(0.0, 1.0) var condition: float = 1.0
@export_range(0.0, 1.0) var wear: float = 0.0
@export var part_metadata: Dictionary = {}
@export var installation_position := Vector3.ZERO
@export var installation_rotation_degrees := Vector3.ZERO

var state: State = State.FREE
var installed: bool:
	get: return is_instance_valid(placement_socket)
var current_socket: Node3D:
	get: return placement_socket
var fastened: bool:
	get: return state == State.FASTENED
var fastening_ratio: float:
	get: return get_fastening_ratio()


func get_persistent_id() -> StringName:
	return part_id


func can_pick_up() -> bool:
	return super.can_pick_up() and (not installed or placement_socket.can_remove())


func begin_hold(holder: PhysicsBody3D) -> bool:
	if not super.begin_hold(holder):
		return false
	_set_state(State.HELD)
	return true


func end_hold() -> void:
	super.end_hold()
	if not installed:
		_set_state(State.FREE)


func on_placed(socket: Node3D, local_pose: Transform3D) -> void:
	super.on_placed(socket, local_pose)
	refresh_fastening_state()
	part_installed.emit(self, socket)


func on_removed() -> void:
	var was_installed: bool = installed
	super.on_removed()
	_set_state(State.FREE)
	if was_installed:
		part_removed.emit(self)


func get_installation_pose() -> Transform3D:
	return Transform3D(Basis.from_euler(installation_rotation_degrees * PI / 180.0), installation_position)


func get_fastening_ratio() -> float:
	return placement_socket.get_fastening_ratio() if installed else 0.0


func refresh_fastening_state() -> void:
	if not installed:
		return
	var ratio: float = get_fastening_ratio()
	_set_state(State.FASTENED if ratio >= 1.0 else (
		State.PARTIALLY_FASTENED if ratio > 0.0 else State.PLACED))


func _set_state(next_state: State) -> void:
	if state != next_state:
		state = next_state
		state_changed.emit(state)


func interaction_context(held: RigidBody3D) -> Dictionary:
	var result: Dictionary = super.interaction_context(held)
	if installed:
		result["hint"] = "Segure LMB para remover" if can_pick_up() else (
			"Afrouxe todos os %d parafusos" % required_fasteners)
		result["detail"] = "%s · Fixação %.0f%%" % [State.keys()[state], fastening_ratio * 100.0]
	result["debug"] += "\nTipo: %s\nEstado: %s\nSocket: %s\nCondição: %.2f" % [
		part_type, State.keys()[state], placement_socket.socket_id if installed else "-", condition]
	return result


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if part_type.is_empty() or compatible_socket_types.is_empty():
		issues.append("Peça sem tipo/compatibilidade: " + name)
	if required_fasteners < 0:
		issues.append("Quantidade de parafusos inválida: " + name)
	return issues
