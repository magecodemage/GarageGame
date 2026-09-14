extends Node3D
## F3: coordenadas reais da integração, sem alterar meshes/colliders de gameplay.
## Linhas ImmediateMesh e metadata integration_debug permitem ignorar este helper
## nas medições do carro. O scan só acontece com debug ligado, a 10 Hz.

const VISUAL_COLOR := Color(0.35, 1.0, 0.35)
const PART_COLOR := Color(1.0, 1.0, 1.0)
const SOCKET_COLOR := Color(0.1, 0.85, 1.0)
const COLLISION_COLOR := Color(1.0, 0.6, 0.05)
const FASTENER_COLOR := Color(1.0, 0.2, 0.75)

var _car: Node3D
var _hud: InteractionHUD
var _lines := ImmediateMesh.new()
var _line_instance: MeshInstance3D
var _legend: CanvasLayer
var _elapsed: float = 0.0
var _was_enabled: bool = false
var _socket_labels: Dictionary = {}


func _ready() -> void:
	set_meta(&"integration_debug", true)
	_car = get_parent() as Node3D
	_hud = _car.get_parent().get_node_or_null("Player/HUD") as InteractionHUD
	_line_instance = MeshInstance3D.new()
	_line_instance.name = "AlignmentLines"
	_line_instance.mesh = _lines
	_line_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line_instance.set_meta(&"integration_debug", true)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 10
	_line_instance.material_override = material
	add_child(_line_instance)
	_legend = CanvasLayer.new()
	_legend.name = "AlignmentLegend"
	_legend.layer = 10
	add_child(_legend)
	var text := Label.new()
	text.position = Vector2(24, 24)
	text.text = "F3 · ALINHAMENTO\nBranco: VehiclePart · Verde: origem visual\nCiano: socket · Laranja: collision · Rosa: fasteners"
	text.add_theme_color_override("font_shadow_color", Color.BLACK)
	text.add_theme_constant_override("shadow_offset_x", 2)
	text.add_theme_constant_override("shadow_offset_y", 2)
	text.add_theme_font_size_override("font_size", 16)
	_legend.add_child(text)
	visible = false
	_legend.visible = false


func _process(delta: float) -> void:
	var enabled: bool = is_instance_valid(_hud) and _hud.debug_enabled
	visible = enabled
	_legend.visible = enabled
	if not enabled:
		_was_enabled = false
		return
	_elapsed += delta
	if _was_enabled and _elapsed < 0.1:
		return
	_was_enabled = true
	_elapsed = 0.0
	_redraw()


func _redraw() -> void:
	_lines.clear_surfaces()
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for socket_node in get_tree().get_nodes_in_group("snap_sockets"):
		var socket := socket_node as SnapSocket
		if not _belongs_to_vehicle_service(socket) or not socket.installation_point:
			continue
		_axes(socket.installation_point.global_transform, 0.11, SOCKET_COLOR)
		if "wheel" in str(socket.socket_id):
			_update_socket_label(socket)
	for item in get_tree().get_nodes_in_group("grabbables"):
		if not item is AutomotivePart or not _belongs_to_vehicle_service(item):
			continue
		_axes(item.global_transform, 0.085, PART_COLOR)
		for mesh_node in item.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_node as MeshInstance3D
			if mesh.is_visible_in_tree() and not mesh.has_meta(&"integration_debug"):
				_cross(mesh.global_position, 0.025, VISUAL_COLOR)
	for shape_node in _car.get_parent().find_children("*", "CollisionShape3D", true, false):
		var collision := shape_node as CollisionShape3D
		if _belongs_to_vehicle_service(collision) and not collision.disabled and collision.shape:
			_draw_shape(collision)
	for fastener_node in get_tree().get_nodes_in_group("fasteners"):
		var fastener := fastener_node as Fastener
		if _belongs_to_vehicle_service(fastener):
			_cross(fastener.global_position, 0.018, FASTENER_COLOR)
	_lines.surface_end()


func _belongs_to_vehicle_service(node: Node) -> bool:
	var jack_setup := _car.get_parent().get_node_or_null("JackSetup")
	return _car.is_ancestor_of(node) or (jack_setup != null and jack_setup.is_ancestor_of(node))


func _line(from: Vector3, to: Vector3, color: Color) -> void:
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(to_local(from))
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(to_local(to))


func _cross(point: Vector3, radius: float, color: Color) -> void:
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		_line(point - axis * radius, point + axis * radius, color)


func _axes(pose: Transform3D, length: float, color: Color) -> void:
	_cross(pose.origin, 0.02, color)
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		_line(pose.origin, pose * (axis * length), color)


func _draw_shape(collision: CollisionShape3D) -> void:
	var shape: Shape3D = collision.shape
	var pose: Transform3D = collision.global_transform
	if shape is BoxShape3D:
		_box(pose, shape.size * 0.5)
	elif shape is CylinderShape3D:
		_ring(pose, shape.radius, -shape.height * 0.5)
		_ring(pose, shape.radius, shape.height * 0.5)
		for index in 4:
			var radial: Vector3 = Vector3(cos(index * PI * 0.5), 0, sin(index * PI * 0.5)) * shape.radius
			_line(pose * (radial + Vector3.DOWN * shape.height * 0.5),
				pose * (radial + Vector3.UP * shape.height * 0.5), COLLISION_COLOR)
	elif shape is SphereShape3D:
		_ring(pose, shape.radius, 0.0)
		_ring(pose * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), shape.radius, 0.0)
		_ring(pose * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), shape.radius, 0.0)
	elif shape is CapsuleShape3D:
		_box(pose, Vector3(shape.radius, shape.height * 0.5, shape.radius))
	elif shape is ConvexPolygonShape3D:
		# New service parts use small compound hulls; show their real vertices too.
		for point: Vector3 in shape.points:
			_cross(pose * point, 0.004, COLLISION_COLOR)


func _box(pose: Transform3D, half_size: Vector3) -> void:
	for axis in 3:
		var side_a: int = (axis + 1) % 3
		var side_b: int = (axis + 2) % 3
		for sign_a in [-1.0, 1.0]:
			for sign_b in [-1.0, 1.0]:
				var from := Vector3.ZERO
				from[axis] = -half_size[axis]
				from[side_a] = sign_a * half_size[side_a]
				from[side_b] = sign_b * half_size[side_b]
				var to := from
				to[axis] = half_size[axis]
				_line(pose * from, pose * to, COLLISION_COLOR)


func _ring(pose: Transform3D, radius: float, height: float) -> void:
	for index in 24:
		var angle: float = TAU * index / 24.0
		var next_angle: float = TAU * (index + 1) / 24.0
		_line(pose * Vector3(cos(angle) * radius, height, sin(angle) * radius),
			pose * Vector3(cos(next_angle) * radius, height, sin(next_angle) * radius), COLLISION_COLOR)


func _update_socket_label(socket: SnapSocket) -> void:
	var label: Label3D = _socket_labels.get(socket.socket_id)
	if not is_instance_valid(label):
		label = Label3D.new()
		label.text = str(socket.socket_id)
		label.font_size = 24
		label.pixel_size = 0.0015
		label.modulate = SOCKET_COLOR
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.set_meta(&"integration_debug", true)
		add_child(label)
		_socket_labels[socket.socket_id] = label
	label.global_position = socket.installation_point.global_position + Vector3.UP * 0.2
