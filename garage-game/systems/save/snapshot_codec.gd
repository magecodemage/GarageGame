class_name SnapshotCodec
extends RefCounted

static func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func to_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not valid_number(component) or absf(float(component)) > 10000.0:
			return false
	return true


static func transform_of(record: Dictionary) -> Transform3D:
	return Transform3D(Basis.from_euler(to_vector(record["rotation"])), to_vector(record["position"]))


static func pose(node: Node3D) -> Dictionary:
	return {"position": vector(node.global_position), "rotation": vector(node.global_rotation)}
