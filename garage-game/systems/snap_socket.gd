class_name SnapSocket
extends Area3D
## Placement comum a peças e slots de ferramentas; IDs nunca são NodePaths.

signal item_placed(item: Grabbable)
signal item_removed(item: Grabbable)

@export var socket_id: StringName = &""
@export var socket_type: StringName = &""
@export var snap_position := Vector3.ZERO
@export var snap_rotation := Vector3.ZERO
@export_range(0.05, 1.5) var snap_distance: float = 0.65
@export var installation_point: Marker3D
@export var preview: MeshInstance3D

var installed_item: Grabbable
var occupied: bool:
	get: return is_instance_valid(installed_item)
var _preview_material: StandardMaterial3D
var _ray_layer: int


func _ready() -> void:
	add_to_group("snap_sockets")
	add_to_group("persistable")
	_ray_layer = collision_layer
	InteractionTarget.register(self)
	if preview and preview.material_override:
		_preview_material = preview.material_override.duplicate() as StandardMaterial3D
		preview.material_override = _preview_material
	set_highlight(false)


func get_persistent_id() -> StringName:
	return socket_id


func is_accessible() -> bool:
	return true


func is_compatible(_item: Grabbable) -> bool:
	return false


func can_snap(item: Grabbable) -> bool:
	return get_snap_evaluation(item)["allowed"]


func get_snap_evaluation(item: Grabbable) -> Dictionary:
	if not is_instance_valid(item):
		return {"allowed": false, "reason": "Item inválido."}
	if occupied:
		return {"allowed": false, "reason": "Encaixe ocupado."}
	if not is_accessible():
		return {"allowed": false, "reason": "Encaixe inacessível."}
	if not is_compatible(item):
		return {"allowed": false, "reason": "Peça incompatível."}
	if item is AutomotivePart:
		var dependency_result: Dictionary = item.can_install(self as PartSocket)
		if not dependency_result["allowed"]:
			return dependency_result
	if not item.is_held:
		return {"allowed": false, "reason": "Segure a peça para instalar."}
	if item.global_position.distance_to(installation_point.global_position) > snap_distance:
		return {"allowed": false, "reason": "Aproxime a peça do encaixe."}
	# Não permite snap através de paredes ou do chassi.
	var query := PhysicsRayQueryParameters3D.create(
		item.global_position, installation_point.global_position, 33, [item.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return {"allowed": false, "reason": "O encaixe está obstruído."}
	return {"allowed": true, "reason": ""}


func place_item(item: Grabbable, restoring: bool = false) -> bool:
	if occupied or not is_compatible(item) or (not restoring and not can_snap(item)):
		return false
	installed_item = item
	var socket_pose := Transform3D(Basis.from_euler(snap_rotation * PI / 180.0), snap_position)
	item.on_placed(self, socket_pose * item.get_installation_pose())
	collision_layer = 0
	set_highlight(false)
	item_placed.emit(item)
	return true


func remove_item() -> void:
	if not occupied:
		return
	var item: Grabbable = installed_item
	installed_item = null
	item.on_removed()
	collision_layer = _ray_layer
	set_highlight(false)
	item_removed.emit(item)


func set_highlight(available: bool) -> void:
	if not preview:
		return
	preview.visible = not occupied and is_accessible()
	if _preview_material:
		var color := Color(0.25, 0.9, 0.55, 0.32) if available else Color(0.85, 0.62, 0.25, 0.1)
		_preview_material.albedo_color = color
		_preview_material.emission = Color(color.r, color.g, color.b)
		_preview_material.emission_energy_multiplier = 0.25 if available else 0.0


func release_hint() -> String:
	return "Solte LMB para instalar"


func interaction_context(_held: RigidBody3D) -> Dictionary:
	return {"title": "Encaixe", "hint": "", "debug": "ID: %s\nTipo: %s\nOcupado: %s" % [
		socket_id, socket_type, occupied]}


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if socket_id.is_empty() or socket_type.is_empty():
		issues.append("Socket sem ID/tipo: " + name)
	if not installation_point:
		issues.append("Socket sem InstallationPoint: " + name)
	return issues
