class_name VehicleJackSupport
extends VehicleRuntimeSystem
## Deterministic three-point support: the jack and the two opposite tires.
## Rigid rotation only, no shear, no dynamic vehicle-body simulation.

const MAX_LIFT := 0.30
const SERVICE_LIFT := 0.13
const STEP := 0.035
# Measured lower sill surface, ray-cast against the original Golf triangles.
const CONTACTS := {"fl": Vector3(0.77, 0.147048, 0.69), "fr": Vector3(-0.77, 0.147048, 0.69),
	"rl": Vector3(0.77, 0.158451, -0.80), "rr": Vector3(-0.77, 0.158451, -0.80)}
const PREFIX := {"fl": "front_left", "fr": "front_right", "rl": "rear_left", "rr": "rear_right"}

var car: Node3D
var jack: FloorJack
var points: Dictionary = {}
var active_point: VehicleJackPoint
var current_lift := 0.0
var target_lift := 0.0
var feedback_reason := ""
var _rest := Transform3D.IDENTITY
var _support_points: Array[Vector3] = []
var _pending: Dictionary = {}
var _loose_root: Node3D
var _jack_pose := Transform3D.IDENTITY


func configure(vehicle: Node3D, floor_jack: FloorJack, loose_root: Node3D) -> void:
	car = vehicle
	jack = floor_jack
	jack.support = self
	_loose_root = loose_root
	_rest = car.global_transform
	for item: Node in get_tree().get_nodes_in_group("grabbables"):
		if item is AutomotivePart and car.is_ancestor_of(item):
			item.set_release_parent(loose_root)
	# Convex support samples are measured on the actual imported tires. Older
	# manifests fall back to conservative geometry bounds until reimported.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GolfSuspensionBuilder.MANIFEST))
	for corner: String in CONTACTS:
		var samples: Array = manifest.get("wheel_support_points", {}).get(corner, [])
		if not samples.is_empty():
			for sample: Array in samples: _support_points.append(GolfSuspensionBuilder.v(sample))
		else:
			var center: Vector3 = car.wheel_centers[corner]
			for x: float in [-0.10964, 0.10964]:
				for y: float in [-0.307435, 0.307435]:
					for z: float in [-0.307435, 0.307435]: _support_points.append(center + Vector3(x, y, z))
		_make_point(corner)
	jack.set_release_parent(loose_root)


func _make_point(corner: String) -> void:
	var point := VehicleJackPoint.new()
	point.name = "JackPoint_" + corner.to_upper()
	point.socket_id = StringName("jack_point_" + corner)
	point.socket_type = &"floor_jack_mount"
	point.compatible_part_types.assign([&"floor_jack"])
	point.requires_fasteners = false
	point.corner = StringName(corner)
	point.support = self
	point.body_contact = CONTACTS[corner]
	point.snap_distance = 0.34
	point.collision_layer = 4
	point.collision_mask = 2
	var marker := Marker3D.new()
	marker.name = "InstallationPoint"
	point.add_child(marker)
	point.installation_point = marker
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.30, 0.10, 0.48)
	collision.shape = box
	collision.position.y = 0.05
	point.add_child(collision)
	var preview := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.06
	mesh.height = 0.008
	preview.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.85, 0.66, 0.2, 0.22)
	preview.material_override = material
	point.add_child(preview)
	point.preview = preview
	add_child(point)
	var side := signf(point.body_contact.x)
	var basis := _rest.basis * Basis(Vector3.UP, -side * PI * 0.5)
	var contact: Vector3 = _rest * point.body_contact
	var pad := jack.pad_position(point.body_contact.y)
	point.global_transform = Transform3D(basis, contact - basis * pad)
	preview.position = pad
	point.item_placed.connect(func(item: Grabbable) -> void: _bind(point, item))
	point.item_removed.connect(func(_item: Grabbable) -> void: _detach(point))
	points[corner] = point


func _bind(point: VehicleJackPoint, item: Grabbable) -> void:
	if item != jack: return
	active_point = point
	current_lift = 0.0
	target_lift = 0.0
	_jack_pose = point.global_transform
	feedback_reason = ""
	_apply_lift()


func _detach(point: VehicleJackPoint) -> void:
	if point != active_point: return
	active_point = null
	current_lift = 0.0
	target_lift = 0.0
	car.global_transform = _rest
	jack.set_pad_height(0.105)


func is_supporting() -> bool:
	return current_lift > 0.002 or target_lift > 0.002


func can_service(corner: StringName) -> bool:
	return active_point != null and active_point.corner == corner and current_lift >= SERVICE_LIFT and target_lift >= SERVICE_LIFT


