extends RefCounted


func run(t: SceneTree) -> void:
	var engine := t.garage.get_node("CarPrototype/EngineSystems/EngineController") as EngineController
	var ignition := t.garage.get_node("CarPrototype/EngineSystems/IgnitionSystem") as IgnitionSystem
	var fuel := t.garage.get_node("CarPrototype/EngineSystems/FuelSystem") as FuelSystem
	var oil := t.garage.get_node("CarPrototype/EngineSystems/OilSystem") as OilSystem
	var coolant := t.garage.get_node("CarPrototype/EngineSystems/CoolantSystem") as CoolantSystem
	engine.set_physics_process(false)

	await _reset(t, engine)
	_start(engine, ignition)
	t.check(engine.state == EngineController.State.RUNNING and engine.engine_rpm >= engine.minimum_start_rpm,
		"ENGINE TEST 1: carro completo liga após o tempo mínimo de crank")
	engine.set_throttle(1.0)
	_advance(engine, 1.0)
	t.check(engine.engine_rpm > engine.idle_rpm, "Acelerador de teste eleva RPM sem física de direção")
	engine.set_throttle(0.0)

	await _reset(t, engine)
	var battery := t.part(&"battery") as BatteryPart
	battery.set_terminal_connected(true, false)
	ignition.set_state(IgnitionSystem.State.IGNITION)
	ignition.engage_starter(true)
	_advance(engine, 0.25)
	t.check(engine.state == EngineController.State.FAILED and is_zero_approx(engine.engine_rpm),
		"ENGINE TEST 2: terminal desconectado impede o starter")
	t.check(engine.last_diagnostic.has(EngineStartDiagnostic.Code.BATTERY_DISCONNECTED),
		"Debug diagnostica Battery disconnected")
	ignition.engage_starter(false)

	await _reset(t, engine)
	battery = t.part(&"battery") as BatteryPart
	battery.charge = 0.08
	ignition.set_state(IgnitionSystem.State.IGNITION)
	ignition.engage_starter(true)
	_advance(engine, 1.0)
	t.check(engine.state == EngineController.State.CRANKING and engine.engine_rpm < engine.minimum_start_rpm,
		"ENGINE TEST 3: bateria fraca produz crank lento e insuficiente")
	ignition.engage_starter(false)

	await _reset(t, engine)
	fuel.fuel_amount = 0.0
	ignition.set_state(IgnitionSystem.State.IGNITION)
	ignition.engage_starter(true)
	_advance(engine, 1.0)
	t.check(engine.state == EngineController.State.CRANKING and engine.engine_rpm > 0.0,
		"ENGINE TEST 4: sem combustível o starter gira, mas o motor não pega")
	t.check(engine.last_diagnostic.has(EngineStartDiagnostic.Code.NO_FUEL), "Diagnóstico registra No fuel")
	ignition.engage_starter(false)

	await _reset(t, engine)
	var starter := t.part(&"starter_motor") as StarterMotorPart
	var starter_socket: PartSocket = t.socket_by_id(&"starter_mount")
	for bolt in starter_socket.fasteners:
		bolt.set_tightness(0)
	starter.begin_hold(t.player)
	starter.end_hold()
	ignition.set_state(IgnitionSystem.State.IGNITION)
	ignition.engage_starter(true)
	_advance(engine, 0.25)
	t.check(engine.state == EngineController.State.FAILED and engine.last_diagnostic.has(
		EngineStartDiagnostic.Code.NO_STARTER), "ENGINE TEST 5: starter removido impede crank")
	ignition.engage_starter(false)

	await _reset(t, engine)
	var alternator := t.part(&"alternator") as AlternatorPart
	var alternator_socket: PartSocket = t.socket_by_id(&"alternator_mount")
	for bolt in alternator_socket.fasteners:
		bolt.set_tightness(0)
	alternator.begin_hold(t.player)
	alternator.end_hold()
	battery = t.part(&"battery") as BatteryPart
	battery.charge = 0.75
	_start(engine, ignition)
	var charge_before := battery.charge
	_advance(engine, 20.0)
	t.check(engine.state == EngineController.State.RUNNING and battery.charge < charge_before and
		is_zero_approx(engine.alternator_output), "ENGINE TEST 6: sem alternador a bateria descarrega")

	await _reset(t, engine)
	_start(engine, ignition)
	var fuel_before := fuel.fuel_amount
	var temperature_before := engine.engine_temperature
	_advance(engine, 30.0)
	t.check(fuel.fuel_amount < fuel_before, "ENGINE TEST 7: motor funcionando consome combustível")
	t.check(engine.engine_temperature > temperature_before, "ENGINE TEST 8: motor funcionando aquece")
	var cooled_temperature := engine.engine_temperature
	_advance(engine, 270.0)
	t.check(engine.engine_temperature > 84.0 and engine.engine_temperature < 96.0,
		"ENGINE TEST 9: radiador e coolant estabilizam perto da temperatura operacional")

	await _reset(t, engine)
	coolant.coolant_amount = 0.0
	_start(engine, ignition)
	_advance(engine, 30.0)
	t.check(engine.engine_temperature > cooled_temperature,
		"ENGINE TEST 10: sem coolant a temperatura sobe mais rapidamente")

	await _reset(t, engine)
	oil.oil_amount = 0.0
	_start(engine, ignition)
	var condition_before := engine.engine_condition
	_advance(engine, 20.0)
	t.check(engine.state == EngineController.State.RUNNING and engine.engine_condition < condition_before,
		"ENGINE TEST 11: óleo muito baixo degrada condição gradualmente")

	ignition.set_state(IgnitionSystem.State.OFF)
	_advance(engine, 1.0)
	t.check(engine.state == EngineController.State.OFF and is_zero_approx(engine.engine_rpm),
		"ENGINE TEST 12: desligar ignição para o motor e reduz RPM a zero")

	await _reset(t, engine)
	battery = t.part(&"battery") as BatteryPart
	_start(engine, ignition)
	battery.charge = 0.67
	fuel.fuel_amount = 12.3
	oil.oil_amount = 2.2
	oil.oil_condition = 0.74
	coolant.coolant_amount = 3.1
	engine.engine_temperature = 77.0
	engine.engine_condition = 0.83
	t.check(t.save.save_game(), "ENGINE TEST 13: save grava sistemas do motor")
	battery.charge = 0.2
	fuel.fuel_amount = 1.0
	oil.oil_amount = 0.1
	coolant.coolant_amount = 0.0
	engine.engine_temperature = 20.0
	engine.engine_condition = 0.2
	ignition.set_state(IgnitionSystem.State.START)
	t.check(t.save.load_game(), "ENGINE TEST 13: load restaura sistemas do motor")
	t.check(is_equal_approx(battery.charge, 0.67) and is_equal_approx(fuel.fuel_amount, 12.3),
		"Load restaura bateria e combustível")
	t.check(is_equal_approx(oil.oil_amount, 2.2) and is_equal_approx(coolant.coolant_amount, 3.1),
		"Load restaura óleo e coolant")
	t.check(is_equal_approx(engine.engine_temperature, 77.0) and is_equal_approx(engine.engine_condition, 0.83),
		"Load restaura temperatura e condição")
	t.check(engine.state == EngineController.State.RUNNING and not ignition.starter_engaged,
		"Load preserva RUNNING sem deixar starter preso")
	var invalid_runtime: Dictionary = t.save.capture_snapshot()
	for record: Dictionary in invalid_runtime["systems"]:
		if record["id"] == "fuel_system":
			record["data"]["amount"] = -1.0
	t.check(not t.save.restore_snapshot(invalid_runtime), "Save rejeita valores de sistema fora dos limites")

	t.check(t.save.reset_test_scene(), "ENGINE TEST 14: reset restaura preset funcional")
	await t.frames(3)
	engine.set_physics_process(false)
	ignition.set_state(IgnitionSystem.State.IGNITION)
	t.check(engine.can_engine_start().is_clear(), "Reset deixa o carro apto a ligar")
	t.check(is_equal_approx((t.part(&"battery") as BatteryPart).charge, 1.0) and fuel.fuel_amount > 0.0 and
		oil.oil_amount > oil.critical_oil_amount and coolant.is_adequate(),
		"Reset restaura carga e fluidos funcionais")
	var mechanical_readiness: float = t.mechanical_state.get_mechanical_readiness()
	t.check(mechanical_readiness >= 0.0 and mechanical_readiness <= 1.0 and
		t.mechanical_state.get_electrical_readiness() > 0.99 and
		t.mechanical_state.get_engine_readiness() > 0.99, "Readiness separa mecânica, elétrica e motor")
	ignition.set_state(IgnitionSystem.State.OFF)
	var test_mode := t.garage.get_node("EngineTestMode") as EngineTestMode
	var event := InputEventAction.new()
	event.action = &"engine_test_mode"
	event.pressed = true
	test_mode.handle_input(event)
	t.check(test_mode.active and not t.player.controls_enabled, "T ativa modo do motor sem mover o FPS")
	event.action = &"ignition_toggle"
	test_mode.handle_input(event)
	event.action = &"engine_start"
	test_mode.handle_input(event)
	t.check(ignition.starter_engaged, "K pressionado mantém starter engatado")
	event.pressed = false
	test_mode.handle_input(event)
	t.check(not ignition.starter_engaged and ignition.state == IgnitionSystem.State.IGNITION,
		"Soltar K devolve START para IGNITION")
	event.action = &"engine_test_mode"
	event.pressed = true
	test_mode.handle_input(event)
	t.check(not test_mode.active and t.player.controls_enabled, "Sair do modo devolve controles FPS")
	DirAccess.remove_absolute(t.save.save_path)


func _start(engine: EngineController, ignition: IgnitionSystem) -> void:
	ignition.set_state(IgnitionSystem.State.IGNITION)
	ignition.engage_starter(true)
	_advance(engine, 1.0)
	ignition.engage_starter(false)
	_advance(engine, 0.2)


func _advance(engine: EngineController, seconds: float, step: float = 0.05) -> void:
	for index in ceili(seconds / step):
		engine._physics_process(step)


func _reset(t: SceneTree, engine: EngineController) -> void:
	t.save.reset_test_scene()
	await t.frames(2)
	engine.set_physics_process(false)
