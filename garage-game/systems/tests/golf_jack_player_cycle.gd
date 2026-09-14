extends SceneTree
## Player-input acceptance session. No part teleport, state setters, direct
## pickup/place calls or direct bolt manipulation. Only keyboard/mouse events.
## Read-only telemetry supplies targets; actual ray/physics/controller decide.
## --jack-only saves a raised checkpoint; --resume-fl continues through F9.

var garage: Node3D
var player: FirstPersonPlayer
var car: Node3D
var carrier: PartCarrier
var save: SaveSystem
var support: VehicleJackSupport
var keys: Dictionary = {}
var failure := ""
var completed: Array[String] = []
var parking_index := 0


func _initialize() -> void:
	run.call_deferred()


func frames(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame


func key(code: Key, pressed: bool) -> void:
	if keys.get(code, false) == pressed: return
	keys[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(3)


func click() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = root.size * 0.5
		Input.parse_input_event(event)
		await frames(3)


func scroll(direction: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if direction > 0 else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = root.size * 0.5
	Input.parse_input_event(event)
	await frames(3)


func aim(point: Vector3) -> void:
	var delta := point - player.camera.global_position
	var yaw := atan2(-delta.x, -delta.z)
	var pitch := atan2(delta.y, Vector2(delta.x, delta.z).length())
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(yaw - player.rotation.y, -PI, PI), player.camera.rotation.x - pitch) / player.mouse_sensitivity
	Input.parse_input_event(event)


func aim_held(point: Vector3) -> void:
	var offset := carrier.held_item.get_carry_offset(carrier.hold_distance)
	aim(point - player.camera.global_basis.x * offset.x - player.camera.global_basis.y * offset.y)


func stop_walking() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D]: key(code, false)


func walk(point: Vector3, look: Vector3, carrying_to: bool = false, required: bool = true, desired_subject: Node = null) -> bool:
	var last_progress := player.global_position
	var stuck := 0
	for i: int in 380:
		var delta := Vector3(point.x - player.global_position.x, 0, point.z - player.global_position.z)
		if delta.length() < 0.10:
			stop_walking()
			await frames(8)
			return true
		if carrying_to and carrier.held_item: aim_held(look)
		else: aim(look)
		var local := player.global_basis.inverse() * delta.normalized()
		key(KEY_W, local.z < -0.27)
		key(KEY_S, local.z > 0.27)
		key(KEY_A, local.x < -0.27)
		key(KEY_D, local.x > 0.27)
		await frames(3)
		if desired_subject != null and subject() == desired_subject:
			stop_walking()
			return true
		if player.global_position.distance_to(last_progress) < 0.01:
			stuck += 1
		else:
			stuck = 0
			last_progress = player.global_position
		if stuck > 25: break
	stop_walking()
	return fail("Caminhada bloqueada em %s; destino %s" % [player.global_position, point]) if required else false


func fail(reason: String) -> bool:
	if failure.is_empty():
		failure = reason
		print("PLAYER BLOCKED: ", reason)
	return false


func subject() -> Node:
	return player.interaction.target.subject if player.interaction.target else null


func item(id: String) -> Grabbable:
	return save.registry.nodes.get(StringName(id)) as Grabbable


func socket(id: String) -> PartSocket:
	return save.registry.nodes.get(StringName(id + "_socket")) as PartSocket


func pick(object: Grabbable, point: Vector3) -> bool:
	aim(point)
	await frames(5)
	# Pivots in hub/rotor centres may be empty or covered by a bolt. Aim at the
	# actual manufactured collision components, never pick a node directly.
	if subject() != object:
		for child: Node in object.get_children():
			if not child is CollisionShape3D or child.disabled or child.shape == null: continue
			var centre := Vector3.ZERO
			if child.shape is ConvexPolygonShape3D:
				for vertex: Vector3 in child.shape.points: centre += vertex
				centre /= maxf(1, child.shape.points.size())
			aim(child.to_global(centre))
			await frames(3)
			if subject() == object: break
	if subject() != object: return fail("Alvo oculto: " + str(object.get_persistent_id()) + "; ray=" + str(subject()))
	await click()
	await frames(16)
	if carrier.held_item == object and object is Tool:
		key(KEY_R, true)
		for i: int in 16:
			if carrier.hold_distance <= 1.36: break
			await scroll(-1)
		key(KEY_R, false)
	return carrier.held_item == object or fail("LMB não pegou " + object.display_name + ": " + str(object.interaction_context(null)))


func place(mount: SnapSocket) -> bool:
	key(KEY_CTRL, not mount is ToolSlot)
	await frames(22)
	var point := mount.installation_point.global_position
	var offset := carrier.held_item.get_carry_offset(carrier.hold_distance)
	var dy := point.y - player.camera.global_position.y
	var distance := sqrt(maxf(0.64, offset.length_squared() - dy * dy))
	var stand := Vector3(point.x - 0.30, 0, -4.18) if mount is ToolSlot else point + Vector3(distance, -point.y, 0)
	if not await walk(stand, point, true): return false
	if mount is ToolSlot:
		var forward := sqrt(maxf(0.25, point.distance_squared_to(player.camera.global_position) - 0.25 * 0.25 - 0.21 * 0.21))
		var reach := clampf(1.35 + forward - 0.5, 1.35, 2.25)
		key(KEY_R, true)
		for i: int in 16:
			if absf(carrier.hold_distance - reach) < 0.06: break
			await scroll(1 if carrier.hold_distance < reach else -1)
		key(KEY_R, false)
		if absf(carrier.hold_distance - reach) > 0.12: return fail("R + scroll não ajustou alcance")
		aim_held(point + Vector3.UP * 0.32)
		await frames(35)
	for i: int in 150:
		aim_held(mount.installation_point.global_position)
		await frames(2)
		if carrier.candidate == mount:
			var object := carrier.held_item
			await tap(KEY_G)
			return object.placement_socket == mount or fail("G não encaixou " + str(mount.socket_id))
	return fail("Sem encaixe " + str(mount.socket_id) + "; peça=" + str(carrier.held_item.global_position) + "; alvo=" + str(mount.installation_point.global_position) + "; " + carrier.candidate_failure_reason)


func to_bench() -> bool:
	key(KEY_CTRL, false)
	await frames(12)
	if player.global_position.x > 0.0:
		if player.global_position.x < 3.1 and player.global_position.z > -1.1 and player.global_position.z < 0.8:
			if not await walk(Vector3(player.global_position.x, 0, 0.85), Vector3(3.5, 0.8, 0.85)): return false
		if player.global_position.x < 3.15:
			if not await walk(Vector3(3.5, 0, player.global_position.z), Vector3(3.5, 0.8, -4)): return false
		if not await walk(Vector3(3.15, 0, -4.0), Vector3(1, 0.8, -1)): return false
	return await walk(Vector3(-3.4, 0, -4.0), Vector3(-3.5, 1.2, -5.0))


func to_front(look: Vector3) -> bool:
	key(KEY_CTRL, false)
	await frames(12)
	if player.global_position.x < 0:
		if not await walk(Vector3(3.15, 0, -4.0), Vector3(1, 0.8, -1)): return false
	return await walk(Vector3(3.15, 0, 0.2), look)


func equip(size: int) -> bool:
	var tool := item("wrench_%dmm" % size) as Tool
	if carrier.held_item == tool: return true
	if carrier.held_item != null:
		if not await return_tool(): return false
	if not tool.stored:
		if tool.global_position.z > -3 and not await to_front(tool.global_position): return false
		if tool.global_position.z <= -3:
			if tool.global_position.x < 0 and not await to_bench(): return false
			if tool.global_position.x >= 0 and not await walk(Vector3(3.5, 0, -4), tool.global_position): return false
		key(KEY_CTRL, tool.global_position.y < 0.8)
		await frames(22)
		await walk(tool.global_position + Vector3(0.6, -tool.global_position.y, 0.45), tool.global_position, false, false, tool)
		return await pick(tool, tool.global_position)
	if not await to_bench(): return false
	var pos := tool.global_position
	if not await walk(Vector3(pos.x, 0, -4.05), pos): return false
	return await pick(tool, pos)


func return_tool() -> bool:
	if not carrier.held_item is Tool: return fail("Item na mão não é chave")
	var tool := carrier.held_item as Tool
	if not await to_bench(): return false
	var mount: SnapSocket = save.registry.nodes[StringName("metric_toolbox_%dmm_slot" % tool.tool_size)]
	# Tool holds closer to the camera. Approach the open tray normally.
	if not await place(mount): return false
	return true


func aim_bolt(bolt: Fastener) -> bool:
	print("PLAYER aiming ", bolt.fastener_id)
	var point := bolt.global_position
	var on_car := car.is_ancestor_of(bolt)
	if on_car and not await to_front(point): return false
	if not on_car:
		print("OFFCAR bolt=", point, " host=", (item("front_left_strut") as AutomotivePart).global_position,
			" held=", item("front_left_strut").is_held, " velocity=", item("front_left_strut").linear_velocity)
		if point.x < -5.0:
			if not await to_bench(): return false
			if not await walk(Vector3(-5.5, 0, -4.0), bolt.global_position): return false
			if not await walk(Vector3(-5.5, 0, point.z + 0.9), bolt.global_position, false, false, bolt): pass
	aim(point)
	await frames(4)
	if subject() == bolt: return true
	for crouch: bool in [true, false]:
		key(KEY_CTRL, crouch)
		await frames(22)
		if not on_car:
			var front_stand := bolt.global_position + Vector3(0, -bolt.global_position.y, 0.9)
			if await walk(front_stand, bolt.global_position, false, false, bolt):
				aim(bolt.global_position)
				await frames(4)
				if subject() == bolt: return true
		for z_shift: float in [0.35, 0.7, 0.0, 1.0, -0.35, -0.7]:
			var stand := Vector3(maxf(car.global_position.x + 1.25, point.x + 0.9) if on_car else point.x + 0.9, 0, point.z + z_shift)
			if not await walk(stand, bolt.global_position, false, false, bolt): continue
			aim(bolt.global_position)
			await frames(4)
			if subject() == bolt: return true
	return fail("Fastener inalcançável: " + str(bolt.fastener_id))


func bolts(id: String, direction: int) -> bool:
	for bolt: Fastener in socket(id).fasteners:
		var goal := bolt.max_tightness if direction > 0 else 0
		if bolt.tightness == goal: continue
		if not await equip(bolt.required_tool_size): return false
		if not await aim_bolt(bolt): return false
		for i: int in bolt.max_tightness:
			if bolt.tightness == goal: break
			await scroll(direction)
		if bolt.tightness != goal: return fail("Scroll recusado: " + str(bolt.fastener_id))
	return true


func park_held() -> bool:
	var transported := carrier.held_item
	key(KEY_CTRL, false)
	var destination := Vector3(3.5 - (parking_index % 4) * 0.85, 0, 2.65 + floori(parking_index / 4.0) * 0.75)
	if not await walk(Vector3(3.6, 0, 1.65), destination): return false
	if not await walk(destination, destination + Vector3(0, 0.15, 1.0)): return false
	await frames(30)
	if transported.global_position.distance_to(player.global_position) > 2.7:
		return fail("Peça presa no transporte: " + str(transported.get_persistent_id()))
	await tap(KEY_G)
	await frames(20)
	parking_index += 1
	return carrier.held_item == null or fail("G não largou peça")


func remove(id: String) -> bool:
	var part := item(id) as AutomotivePart
	if not part.installed: return true
	if not await bolts(id, -1): return false
	if carrier.held_item and not await return_tool(): return false
	if part.global_position.z < 1.5:
		if not await to_front(part.global_position): return false
	key(KEY_CTRL, true)
	await frames(22)
	if not await walk(part.global_position + Vector3(0.95, -part.global_position.y, 0), part.global_position): return false
	if not await pick(part, part.global_position): return false
	if not await park_held(): return false
	completed.append("remove:" + id)
	print("PLAYER removed ", id)
	return true


func install(id: String) -> bool:
	var part := item(id) as AutomotivePart
	if not part.installed:
		if carrier.held_item and not await return_tool(): return false
		key(KEY_CTRL, true)
		await frames(22)
		if not await walk(part.global_position + Vector3(0.9, -part.global_position.y, 0), part.global_position): return false
		if not await pick(part, part.global_position): return false
		if socket(id).global_position.z < 1.5 and not await to_front(socket(id).global_position): return false
		if not await place(socket(id)): return false
		if part.required_fasteners > 0 and part.state != AutomotivePart.State.PLACED: return fail("Encaixe apertou automaticamente " + id)
	if not await bolts(id, 1): return false
	completed.append("install:" + id)
	print("PLAYER installed ", id)
	return true


func jack_phase() -> bool:
	var jack := support.jack
	if not await walk(Vector3(3.75, 0, 1.7), jack.global_position + Vector3.UP * 0.05): return false
	if not await pick(jack, jack.global_position + Vector3.UP * 0.05): return false
	if not await place(support.points["fl"]): return false
	aim(jack.to_global(Vector3(0, 0.50, -0.49)))
	await frames(4)
	if subject() != jack: return fail("Não alcança alavanca do macaco")
	for i: int in 6: await scroll(1)
	await frames(100)
	if not support.can_service(&"fl"): return fail("Macaco não atingiu altura de serviço")
	completed.append("jack:FL lifted by scroll")
	await tap(KEY_F2)
	await tap(KEY_F9)
	await frames(12)
	if not support.can_service(&"fl"): return fail("Save/load perdeu apoio")
	await shot("jack_raised_player")
	return true


func fl_phase() -> bool:
	if not "--resume-assembly" in OS.get_cmdline_user_args():
		if not await fl_disassemble(): return false
	for suffix: String in ["lower_control_arm", "ball_joint", "spring", "strut", "knuckle", "hub", "cv_axle", "brake_disc", "brake_caliper", "tie_rod_end", "stabilizer_link", "wheel"]:
		if not await install("front_left_" + suffix): return false
	if carrier.held_item and not await return_tool(): return false
	if not await to_front(support.jack.global_position): return false
	aim(support.jack.to_global(Vector3(0, 0.50, -0.49)))
	await frames(4)
	if subject() != support.jack: return fail("Mira não alcançou macaco para baixar")
	for i: int in 10: await scroll(-1)
	await frames(140)
	if support.current_lift >= 0.001: return fail("Carro não baixou após remontagem")
	completed.append("jack:lowered after FL reassembly")
	await tap(KEY_F2)
	await tap(KEY_F9)
	await frames(15)
	await shot("fl_reassembled_player")
	await tap(KEY_F8)
	await frames(40)
	if support.is_supporting() or support.active_point != null: return fail("Reset manteve macaco preso/levantado")
	for prefix: String in VehicleJackSupport.PREFIX.values():
		if not (item(prefix + "_wheel") as AutomotivePart).is_secure(): return fail("Reset não restaurou roda " + prefix)
	completed.append("F2/F9 assembled; F8 restores all wheels and grounded jack")
	return true


func fl_disassemble() -> bool:
	if not car.hood.is_open:
		if carrier.held_item and not await return_tool(): return false
		if not await to_front(car.global_position): return false
		key(KEY_CTRL, false)
		if not await walk(Vector3(2.5, 0, 1.9), car.to_global(Vector3(0.35, 0.85, 1.5))): return false
		aim(car.to_global(Vector3(0.35, 0.85, 1.5)))
		await frames(5)
		await click()
		await frames(45)
		if not car.hood.is_open: return fail("LMB não abriu capô para acesso à torre")
	for suffix: String in ["wheel", "brake_caliper", "brake_disc", "cv_axle", "hub", "tie_rod_end", "stabilizer_link", "ball_joint"]:
		if not await remove("front_left_" + suffix): return false
	if not await bolts("front_left_knuckle", -1): return false
	for suffix: String in ["strut", "spring", "knuckle", "lower_control_arm"]:
		if not await remove("front_left_" + suffix): return false
	await shot("fl_all_removed_player")
	await tap(KEY_F2)
	await tap(KEY_F9)
	return true


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://blender/previews_jack/" + label + ".png")


func run() -> void:
	garage = (load("res://world/garage_golf_test.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	current_scene = garage
	player = garage.get_node("Player")
	car = garage.get_node("CarPrototype")
	carrier = player.get_node("PartCarrier")
	save = garage.get_node("SaveSystem")
	save.save_path = "user://golf_jack_player_validation.json" # isolated test storage only
	await frames(35)
	support = garage.get_node("JackSetup/VehicleJackSupport")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://blender/previews_jack"))
	await click() # normal focus capture if the window started without focus
	var passed := true
	if "--resume-fl" in OS.get_cmdline_user_args() or "--resume-assembly" in OS.get_cmdline_user_args(): await tap(KEY_F9)
	else: passed = await jack_phase()
	if passed and not "--jack-only" in OS.get_cmdline_user_args(): passed = await fl_phase()
	stop_walking()
	key(KEY_CTRL, false)
	await shot("session_end")
	if not passed: await tap(KEY_F2) # normal checkpoint, permits continuing the failed step
	var report := FileAccess.open("res://.godot/jack_player_cycle.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": passed, "failure": failure, "completed": completed,
		"method": "InputEventKey and InputEventMouse through unchanged gameplay input pipeline", "partial": "--jack-only" in OS.get_cmdline_user_args()}, "\t"))
	print("PLAYER CYCLE: ", passed, " ", failure)
	quit(0 if passed else 1)
