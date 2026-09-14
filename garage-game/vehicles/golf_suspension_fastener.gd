extends Fastener
## Service access and correct bolt-axis rotation are local to the new assemblies.
## The existing Fastener still owns tightness, tool matching, feedback and save.

var visual_axis_basis := Basis.IDENTITY


func set_tightness(value: int) -> void:
	super.set_tightness(value)
	if bolt_mesh:
		bolt_mesh.position = _mesh_origin - insertion_axis * tightness * travel_per_step
		bolt_mesh.basis = visual_axis_basis * Basis(Vector3.UP, float(tightness) * PI / 3.0)


func _service_access() -> Dictionary:
	var mount := get_parent().get_parent() as PartSocket
	if mount and mount.installed_part is GolfSuspensionPart:
		return mount.installed_part.get_fastener_access()
	return {"allowed": true, "reason": ""}


func interaction_scroll(item: RigidBody3D, direction: int) -> bool:
	return super.interaction_scroll(item, direction) if _service_access()["allowed"] else false


func interaction_context(held: RigidBody3D) -> Dictionary:
	var result := super.interaction_context(held)
	var access := _service_access()
	if not access["allowed"]:
		result["hint"] = access["reason"]
		result["available"] = false
	return result
