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
@export var dependencies: MechanicalDependencySet
@export var installation_position := Vector3.ZERO
@export var installation_rotation_degrees := Vector3.ZERO

var state: State = State.FREE
var removal_guard: Callable
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
	return super.can_pick_up() and get_remove_evaluation()["allowed"]


func can_install(_socket: PartSocket = null) -> Dictionary:
	if not dependencies:
		return {"allowed": true, "reason": ""}
	return dependencies.evaluate_install(_mechanical_registry())


func can_remove() -> Dictionary:
	return get_remove_evaluation()


func get_remove_evaluation() -> Dictionary:
	if not installed:
		return {"allowed": true, "reason": ""}
	if removal_guard.is_valid():
		var guarded: Dictionary = removal_guard.call()
		if not guarded["allowed"]:
			return guarded
	if not placement_socket.can_remove():
		return {"allowed": false, "reason": "Afrouxe todos os %d parafusos" % required_fasteners}
	if dependencies:
		return dependencies.evaluate_remove(_mechanical_registry())
	return {"allowed": true, "reason": ""}


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


func is_secure() -> bool:
	return installed and (required_fasteners == 0 or is_equal_approx(get_fastening_ratio(), 1.0))


func is_partially_secure() -> bool:
	var ratio := get_fastening_ratio()
	return installed and ratio > 0.0 and ratio < 1.0


func is_loose() -> bool:
	return installed and not is_secure() and not is_partially_secure()


func get_custom_state() -> Dictionary:
	return {}


func apply_custom_state(_data: Dictionary) -> void:
	pass


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
	result["detail"] = _inspection_status()
	if installed:
		var evaluation := get_remove_evaluation()
		result["hint"] = "[LMB] Pegar / remover" if evaluation["allowed"] else evaluation["reason"]
	result["debug"] += "\nClasse: %s\nTipo: %s\nEstado: %s\nSocket: %s\nFixação: %.2f\n%s" % [
		_class_label(), part_type, State.keys()[state], placement_socket.socket_id if installed else "-",
		fastening_ratio, dependencies.describe() if dependencies else "Sem dependências"]
	return result


func _inspection_status() -> String:
	if not installed:
		return "Livre"
	if required_fasteners <= 0:
		return "Instalada"
	var secured: int = placement_socket.get_fully_tight_fastener_count()
	return "%d/%d parafusos firmes · %s" % [secured, required_fasteners,
		"Segura" if is_secure() else ("Parcial" if is_partially_secure() else "Solta")]


func _mechanical_registry() -> Dictionary:
	var states := get_tree().get_nodes_in_group("vehicle_mechanical_states")
	if states.is_empty():
		return {}
	var mechanical_state := states[0] as VehicleMechanicalState
	mechanical_state.rebuild()
	return mechanical_state.registry


func _class_label() -> String:
	var source: Script = get_script()
	var global_name: StringName = source.get_global_name()
	return str(global_name) if not global_name.is_empty() else source.resource_path.get_file()


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if part_type.is_empty() or compatible_socket_types.is_empty():
		issues.append("Peça sem tipo/compatibilidade: " + name)
	if required_fasteners < 0:
		issues.append("Quantidade de parafusos inválida: " + name)
	return issues
