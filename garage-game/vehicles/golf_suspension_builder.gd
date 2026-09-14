class_name GolfSuspensionBuilder
extends RefCounted
## Scene-specific assembler. One Blender manifest drives visible meshes,
## socket origins, simplified collisions, connections and fastener locations.

const MANIFEST := "res://vehicles/golf_suspension_manifest.json"
const VISUAL := "res://blender/exports/golf_suspension_parts.glb"
const BOLT := preload("res://vehicles/fasteners/wheel_bolt.tscn")
const PART := preload("res://vehicles/golf_suspension_part.gd")
const SERVICE_BOLT := preload("res://vehicles/golf_suspension_fastener.gd")

var parts: Dictionary = {}
var sockets: Dictionary = {}
var records: Array = []
var _car: Node3D
var _root: Node3D


func build(car: Node3D) -> void:
	_car = car
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary or not data.get("parts") is Array:
		push_error("Suspension manifest missing or invalid; rebuild Blender service parts")
		return
	records = data["parts"]
	var imported := _load_visual()
	if imported == null:
		return
	_remove_old_front_parts()
	_root = Node3D.new()
	_root.name = "Suspension"
	car.add_child(_root)
	for corner: String in ["fl", "fr", "rl", "rr", "front", "rear"]:
		var group := Node3D.new()
		group.name = corner.to_upper()
		_root.add_child(group)
		for label: String in ["Parts", "Sockets"]:
			var container := Node3D.new()
			container.name = label
			group.add_child(container)
	for record: Dictionary in records:
		_make_part(record, imported)
	for record: Dictionary in records:
		_make_socket(record)
	# Nested spring seats belong to the strut, not the car. The existing
	# Grabbable.on_placed reparents into InstallationPoint and carries the spring
	# naturally with a removed strut. SaveSystem already persists both items.
	for record: Dictionary in records:
		var parent_id: String = record.get("assembly_parent", "")
		if not parent_id.is_empty():
			var socket: PartSocket = sockets[record["id"]]
			socket.reparent(parts[parent_id], true)
	# Setup is the only restoring=true path; player reinstallation never tightens.
	for record: Dictionary in records:
		var socket: PartSocket = sockets[record["id"]]
		socket.place_item(parts[record["id"]], true)
	# The rear carrier and seated spring have no invented duplicate bolts. Their
	# securing state follows the actual neighboring parts owning those joints.
	for prefix: String in ["rear_left_", "rear_right_"]:
		var carrier_connections: Array[AutomotivePart] = []
		for suffix: String in ["lower_link", "upper_link", "trailing_arm", "shock"]:
			carrier_connections.append(parts[prefix + suffix])
		parts[prefix + "wheel_carrier"].bind_retaining_parts(carrier_connections)
		var spring_connections: Array[AutomotivePart] = [parts[prefix + "lower_link"], parts[prefix + "shock"]]
		parts[prefix + "spring"].bind_retaining_parts(spring_connections)
	var mechanical := car.get_node("MechanicalState") as VehicleMechanicalState
	for id: String in parts:
		if not StringName(id) in mechanical.critical_part_ids:
			mechanical.critical_part_ids.append(StringName(id))
	for corner: String in ["front_left", "front_right", "rear_left", "rear_right"]:
		var wheel := _find_part(StringName(corner + "_wheel"))
		if wheel:
			var dependency := MechanicalDependencySet.new()
			dependency.required_parts_installed.assign([StringName(corner + "_hub"), StringName(corner + "_brake_disc")])
			wheel.dependencies = dependency
	imported.free()
	mechanical.rebuild()


func _remove_old_front_parts() -> void:
	var assembly := _car.get_node("FrontLeftAssembly")
	for label: String in ["StrutSocket", "HubSocket", "BrakeDiscSocket", "BrakeCaliperSocket"]:
		var old := assembly.get_node_or_null(label)
		if old:
			old.get_parent().remove_child(old)
			old.free()
	for old: Node in assembly.get_node("Parts").get_children():
		if old is AutomotivePart and old.part_id != &"front_left_wheel":
			old.get_parent().remove_child(old)
			old.free()


