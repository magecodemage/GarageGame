extends "res://vehicles/golf_reference_integration.gd"
## Extends the current Golf integration. Wheels, hood, engine and input stay in
## the proven base; only service assemblies and real articulated panels change.

var suspension_builder: GolfSuspensionBuilder
var body_panels: Dictionary = {}
var _service_sockets: Array[SnapSocket] = []
var _carrier: PartCarrier
var _hud: InteractionHUD


func _ready() -> void:
	super._ready()
	_configure_body_panels()
	var player := get_parent().get_node("Player") as FirstPersonPlayer
	_carrier = player.get_node("PartCarrier") as PartCarrier
	_hud = player.get_node("HUD") as InteractionHUD
	for node: Node in get_tree().get_nodes_in_group("snap_sockets"):
		if is_ancestor_of(node):
			_service_sockets.append(node as SnapSocket)


func _process(_delta: float) -> void:
	# Empty snap indicators are UI, not vehicle geometry. Show them when relevant
	# to placement or F3, avoiding large idle wheel ghosts over the actual brakes.
	for socket: SnapSocket in _service_sockets:
		# A vacant wheel-size Area must not hide the actual brake/knuckle behind it.
		# Placement already uses physical proximity in PartCarrier, not this ray.
		var relevant := is_instance_valid(_carrier.held_item) and socket.is_compatible(_carrier.held_item)
		socket.collision_layer = 4 if not socket.occupied and relevant else 0
		if is_instance_valid(socket.preview) and not socket.occupied:
			socket.preview.visible = _hud.debug_enabled or _carrier.candidate == socket


func _configure_front_left_mechanics() -> void:
	suspension_builder = GolfSuspensionBuilder.new()
	suspension_builder.build(self)


func _configure_colliders() -> void:
	super._configure_colliders()
	# The former solid cabin box extended through the rear wheel wells. Replace
	# it with actual roof/floor/quarter surfaces, leaving all four assemblies open.
	$Chassis.position = Vector3(0, 0.17, -0.15)
	_set_box_collision($Chassis/Collision, Vector3(1.0, 0.055, 1.65))
	$Cabin.position = Vector3(0, 1.34, -0.28)
	_set_box_collision($Cabin/Collision, Vector3(1.12, 0.055, 1.65))
	for side: float in [-1.0, 1.0]:
		_add_static_box("RearQuarterLeft" if side > 0 else "RearQuarterRight",
			Vector3(side * 0.78, 0.93, -1.02), Vector3(0.065, 0.40, 0.73))
	# New fitted cargo deck is above the rear coils, not in their service space.
	_add_static_box("CargoFloorCenter", Vector3(0, 0.5995, -1.645), Vector3(1.05, 0.011, 0.61))
	_add_static_box("CargoFloorRear", Vector3(0, 0.5995, -1.815), Vector3(1.34, 0.011, 0.24))


func _configure_body_panels() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://blender/reports/golf_reference_panels.json"))
	if not data is Dictionary or not data.get("panels") is Dictionary:
		push_error("Golf panel hinge manifest missing")
		return
	var names := {"door_fl": "Porta dianteira esquerda", "door_fr": "Porta dianteira direita", "trunk_hatch": "Porta-malas"}
	for id: String in names:
		var record: Dictionary = data["panels"][id]
		var pivot := $CarVisual.find_child(id, true, false) as Node3D
		if pivot == null:
			push_error("Missing real Golf panel: " + id)
			continue
		var panel := GolfBodyPanel.new()
		panel.name = id + "_hinge"
		panel.system_id = StringName(id)
		panel.configure(pivot, names[id], GolfSuspensionBuilder.v(record["axisGodot"]), float(record["angleDegrees"]))
		add_child(panel)
		body_panels[id] = panel
		var body := StaticBody3D.new()
		body.set_script(load("res://vehicles/golf_panel_target.gd"))
		body.name = id + "_interaction"
		body.panel = panel
		body.collision_layer = 32
		body.collision_mask = 0
		var hinge := GolfSuspensionBuilder.v(record["pivotGodot"])
		if id.begins_with("door_"):
			var side: float = 1.0 if id == "door_fl" else -1.0
			_panel_shape(body, Vector3(side * 0.765, 0.565, 0.11) - hinge,
				Vector3(0.14, 0.54, 1.20), Vector3.ZERO)
			_panel_shape(body, Vector3(side * 0.665, 1.105, 0.06) - hinge,
				Vector3(0.045, 0.46, 0.95), Vector3(0, 0, side * 14.0))
		else:
			_panel_shape(body, Vector3(0, 1.14, -1.70) - hinge,
				Vector3(1.20, 0.025, 0.59), Vector3(-43.0, 0, 0))
			_panel_shape(body, Vector3(0, 0.795, -1.965) - hinge,
				Vector3(1.28, 0.36, 0.035), Vector3.ZERO)
		pivot.add_child(body)


func _panel_shape(body: StaticBody3D, center: Vector3, size: Vector3, degrees: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = center
	collision.rotation_degrees = degrees
	body.add_child(collision)