func request_step(direction: int) -> bool:
	feedback_reason = ""
	if active_point == null or jack.is_held or jack.placement_socket != active_point:
		feedback_reason = "Posicione o macaco em um ponto válido"
		return false
	var proposed := clampf(target_lift + signi(direction) * STEP, 0.0, MAX_LIFT)
	if proposed < SERVICE_LIFT and direction < 0:
		var wheel := _part(str(PREFIX[str(active_point.corner)]) + "_wheel")
		if wheel == null or not wheel.is_secure():
			feedback_reason = "Reinstale e aperte a roda antes de baixar"
			return false
	if is_equal_approx(proposed, target_lift):
		feedback_reason = "Altura máxima atingida" if direction > 0 else "Veículo no chão"
		return false
	target_lift = proposed
	return true


func _physics_process(delta: float) -> void:
	if active_point == null: return
	if target_lift < SERVICE_LIFT and current_lift >= SERVICE_LIFT:
		var wheel := _part(str(PREFIX[str(active_point.corner)]) + "_wheel")
		if wheel == null or not wheel.is_secure():
			target_lift = SERVICE_LIFT
			feedback_reason = "Reinstale e aperte a roda antes de baixar"
	if not is_equal_approx(current_lift, target_lift):
		current_lift = move_toward(current_lift, target_lift, delta * 0.14)
		_apply_lift()


func _local_pose(angle: float) -> Transform3D:
	var side := signf(active_point.body_contact.x)
	var pivot := Vector3(-side * 0.85, 0, 0)
	var basis := Basis(Vector3.BACK, side * angle)
	var pose := Transform3D(basis, pivot - basis * pivot)
	var minimum := INF
	for point: Vector3 in _support_points: minimum = minf(minimum, (pose * point).y)
	pose.origin.y -= minimum
	return pose


func _apply_lift() -> void:
	if active_point == null: return
	var contact := active_point.body_contact
	var low := 0.0
	var high := 0.25
	for i: int in 14:
		var mid := (low + high) * 0.5
		var height := (_local_pose(mid) * contact).y - contact.y
		if height < current_lift: low = mid
		else: high = mid
	var pose := _local_pose((low + high) * 0.5) if current_lift > 0.0001 else Transform3D.IDENTITY
	car.global_transform = _rest * pose
	var world_contact: Vector3 = car.global_transform * contact
	var pad_height := world_contact.y - _rest.origin.y
	jack.set_pad_height(pad_height)
	# Wheeled chassis rolls horizontally as the jack arm describes its arc.
	# It stays upright and its tire bottoms remain on ground Y=0.
	jack.global_transform = Transform3D(_jack_pose.basis, world_contact - _jack_pose.basis * jack.pad_position(pad_height))


func _part(id: String) -> AutomotivePart:
	for item: Node in get_tree().get_nodes_in_group("grabbables"):
		if item is AutomotivePart and str(item.part_id) == id: return item
	return null


func capture_state() -> Dictionary:
	return {"point": str(active_point.corner) if active_point else "", "lift": current_lift, "jack_id": str(jack.part_id)}


func apply_state(data: Dictionary) -> void:
	_pending = data.duplicate(true)


func normalize_after_load() -> void:
	var id: String = _pending.get("point", "")
	active_point = points.get(id) as VehicleJackPoint
	if active_point != null and jack.placement_socket != active_point:
		active_point = null
	current_lift = float(_pending.get("lift", 0.0)) if active_point else 0.0
	target_lift = current_lift
	feedback_reason = ""
	if active_point:
		_jack_pose = active_point.global_transform
		_apply_lift()
	else:
		car.global_transform = _rest
		jack.set_pad_height(0.105)


func validate_saved_state(data: Dictionary) -> String:
	if not data.get("point") is String or not SnapshotCodec.valid_number(data.get("lift")):
		return "Estado de apoio do macaco inválido"
	if data["point"] != "" and not points.has(data["point"]): return "Ponto de macaco desconhecido"
	if float(data["lift"]) < 0 or float(data["lift"]) > MAX_LIFT: return "Altura de macaco inválida"
	if data["point"] == "" and float(data["lift"]) > 0: return "Elevação sem macaco posicionado"
	return "" if data.get("jack_id") == str(jack.part_id) else "Macaco desconhecido"


func validate_saved_snapshot(data: Dictionary, snapshot: Dictionary) -> String:
	var expected_socket := ""
	if data["point"] != "":
		var point := points[data["point"]] as VehicleJackPoint
		expected_socket = str(point.socket_id)
	for record: Dictionary in snapshot["items"]:
		if record["id"] == data["jack_id"]:
			if record["socket"] != expected_socket:
				return "O ponto de apoio não corresponde ao encaixe salvo do macaco"
			return ""
	return "Macaco ausente no snapshot de apoio"
