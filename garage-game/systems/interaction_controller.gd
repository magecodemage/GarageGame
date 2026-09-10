class_name InteractionController
extends Node
## O collider fornece as ações; este componente só coordena entrada, alvo e hold.

signal context_changed(context: Dictionary)

@export var ray: RayCast3D
@export var carrier: PartCarrier
@export var player_body: CharacterBody3D

var target: InteractionTarget
var enabled: bool = true
var wait_for_primary_release: bool = false
var _was_primary_down: bool = false
var _scroll_steps: Array[int] = []
var _ray_ignored_item: Grabbable


func _ready() -> void:
	ray.add_exception(player_body)
	carrier.held_changed.connect(_on_held_changed)


func _physics_process(delta: float) -> void:
	if not enabled:
		context_changed.emit({"hint": "Clique para continuar"})
		return
	carrier.update_hold(delta)
	refresh_target()
	var primary_down: bool = Input.is_action_pressed("primary_interact")
	if wait_for_primary_release:
		wait_for_primary_release = primary_down
	elif primary_down and not _was_primary_down and target:
		var body: RigidBody3D = target.primary()
		if body is Grabbable:
			carrier.pick_up(body)
	if not primary_down and is_instance_valid(carrier.held_item):
		carrier.release()
	_was_primary_down = primary_down
	for direction in _scroll_steps:
		if target:
			target.scroll(carrier.held_item, direction)
	_scroll_steps.clear()
	emit_context()


func refresh_target() -> void:
	ray.force_raycast_update()
	target = InteractionTarget.resolve(ray.get_collider() if ray.is_colliding() else null)


func handle_input(event: InputEvent) -> bool:
	if not enabled:
		return false
	if event is InputEventMouseMotion and is_instance_valid(carrier.held_item):
		if Input.is_action_pressed("secondary_interact"):
			carrier.rotate_item(event.relative)
			return true
	var direction: int = 0
	if event.is_action_pressed("tighten"):
		direction = 1
	elif event.is_action_pressed("loosen"):
		direction = -1
	if direction != 0:
		if Input.is_action_pressed("adjust_hold_distance") and is_instance_valid(carrier.held_item):
			carrier.adjust_distance(direction)
		else:
			# Uma entrada por evento, mesmo com vários ticks de scroll no mesmo frame.
			_scroll_steps.append(direction)
		return true
	return false


func emit_context() -> void:
	var held: Grabbable = carrier.held_item
	var context: Dictionary = target.context(held) if is_instance_valid(target) else {}
	if is_instance_valid(held):
		context["held"] = held.display_name
		if carrier.candidate:
			context["title"] = held.display_name
			context["hint"] = carrier.candidate.release_hint()
			context["available"] = true
	context_changed.emit(context)


func cancel_interaction() -> void:
	carrier.release(false)
	_scroll_steps.clear()
	wait_for_primary_release = true


func _on_held_changed(item: Grabbable) -> void:
	if is_instance_valid(_ray_ignored_item):
		ray.remove_exception(_ray_ignored_item)
	_ray_ignored_item = item
	if is_instance_valid(item):
		ray.add_exception(item)
