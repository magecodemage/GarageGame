class_name SceneRegistry
extends RefCounted
## Registro limitado a esta cena, sem buscas globais por nomes ou NodePaths salvos.

var nodes: Dictionary = {}
var items: Array[Grabbable] = []
var sockets: Array[SnapSocket] = []
var fasteners: Array[Fastener] = []
var toolboxes: Array[Toolbox] = []
var runtime_systems: Array[VehicleRuntimeSystem] = []
var issues := PackedStringArray()


func rebuild(scene: Node) -> bool:
	nodes.clear()
	items.clear()
	sockets.clear()
	fasteners.clear()
	toolboxes.clear()
	runtime_systems.clear()
	issues.clear()
	for node in scene.get_tree().get_nodes_in_group("persistable"):
		if not scene.is_ancestor_of(node):
			continue
		var id: StringName = node.get_persistent_id()
		if id.is_empty():
			issues.append("ID persistente vazio em " + str(node.name))
		elif nodes.has(id):
			issues.append("ID persistente duplicado: " + str(id))
		else:
			nodes[id] = node
		if node is Grabbable:
			items.append(node)
		elif node is SnapSocket:
			sockets.append(node)
		elif node is Fastener:
			fasteners.append(node)
		elif node is Toolbox:
			toolboxes.append(node)
		elif node is VehicleRuntimeSystem:
			runtime_systems.append(node)
		if node.has_method("validate_configuration"):
			issues.append_array(node.validate_configuration())
	for state_node in scene.get_tree().get_nodes_in_group("vehicle_mechanical_states"):
		if scene.is_ancestor_of(state_node):
			state_node.rebuild()
			issues.append_array(state_node.validate_dependencies(nodes))
	return issues.is_empty()
