class_name EngineController
extends VehicleRuntimeSystem

signal engine_started
signal engine_stopped
signal engine_stalled
signal engine_state_changed(state: State)
signal rpm_changed(rpm: float)
signal temperature_changed(temperature: float)
signal engine_condition_changed(condition: float)
signal alternator_output_changed(output: float)

enum State { OFF, CRANKING, RUNNING, STALLED, FAILED }

@export_group("References")
@export var mechanical_state: VehicleMechanicalState
@export var ignition: IgnitionSystem
@export var fuel_system: FuelSystem
@export var oil_system: OilSystem
@export var coolant_system: CoolantSystem
@export var engine_audio: EngineAudio

@export_group("Configured IDs")
@export var battery_part_id: StringName = &"battery"
@export var starter_part_id: StringName = &"starter_motor"
@export var alternator_part_id: StringName = &"alternator"
@export var radiator_part_id: StringName = &"radiator"

@export_group("Engine")
@export var engine_rpm: float = 0.0
@export var idle_rpm: float = 850.0
@export var max_rpm: float = 6500.0
@export var cranking_rpm: float = 230.0
@export var minimum_start_rpm: float = 150.0
@export var minimum_crank_time: float = 0.65
@export var engine_temperature: float = 20.0
@export var ambient_temperature: float = 20.0
@export var operating_temperature: float = 90.0
@export var critical_temperature: float = 115.0
@export_range(0.0, 1.0) var engine_condition: float = 1.0
@export var compression: float = 1.0
@export var airflow: float = 1.0
@export var fuel_mixture: float = 1.0

@export_group("Electrical")
@export var minimum_battery_charge: float = 0.18
@export var critical_battery_charge: float = 0.04
@export var starter_current_draw: float = 220.0
@export var ignition_current_draw: float = 8.0
@export var alternator_max_output: float = 70.0

@export_group("Thermal")
@export var no_coolant_heat_rate: float = 3.2
@export var warmup_rate: float = 0.055
@export var cooldown_rate: float = 0.012
@export var overheat_damage_rate: float = 0.0015

var state: State = State.OFF
var throttle_input: float = 0.0
var starter_engaged: bool = false
var alternator_output: float = 0.0
var last_diagnostic := EngineStartDiagnostic.new()
var _crank_elapsed: float = 0.0
var _slow_accumulator: float = 0.0
var _saved_state: State = State.OFF
var _last_reported_rpm: float = 0.0
var _last_reported_temperature: float = 20.0
var _last_reported_condition: float = 1.0
var _last_reported_alternator_output: float = 0.0

var oil_amount: float:
	get: return oil_system.oil_amount if oil_system else 0.0
var oil_capacity: float:
	get: return oil_system.oil_capacity if oil_system else 0.0
var coolant_amount: float:
	get: return coolant_system.coolant_amount if coolant_system else 0.0
var coolant_capacity: float:
	get: return coolant_system.coolant_capacity if coolant_system else 0.0
var fuel_available: bool:
	get: return fuel_system.has_fuel() if fuel_system else false
var ignition_enabled: bool:
	get: return ignition.ignition_enabled if ignition else false


func _ready() -> void:
	super._ready()
	if ignition:
		ignition.starter_command_changed.connect(_on_starter_command_changed)
		ignition.ignition_state_changed.connect(_on_ignition_state_changed)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_update_state(delta)
	_update_rpm(delta)
	_slow_accumulator += delta
	if _slow_accumulator >= 0.1:
		var elapsed := _slow_accumulator
		_slow_accumulator = 0.0
		_update_resources(elapsed)
		_update_temperature(elapsed)
	_emit_threshold_signals()


