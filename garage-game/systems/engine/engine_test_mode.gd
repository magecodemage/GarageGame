class_name EngineTestMode
extends Node
## Bancada temporária: captura W apenas enquanto o modo de teste está ativo.

@export var engine: EngineController
@export var ignition: IgnitionSystem
@export var fuel_system: FuelSystem
@export var player: FirstPersonPlayer
@export var hud: InteractionHUD

var active: bool = false
var _status_accumulator: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("engine_test_modes")
	engine.engine_started.connect(func() -> void: hud.notify("Motor funcionando"))
	engine.engine_stalled.connect(func() -> void: hud.notify("Motor apagou"))
	engine.engine_stopped.connect(func() -> void: hud.notify("Motor desligado"))


func _process(delta: float) -> void:
	if active and player.controls_enabled:
		player.set_controls_enabled(false)
	engine.set_throttle(Input.get_action_strength("engine_throttle") if active else 0.0)
	_status_accumulator += delta
	if _status_accumulator >= 0.1:
		_status_accumulator = 0.0
		if active or hud.debug_enabled or ignition.state != IgnitionSystem.State.OFF or engine.state != EngineController.State.OFF:
			_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("engine_test_mode"):
		set_active(not active)
		return true
	if not active:
		return false
	if event.is_action_pressed("ignition_toggle"):
		ignition.toggle_ignition()
		return true
	if event.is_action_pressed("engine_start"):
		ignition.engage_starter(true)
		return true
	if event.is_action_released("engine_start"):
		ignition.engage_starter(false)
		return true
	if event.is_action_pressed("debug_add_fuel"):
		var added := fuel_system.add_fuel(5.0)
		hud.notify("Combustível: +%.1f L" % added)
		return true
	return false


func set_active(value: bool) -> void:
	active = value
	if not active:
		ignition.engage_starter(false)
		engine.set_throttle(0.0)
	player.set_controls_enabled(not active)
	hud.notify("Modo de teste do motor" if active else "Modo de teste encerrado")
	_update_hud()


func reset_mode() -> void:
	active = false
	engine.set_throttle(0.0)
	ignition.engage_starter(false)
	hud.set_engine_status("", false)
	player.set_controls_enabled(true)


func _update_hud() -> void:
	var status := "Engine Off"
	if engine.state == EngineController.State.CRANKING:
		status = "Cranking... %.0f RPM" % engine.engine_rpm
	elif engine.state == EngineController.State.RUNNING:
		status = "Running  %.0f RPM" % engine.engine_rpm
	elif engine.state == EngineController.State.STALLED:
		status = "Engine Stalled"
	elif engine.state == EngineController.State.FAILED:
		status = "Start Failed"
	hud.set_engine_status(status + ("  ·  [I] Ignição  [K] Starter  [W] Acelerar" if active else ""),
		active or ignition.state != IgnitionSystem.State.OFF or engine.state != EngineController.State.OFF)
	hud.set_vehicle_debug(engine.get_debug_text())
