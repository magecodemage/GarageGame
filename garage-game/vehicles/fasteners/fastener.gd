class_name Fastener
extends Area3D

signal fastener_changed(fastener: Fastener)
signal fastener_fully_tightened(fastener: Fastener)
signal fastener_fully_loosened(fastener: Fastener)

@export var fastener_id: StringName = &""
@export var display_name: String = "Wheel Bolt"
@export var spec: FastenerSpec
@export var tightness: int = 0
@export var installed: bool = true
@export var locked: bool = false
@export var position_index: int = 0
@export var bolt_mesh: MeshInstance3D
@export var interaction_audio: InteractionAudio

var required_tool_type: StringName:
	get: return spec.required_tool_type
var required_tool_size: int:
	get: return spec.required_tool_size
var max_tightness: int:
	get: return spec.max_tightness
var active: bool = false
var _material: StandardMaterial3D
var _mesh_origin := Vector3.ZERO


func _ready() -> void:
	if not spec:
		spec = FastenerSpec.new()
	add_to_group("fasteners")
	add_to_group("persistable")
	InteractionTarget.register(self)
	if bolt_mesh:
		_material = bolt_mesh.material_override.duplicate() as StandardMaterial3D
		bolt_mesh.material_override = _material
		_mesh_origin = bolt_mesh.position
	set_tightness(tightness)
	set_active(false)


func get_persistent_id() -> StringName:
	return fastener_id


func set_active(value: bool) -> void:
	active = value
	visible = active and installed
	collision_layer = 64 if visible else 0


func set_tightness(value: int) -> void:
	var previous: int = tightness
	tightness = clampi(value, 0, max_tightness)
	if bolt_mesh:
		bolt_mesh.position = _mesh_origin + Vector3(tightness * 0.004, 0, 0)
		bolt_mesh.rotation.x = float(tightness) * PI / 3.0
	if _material:
		_material.albedo_color = Color(0.45, 0.5, 0.53) if tightness == 0 else (
			Color(0.25, 0.75, 0.48) if tightness == max_tightness else Color(0.85, 0.66, 0.24))
	if previous == tightness:
		return
	fastener_changed.emit(self)
	if tightness == max_tightness:
		fastener_fully_tightened.emit(self)
	elif tightness == 0:
		fastener_fully_loosened.emit(self)


func accepts_tool(item: RigidBody3D) -> bool:
	return item is Tool and item.usable and item.is_held and (
		item.tool_type == required_tool_type and item.tool_size == required_tool_size)


func interaction_scroll(item: RigidBody3D, direction: int) -> bool:
	if not active or not installed or locked or not accepts_tool(item):
		return false
	var previous: int = tightness
	set_tightness(tightness + signi(direction))
	if previous == tightness:
		return false
	(item as Tool).use_feedback(direction)
	if interaction_audio:
		interaction_audio.cue(&"tighten" if direction > 0 else &"loosen")
	return true


func interaction_context(held: RigidBody3D) -> Dictionary:
	var progress: String = "■".repeat(tightness) + "□".repeat(max_tightness - tightness)
	var status: String = "Solto" if tightness == 0 else "Aperto: %d/%d" % [tightness, max_tightness]
	if tightness == max_tightness:
		status = "APERTADO · %d/%d" % [tightness, max_tightness]
	var hint: String = "Requer chave %d mm" % required_tool_size
	if accepts_tool(held):
		hint = "Scroll ↑ Apertar   ·   Scroll ↓ Afrouxar"
	elif held is Tool:
		hint = ("Tamanho incorreto — necessário %d mm" % required_tool_size
			if held.tool_type == required_tool_type else "Tipo de ferramenta incorreto")
	if locked:
		hint = "Parafuso bloqueado"
	return {"title": "%s %d" % [display_name, position_index + 1],
		"detail": "%d mm · %s\n%s" % [required_tool_size, status, progress],
		"hint": hint, "available": accepts_tool(held) and not locked,
		"debug": "ID: %s\nTool: %s / %d mm\nTightness: %d/%d\nLocked: %s" % [
			fastener_id, required_tool_type, required_tool_size, tightness, max_tightness, locked]}


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if fastener_id.is_empty():
		issues.append("Parafuso sem ID: " + name)
	if not spec or required_tool_size <= 0 or required_tool_type.is_empty() or max_tightness <= 0:
		issues.append("Parafuso sem ferramenta/tamanho/aperto válido: " + name)
	if tightness < 0 or tightness > max_tightness:
		issues.append("Aperto fora dos limites: " + name)
	return issues