func can_engine_start() -> EngineStartDiagnostic:
	var diagnostic := EngineStartDiagnostic.new()
	_refresh_registry()
	var battery := get_battery()
	var starter := get_starter()
	if not battery or not battery.installed:
		diagnostic.add(EngineStartDiagnostic.Code.NO_BATTERY)
	elif not battery.is_electrically_connected():
		diagnostic.add(EngineStartDiagnostic.Code.BATTERY_DISCONNECTED)
	elif battery.charge < minimum_battery_charge or battery.get_voltage() < 11.0:
		diagnostic.add(EngineStartDiagnostic.Code.LOW_BATTERY)
	if not starter or not starter.installed:
		diagnostic.add(EngineStartDiagnostic.Code.NO_STARTER)
	elif not starter.is_electrically_connected():
		diagnostic.add(EngineStartDiagnostic.Code.STARTER_DISCONNECTED)
	if not fuel_system or not fuel_system.has_fuel():
		diagnostic.add(EngineStartDiagnostic.Code.NO_FUEL)
	if not ignition or not ignition.ignition_available or not ignition.ignition_enabled:
		diagnostic.add(EngineStartDiagnostic.Code.NO_IGNITION)
	if mechanical_state:
		for id in mechanical_state.get_missing_engine_parts():
			if id != battery_part_id and id != starter_part_id:
				diagnostic.add(EngineStartDiagnostic.Code.CRITICAL_PART_MISSING, str(id))
	last_diagnostic = diagnostic
	return diagnostic


func can_crank() -> EngineStartDiagnostic:
	var diagnostic := EngineStartDiagnostic.new()
	_refresh_registry()
	var battery := get_battery()
	var starter := get_starter()
	if not battery or not battery.installed:
		diagnostic.add(EngineStartDiagnostic.Code.NO_BATTERY)
	elif not battery.is_electrically_connected():
		diagnostic.add(EngineStartDiagnostic.Code.BATTERY_DISCONNECTED)
	elif battery.charge <= critical_battery_charge:
		diagnostic.add(EngineStartDiagnostic.Code.LOW_BATTERY)
	if not starter or not starter.installed:
		diagnostic.add(EngineStartDiagnostic.Code.NO_STARTER)
	elif not starter.is_electrically_connected():
		diagnostic.add(EngineStartDiagnostic.Code.STARTER_DISCONNECTED)
	return diagnostic


func set_throttle(value: float) -> void:
	throttle_input = clampf(value, 0.0, 1.0)


func stop_engine(failed: bool = false) -> void:
	starter_engaged = false
	_crank_elapsed = 0.0
	_set_state(State.FAILED if failed else State.OFF)
	if engine_audio:
		engine_audio.set_starter_active(false)
		engine_audio.set_engine_active(false)
		engine_audio.play_shutdown()
	engine_stopped.emit()


func get_battery() -> BatteryPart:
	return mechanical_state.get_part(battery_part_id) as BatteryPart if mechanical_state else null


func get_starter() -> StarterMotorPart:
	return mechanical_state.get_part(starter_part_id) as StarterMotorPart if mechanical_state else null


func get_alternator() -> AlternatorPart:
	return mechanical_state.get_part(alternator_part_id) as AlternatorPart if mechanical_state else null


func get_radiator() -> RadiatorPart:
	return mechanical_state.get_part(radiator_part_id) as RadiatorPart if mechanical_state else null


func get_debug_text() -> String:
	var battery := get_battery()
	var blockers := can_engine_start().messages()
	var blocker_text := "None" if blockers.is_empty() else "\n- " + "\n- ".join(blockers)
	return "Engine State: %s\nRPM: %.0f\nBattery: %.2f V / %.1f%%\nFuel: %.2f L\nOil: %.2f L (%.0f%%)\nCoolant: %.2f L\nTemperature: %.1f C\nEngine Condition: %.1f%%\nStarter: %s\nAlternator Output: %.1f A\nIgnition: %s\nStart blockers: %s" % [
		State.keys()[state], engine_rpm, battery.get_voltage() if battery else 0.0,
		(battery.charge * 100.0) if battery else 0.0, fuel_system.fuel_amount,
		oil_system.oil_amount, oil_system.oil_condition * 100.0, coolant_system.coolant_amount,
		engine_temperature, engine_condition * 100.0, "ENGAGED" if starter_engaged else "OFF",
		alternator_output, IgnitionSystem.State.keys()[ignition.state], blocker_text]


