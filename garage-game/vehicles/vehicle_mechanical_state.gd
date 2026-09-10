class_name VehicleMechanicalState
extends Node
## Consulta agregada do veículo. Não impõe regras de gameplay.

@export var vehicle_id: StringName = &"prototype_vehicle"
@export var critical_part_ids: Array[StringName] = []

var registry: Dictionary = {}


func _ready() -> void:
	add_to_group("vehicle_mechanical_states")
	rebuild.call_deferred()


func rebuild() -> void:
	registry.clear()
	for node in get_tree().get_nodes_in_group("persistable"):
		if node.has_method("get_persistent_id"):
			var id: StringName = node.get_persistent_id()
			if not id.is_empty():
				registry[id] = node


func get_part(id: StringName) -> AutomotivePart:
	return registry.get(id) as AutomotivePart


func get_fastener(id: StringName) -> Fastener:
	return registry.get(id) as Fastener


func get_parts() -> Array[AutomotivePart]:
	var parts: Array[AutomotivePart] = []
	for node in registry.values():
		if node is AutomotivePart:
			parts.append(node)
	return parts


func get_missing_critical_parts() -> Array[StringName]:
	var missing: Array[StringName] = []
	for id in critical_part_ids:
		var part := get_part(id)
		if not part or not part.installed:
			missing.append(id)
	return missing


func get_loose_parts() -> Array[AutomotivePart]:
	var result: Array[AutomotivePart] = []
	for part in get_parts():
		if part.installed and part.is_loose():
			result.append(part)
	return result


func get_partially_secure_parts() -> Array[AutomotivePart]:
	var result: Array[AutomotivePart] = []
	for part in get_parts():
		if part.is_partially_secure():
			result.append(part)
	return result


func get_vehicle_readiness() -> float:
	if critical_part_ids.is_empty():
		return 1.0
	var score: float = 0.0
	for id in critical_part_ids:
		var part := get_part(id)
		if part and part.installed:
			score += part.get_fastening_ratio() if part.required_fasteners > 0 else 1.0
	return score / float(critical_part_ids.size())


func validate_dependencies(nodes: Dictionary) -> PackedStringArray:
	var issues := PackedStringArray()
	for part in get_parts():
		if not part.dependencies:
			continue
		var part_dependencies: Array[StringName] = []
		part_dependencies.append_array(part.dependencies.required_parts_installed)
		part_dependencies.append_array(part.dependencies.required_parts_removed)
		part_dependencies.append_array(part.dependencies.blocking_parts)
		part_dependencies.append_array(part.dependencies.required_fasteners_loose)
		for id in part_dependencies:
			if not nodes.has(id):
				issues.append("Dependência desconhecida em %s: %s" % [part.part_id, id])
			elif id == part.part_id:
				issues.append("Peça depende de si mesma: " + str(id))
	for id in critical_part_ids:
		if not nodes.get(id) is AutomotivePart:
			issues.append("Peça crítica desconhecida: " + str(id))
	return issues
