extends SceneTree
## Sem framework: fluxo físico real, entrada simulada e verificações persistentes.

var failures: int = 0
var checks: int = 0
var garage: Node3D
var player: FirstPersonPlayer
var wheel: AutomotivePart
var socket: PartSocket
var toolbox: Toolbox
var carrier: PartCarrier
var interaction: InteractionController
var save: SaveSystem
var mechanical_state: VehicleMechanicalState
var last_context: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func aim_at(point: Vector3) -> void:
	var direction: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.camera.rotation = Vector3(atan2(direction.y, Vector2(direction.x, direction.z).length()), 0, 0)


func press(action: StringName, count: int = 3) -> void:
	Input.action_press(action)
	await frames(count)
	Input.action_release(action)
	await frames(3)


func begin_grab(item: Grabbable) -> void:
	Input.action_release("primary_interact")
	await frames(3)
	aim_at(item.global_position)
	await frames(3)
	Input.action_press("primary_interact")
	await frames(3)
	check(carrier.held_item == item, "LMB down pega " + item.display_name)


func release_grab() -> void:
	Input.action_release("primary_interact")
	await frames(4)


func scroll(direction: int, count: int = 1) -> void:
	for index in count:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP if direction > 0 else MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		player._unhandled_input(event)
	await frames(3)


func carry_to(point: Vector3, look_point: Vector3) -> void:
	for index in 400:
		var destination := Vector3(point.x, player.global_position.y, point.z)
		if player.global_position.distance_to(destination) < 0.02:
			break
		player.global_position = player.global_position.move_toward(destination, 0.035)
		aim_at(look_point)
		await frames(1)
	await frames(65)


func grab_tool(size: int) -> Tool:
	var tool: Tool
	for item in toolbox.tools:
		if item.tool_size == size:
			tool = item
	player.global_position = Vector3(tool.global_position.x, 0, tool.global_position.z + 1.1)
	player.velocity = Vector3.ZERO
	await frames(4)
	await begin_grab(tool)
	await frames(40)
	await capture("toolbox_%dmm" % size)
	await carry_to(Vector3(-1.35, 0, 0.1), socket.global_position)
	return tool


func capture(file_name: String) -> void:
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/slice_" + file_name + ".png")


func part(id: StringName) -> AutomotivePart:
	mechanical_state.rebuild()
	return mechanical_state.get_part(id)


func socket_by_id(id: StringName) -> PartSocket:
	save.registry.rebuild(garage)
	return save.registry.nodes[id] as PartSocket


func tool_by_size(size: int) -> Tool:
	for tool in toolbox.tools:
		if tool.tool_size == size:
			return tool
	return null


func run() -> void:
	garage = (load("res://world/garage_test.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(garage)
	current_scene = garage
	player = garage.get_node("Player") as FirstPersonPlayer
	toolbox = garage.get_node("Toolbox") as Toolbox
	carrier = player.interaction.carrier
	interaction = player.interaction
	save = garage.get_node("SaveSystem") as SaveSystem
	mechanical_state = garage.get_node("CarPrototype/MechanicalState") as VehicleMechanicalState
	save.save_path = "user://garage_slice_validation.json"
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	interaction.context_changed.connect(func(context: Dictionary) -> void: last_context = context)
	await frames(15)
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(30)
	mechanical_state.rebuild()
	wheel = part(&"front_left_wheel")
	socket = socket_by_id(&"front_left_wheel_socket")
	check(save.validate_scene(), "Registro sem IDs duplicados/configurações inválidas")
	check(toolbox.tools.size() == 12 and toolbox.slots.size() == 12, "Caixa contém 12 chaves e 12 slots")
	check(socket.fasteners.size() == 5, "Roda possui cinco parafusos independentes")
	check(mechanical_state.get_parts().size() == 10, "Veículo registra dez peças mecânicas")
	var used_sizes: Dictionary = {}
	for fastener in garage.get_tree().get_nodes_in_group("fasteners"):
		used_sizes[fastener.required_tool_size] = true
	check([8, 10, 12, 13, 14, 17, 19].all(func(size: int) -> bool: return used_sizes.has(size)),
		"Conjunto mecânico usa todas as sete chaves requeridas")
	check(player.is_on_floor(), "Player apoiado no piso")
	_check_input_map()
	await capture("initial")
	await _movement_checks()
	await (load("res://systems/tests/mechanics_checks.gd").new() as RefCounted).run(self)
	await (load("res://systems/tests/persistence_checks.gd").new() as RefCounted).run(self)
	await (load("res://systems/tests/engine_checks.gd").new() as RefCounted).run(self)
	Input.action_release("primary_interact")
	Input.action_release("secondary_interact")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("RESULT: %d checks, %d failure(s)" % [checks, failures])
	var result_file := FileAccess.open("res://.godot/slice_test_result.json", FileAccess.WRITE)
	result_file.store_string(JSON.stringify({"checks": checks, "failures": failures}))
	result_file.close()
	quit(0 if failures == 0 else 1)


func _movement_checks() -> void:
	var start: Vector3 = player.global_position
	for action in [&"move_forward", &"move_backward", &"move_left", &"move_right"]:
		var before: Vector3 = player.global_position
		await press(action, 20)
		check(player.global_position.distance_to(before) > 0.25, "%s movimenta o jogador" % action)
	await press(&"jump")
	check(player.global_position.y > 0.1, "Pulo discreto funciona")
	await frames(65)
	Input.action_press("crouch")
	await frames(25)
	check(player.crouched and player.camera.position.y < 1.0, "Ctrl reduz cápsula e câmera")
	Input.action_release("crouch")
	await frames(25)
	check(not player.crouched and player.camera.position.y > 1.5, "Soltar Ctrl restaura altura")
	# Teto baixo: não permite levantar a cápsula através do obstáculo.
	Input.action_press("crouch")
	await frames(25)
	var ceiling := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 0.15, 2)
	collider.shape = shape
	ceiling.add_child(collider)
	garage.add_child(ceiling)
	ceiling.global_position = player.global_position + Vector3(0, 1.25, 0)
	await frames(3)
	Input.action_release("crouch")
	await frames(25)
	check(player.crouched, "Crouch não atravessa teto baixo ao levantar")
	ceiling.queue_free()
	await frames(25)
	check(not player.crouched, "Levanta quando há espaço")
	player.global_position = start
	player.velocity = Vector3.ZERO
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(14, 0)
	var yaw: float = player.rotation.y
	player._unhandled_input(motion)
	check(not is_equal_approx(yaw, player.rotation.y), "Mouse controla câmera")
	await frames(5)


func _check_input_map() -> void:
	for entry in [[KEY_F2, "save_game"], [KEY_F3, "debug_toggle"], [KEY_F8, "reset_test_scene"],
			[KEY_F9, "load_game"], [KEY_CTRL, "crouch"], [KEY_ESCAPE, "release_mouse"]]:
		var key := InputEventKey.new()
		key.physical_keycode = entry[0]
		key.pressed = true
		check(InputMap.event_is_action(key, entry[1]), "InputMap reconhece " + entry[1])
	for action in [&"engine_test_mode", &"ignition_toggle", &"engine_start", &"engine_throttle", &"debug_add_fuel"]:
		check(InputMap.has_action(action), "InputMap contém " + action)
	check(not InputMap.has_action("interact") and not InputMap.has_action("drop_part"), "E/Q antigos removidos do InputMap")
