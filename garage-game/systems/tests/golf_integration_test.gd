extends SceneTree
## End-to-end regression for the imported Golf integration, using real raycasts.
## Run: Godot --headless --path . --script res://systems/tests/golf_integration_test.gd
## Add -- --visual with a rendering display to save the requested review views.

const WHEEL_IDS: Array[StringName] = [
	&"front_left_wheel", &"front_right_wheel", &"rear_left_wheel", &"rear_right_wheel",
]
const CORNERS: Array[String] = ["FL", "FR", "RL", "RR"]

var checks: int = 0
var failures: int = 0
var garage: Node3D
var car: Node3D
var player: FirstPersonPlayer
var interaction: InteractionController
var carrier: PartCarrier
var save: SaveSystem
var hood: VehicleRuntimeSystem
var toolbox: Toolbox
var last_context: Dictionary = {}
var last_feedback: String = ""
var measurements: Dictionary = {}
var visual: bool = false
var review_camera: Camera3D


func _initialize() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func frames(count: int = 3) -> void:
	for index: int in count:
		await physics_frame
		await process_frame


func press(action: StringName, duration: int = 2) -> void:
	Input.action_press(action)
	await frames(duration)
	Input.action_release(action)
	await frames(3)


func aim_at(point: Vector3) -> void:
	var direction: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.camera.rotation = Vector3(atan2(direction.y, Vector2(direction.x, direction.z).length()), 0, 0)
	interaction.refresh_target()


func scroll(direction: int, count: int = 1) -> void:
	for index: int in count:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP if direction > 0 else MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		player._unhandled_input(event)
	await frames(3)


func part(id: StringName) -> AutomotivePart:
	return save.registry.nodes.get(id) as AutomotivePart


func wheel_socket(id: StringName) -> PartSocket:
	return save.registry.nodes.get(StringName(str(id) + "_socket")) as PartSocket


func tool(size: int) -> Tool:
	for candidate: Tool in toolbox.tools:
		if candidate.tool_size == size:
			return candidate
	return null


func _set_player(point: Vector3) -> void:
	player.global_position = point
	player.velocity = Vector3.ZERO


func move_to(point: Vector3, look_point: Vector3) -> void:
	for index: int in range(350):
		var destination := Vector3(point.x, player.global_position.y, point.z)
		if player.global_position.distance_to(destination) < 0.025:
			break
		player.global_position = player.global_position.move_toward(destination, 0.045)
		player.velocity = Vector3.ZERO
		aim_at(look_point)
		await frames(1)
	await frames(8)


func stand_outside(wheel: AutomotivePart, transporting: bool = false) -> void:
	var side: float = signf(car.to_local(wheel.global_position).x)
	var point: Vector3 = wheel.global_position + Vector3(side * 0.95, 0, 0)
	point.y = 0.01
	if transporting:
		# Follow the outside aisles; never carry a wheel/tool through the car body.
		var aisle_z: float = car.global_position.z - 3.0
		await move_to(Vector3(player.global_position.x, 0, aisle_z), wheel.global_position)
		await move_to(Vector3(point.x, 0, aisle_z), wheel.global_position)
		await move_to(point, wheel.global_position)
	else:
		_set_player(point)
	Input.action_press("crouch")
	await frames(24)
	aim_at(wheel.global_position)
	await frames(3)


func pick_tool(size: int) -> Tool:
	var item: Tool = tool(size)
	Input.action_release("crouch")
	_set_player(item.global_position + Vector3(0, -item.global_position.y, 0.95))
	await frames(24)
	aim_at(item.global_position)
	await frames(3)
	check(interaction.target != null and interaction.target.subject == item,
		"RayCast reaches stored wrench %d mm" % size)
	await press(&"grab_item")
	await frames(16)
	check(carrier.held_item == item and item.is_held and not Input.is_action_pressed("grab_item"),
		"One click equips wrench %d mm after LMB release" % size)
	return item


