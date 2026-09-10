class_name Grabbable
extends RigidBody3D
## Corpo físico comum a ferramentas e peças. Nunca é parentado à câmera.

signal picked_up(item: Grabbable)
signal dropped(item: Grabbable)

@export var display_name: String = "Objeto"
@export var can_be_grabbed: bool = true
@export_range(0.05, 2.0) var carry_radius: float = 0.25
@export var interaction_audio: InteractionAudio

var is_held: bool = false
# Protocolo de placement: SnapSocket expõe remove_item/is_accessible.
# Node3D mantém a base independente de PartSocket/ToolSlot.
var placement_socket: Node3D
var hold_target := Transform3D.IDENTITY
var hold_strength: float = 90.0
var hold_damping: float = 18.0
var max_hold_force: float = 900.0
var max_hold_speed: float = 4.0
var _world_parent: Node
var _holder: PhysicsBody3D


func _ready() -> void:
	_world_parent = get_parent()
	add_to_group("grabbables")
	add_to_group("persistable")
	InteractionTarget.register(self)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func get_persistent_id() -> StringName:
	return &""


func can_pick_up() -> bool:
	return can_be_grabbed and not is_held and (
		not is_instance_valid(placement_socket) or placement_socket.is_accessible()
	)


func begin_hold(holder: PhysicsBody3D) -> bool:
	if not can_pick_up():
		return false
	if is_instance_valid(placement_socket):
		placement_socket.remove_item()
	_holder = holder
	add_collision_exception_with(holder)
	is_held = true
	freeze = false
	sleeping = false
	hold_target = global_transform
	picked_up.emit(self)
	play_cue(&"pickup")
	return true


func end_hold() -> void:
	is_held = false
	_restore_holder_collision()
	linear_velocity = linear_velocity.limit_length(2.5)
	angular_velocity = angular_velocity.limit_length(4.0)
	dropped.emit(self)
	play_cue(&"drop")


func _physics_process(_delta: float) -> void:
	if not is_held:
		_restore_holder_collision()


func _restore_holder_collision() -> void:
	if not is_instance_valid(_holder):
		return
	var sphere := SphereShape3D.new()
	sphere.radius = carry_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = 8
	# Se o jogador entrou no item, restaura o contato quando houver separação.
	# O objeto já está FREE; isso nunca mantém um hold depois de soltar LMB.
	if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		remove_collision_exception_with(_holder)
		_holder = null


func on_placed(socket: Node3D, local_pose: Transform3D) -> void:
	if is_held:
		end_hold()
	placement_socket = socket
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reparent(socket.installation_point)
	transform = local_pose
	play_cue(&"snap")


func on_removed() -> void:
	if get_parent() != _world_parent:
		reparent(_world_parent)
	placement_socket = null
	freeze = false
	sleeping = false


func restore_free(pose: Transform3D) -> void:
	if is_held:
		end_hold()
	if is_instance_valid(placement_socket):
		placement_socket.remove_item()
	on_removed()
	global_transform = pose
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func get_installation_pose() -> Transform3D:
	return Transform3D.IDENTITY


func _integrate_forces(body_state: PhysicsDirectBodyState3D) -> void:
	if not is_held:
		return
	var error: Vector3 = hold_target.origin - body_state.transform.origin
	var response: float = clampf(8.0 / mass, 0.2, 1.0)
	var acceleration: Vector3 = error * hold_strength * response - body_state.linear_velocity * hold_damping
	var force: Vector3 = (acceleration - body_state.total_gravity) * mass
	body_state.apply_central_force(force.limit_length(max_hold_force))
	body_state.linear_velocity = body_state.linear_velocity.limit_length(max_hold_speed)
	var desired := hold_target.basis.get_rotation_quaternion()
	var current := body_state.transform.basis.orthonormalized().get_rotation_quaternion()
	var difference := (desired * current.inverse()).normalized()
	if difference.w < 0.0:
		difference = -difference
	var angular_target: Vector3 = difference.get_axis() * difference.get_angle() * 8.0
	body_state.angular_velocity = body_state.angular_velocity.lerp(
		angular_target.limit_length(4.0), 1.0 - exp(-12.0 * body_state.step)
	)


func interaction_primary() -> RigidBody3D:
	return self if can_pick_up() else null


func interaction_context(_held: RigidBody3D) -> Dictionary:
	return {"title": display_name, "hint": "Segure LMB para pegar" if can_pick_up() else "",
		"debug": "ID: %s\nMassa: %.2f kg" % [get_persistent_id(), mass]}


func play_cue(action: StringName) -> void:
	if interaction_audio:
		interaction_audio.cue(action)


func _on_body_entered(_body: Node) -> void:
	if not is_held and linear_velocity.length() > 0.6:
		play_cue(&"impact")


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if get_persistent_id().is_empty():
		issues.append("Objeto sem ID persistente: " + name)
	if mass <= 0.0:
		issues.append("Massa inválida: " + name)
	return issues
