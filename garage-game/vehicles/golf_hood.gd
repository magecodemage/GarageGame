class_name GolfHood
extends VehicleRuntimeSystem
## Persistent hinge controller; the imported hood keeps its original closed pose.

var pivot: Node3D
var is_open: bool = false
var open_degrees: float = -65.0
var _closed_basis: Basis
var _motion: Tween


func configure(hinge: Node3D) -> void:
	pivot = hinge
	_closed_basis = pivot.basis


func set_open(value: bool, immediate: bool = false) -> void:
	is_open = value
	if not is_instance_valid(pivot):
		return
	if is_instance_valid(_motion):
		_motion.kill()
	var angle: float = deg_to_rad(open_degrees) if value else 0.0
	if immediate:
		_apply_angle(angle)
	else:
		_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_motion.tween_method(_apply_angle, pivot.rotation.x, angle, 0.65)


func _apply_angle(angle: float) -> void:
	pivot.basis = _closed_basis * Basis(Vector3.RIGHT, angle)


func capture_state() -> Dictionary:
	return {"open": is_open}


func apply_state(data: Dictionary) -> void:
	set_open(data.get("open", false), true)


func validate_saved_state(data: Dictionary) -> String:
	return "" if data.get("open") is bool else "Estado do capô inválido"
