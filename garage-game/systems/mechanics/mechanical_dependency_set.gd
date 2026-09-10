class_name MechanicalDependencySet
extends Resource
## Regras declarativas por IDs persistentes. Não conhece cenas nem Player.

@export var required_parts_installed: Array[StringName] = []
@export var blocking_parts: Array[StringName] = []
@export var required_parts_removed: Array[StringName] = []
@export var required_fasteners_loose: Array[StringName] = []


func evaluate_install(registry: Dictionary) -> Dictionary:
	for id in required_parts_installed:
		var part := registry.get(id) as AutomotivePart
		if not part or not part.installed:
			return _blocked("Instale %s primeiro." % _label(registry, id))
	for id in required_parts_removed:
		var part := registry.get(id) as AutomotivePart
		if part and part.installed:
			return _blocked("Remova %s primeiro." % _label(registry, id))
	return _allowed()


func evaluate_remove(registry: Dictionary) -> Dictionary:
	for id in blocking_parts:
		var part := registry.get(id) as AutomotivePart
		if part and part.installed:
			return _blocked("Remova %s primeiro." % _label(registry, id))
	var loose_count: int = 0
	for id in required_fasteners_loose:
		var fastener := registry.get(id) as Fastener
		if fastener and fastener.tightness > 0:
			loose_count += 1
	if loose_count > 0:
		return _blocked("Afrouxe %d parafuso%s primeiro." % [loose_count, "" if loose_count == 1 else "s"])
	return _allowed()


func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.append_array(required_parts_installed)
	result.append_array(blocking_parts)
	result.append_array(required_parts_removed)
	result.append_array(required_fasteners_loose)
	return result


func describe() -> String:
	var lines: PackedStringArray = []
	if not required_parts_installed.is_empty():
		lines.append("Requer instaladas: " + _join_ids(required_parts_installed))
	if not blocking_parts.is_empty():
		lines.append("Bloqueiam remoção: " + _join_ids(blocking_parts))
	if not required_parts_removed.is_empty():
		lines.append("Requer removidas: " + _join_ids(required_parts_removed))
	if not required_fasteners_loose.is_empty():
		lines.append("Requer soltos: " + _join_ids(required_fasteners_loose))
	return "\n".join(lines) if not lines.is_empty() else "Sem dependências"


func _label(registry: Dictionary, id: StringName) -> String:
	var node: Node = registry.get(id)
	return node.display_name if node and "display_name" in node else str(id)


func _join_ids(ids: Array[StringName]) -> String:
	var values := PackedStringArray()
	for id in ids:
		values.append(str(id))
	return ", ".join(values)


func _allowed() -> Dictionary:
	return {"allowed": true, "reason": ""}


func _blocked(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason}
