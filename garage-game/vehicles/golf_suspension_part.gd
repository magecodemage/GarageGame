class_name GolfSuspensionPart
extends AutomotivePart
## Only the service-assembly behavior is specialized. Pickup, sockets, fastening
## and persistence still belong to the existing AutomotivePart implementation.

var assembly_parent_id: StringName = &""
var service_requires_removed: Array[StringName] = []
var required_secure: Array[StringName] = []
var retaining_parts: Array[AutomotivePart] = []
var _separating_contacts: Array[PhysicsBody3D] = []


func get_remove_evaluation() -> Dictionary:
	var result := super.get_remove_evaluation()
	if not result["allowed"] or not installed:
		return result
	return _service_access()


func can_install(socket: PartSocket = null) -> Dictionary:
	var result := super.can_install(socket)
	if not result["allowed"]:
		return result
	var registry := _mechanical_registry()
	for id: StringName in required_secure:
		var component := registry.get(id) as AutomotivePart
		if component == null or not component.is_secure():
			return {"allowed": false, "reason": "Fixe o retentor da mola na bancada antes de instalar o conjunto"}
	return _service_access()


func get_fastener_access() -> Dictionary:
	return _service_access()


func bind_retaining_parts(components: Array[AutomotivePart]) -> void:
	retaining_parts = components
	for component: AutomotivePart in retaining_parts:
		component.state_changed.connect(func(_state: AutomotivePart.State) -> void: refresh_fastening_state())
	refresh_fastening_state()


func get_fastening_ratio() -> float:
	if retaining_parts.is_empty():
		return super.get_fastening_ratio()
	if not installed:
		return 0.0
	var total := 0.0
	for component: AutomotivePart in retaining_parts:
		total += component.get_fastening_ratio() if component.installed else 0.0
	return total / retaining_parts.size()


func is_secure() -> bool:
	return super.is_secure() if retaining_parts.is_empty() else installed and is_equal_approx(get_fastening_ratio(), 1.0)


func _inspection_status() -> String:
	if retaining_parts.is_empty() or not installed:
		return super._inspection_status()
	return "Segura · fixação pelas conexões" if is_secure() else "Encaixada · fixe braços/amortecedor"


func _service_access() -> Dictionary:
	var registry := _mechanical_registry()
	for id: StringName in service_requires_removed:
		var host := registry.get(id) as AutomotivePart
		if host != null and host.installed:
			return {"allowed": false, "reason": "Retire %s para trabalhar na bancada" % host.display_name}
	return {"allowed": true, "reason": ""}


func begin_hold(holder: PhysicsBody3D) -> bool:
	if not super.begin_hold(holder):
		return false
	# Interlocking service colliders may touch in the installed pose (hub in rotor,
	# damper inside coil). Ignore only these initial contacts until separated;
	# floor, bodywork, walls and unrelated loose parts remain physical throughout.
	for node: Node in get_tree().get_nodes_in_group("grabbables"):
		if node == self or not node is AutomotivePart:
			continue
		var other := node as AutomotivePart
		if other.installed and global_position.distance_to(other.global_position) < carry_radius + other.carry_radius + 0.08:
			add_collision_exception_with(other)
			if not _separating_contacts.has(other):
				_separating_contacts.append(other)
	return true


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	for index: int in range(_separating_contacts.size() - 1, -1, -1):
		var other := _separating_contacts[index]
		if not is_instance_valid(other):
			_separating_contacts.remove_at(index)
			continue
		# An installed nested coil travels with its strut; keep their mutual
		# collision exception until that actual assembly is dismantled.
		if is_ancestor_of(other) or other.is_ancestor_of(self):
			continue
		var other_radius: float = other.carry_radius if other is Grabbable else 0.15
		if global_position.distance_to(other.global_position) > carry_radius + other_radius + 0.08:
			remove_collision_exception_with(other)
			_separating_contacts.remove_at(index)


func on_placed(socket: Node3D, local_pose: Transform3D) -> void:
	super.on_placed(socket, local_pose)
	if not assembly_parent_id.is_empty():
		var host := _mechanical_registry().get(assembly_parent_id) as AutomotivePart
		if host:
			add_collision_exception_with(host)
			if not _separating_contacts.has(host):
				_separating_contacts.append(host)


func interaction_context(held: RigidBody3D) -> Dictionary:
	var result := super.interaction_context(held)
	if not service_requires_removed.is_empty():
		result["debug"] += "\nMola: desmontagem em bancada; compressão abstraída no protótipo"
	return result