func _make_part(record: Dictionary, imported: Node3D) -> void:
	var id: String = record["id"]
	var source := imported.find_child(id, true, false) as Node3D
	if source == null:
		push_error("Suspension geometry missing: " + id)
		return
	var part := PART.new() as GolfSuspensionPart
	part.name = id
	part.part_id = StringName(id)
	part.part_type = &"suspension_service"
	part.display_name = record["name"]
	part.compatible_socket_types.assign([StringName(id + "_mount")])
	part.required_fasteners = record["fasteners"].size()
	part.mass = float(record["mass"])
	part.position = v(record["origin"])
	part.linear_damp = 1.4
	part.angular_damp = 2.2
	part.collision_layer = 2
	part.collision_mask = 1 | 2 | 8 | 16 | 32
	part.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	part.part_metadata = {"suspension_corner": record["corner"], "geometry": "Blender", "revision": 1}
	part.assembly_parent_id = StringName(record.get("assembly_parent", ""))
	part.service_requires_removed.assign(record.get("service_requires_removed", []))
	part.required_secure.assign(record.get("required_secure", []))
	var size := v(record["bounds"]["size"])
	part.carry_radius = clampf(maxf(size.x, maxf(size.y, size.z)) * 0.48, 0.07, 0.65)
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.85
	physics_material.bounce = 0.0
	part.physics_material_override = physics_material
	var dependency := MechanicalDependencySet.new()
	dependency.required_parts_installed.assign(record["required_installed"])
	dependency.required_parts_removed.assign(record["required_removed"])
	dependency.blocking_parts.assign(record["blocking"])
	dependency.required_fasteners_loose.assign(record["loose_fasteners"])
	part.dependencies = dependency
	_clear_owners(source)
	source.get_parent().remove_child(source)
	source.name = "Visual"
	source.transform = Transform3D.IDENTITY
	part.add_child(source)
	for shape_record: Dictionary in record["colliders"]:
		_add_collision(part, shape_record)
	parts[id] = part
	_root.get_node(str(record["corner"]).to_upper() + "/Parts").add_child(part)


func _make_socket(record: Dictionary) -> void:
	var id: String = record["id"]
	var socket := PartSocket.new()
	socket.name = id + "_socket"
	socket.socket_id = StringName(id + "_socket")
	socket.socket_type = StringName(id + "_mount")
	socket.position = v(record["origin"])
	socket.snap_distance = 0.38
	socket.compatible_part_types.assign([&"suspension_service"])
	socket.requires_fasteners = not record["fasteners"].is_empty()
	socket.collision_layer = 4
	socket.collision_mask = 2
	var marker := Marker3D.new()
	marker.name = "InstallationPoint"
	socket.add_child(marker)
	socket.installation_point = marker
	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.065
	area_shape.shape = sphere
	socket.add_child(area_shape)
	var preview := MeshInstance3D.new()
	preview.name = "SocketIndicator"
	var mesh := SphereMesh.new()
	mesh.radius = 0.026
	mesh.height = 0.052
	preview.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.8, 0.6, 0.25)
	preview.material_override = material
	socket.add_child(preview)
	socket.preview = preview
	var fastener_root := Node3D.new()
	fastener_root.name = "Fasteners"
	socket.add_child(fastener_root)
	socket.fastener_root = fastener_root
	for index: int in record["fasteners"].size():
		var raw: Dictionary = record["fasteners"][index]
		var bolt := BOLT.instantiate() as Fastener
		bolt.set_script(SERVICE_BOLT)
		bolt.bolt_mesh = bolt.get_node("Mesh") as MeshInstance3D
		bolt.interaction_audio = bolt.get_node("Audio") as InteractionAudio
		bolt.name = "Bolt%d" % (index + 1)
		bolt.fastener_id = StringName(raw["id"])
		bolt.display_name = record["name"]
		bolt.spec = FastenerSpec.new()
		bolt.spec.required_tool_size = int(raw["size"])
		bolt.spec.max_tightness = 4
		bolt.tightness = 4
		bolt.position_index = index
		bolt.position = v(raw["position"]) - v(record["origin"])
		bolt.insertion_axis = v(raw["axis"]).normalized()
		var hex := CylinderMesh.new()
		hex.top_radius = float(raw["size"]) / 1732.05
		hex.bottom_radius = hex.top_radius
		hex.height = 0.010
		hex.radial_segments = 6
		var bolt_visual := bolt.get_node("Mesh") as MeshInstance3D
		bolt_visual.mesh = hex
		bolt.visual_axis_basis = Basis(Quaternion(Vector3.UP, bolt.insertion_axis))
		bolt_visual.basis = bolt.visual_axis_basis
		var hit := SphereShape3D.new()
		hit.radius = 0.020
		(bolt.get_node("HitShape") as CollisionShape3D).shape = hit
		fastener_root.add_child(bolt)
	sockets[id] = socket
	_root.get_node(str(record["corner"]).to_upper() + "/Sockets").add_child(socket)


func _clear_owners(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_owners(child)


func _add_collision(part: AutomotivePart, data: Dictionary) -> void:
	var node := CollisionShape3D.new()
	node.name = "Collision%d" % part.get_child_count()
	if data["type"] == "convex":
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for point: Array in data["points"]:
			points.append(v(point))
		shape.points = points
		node.shape = shape
	else:
		var shape := BoxShape3D.new()
		shape.size = v(data["size"])
		node.shape = shape
		node.position = v(data.get("center", [0, 0, 0]))
		node.rotation_degrees = v(data.get("rotation", [0, 0, 0]))
	part.add_child(node)


func _load_visual() -> Node3D:
	if ResourceLoader.exists(VISUAL, "PackedScene"):
		return (load(VISUAL) as PackedScene).instantiate() as Node3D
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(ProjectSettings.globalize_path(VISUAL), state) != OK:
		push_error("Missing Blender suspension GLB")
		return null
	return document.generate_scene(state)


func _find_part(id: StringName) -> AutomotivePart:
	for item: Node in _car.get_tree().get_nodes_in_group("grabbables"):
		if item is AutomotivePart and item.part_id == id:
			return item
	return null


static func v(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
