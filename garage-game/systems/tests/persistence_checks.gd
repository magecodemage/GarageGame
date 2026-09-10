extends RefCounted


func run(t: SceneTree) -> void:
	var wheel: AutomotivePart = t.part(&"front_left_wheel")
	var caliper: AutomotivePart = t.part(&"front_left_brake_caliper")
	var battery := t.part(&"battery") as BatteryPart
	var radiator := t.part(&"radiator") as RadiatorPart
	var air_filter := t.part(&"air_filter_box") as AirFilterBoxPart
	var alternator := t.part(&"alternator") as AlternatorPart
	var starter := t.part(&"starter_motor") as StarterMotorPart
	var coolant_system := t.garage.get_node("CarPrototype/EngineSystems/CoolantSystem") as CoolantSystem
	var wheel_socket: PartSocket = t.socket_by_id(&"front_left_wheel_socket")
	var caliper_socket: PartSocket = t.socket_by_id(&"front_left_brake_caliper_socket")
	var battery_socket: PartSocket = t.socket_by_id(&"battery_mount")

	for bolt in wheel_socket.fasteners:
		bolt.set_tightness(0)
	wheel.begin_hold(t.player)
	wheel.end_hold()
	for bolt in caliper_socket.fasteners:
		bolt.set_tightness(0)
	caliper.begin_hold(t.player)
	caliper.end_hold()
	battery.charge = 0.63
	battery.condition = 0.78
	battery.set_terminal_connected(true, false)
	radiator.coolant_amount = 3.4
	coolant_system.coolant_amount = 3.4
	air_filter.air_filter_condition = 0.41
	alternator.belt_connected = false
	alternator.electrical_connected = false
	starter.electrical_connected = false
	battery_socket.fasteners[0].set_tightness(2)
	t.player.global_position = Vector3(-2.0, 0.0, 0.2)
	t.player.camera.rotation.x = -0.35
	await t.frames(4)
	t.check(t.save.save_game(), "TEST 10: save grava conjunto parcialmente desmontado")

	wheel_socket.place_item(wheel, true)
	caliper_socket.place_item(caliper, true)
	for bolt in wheel_socket.fasteners:
		bolt.set_tightness(4)
	for bolt in caliper_socket.fasteners:
		bolt.set_tightness(4)
	battery.charge = 1.0
	battery.set_terminal_connected(true, true)
	radiator.coolant_amount = radiator.coolant_capacity
	coolant_system.coolant_amount = coolant_system.coolant_capacity
	air_filter.air_filter_condition = 1.0
	alternator.belt_connected = true
	alternator.electrical_connected = true
	starter.electrical_connected = true
	battery_socket.fasteners[0].set_tightness(4)
	t.check(t.save.load_game(), "TEST 10: load aceita o save válido")
	t.check(not wheel.installed and not caliper.installed, "Load restaura peças removidas")
	t.check(battery_socket.fasteners[0].tightness == 2, "Load restaura tightness independente")
	t.check(is_equal_approx(battery.charge, 0.63) and not battery.battery_positive_terminal.is_connected,
		"Load restaura propriedades elétricas importantes")
	t.check(is_equal_approx(battery.condition, 0.78), "Load restaura condição da peça")
	t.check(is_equal_approx(radiator.coolant_amount, 3.4), "Load restaura quantidade de coolant")
	t.check(is_equal_approx(air_filter.air_filter_condition, 0.41), "Load restaura condição do filtro")
	t.check(not alternator.belt_connected and not alternator.electrical_connected,
		"Load restaura conexões do alternador")
	t.check(not starter.electrical_connected, "Load restaura conexão do motor de partida")
	t.check(is_equal_approx(t.player.camera.rotation.x, -0.35), "Load restaura orientação do jogador")

	var saved: Dictionary = t.save.capture_snapshot()
	var invalid: Dictionary = saved.duplicate(true)
	invalid["items"][0]["socket"] = "unknown_socket"
	t.check(not t.save.restore_snapshot(invalid), "Save com socket desconhecido é rejeitado sem aplicar")
	invalid = saved.duplicate(true)
	invalid["fasteners"][0]["tightness"] = -1
	t.check(not t.save.restore_snapshot(invalid), "Save com aperto inválido é rejeitado")

	t.check(t.save.reset_test_scene(), "TEST 11: reset aplica o snapshot inicial")
	await t.frames(8)
	t.check(t.part(&"front_left_wheel").installed and t.part(&"front_left_brake_caliper").installed,
		"Reset reinstala o conjunto dianteiro esquerdo")
	t.check(t.socket_by_id(&"front_left_wheel_socket").fasteners.all(
		func(bolt: Fastener) -> bool: return bolt.tightness == 4), "Reset reaperta a roda")
	t.check(t.toolbox.tools.all(func(tool: Tool) -> bool: return tool.stored), "Reset devolve todas as ferramentas")
	t.check(is_equal_approx((t.part(&"battery") as BatteryPart).charge, 1.0),
		"Reset restaura as propriedades da bateria")
	var initial_player: Vector3 = SnapshotCodec.to_vector(t.save.initial_snapshot["player"]["position"])
	t.check(t.player.global_position.distance_to(initial_player) < 0.08, "Reset devolve o jogador ao spawn")

	var session: Node = t.garage.get_node("GarageSession")
	var event := InputEventAction.new()
	event.action = &"debug_toggle"
	event.pressed = true
	session.handle_shortcut(event)
	t.check(session.hud.debug_enabled, "F3 alterna o debug expandido")
	session.handle_shortcut(event)
	DirAccess.remove_absolute(t.save.save_path)
