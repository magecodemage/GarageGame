extends Node3D
## Local-only Golf integration. Source geometry is the spatial authority.
## Blender X/ Y/ Z => Godot X/ -Z/ Y. Vehicle left is +X (front +Z).

const WHEEL_IDS := {"fl": "front_left", "fr": "front_right", "rl": "rear_left", "rr": "rear_right"}
const WHEEL_SCENE_PATH := "res://parts/wheel_golf_reference.tscn"
const BOLT_SCENE = preload("res://vehicles/fasteners/wheel_bolt.tscn")
const HOOD_SCRIPT = preload("res://vehicles/golf_hood.gd")
const HOOD_TARGET = preload("res://vehicles/golf_hood_target.gd")

var wheel_centers: Dictionary = {
	"fl": Vector3(0.742542, 0.307435, 1.195712),
	"fr": Vector3(-0.742542, 0.307435, 1.195712),
	"rl": Vector3(0.734919, 0.307435, -1.310977),
	"rr": Vector3(-0.734919, 0.307435, -1.310977),
}
var wheel_radius: float = 0.307435
var wheel_width: float = 0.219281
var engine_bay_bounds := AABB(Vector3(-0.60, 0.22, 1.07), Vector3(1.20, 0.58, 0.76))
var hood: GolfHood


func _ready() -> void:
	# Children have readied, initial placement callbacks have not run yet.
	_remove_legacy_supports()
	var bridge := $CarVisual as CarVisualBridge
	bridge.transform = Transform3D.IDENTITY
	bridge.hood_open_degrees = 0.0
	bridge.hidden_imported_parts = PackedStringArray()
	_configure_colliders()
	_configure_wheels()
	_configure_front_left_mechanics()
	_configure_engine_bay()
	_configure_hood()
	var state := $MechanicalState as VehicleMechanicalState
	for key: String in ["fr", "rl", "rr"]:
		state.critical_part_ids.append(StringName(WHEEL_IDS[key] + "_wheel"))
	var debug_script := load("res://vehicles/golf_alignment_debug.gd") as Script
	if debug_script:
		var debug := Node3D.new()
		debug.set_script(debug_script)
		debug.name = "AlignmentDebug"
		add_child(debug)
	(get_parent().get_node("SaveSystem") as SaveSystem).reset_nodes.append(self)


func _remove_legacy_supports() -> void:
	for node_name: String in ["StandLeftRear", "StandLeftFront", "StandRightRear", "StandRightFront",
		"Windshield", "Hood", "FrontBumper", "LeftHeadlight", "RightHeadlight", "RearLeft", "RearRight",
		"FrontRight", "EngineTestInstructions"]:
		var old := get_node_or_null(node_name)
		if old:
			remove_child(old)
			old.free()
	$FrontLeftAssembly.position = Vector3.ZERO


func _configure_colliders() -> void:
	# The stationary development car has no support block or lifting rigid body.
	# Thin undertray + cabin + fender rails leave all hubs and engine access clear.
	$Chassis.position = Vector3(0, 0.17, -0.08)
	_set_box_collision($Chassis/Collision, Vector3(1.20, 0.055, 3.30))
	$Cabin.position = Vector3(0, 0.79, -0.50)
	_set_box_collision($Cabin/Collision, Vector3(1.46, 1.08, 2.30))
	_add_static_box("Firewall", Vector3(0, 0.57, 0.72), Vector3(1.24, 0.62, 0.06))
	_add_static_box("FrontCrashBeam", Vector3(0, 0.39, 1.94), Vector3(1.35, 0.21, 0.10))
	for side: float in [-1.0, 1.0]:
		_add_static_box("FenderRailLeft" if side > 0 else "FenderRailRight",
			Vector3(side * 0.79, 0.75, 1.23), Vector3(0.075, 0.14, 1.00))


