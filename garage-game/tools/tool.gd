class_name Tool
extends Grabbable

signal tool_picked_up(tool: Tool)
signal tool_dropped(tool: Tool)

@export var tool_id: StringName = &""
@export var spec: ToolSpec
@export var visuals: Node3D
@export var size_label: Label3D

var tool_type: StringName:
	get: return spec.tool_type
var tool_size: int:
	get: return spec.tool_size
var usable: bool:
	get: return spec.usable
var stored: bool:
	get: return is_instance_valid(placement_socket)
var _feedback_tween: Tween
var _visual_rotation := Vector3.ZERO


func _ready() -> void:
	if not spec:
		spec = ToolSpec.new()
	mass = spec.mass_kg
	display_name = "Chave %d mm" % tool_size
	if size_label:
		size_label.text = str(tool_size)
	if visuals:
		_visual_rotation = visuals.rotation
	super._ready()
	picked_up.connect(func(_item: Grabbable) -> void: tool_picked_up.emit(self))
	dropped.connect(func(_item: Grabbable) -> void: tool_dropped.emit(self))


func get_persistent_id() -> StringName:
	return tool_id


func use_feedback(direction: int) -> void:
	play_cue(&"tighten" if direction > 0 else &"loosen")
	if not visuals:
		return
	if _feedback_tween:
		_feedback_tween.kill()
	visuals.rotation = _visual_rotation
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(visuals, "rotation:z", _visual_rotation.z + direction * 0.18, 0.06)
	_feedback_tween.tween_property(visuals, "rotation", _visual_rotation, 0.12)


func interaction_context(held: RigidBody3D) -> Dictionary:
	var result := super.interaction_context(held)
	result["debug"] += "\nTipo: %s\nTamanho: %d mm\nArmazenada: %s" % [tool_type, tool_size, stored]
	return result


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if not spec or tool_size <= 0 or tool_type.is_empty():
		issues.append("Ferramenta sem especificação/tamanho/tipo válido: " + name)
	return issues
