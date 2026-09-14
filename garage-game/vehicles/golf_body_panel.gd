class_name GolfBodyPanel
extends VehicleRuntimeSystem
## Hinge state only; no replacement of the working hood controller.

var pivot: Node3D
var display_name: String = "Painel"
var is_open: bool = false
var open_degrees: float = 65.0
var axis := Vector3.UP
var _closed_basis := Basis.IDENTITY
var _angle: float = 0.0
var _motion: Tween


func configure(node: Node3D, label: String, hinge_axis: Vector3, degrees: float) -> void:
	pivot = node
	display_name = label
	axis = hinge_axis.normalized()
	open_degrees = degrees
	_closed_basis = pivot.basis


func set_open(value: bool, immediate: bool = false) -> void:
	is_open = value
	if not is_instance_valid(pivot):
		return
	if is_instance_valid(_motion):
		_motion.kill()
	var destination := deg_to_rad(open_degrees) if value else 0.0
	if immediate:
		_apply_angle(destination)
	else:
		_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_motion.tween_method(_apply_angle, _angle, destination, 0.7)


func _apply_angle(value: float) -> void:
	_angle = value
	pivot.basis = _closed_basis * Basis(axis, value)


func capture_state() -> Dictionary:
	return {"open": is_open}


func apply_state(data: Dictionary) -> void:
	set_open(data.get("open", false), true)


func validate_saved_state(data: Dictionary) -> String:
	return "" if data.get("open") is bool else "Estado de painel inválido: " + str(system_id)
