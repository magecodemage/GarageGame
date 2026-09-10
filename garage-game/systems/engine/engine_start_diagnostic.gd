class_name EngineStartDiagnostic
extends RefCounted

enum Code {
	NO_BATTERY,
	BATTERY_DISCONNECTED,
	LOW_BATTERY,
	NO_STARTER,
	STARTER_DISCONNECTED,
	NO_FUEL,
	NO_IGNITION,
	CRITICAL_PART_MISSING,
}

var entries: Array[Dictionary] = []


func add(code: Code, detail: String = "") -> void:
	entries.append({"code": code, "detail": detail})


func has(code: Code) -> bool:
	return entries.any(func(entry: Dictionary) -> bool: return entry["code"] == code)


func is_clear() -> bool:
	return entries.is_empty()


func messages() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in entries:
		result.append(message_for(entry["code"], entry["detail"]))
	return result


static func message_for(code: Code, detail: String = "") -> String:
	match code:
		Code.NO_BATTERY: return "Battery missing"
		Code.BATTERY_DISCONNECTED: return "Battery disconnected"
		Code.LOW_BATTERY: return "Battery too weak"
		Code.NO_STARTER: return "Starter missing"
		Code.STARTER_DISCONNECTED: return "Starter disconnected"
		Code.NO_FUEL: return "No fuel"
		Code.NO_IGNITION: return "Ignition system unavailable"
		Code.CRITICAL_PART_MISSING: return "Critical part missing: " + detail
	return "Unknown start blocker"