func run() -> void:
	garage = (load("res://world/garage_golf_test.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(garage)
	current_scene = garage
	car = garage.get_node("CarPrototype") as Node3D
	player = garage.get_node("Player") as FirstPersonPlayer
	interaction = player.interaction
	carrier = interaction.carrier
	save = garage.get_node("SaveSystem") as SaveSystem
	toolbox = garage.get_node("Toolbox") as Toolbox
	player.set_process_unhandled_input(false)
	interaction.context_changed.connect(func(value: Dictionary) -> void: last_context = value)
	interaction.action_feedback.connect(func(value: String) -> void: last_feedback = value)
	save.save_path = "user://golf_integration_validation.json"
	await frames(40)
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(8)
	check(save.validate_scene(), "Registry IDs, dependencies and configurations are valid")
	hood = save.registry.nodes.get(&"golf_hood") as VehicleRuntimeSystem
	check(hood != null, "Hood has its own persistent runtime system")
	check(WHEEL_IDS.all(func(id: StringName) -> bool: return part(id) != null),
		"All four wheel VehicleParts are registered")
	if hood == null or not WHEEL_IDS.all(func(id: StringName) -> bool: return part(id) != null):
		_finish()
		return
	_geometry_checks()
	await _review_views()
	await _wheel_interaction_checks()
	await _hood_checks()
	await _engine_bay_checks()
	await _persistence_checks()
	_finish()


func _geometry_checks() -> void:
	for mapping: Array in [["grab_item", MOUSE_BUTTON_LEFT], ["drop_item", KEY_G]]:
		check(InputMap.has_action(mapping[0]), "InputMap defines " + mapping[0])
	var grab := InputEventMouseButton.new()
	grab.button_index = MOUSE_BUTTON_LEFT
	grab.pressed = true
	var drop := InputEventKey.new()
	drop.physical_keycode = KEY_G
	drop.pressed = true
	check(InputMap.event_is_action(grab, "grab_item"), "LMB maps to grab_item")
	check(InputMap.event_is_action(drop, "drop_item"), "G maps to drop_item")
	var wheel_records: Dictionary = {}
	var bolt_count: int = 0
	for index: int in WHEEL_IDS.size():
		var id: StringName = WHEEL_IDS[index]
		var wheel: AutomotivePart = part(id)
		var socket: PartSocket = wheel_socket(id)
		var bounds: AABB = mesh_bounds(wheel)
		var local_center: Vector3 = car.to_local(wheel.global_position)
		check(socket != null and socket.installed_part == wheel, CORNERS[index] + " installed on its own socket")
		check(wheel.freeze and wheel.state == AutomotivePart.State.FASTENED,
			CORNERS[index] + " is fixed while installed")
		check(wheel.global_position.distance_to(socket.installation_point.global_position) < 0.001,
			CORNERS[index] + " visual/gameplay origin matches socket within 1 mm")
		check(absf(bounds.position.y) < 0.005, CORNERS[index] + " tire touches floor within 5 mm")
		check(absf(bounds.get_center().y - wheel.global_position.y) < 0.003,
			CORNERS[index] + " origin matches geometric tire center")
		check(wheel.scale.is_equal_approx(Vector3.ONE), CORNERS[index] + " normalized rigid-body scale")
		check(socket.fasteners.size() == 5, CORNERS[index] + " has five independent bolts")
		for bolt: Fastener in socket.fasteners:
			check(bolt.required_tool_size == 17 and bolt.tightness == bolt.max_tightness,
				str(bolt.fastener_id) + " requires 17 mm and starts fastened")
			bolt_count += 1
		var mesh_count: int = wheel.find_children("*", "MeshInstance3D", true, false).filter(
			func(node: Node) -> bool: return (node as MeshInstance3D).is_visible_in_tree()).size()
		check(mesh_count == 3, CORNERS[index] + " uses exactly imported rim, tread and sidewall")
		wheel_records[CORNERS[index]] = {"center": SnapshotCodec.vector(local_center),
			"ground_error_m": bounds.position.y, "bounds_size": SnapshotCodec.vector(bounds.size)}
	check(bolt_count == 20, "Exactly twenty wheel fasteners")
	var fl: Vector3 = car.to_local(part(WHEEL_IDS[0]).global_position)
	var fr: Vector3 = car.to_local(part(WHEEL_IDS[1]).global_position)
	var rl: Vector3 = car.to_local(part(WHEEL_IDS[2]).global_position)
	var rr: Vector3 = car.to_local(part(WHEEL_IDS[3]).global_position)
	check(fl.x > 0 and fr.x < 0 and rl.x > 0 and rr.x < 0 and fl.z > rl.z,
		"FL/FR/RL/RR match vehicle left/right with front +Z")
	check(absf(fl.x + fr.x) < 0.002 and absf(rl.x + rr.x) < 0.002,
		"Wheel centers are bilaterally symmetric within 2 mm")
	check(absf((fl.z - rl.z) - 2.51) < 0.03, "Measured wheelbase is approximately 2.51 m")
	measurements["wheels"] = wheel_records
	measurements["wheelbase_m"] = fl.z - rl.z
	var body_visual := car.get_node_or_null("CarVisual") as Node3D
	if body_visual:
		var bounds: AABB = mesh_bounds(body_visual)
		for id: StringName in WHEEL_IDS:
			bounds = bounds.merge(mesh_bounds(part(id)))
		measurements["full_visible_bounds_m"] = SnapshotCodec.vector(bounds.size)
		check(absf(bounds.size.z - 4.15) < 0.06, "Imported body length measures approximately 4.15 m")
	check(player.camera.position.y > 1.5 and player.camera.position.y < 1.8,
		"Standing camera height is an adult eye height")


func mesh_bounds(node: Node) -> AABB:
	var result := AABB()
	var has_point: bool = false
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if not mesh_node.is_visible_in_tree() or not mesh_node.mesh:
			continue
		for surface: int in mesh_node.mesh.get_surface_count():
			var arrays: Array = mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = mesh_node.global_transform * vertex
				result = result.expand(point) if has_point else AABB(point, Vector3.ZERO)
				has_point = true
	return result


func _wheel_interaction_checks() -> void:
	var wrong: Tool = await pick_tool(15)
	await stand_outside(part(WHEEL_IDS[0]), true)
	var first: Fastener = wheel_socket(WHEEL_IDS[0]).fasteners[0]
	aim_at(first.global_position)
	await frames(3)
	check(interaction.target != null and interaction.target.subject == first,
		"RayCast reaches FL wheel bolt through the visible wheel")
	var before: int = first.tightness
	await scroll(-1)
	check(first.tightness == before, "15 mm wrench cannot loosen a 17 mm bolt")
	check("Requer chave 17 mm" in last_feedback or "Requer chave 17 mm" in str(last_context.get("hint", "")),
		"Wrong-tool HUD states Requer chave 17 mm")
	check(carrier.held_item == wrong, "Scroll never drops equipped wrench")
	await press(&"drop_item")
	check(carrier.held_item == null and not wrong.is_held, "G drops wrench")
	check(save.reset_test_scene(), "Reset prepares wheel interaction test")
	await frames(5)
	var correct: Tool = await pick_tool(17)
	for index: int in WHEEL_IDS.size():
		var id: StringName = WHEEL_IDS[index]
		var wheel: AutomotivePart = part(id)
		var socket: PartSocket = wheel_socket(id)
		await stand_outside(wheel, true)
		check(carrier.held_item == correct, CORNERS[index] + " wrench remains equipped while walking and crouching")
		if visual and index == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/golf_validation/tool_held_17mm.png")
		for bolt_index: int in socket.fasteners.size():
			var bolt: Fastener = socket.fasteners[bolt_index]
			aim_at(bolt.global_position)
			await frames(3)
			check(interaction.target != null and interaction.target.subject == bolt,
				str(bolt.fastener_id) + " can be targeted by actual player RayCast")
			await press(&"grab_item")
			check(carrier.held_item == correct, str(bolt.fastener_id) + " LMB does not swap/drop the held tool")
			await scroll(-1, bolt.max_tightness)
			check(bolt.tightness == 0, str(bolt.fastener_id) + " independently loosens via scroll")
			if bolt_index < 4:
				check(not wheel.can_remove()["allowed"], CORNERS[index] + " remains blocked while any bolt is tight")
		check(wheel.can_remove()["allowed"], CORNERS[index] + " becomes removable after all five bolts are zero")
	await press(&"drop_item")
	check(carrier.held_item == null, "G releases the wrench before handling wheels")
	for index: int in WHEEL_IDS.size():
		await _remove_and_replace(index)
	await _retighten_wheels()


func _retighten_wheels() -> void:
	var correct: Tool = await pick_tool(17)
	for index: int in WHEEL_IDS.size():
		var wheel: AutomotivePart = part(WHEEL_IDS[index])
		var socket: PartSocket = wheel_socket(WHEEL_IDS[index])
		await stand_outside(wheel, true)
		for bolt: Fastener in socket.fasteners:
			aim_at(bolt.global_position)
			await frames(3)
			check(interaction.target != null and interaction.target.subject == bolt,
				str(bolt.fastener_id) + " remains targetable after wheel reinstallation")
			await scroll(1, bolt.max_tightness)
			check(bolt.tightness == bolt.max_tightness,
				str(bolt.fastener_id) + " tightens again using wheel-up and wrench 17 mm")
		check(wheel.state == AutomotivePart.State.FASTENED and wheel.is_secure(),
			CORNERS[index] + " returns to FASTENED only after all five bolts are tight")
		check(not wheel.can_remove()["allowed"], CORNERS[index] + " cannot be removed after retightening")
	check(carrier.held_item == correct, "Wrench remains equipped through all twenty retightening operations")
	await press(&"drop_item")


func _remove_and_replace(index: int) -> void:
	var id: StringName = WHEEL_IDS[index]
	var wheel: AutomotivePart = part(id)
	var socket: PartSocket = wheel_socket(id)
	await stand_outside(wheel)
	aim_at(wheel.global_position + Vector3(0, 0.20, 0))
	await frames(3)
	check(interaction.target != null and interaction.target.subject == wheel, CORNERS[index] + " tire itself is pickable")
	await press(&"grab_item")
	await frames(20)
	check(carrier.held_item == wheel and not wheel.installed and not wheel.freeze,
		CORNERS[index] + " one click removes wheel and enables its rigid body")
	check(wheel.is_held and not Input.is_action_pressed("grab_item"), CORNERS[index] + " remains held after LMB release")
	var side: float = signf(car.to_local(socket.global_position).x)
	await move_to(player.global_position + Vector3(side * 0.9, 0, 0),
		player.global_position + Vector3(side, 0.25, 0))
	await press(&"drop_item")
	await frames(90)
	check(carrier.held_item == null and not wheel.installed and not wheel.freeze,
		CORNERS[index] + " G drops wheel as a free physics object")
	check(mesh_bounds(wheel).position.y > -0.02, CORNERS[index] + " removed tire remains above floor")
	if index == 0:
		await capture_view("wheel_removed_fl", Vector3(4.7, 1.6, 4.5), Vector3(0, 0.6, 0.3))
	# Place the player at the dropped wheel, then exercise the real pickup again.
	var pickup_point: Vector3 = wheel.global_position + Vector3(side * 0.9, 0, 0)
	pickup_point.y = 0.01
	_set_player(pickup_point)
	await frames(5)
	aim_at(wheel.global_position)
	await press(&"grab_item")
	check(carrier.held_item == wheel, CORNERS[index] + " dropped wheel can be picked up again")
	# Carry the real physical wheel back through the aisle. No wheel teleport or
	# direct place_item call: hold forces, clearance and G perform the installation.
	var destination: Vector3 = socket.global_position + Vector3(side * 0.95, 0, 0)
	destination.y = 0.01
	await move_to(destination, socket.global_position)
	aim_at(socket.global_position)
	await frames(90)
	carrier.refresh_candidate()
	check(carrier.candidate == socket, CORNERS[index] + " correct socket is indicated within reach")
	await press(&"drop_item")
	check(wheel.installed and wheel.current_socket == socket, CORNERS[index] + " G reinstalls at its matching socket")
	check(wheel.state == AutomotivePart.State.PLACED and socket.fasteners.all(
		func(bolt: Fastener) -> bool: return bolt.tightness == 0), CORNERS[index] + " reinstallation is PLACED, never auto-fastened")
	check(wheel.global_position.distance_to(socket.installation_point.global_position) < 0.001,
		CORNERS[index] + " reinstallation aligns position within 1 mm")


func _hood_checks() -> void:
	hood.call("set_open", false, true)
	check(not bool(hood.get("is_open")), "Hood closes completely")
	Input.action_release("crouch")
	_set_player(car.to_global(Vector3(0, 0.01, 2.8)))
	await frames(30)
	aim_at(car.to_global(Vector3(0, 0.82, 1.65)))
	await frames(3)
	check(interaction.target != null and interaction.target.subject.name == "HoodInteraction", "Actual raycast reaches closed hood")
	await press(&"grab_item")
	await frames(1)
	check(bool(hood.get("is_open")), "Hood opening command changes persistent state")
	var pivot := hood.get("pivot") as Node3D
	check(absf(pivot.rotation.x) > 0.01 and absf(pivot.rotation.x) < deg_to_rad(65), "Hood opens progressively rather than teleporting")
	await frames(55)
	check(absf(pivot.rotation_degrees.x + 65.0) < 0.1, "Hood reaches 65 degrees around rear hinge")
	check(bool(hood.capture_state().get("open")), "Open hood is captured by the save protocol")
	aim_at(pivot.to_global(Vector3(0, -0.07, 0.55)))
	await frames(3)
	check(interaction.target != null and interaction.target.subject.name == "HoodInteraction", "Actual raycast reaches opened hood")
	await press(&"grab_item")
	await frames(55)
	check(not bool(hood.capture_state().get("open")), "Hood closes after interpolation")
	check(absf(pivot.rotation.x) < 0.001, "Hood returns to its exact closed transform")
	var hud := player.get_node("HUD") as InteractionHUD
	hud.debug_enabled = true
	await frames(12)
	check(car.get_node("AlignmentDebug").visible, "F3 enables origins, sockets, colliders and fastener overlay")
	hud.debug_enabled = false


func _engine_bay_checks() -> void:
	hood.call("set_open", false, true)
	var bay := car.get_node("EngineBayPrototype") as Node3D
	var region: AABB = car.get("engine_bay_bounds")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://blender/reports/golf_reference_integration.json"))
	for id: StringName in [&"battery", &"radiator", &"air_filter_box", &"alternator", &"starter_motor"]:
		var item := part(id)
		var bounds := mesh_bounds(item)
		bounds.position -= car.global_position
		check(region.grow(0.015).encloses(bounds), str(id) + " lies inside measured engine bay")
		check(item.global_position.distance_to(item.current_socket.installation_point.global_position) < 0.001,
			str(id) + " socket and component origin coincide")
		var safe_top: float = 2.0
		for sample: Dictionary in report["hood_surface_samples"]:
			if absf(float(sample["x"]) - bounds.get_center().x) < bounds.size.x * 0.5 + 0.16 \
				and absf(float(sample["godot_z"]) - bounds.get_center().z) < bounds.size.z * 0.5 + 0.06:
				safe_top = minf(safe_top, float(sample["surface_y"]))
		check(bounds.end.y < safe_top - 0.015, str(id) + " clears the closed hood surface")
	for node_name: String in ["engine_block", "transmission", "valve_cover", "coolant_tank"]:
		var bounds := mesh_bounds(bay.get_node("EngineLayout/" + node_name))
		bounds.position -= car.global_position
		check(region.grow(0.015).encloses(bounds), node_name + " fits the measured engine envelope")
	hood.call("set_open", true, true)
	Input.action_release("crouch")
	await frames(25)
	for id: StringName in [&"battery", &"radiator", &"air_filter_box", &"alternator", &"starter_motor"]:
		var item := part(id)
		var socket := item.current_socket as PartSocket
		for bolt: Fastener in socket.fasteners:
			var reached := false
			for viewpoint: Vector3 in [Vector3(0, 0.01, 2.65), Vector3(1.15, 0.01, 1.5), Vector3(-1.15, 0.01, 1.5)]:
				_set_player(car.to_global(viewpoint))
				await frames(3)
				aim_at(bolt.global_position)
				await frames(2)
				if interaction.target != null and interaction.target.subject == bolt:
					reached = true
					break
			check(reached, str(bolt.fastener_id) + " is reachable from outside the open bay")
	hood.call("set_open", false, true)


func _persistence_checks() -> void:
	var fl: AutomotivePart = part(WHEEL_IDS[0])
	var rl_socket: PartSocket = wheel_socket(WHEEL_IDS[2])
	# Independent partial-save fixture, after the end-to-end retightening test.
	for bolt: Fastener in wheel_socket(WHEEL_IDS[0]).fasteners:
		bolt.set_tightness(0)
	fl.begin_hold(player)
	fl.end_hold()
	fl.global_position = car.global_position + Vector3(2.3, 0.32, 0)
	for index: int in range(5):
		rl_socket.fasteners[index].set_tightness(index % 4)
	hood.call("set_open", true, true)
	await frames(3)
	check(save.save_game(), "Save writes four independent wheels, twenty bolt states and open hood")
	var saved: Dictionary = save.capture_snapshot()
	check(save.reset_test_scene(), "Reset accepts initial snapshot")
	check(save.load_game(), "Partial Golf save loads successfully")
	check(not fl.installed and wheel_socket(WHEEL_IDS[1]).installed_part == part(WHEEL_IDS[1]),
		"Save/load distinguishes removed FL from installed FR")
	check(rl_socket.fasteners[0].tightness == 0 and rl_socket.fasteners[3].tightness == 3,
		"Save/load restores independent partially tightened bolts")
	check(bool(hood.get("is_open")), "Save/load restores open hood")
	var legacy: Dictionary = saved.duplicate(true)
	legacy["items"] = legacy["items"].filter(func(record: Dictionary) -> bool:
		return not str(record["id"]) in SnapshotMigration.NEW_WHEEL_IDS)
	legacy["fasteners"] = legacy["fasteners"].filter(func(record: Dictionary) -> bool:
		for wheel_id: String in SnapshotMigration.NEW_WHEEL_IDS:
			if str(record["id"]).begins_with(wheel_id + "_bolt_"):
				return false
		return true)
	legacy["systems"] = legacy["systems"].filter(func(record: Dictionary) -> bool: return record["id"] != "golf_hood")
	var before_count: int = legacy["items"].size()
	check(save.restore_snapshot(legacy), "Older schema-3 development save gains known wheel/hood defaults")
	check(legacy["items"].size() == before_count, "Migration does not mutate source data")
	check(not fl.installed and part(WHEEL_IDS[1]).is_secure() and part(WHEEL_IDS[2]).is_secure()
		and part(WHEEL_IDS[3]).is_secure(), "Migration preserves old FL state and installs only new wheel defaults")
	check(not bool(hood.get("is_open")), "Missing legacy hood defaults safely to closed")
	var invalid: Dictionary = save.capture_snapshot()
	invalid["items"].append(invalid["items"][0].duplicate(true))
	check(not save.restore_snapshot(invalid), "Duplicate persistent record remains rejected")
	invalid = save.capture_snapshot()
	invalid["fasteners"] = invalid["fasteners"].filter(func(record: Dictionary) -> bool:
		return record["id"] != "rear_right_wheel_bolt_1")
	check(not save.restore_snapshot(invalid), "Partial new-wheel bundle is rejected rather than silently repaired")
	invalid = save.capture_snapshot()
	invalid["items"] = invalid["items"].filter(func(record: Dictionary) -> bool: return record["id"] != "battery")
	check(not save.restore_snapshot(invalid), "Missing pre-existing item is not hidden by migration")
	car.position += Vector3(0.2, 0.1, 0.15)
	hood.call("set_open", true, true)
	Input.action_release("crouch")
	check(save.reset_test_scene(), "Reset succeeds after displaced car and partial assembly")
	await frames(8)
	for id: StringName in WHEEL_IDS:
		check(part(id).is_secure() and wheel_socket(id).fasteners.all(
			func(bolt: Fastener) -> bool: return bolt.tightness == bolt.max_tightness), str(id) + " reset reinstalls and fully tightens all five bolts")
	check(toolbox.tools.all(func(item: Tool) -> bool: return item.stored), "Reset returns all tools to their slots")
	check(not bool(hood.get("is_open")), "Reset closes hood")
	check(absf(mesh_bounds(part(WHEEL_IDS[0])).position.y) < 0.005, "Reset restores car position with tires on floor")
	check(player.global_position.distance_to(SnapshotCodec.to_vector(save.initial_snapshot["player"]["position"])) < 0.08,
		"Reset restores player spawn")
	DirAccess.remove_absolute(save.save_path)
	await capture_view("all_wheels_installed", Vector3(4.7, 1.7, 4.8), Vector3(0, 0.75, 0))


func _review_views() -> void:
	hood.call("set_open", false, true)
	await capture_view("car_side", Vector3(5.0, 1.0, 0), Vector3(0, 0.8, 0))
	await capture_view("car_front_3q", Vector3(4.7, 1.65, 4.8), Vector3(0, 0.75, 0))
	await capture_view("car_rear_3q", Vector3(3.6, 1.6, -3.8), Vector3(0, 0.75, 0))
	await capture_view("hood_closed", Vector3(2.8, 2.1, 3.3), Vector3(0, 0.8, 1.1))
	hood.call("set_open", true)
	await frames(55)
	await capture_view("hood_open", Vector3(2.8, 2.1, 3.3), Vector3(0, 0.95, 1.1))
	await capture_view("engine_bay", Vector3(1.3, 2.35, 2.55), Vector3(0, 0.7, 1.25))
	hood.call("set_open", false, true)


func capture_view(file_name: String, offset: Vector3, look_offset: Vector3) -> void:
	if not visual:
		return
	if review_camera == null:
		review_camera = Camera3D.new()
		review_camera.fov = 48.0
		garage.add_child(review_camera)
	var hud: CanvasLayer = player.get_node("HUD") as CanvasLayer
	hud.visible = false
	review_camera.global_position = car.to_global(offset)
	review_camera.look_at(car.to_global(look_offset))
	review_camera.make_current()
	await frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/golf_validation")
	root.get_texture().get_image().save_png("res://.godot/golf_validation/" + file_name + ".png")
	player.camera.make_current()
	hud.visible = true


func _finish() -> void:
	for action: StringName in [&"grab_item", &"drop_item", &"primary_interact", &"crouch"]:
		Input.action_release(action)
	print("GOLF RESULT: %d checks, %d failures" % [checks, failures])
	var output := FileAccess.open("res://.godot/golf_integration_result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures, "measurements": measurements}, "\t"))
	output.close()
	quit(0 if failures == 0 else 1)