func capture_state() -> Dictionary:
	return {"state": state, "rpm": engine_rpm, "temperature": engine_temperature,
		"condition": engine_condition, "throttle": 0.0}


func apply_state(data: Dictionary) -> void:
	_saved_state = clampi(int(data.get("state", State.OFF)), State.OFF, State.FAILED)
	engine_rpm = maxf(float(data.get("rpm", 0.0)), 0.0)
	engine_temperature = maxf(float(data.get("temperature", ambient_temperature)), ambient_temperature)
	engine_condition = clampf(float(data.get("condition", engine_condition)), 0.0, 1.0)
	starter_engaged = false
	throttle_input = 0.0
	_crank_elapsed = 0.0


func validate_saved_state(data: Dictionary) -> String:
	for key in ["state", "rpm", "temperature", "condition", "throttle"]:
		if not SnapshotCodec.valid_number(data.get(key)):
			return "Estado salvo do motor inválido"
	if int(data["state"]) < State.OFF or int(data["state"]) > State.FAILED or float(data["rpm"]) < 0.0 or float(data["condition"]) < 0.0 or float(data["condition"]) > 1.0:
		return "Valores salvos do motor fora dos limites"
	return ""


func normalize_after_load() -> void:
	if ignition and ignition.state == IgnitionSystem.State.START:
		ignition.engage_starter(false)
	var restorable_running := _saved_state == State.RUNNING and can_engine_start().is_clear()
	_set_state(State.RUNNING if restorable_running else State.OFF)
	if state == State.OFF:
		engine_rpm = 0.0


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if not mechanical_state or not ignition or not fuel_system or not oil_system or not coolant_system:
		issues.append("EngineController sem referências obrigatórias")
	for id in [battery_part_id, starter_part_id, alternator_part_id, radiator_part_id]:
		if id.is_empty():
			issues.append("EngineController com ID de componente vazio")
	if idle_rpm <= 0.0 or max_rpm <= idle_rpm or minimum_crank_time <= 0.0:
		issues.append("Faixas de RPM/partida inválidas")
	return issues


func _update_state(delta: float) -> void:
	if state == State.RUNNING:
		if not ignition or not ignition.ignition_enabled:
			stop_engine()
		elif not fuel_system.has_fuel():
			_set_state(State.STALLED)
			engine_stalled.emit()
	elif starter_engaged:
		var crank_diagnostic := can_crank()
		if not crank_diagnostic.is_clear():
			last_diagnostic = crank_diagnostic
			var just_failed := state != State.FAILED
			_set_state(State.FAILED)
			if engine_audio and just_failed:
				engine_audio.play_failed_start()
		else:
			_set_state(State.CRANKING)
			_crank_elapsed += delta
			if _crank_elapsed >= minimum_crank_time and engine_rpm >= minimum_start_rpm:
				if can_engine_start().is_clear():
					_set_state(State.RUNNING)
					engine_started.emit()
	else:
		_crank_elapsed = 0.0
		if state == State.CRANKING or state == State.FAILED:
			_set_state(State.OFF)


func _update_rpm(delta: float) -> void:
	var target := 0.0
	if state == State.CRANKING:
		var battery := get_battery()
		var strength := clampf((battery.charge - critical_battery_charge) / maxf(1.0 - critical_battery_charge, 0.01), 0.0, 1.0) if battery else 0.0
		target = cranking_rpm * lerpf(0.35, 1.0, strength) * (battery.condition if battery else 0.0)
	elif state == State.RUNNING:
		target = lerpf(idle_rpm, max_rpm * 0.72, throttle_input)
	engine_rpm = move_toward(engine_rpm, target, (2400.0 if target > engine_rpm else 3200.0) * delta)


