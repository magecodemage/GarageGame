class_name FloorJack
extends AutomotivePart
## Existing click-to-hold, carry physics and save identity; only the lift tool's
## work action and its articulated Blender visual are specialized here.

var support: VehicleJackSupport
var _arm: Node3D
var _saddle: Node3D
var _handle: Node3D
var _barrel: Node3D
var _rod: Node3D
var _return_springs: Node3D
var _links: Array[Node3D] = []
var _handle_rest := Basis.IDENTITY
var _pump_motion: Tween
var _arm_pivot := Vector3(0, 0.097, -0.18)
var _saddle_low := Vector3(0, 0.083, 0.21)
var _pad_offset := 0.022
var _pad_height := 0.105
var _pad_collision: CollisionShape3D


func _ready() -> void:
	super._ready()
	var path := "res://blender/exports/floor_jack.glb"
	var model: Node3D
	if ResourceLoader.exists(path, "PackedScene"):
		model = (load(path) as PackedScene).instantiate()
	else:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(path), state) == OK:
			model = doc.generate_scene(state)
	if model == null:
		push_error("Modelo Blender do macaco ausente")
		return
	model.name = "Visual"
	add_child(model)
	_arm = model.find_child("lift_arm", true, false)
	_saddle = model.find_child("saddle", true, false)
	_handle = model.find_child("pump_handle", true, false)
	_barrel = model.find_child("hydraulic_barrel", true, false)
	_rod = model.find_child("hydraulic_rod", true, false)
	_return_springs = model.find_child("return_springs", true, false)
	for side: String in ["left", "right"]:
		var link := model.find_child("level_link_" + side, true, false) as Node3D
		if link: _links.append(link)
	if _handle: _handle_rest = _handle.basis
	_pad_collision = CollisionShape3D.new()
	_pad_collision.name = "SaddleCollision"
	var pad_shape := CylinderShape3D.new()
	pad_shape.radius = 0.046
	pad_shape.height = 0.012
	_pad_collision.shape = pad_shape
	add_child(_pad_collision)
	set_pad_height(0.105)


func get_remove_evaluation() -> Dictionary:
	if support and support.is_supporting():
		return {"allowed": false, "reason": "Baixe o veículo antes de retirar o macaco"}
	return super.get_remove_evaluation()


func interaction_primary() -> RigidBody3D:
	if support and support.is_supporting():
		support.feedback_reason = "Baixe o veículo antes de retirar o macaco"
		return null
	return super.interaction_primary()


func interaction_scroll(_held: RigidBody3D, direction: int) -> bool:
	if is_held or not installed or support == null:
		return false
	var success := support.request_step(direction)
	if success and _handle:
		if is_instance_valid(_pump_motion): _pump_motion.kill()
		_pump_motion = create_tween()
		_pump_motion.tween_method(func(t: float) -> void: _handle.basis = _handle_rest * Basis(Vector3.RIGHT, sin(t * PI) * 0.14), 0.0, 1.0, 0.3)
	return success


func interaction_context(_held: RigidBody3D) -> Dictionary:
	var result := super.interaction_context(_held)
	if installed:
		result["title"] = "Macaco posicionado"
		result["detail"] = "Elevação: %.0f cm" % (support.current_lift * 100.0)
		result["hint"] = "Scroll ↑ Levantar   ·   Scroll ↓ Baixar"
		if not support.feedback_reason.is_empty(): result["hint"] = support.feedback_reason
		result["debug"] += "\nPonto: " + str(support.active_point.corner if support.active_point else &"")
	return result


func get_carry_offset(distance: float) -> Vector3:
	return Vector3(0.40, -0.48, -maxf(distance, 1.55))


func get_carry_basis(_current: Basis) -> Basis:
	return Basis.IDENTITY


func get_carry_world_basis(proposed: Basis) -> Basis:
	# The chassis is carried level; yaw still follows the player's aim.
	return Basis(Vector3.UP, atan2(proposed.z.x, proposed.z.z))


func get_carry_clearance_offset() -> Vector3:
	# This asset's origin is at the floor, not at its collision centre.
	return Vector3.UP * 0.27


func get_snap_clearance_offset() -> Vector3:
	return Vector3.UP * 0.043


func arm_angle(height: float) -> float:
	var lever := _saddle_low - _arm_pivot
	return atan2(lever.y, lever.z) - asin(clampf((height - _pad_offset - _arm_pivot.y) / lever.length(), -1.0, 1.0))


func pad_position(height: float) -> Vector3:
	return _arm_pivot + Basis(Vector3.RIGHT, arm_angle(height)) * (_saddle_low - _arm_pivot) + Vector3.UP * _pad_offset


func set_pad_height(height: float) -> void:
	_pad_height = clampf(height, 0.105, 0.485)
	var angle := arm_angle(_pad_height)
	if _pad_collision: _pad_collision.position = pad_position(_pad_height) - Vector3.UP * 0.006
	if _arm: _arm.rotation.x = angle
	if _saddle: _saddle.rotation.x = -angle
	for link: Node3D in _links: link.rotation.x = angle
	var hydraulic_base := Vector3(0, 0.055, 0.110)
	var pin := _arm_pivot + Basis(Vector3.RIGHT, angle) * Vector3(0, 0.020, 0.095)
	var direction := (pin - hydraulic_base).normalized()
	var orientation := Basis(Quaternion(Vector3.BACK, direction))
	if _barrel:
		_barrel.transform = Transform3D(orientation, hydraulic_base)
	if _rod:
		_rod.transform = Transform3D(orientation.scaled_local(Vector3(1, 1, maxf(0.001, pin.distance_to(hydraulic_base) - 0.145) / 0.059619)), hydraulic_base + direction * 0.145)
	if _return_springs:
		_return_springs.transform = Transform3D(orientation.scaled_local(Vector3(1, 1, pin.distance_to(hydraulic_base) / 0.204619)), hydraulic_base)
