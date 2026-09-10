class_name IgnitionSystem
extends VehicleRuntimeSystem

signal ignition_state_changed(state: State)
signal starter_command_changed(engaged: bool)

enum State { OFF, ACCESSORY, IGNITION, START }

@export var state: State = State.OFF
@export var ignition_available: bool = true
@export_range(0.0, 1.0) var condition: float = 1.0

var starter_engaged: bool:
	get: return state == State.START
var ignition_enabled: bool:
	get: return state == State.IGNITION or state == State.START


func set_state(next_state: State) -> void:
	if not ignition_available and next_state != State.OFF:
		next_state = State.OFF
	var was_engaged := starter_engaged
	if state == next_state:
		return
	state = next_state
	ignition_state_changed.emit(state)
	if was_engaged != starter_engaged:
		starter_command_changed.emit(starter_engaged)


func toggle_ignition() -> void:
	set_state(State.OFF if state != State.OFF else State.IGNITION)


func engage_starter(engaged: bool) -> void:
	if engaged and state == State.IGNITION:
		set_state(State.START)
	elif not engaged and state == State.START:
		set_state(State.IGNITION)


func capture_state() -> Dictionary:
	var saved_state := State.IGNITION if state == State.START else state
	return {"state": saved_state, "available": ignition_available, "condition": condition}


func apply_state(data: Dictionary) -> void:
	ignition_available = bool(data.get("available", ignition_available))
	condition = clampf(float(data.get("condition", condition)), 0.0, 1.0)
	var loaded := clampi(int(data.get("state", State.OFF)), State.OFF, State.START)
	set_state(State.IGNITION if loaded == State.START else loaded)


func validate_saved_state(data: Dictionary) -> String:
	if not SnapshotCodec.valid_number(data.get("state")) or not data.get("available") is bool or not SnapshotCodec.valid_number(data.get("condition")):
		return "Estado de ignição inválido"
	var saved_state := int(data["state"])
	if saved_state < State.OFF or saved_state > State.START or float(data["condition"]) < 0.0 or float(data["condition"]) > 1.0:
		return "Valores de ignição fora dos limites"
	return ""


func normalize_after_load() -> void:
	if state == State.START:
		set_state(State.IGNITION)