func _update_resources(delta: float) -> void:
	_sync_radiator_state()
	var battery := get_battery()
	if starter_engaged and battery and battery.is_electrically_connected():
		battery.consume_energy(starter_current_draw * delta / 3600.0)
	if state == State.RUNNING:
		if _has_runtime_critical_failure():
			stop_engine(true)
			return
		fuel_system.consume(delta, engine_rpm, max_rpm)
		if battery and battery.is_electrically_connected():
			battery.consume_energy(ignition_current_draw * delta / 3600.0)
		var alternator := get_alternator()
		if alternator and alternator.installed and alternator.is_operational():
			alternator_output = alternator_max_output * clampf(engine_rpm / maxf(max_rpm * 0.45, 1.0), 0.15, 1.0) * alternator.condition
			if battery and battery.is_electrically_connected():
				battery.charge_battery(alternator_output * delta / 3600.0)
		else:
			alternator_output = 0.0
		var damage := oil_system.get_damage_per_second() * delta
		if engine_temperature > critical_temperature:
			damage += overheat_damage_rate * ((engine_temperature - critical_temperature) / 20.0) * delta
		engine_condition = clampf(engine_condition - damage, 0.0, 1.0)
	else:
		alternator_output = 0.0


func _update_temperature(delta: float) -> void:
	if state == State.RUNNING:
		var radiator := get_radiator()
		var cooling_ok := radiator and radiator.installed and radiator.condition > 0.2 and coolant_system.is_adequate()
		if cooling_ok:
			var load_target := operating_temperature + throttle_input * 12.0
			engine_temperature = lerpf(engine_temperature, load_target, 1.0 - exp(-warmup_rate * delta))
		else:
			engine_temperature += no_coolant_heat_rate * delta * maxf(engine_rpm / idle_rpm, 0.6)
	else:
		engine_temperature = lerpf(engine_temperature, ambient_temperature, 1.0 - exp(-cooldown_rate * delta))


func _has_runtime_critical_failure() -> bool:
	var diagnostic := can_engine_start()
	for entry in diagnostic.entries:
		if entry["code"] in [EngineStartDiagnostic.Code.NO_BATTERY,
			EngineStartDiagnostic.Code.BATTERY_DISCONNECTED, EngineStartDiagnostic.Code.NO_STARTER,
			EngineStartDiagnostic.Code.STARTER_DISCONNECTED, EngineStartDiagnostic.Code.NO_IGNITION,
			EngineStartDiagnostic.Code.CRITICAL_PART_MISSING]:
			return true
	return false


func _refresh_registry() -> void:
	if mechanical_state:
		mechanical_state.rebuild()


func _sync_radiator_state() -> void:
	var radiator := get_radiator()
	if radiator and coolant_system:
		radiator.coolant_capacity = coolant_system.coolant_capacity
		radiator.coolant_amount = coolant_system.coolant_amount


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	engine_state_changed.emit(state)
	if engine_audio:
		engine_audio.set_starter_active(state == State.CRANKING)
		engine_audio.set_engine_active(state == State.RUNNING, throttle_input > 0.35)


func _emit_threshold_signals() -> void:
	if absf(engine_rpm - _last_reported_rpm) >= 10.0 or (engine_rpm == 0.0 and _last_reported_rpm != 0.0):
		_last_reported_rpm = engine_rpm
		rpm_changed.emit(engine_rpm)
	if absf(engine_temperature - _last_reported_temperature) >= 0.2:
		_last_reported_temperature = engine_temperature
		temperature_changed.emit(engine_temperature)
	if absf(engine_condition - _last_reported_condition) >= 0.001:
		_last_reported_condition = engine_condition
		engine_condition_changed.emit(engine_condition)
	if absf(alternator_output - _last_reported_alternator_output) >= 0.5:
		_last_reported_alternator_output = alternator_output
		alternator_output_changed.emit(alternator_output)


func _on_starter_command_changed(engaged: bool) -> void:
	starter_engaged = engaged
	if not engaged and state == State.CRANKING:
		_set_state(State.OFF)


func _on_ignition_state_changed(next_state: IgnitionSystem.State) -> void:
	if next_state == IgnitionSystem.State.OFF and state == State.RUNNING:
		stop_engine()
