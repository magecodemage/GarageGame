class_name PartCarrier
extends Node3D
## Grab físico limitado por força, velocidade e alcance. Sem parenting à câmera.

signal held_changed(item: Grabbable)

@export var camera: Camera3D
@export var player_body: CharacterBody3D
@export_range(0.8, 2.5) var hold_distance: float = 1.35
@export var min_hold_distance: float = 0.85
@export var max_hold_distance: float = 3.2
@export var hold_strength: float = 90.0
@export var hold_damping: float = 18.0
@export var max_hold_force: float = 900.0
@export var target_speed: float = 4.5
@export var rotation_sensitivity: float = 0.008

@onready var clearance: ShapeCast3D = $Clearance

var held_item: Grabbable
var candidate: SnapSocket
var _relative_basis := Basis.IDENTITY
var _smoothed_target := Vector3.ZERO


func _ready() -> void:
	clearance.add_exception(player_body)


func pick_up(item: Grabbable) -> bool:
	if is_instance_valid(held_item) or not item.begin_hold(player_body):
		return false
	held_item = item
	clearance.add_exception(item)
	var sphere := SphereShape3D.new()
	sphere.radius = item.carry_radius
	clearance.shape = sphere
	_relative_basis = camera.global_basis.inverse() * item.global_basis
	_smoothed_target = item.global_position
	item.hold_strength = hold_strength
	item.hold_damping = hold_damping
	item.max_hold_force = max_hold_force
	held_changed.emit(item)
	return true


func update_hold(delta: float) -> void:
	if not is_instance_valid(held_item):
		_clear_candidate()
		return
	if camera.global_position.distance_to(held_item.global_position) > max_hold_distance:
		release(false)
		return
	global_transform = camera.global_transform
	var distance: float = clampf(hold_distance, maxf(min_hold_distance, held_item.carry_radius + 0.4), 2.3)
	var offset := Vector3(0.38, -0.22, -distance)
	clearance.target_position = Vector3.ZERO
	clearance.force_shapecast_update()
	if clearance.is_colliding():
		# Não puxa uma peça para dentro de uma câmera encostada na parede.
		_smoothed_target = held_item.global_position
	else:
		clearance.target_position = offset
		clearance.force_shapecast_update()
		var fraction: float = maxf(0.0, clearance.get_closest_collision_safe_fraction() - 0.02)
		var desired: Vector3 = camera.to_global(offset * fraction)
		_smoothed_target = _smoothed_target.move_toward(desired, target_speed * delta)
	held_item.hold_target = Transform3D(
		(camera.global_basis * _relative_basis).orthonormalized(), _smoothed_target)
	refresh_candidate()


func refresh_candidate() -> void:
	_clear_candidate()
	if not is_instance_valid(held_item):
		return
	var closest: float = INF
	for node in get_tree().get_nodes_in_group("snap_sockets"):
		var socket := node as SnapSocket
		if not socket.can_snap(held_item):
			continue
		var distance: float = held_item.global_position.distance_squared_to(socket.installation_point.global_position)
		if distance < closest:
			candidate = socket
			closest = distance
	if candidate:
		candidate.set_highlight(true)


func release(allow_snap: bool = true) -> void:
	if not is_instance_valid(held_item):
		return
	refresh_candidate()
	var item: Grabbable = held_item
	var did_snap: bool = allow_snap and candidate != null and candidate.place_item(item)
	if not did_snap:
		item.end_hold()
	clearance.remove_exception(item)
	held_item = null
	_clear_candidate()
	held_changed.emit(null)


func rotate_item(relative: Vector2) -> void:
	if not is_instance_valid(held_item):
		return
	_relative_basis = (Basis(Vector3.UP, -relative.x * rotation_sensitivity)
		* Basis(Vector3.RIGHT, -relative.y * rotation_sensitivity) * _relative_basis).orthonormalized()


func adjust_distance(direction: int) -> void:
	hold_distance = clampf(hold_distance + direction * 0.1, min_hold_distance, 2.3)


func _clear_candidate() -> void:
	if is_instance_valid(candidate):
		candidate.set_highlight(false)
	candidate = null
