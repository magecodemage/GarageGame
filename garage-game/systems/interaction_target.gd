class_name InteractionTarget
extends Node
## Adaptador local: o collider fornece contexto/ações, sem tipos de gameplay no Player.

var subject: Node


static func register(collider: Node) -> void:
	var target := InteractionTarget.new()
	target.name = "InteractionTarget"
	target.subject = collider
	collider.add_child(target)
	collider.set_meta(&"interaction_target", target)


static func resolve(collider: Object) -> InteractionTarget:
	if is_instance_valid(collider) and collider.has_meta(&"interaction_target"):
		return collider.get_meta(&"interaction_target") as InteractionTarget
	return null


func context(held: RigidBody3D) -> Dictionary:
	return subject.interaction_context(held)


func primary() -> RigidBody3D:
	if subject.has_method("interaction_primary"):
		return subject.interaction_primary() as RigidBody3D
	return null


func scroll(held: RigidBody3D, direction: int) -> bool:
	if subject.has_method("interaction_scroll"):
		return subject.interaction_scroll(held, direction)
	return false