func _add_static_box(node_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 32
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _set_box_collision(collision: CollisionShape3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape


func _configure_wheels() -> void:
	var wheel_scene := load(WHEEL_SCENE_PATH) as PackedScene
	if wheel_scene == null:
		push_error("Cena de roda local ausente; consulte docs/GIT_REFERENCE_SETUP.md")
		return
	var fl_socket := $FrontLeftAssembly/WheelSocket as PartSocket
	var fl_wheel := $FrontLeftAssembly/Parts/Wheel as AutomotivePart
	for key: String in WHEEL_IDS:
		var prefix: String = WHEEL_IDS[key]
		var socket: PartSocket
		var wheel: AutomotivePart
		if key == "fl":
			socket = fl_socket
			wheel = fl_wheel
		else:
			wheel = wheel_scene.instantiate() as AutomotivePart
			wheel.name = "WheelPart_" + key.to_upper()
			wheel.part_id = StringName(prefix + "_wheel")
			wheel.dependencies = null
			socket = PartSocket.new()
			socket.socket_id = StringName(prefix + "_wheel_socket")
			socket.collision_layer = 4
			socket.collision_mask = 2
			socket.compatible_part_types = [&"wheel"]
			var marker := Marker3D.new()
			marker.name = "InstallationPoint"
			socket.add_child(marker)
			socket.installation_point = marker
			var fasteners := Node3D.new()
			fasteners.name = "Fasteners"
			socket.add_child(fasteners)
			socket.fastener_root = fasteners
			for index in 5:
				var bolt := BOLT_SCENE.instantiate() as Fastener
				bolt.name = "Bolt%d" % (index + 1)
				bolt.fastener_id = StringName(prefix + "_wheel_bolt_%d" % (index + 1))
				bolt.position_index = index
				bolt.tightness = 4
				fasteners.add_child(bolt)
			var hit := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 0.08
			hit.shape = sphere
			socket.add_child(hit)
			var preview := MeshInstance3D.new()
			preview.name = "Preview"
			var disc := CylinderMesh.new()
			disc.top_radius = wheel_radius
			disc.bottom_radius = wheel_radius
			disc.height = 0.012
			preview.mesh = disc
			preview.rotation.z = PI / 2.0
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.2, 0.8, 0.5, 0.12)
			preview.material_override = mat
			socket.add_child(preview)
			socket.preview = preview
		wheel.compatible_socket_types = [StringName("wheel_hub_" + key)]
		wheel.display_name = "Roda " + {"fl": "dianteira esquerda", "fr": "dianteira direita",
			"rl": "traseira esquerda", "rr": "traseira direita"}[key]
		wheel.carry_radius = 0.32
		socket.name = "socket_wheel_" + key
		socket.position = wheel_centers[key]
		socket.socket_type = StringName("wheel_hub_" + key)
		socket.snap_distance = 0.48
		_set_wheel_visual(wheel, key)
		_configure_wheel_bolts(socket, key)
		if key != "fl":
			add_child(wheel)
			socket.initial_part = wheel
			add_child(socket)
		wheel.position = wheel_centers[key]
		# All wheel rigid bodies retain unit transforms and metric cylinder shapes.
		var shape := CylinderShape3D.new()
		shape.radius = wheel_radius
		shape.height = wheel_width
		wheel.get_node("CollisionShape3D").shape = shape
		wheel.get_node("CollisionShape3D").rotation = Vector3(0, 0, PI / 2.0)


func _set_wheel_visual(wheel: AutomotivePart, key: String) -> void:
	var visual := wheel.get_node("Visual") as Node3D
	for child in visual.get_children():
		visual.remove_child(child)
		child.free()
	var imported := _load_glb("res://blender/exports/golf_reference_wheel_" + key + ".glb")
	if imported:
		imported.name = "GolfWheelMesh"
		visual.add_child(imported)
	for old_name: String in ["Tire", "Rim"]:
		var old := wheel.get_node_or_null(old_name)
		if old:
			wheel.remove_child(old)
			old.free()


func _configure_wheel_bolts(socket: PartSocket, key: String) -> void:
	var outward: float = signf(wheel_centers[key].x)
	for index in socket.fastener_root.get_child_count():
		var bolt := socket.fastener_root.get_child(index) as Fastener
		var angle: float = TAU * float(index) / 5.0
		# 5x100 bolt circle: 50 mm radius, not the old 170 mm circle.
		bolt.position = Vector3(outward * (wheel_width * 0.5 + 0.008), 0.05 * cos(angle), 0.05 * sin(angle))
		bolt.insertion_axis = Vector3(-outward, 0, 0)
		bolt.spec = bolt.spec.duplicate() as FastenerSpec
		bolt.spec.required_tool_size = 17
		bolt.display_name = "Parafuso da roda " + key.to_upper()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0098
		mesh.bottom_radius = 0.0098
		mesh.height = 0.012
		mesh.radial_segments = 6
		bolt.get_node("Mesh").mesh = mesh
		var hit := SphereShape3D.new()
		hit.radius = 0.022
		bolt.get_node("HitShape").shape = hit


func _configure_front_left_mechanics() -> void:
	var assembly := $FrontLeftAssembly as Node3D
	var center: Vector3 = wheel_centers.fl
	var offsets := {
		"StrutSocket": Vector3(-0.13, 0.25, 0),
		"HubSocket": Vector3(-0.075, 0, 0),
		"BrakeDiscSocket": Vector3.ZERO,
		"BrakeCaliperSocket": Vector3.ZERO,
	}
	for socket_name: String in offsets:
		var socket := assembly.get_node(socket_name) as PartSocket
		socket.position = center + offsets[socket_name]
		var part := socket.initial_part
		part.position = socket.position
		# Resize overly large authoring primitives uniformly in mesh/shape data.
		var factor: float = {"StrutSocket": 0.46, "HubSocket": 0.36,
			"BrakeDiscSocket": 0.44, "BrakeCaliperSocket": 0.43}[socket_name]
		_scale_part_geometry(part, factor)
		for index in socket.fasteners.size():
			var bolt := socket.fasteners[index]
			bolt.position = Vector3(0.045, (0.055 if index == 0 else -0.055), 0)
			_small_fastener(bolt, Vector3.LEFT)
		if socket_name == "BrakeDiscSocket" or socket_name == "BrakeCaliperSocket":
			var suffix: String = "brake_disc_fl" if socket_name == "BrakeDiscSocket" else "brake_caliper_fl"
			var path := "res://blender/exports/golf_reference_" + suffix + ".glb"
			if FileAccess.file_exists(path):
				_replace_part_visual(part, path)
				var box := _visual_bounds(part)
				var collision := part.get_node("Collision1") as CollisionShape3D
				collision.position = box.get_center()
				if socket_name == "BrakeDiscSocket":
					var shape := CylinderShape3D.new()
					shape.radius = maxf(box.size.y, box.size.z) * 0.5
					shape.height = box.size.x
					collision.shape = shape
				else:
					collision.rotation = Vector3.ZERO
					_set_box_collision(collision, box.size)
				for index in socket.fasteners.size():
					socket.fasteners[index].position = box.get_center() + Vector3(box.size.x * 0.5 + 0.01,
						0.05 if index == 0 else -0.05, 0)


func _configure_engine_bay() -> void:
	var bay := $EngineBayPrototype as Node3D
	# Uniformly sized temporary service components, preserving their electrical
	# state, dependencies, terminals and original scripts. Root scales stay one.
	var layout := {
		"BatterySocket": [Vector3(-0.40, 0.60, 1.63), 0.5],
		"RadiatorSocket": [Vector3(0, 0.49, 1.75), 0.72],
		"AirFilterSocket": [Vector3(0.38, 0.72, 1.22), 0.52],
		"AlternatorSocket": [Vector3(0.30, 0.49, 1.56), 0.43],
		"StarterSocket": [Vector3(-0.29, 0.43, 1.47), 0.48],
	}
	for socket_name: String in layout:
		var socket := bay.get_node(socket_name) as PartSocket
		var part := socket.initial_part
		socket.position = layout[socket_name][0]
		part.position = socket.position
		_scale_part_geometry(part, layout[socket_name][1])
		var bounds := _visual_bounds(part)
		for index in socket.fasteners.size():
			var bolt := socket.fasteners[index]
			bolt.position = Vector3((bounds.size.x * 0.35) * (-1 if index == 0 else 1),
				bounds.end.y + 0.012, 0)
			_small_fastener(bolt, Vector3.DOWN)
			bolt.get_node("Mesh").rotation = Vector3.ZERO
		if part is BatteryPart:
			for bolt: Fastener in [part.positive_terminal_fastener, part.negative_terminal_fastener]:
				_small_fastener(bolt, Vector3.DOWN)
				bolt.get_node("Mesh").rotation = Vector3.ZERO
	var refs := Node3D.new()
	refs.name = "EngineBayReference"
	add_child(refs)
	var center := engine_bay_bounds.get_center()
	var limits := {"center": center, "front_limit": Vector3(center.x, center.y, engine_bay_bounds.end.z),
		"rear_limit": Vector3(center.x, center.y, engine_bay_bounds.position.z),
		"left_limit": Vector3(engine_bay_bounds.end.x, center.y, center.z),
		"right_limit": Vector3(engine_bay_bounds.position.x, center.y, center.z),
		"top_limit": Vector3(center.x, engine_bay_bounds.end.y, center.z),
		"bottom_limit": Vector3(center.x, engine_bay_bounds.position.y, center.z)}
	for key: String in limits:
		var marker := Marker3D.new()
		marker.name = "engine_bay_" + key
		marker.position = limits[key]
		refs.add_child(marker)
	var engine := Node3D.new()
	engine.name = "EngineLayout"
	bay.add_child(engine)
	_mechanical_box(engine, "engine_block", Vector3(0.035, 0.48, 1.30), Vector3(0.52, 0.39, 0.40), Color(0.30, 0.33, 0.35))
	_mechanical_box(engine, "valve_cover", Vector3(0.035, 0.71, 1.30), Vector3(0.53, 0.065, 0.35), Color(0.10, 0.12, 0.14))
	_mechanical_box(engine, "transmission", Vector3(-0.32, 0.35, 1.25), Vector3(0.22, 0.24, 0.31), Color(0.38, 0.40, 0.41))
	_mechanical_box(engine, "coolant_tank", Vector3(0.47, 0.61, 1.60), Vector3(0.17, 0.18, 0.17), Color(0.77, 0.72, 0.62))


func _mechanical_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 32
	body.collision_mask = 0
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.35
	mat.roughness = 0.6
	mesh.material = mat
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	_set_box_collision(collision, size)
	body.add_child(collision)
	parent.add_child(body)


func _scale_part_geometry(part: AutomotivePart, factor: float) -> void:
	for node in part.get_children():
		if node is Node3D:
			node.position *= factor
		if node is MeshInstance3D and node.mesh is PrimitiveMesh:
			var mesh := node.mesh.duplicate() as PrimitiveMesh
			if mesh is BoxMesh:
				mesh.size *= factor
			elif mesh is CylinderMesh:
				mesh.top_radius *= factor
				mesh.bottom_radius *= factor
				mesh.height *= factor
			node.mesh = mesh
		if node is CollisionShape3D:
			var shape := node.shape.duplicate() as Shape3D
			if shape is BoxShape3D:
				shape.size *= factor
			elif shape is CylinderShape3D:
				shape.radius *= factor
				shape.height *= factor
			node.shape = shape
	part.carry_radius *= factor


func _small_fastener(bolt: Fastener, axis: Vector3) -> void:
	bolt.insertion_axis = axis
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.009
	mesh.bottom_radius = 0.009
	mesh.height = 0.012
	mesh.radial_segments = 6
	bolt.get_node("Mesh").mesh = mesh
	var hit := SphereShape3D.new()
	hit.radius = 0.023
	bolt.get_node("HitShape").shape = hit


func _replace_part_visual(part: AutomotivePart, path: String) -> void:
	for node in part.get_children():
		if node is MeshInstance3D:
			part.remove_child(node)
			node.free()
	var visual := _load_glb(path)
	visual.name = "GolfVisual"
	part.add_child(visual)


func _configure_hood() -> void:
	var pivot := $CarVisual.find_child("hood", true, false) as Node3D
	if not pivot:
		push_error("Golf hood hinge missing")
		return
	pivot.rotation = Vector3.ZERO
	hood = HOOD_SCRIPT.new() as GolfHood
	hood.name = "HoodSystem"
	hood.system_id = &"golf_hood"
	hood.configure(pivot)
	add_child(hood)
	var body := StaticBody3D.new()
	body.set_script(HOOD_TARGET)
	body.name = "HoodInteraction"
	body.hood = hood
	body.collision_layer = 32
	body.collision_mask = 0
	# Four thin convex strips follow the measured curved hood without triangle
	# collision and without a broad box floating above the engine.
	for sample: Vector3 in [Vector3(0, 0.922, 1.08), Vector3(0, 0.885, 1.32),
		Vector3(0, 0.846, 1.56), Vector3(0, 0.770, 1.80)]:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.24, 0.025, 0.255)
		collision.shape = shape
		collision.position = sample - pivot.position
		collision.rotation.x = 0.20
		body.add_child(collision)
	pivot.add_child(body)


func _load_glb(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if error != OK:
		push_error("Reference GLB could not load: " + path)
		return null
	return document.generate_scene(state)


func _visual_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh_node: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh_node.visible or mesh_node.mesh == null:
			continue
		var local: Transform3D = node.global_transform.affine_inverse() * mesh_node.global_transform
		var box: AABB = local * mesh_node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
