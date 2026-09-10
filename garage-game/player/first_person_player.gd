class_name FirstPersonPlayer
extends CharacterBody3D

@export var movement_speed: float = 3.2
@export var movement_acceleration: float = 14.0
@export var jump_velocity: float = 3.7
@export var mouse_sensitivity: float = 0.0025
@export var crouch_speed: float = 1.35
@export var head_bob_enabled: bool = false
@export var head_bob_amount: float = 0.009
@export var interaction: InteractionController

@onready var camera: Camera3D = $Camera3D
@onready var body_shape: CollisionShape3D = $CollisionShape3D

var controls_enabled: bool = true
var crouched: bool = false
var _capsule: CapsuleShape3D
var _bob_phase: float = 0.0


func _ready() -> void:
	_capsule = body_shape.shape.duplicate() as CapsuleShape3D
	body_shape.shape = _capsule
	set_controls_enabled(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		set_controls_enabled(false)
		return
	if not controls_enabled:
		if event.is_action_pressed("primary_interact") and not get_tree().paused:
			set_controls_enabled(true)
			interaction.wait_for_primary_release = true
		return
	if interaction.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0), deg_to_rad(85.0))


func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	interaction.enabled = value
	if not value:
		interaction.cancel_interaction()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		set_controls_enabled(false)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_update_posture(delta)
	var input_direction := Vector2.ZERO
	if controls_enabled:
		input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if Input.is_action_just_pressed("jump") and is_on_floor() and not crouched:
			velocity.y = jump_velocity
	var direction: Vector3 = global_basis * Vector3(input_direction.x, 0.0, input_direction.y)
	var speed: float = crouch_speed if crouched else movement_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, movement_acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, movement_acceleration * delta)
	move_and_slide()


func _update_posture(delta: float) -> void:
	var wants_crouch: bool = controls_enabled and Input.is_action_pressed("crouch")
	crouched = wants_crouch or (_capsule.height < 1.79 and not can_stand())
	var height: float = 1.05 if crouched else 1.8
	_capsule.height = move_toward(_capsule.height, height, delta * 3.5)
	body_shape.position.y = _capsule.height * 0.5
	var camera_height: float = _capsule.height - 0.18
	if head_bob_enabled and is_on_floor() and not is_instance_valid(interaction.carrier.held_item):
		_bob_phase += Vector2(velocity.x, velocity.z).length() * delta * 2.5
		camera_height += sin(_bob_phase) * head_bob_amount
	camera.position.y = lerpf(camera.position.y, camera_height, 1.0 - exp(-18.0 * delta))


func can_stand() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = _capsule.radius
	shape.height = 1.78
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.91, 0))
	query.collision_mask = 51
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func restore_pose(pose: Transform3D, pitch: float, was_crouched: bool) -> void:
	global_transform = pose
	velocity = Vector3.ZERO
	camera.rotation = Vector3(pitch, 0, 0)
	crouched = was_crouched
	_capsule.height = 1.05 if crouched else 1.8
	body_shape.position.y = _capsule.height * 0.5
	camera.position.y = _capsule.height - 0.18
