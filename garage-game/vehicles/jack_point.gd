class_name VehicleJackPoint
extends PartSocket
## World-ground socket: only the saddle follows the body. Never parent the
## jack chassis to the vehicle that it is lifting.

var support: VehicleJackSupport
var corner: StringName
var body_contact := Vector3.ZERO


func is_accessible() -> bool:
	return support != null and (support.active_point == null or support.active_point == self)


func get_snap_evaluation(item: Grabbable) -> Dictionary:
	var result := super.get_snap_evaluation(item)
	if not result["allowed"]:
		return result
	if item.global_basis.orthonormalized().y.dot(Vector3.UP) < 0.9:
		return {"allowed": false, "reason": "Mantenha as rodas do macaco voltadas para o chão"}
	return result


func release_hint() -> String:
	return "[G] Posicionar macaco neste ponto"


func interaction_context(_held: RigidBody3D) -> Dictionary:
	return {"title": "Ponto do macaco · " + str(corner).to_upper(),
		"hint": "Aproxime o macaco e pressione G", "debug": str(socket_id)}
