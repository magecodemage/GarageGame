class_name SnapshotMigration
extends RefCounted
## Narrow schema-3 upgrade: only complete, newly introduced Golf wheel bundles.
## Existing records are never replaced, renamed or silently repaired.

const NEW_WHEEL_IDS: Array[String] = [
	"front_right_wheel", "rear_left_wheel", "rear_right_wheel",
]


static func with_scene_additions(data: Dictionary, initial: Dictionary,
		registry: SceneRegistry) -> Dictionary:
	var upgraded: Dictionary = data.duplicate(true)
	if data.get("version") != SceneSnapshot.VERSION or initial.is_empty():
		return upgraded
	for key: String in ["items", "fasteners", "systems"]:
		if not data.get(key) is Array or not initial.get(key) is Array:
			return upgraded
	for wheel_id: String in NEW_WHEEL_IDS:
		if not registry.nodes.has(StringName(wheel_id)):
			continue
		var bundle_absent: bool = not _has_record(data["items"], wheel_id)
		for number: int in range(1, 6):
			bundle_absent = bundle_absent and not _has_record(
				data["fasteners"], "%s_bolt_%d" % [wheel_id, number])
		# A partial bundle is a corrupt save, not an older scene version.
		if not bundle_absent:
			continue
		_append_initial(upgraded["items"], initial["items"], wheel_id)
		for number: int in range(1, 6):
			_append_initial(upgraded["fasteners"], initial["fasteners"],
				"%s_bolt_%d" % [wheel_id, number])
	if registry.nodes.has(&"golf_hood") and not _has_record(data["systems"], "golf_hood"):
		_append_initial(upgraded["systems"], initial["systems"], "golf_hood")
	# Add only the complete jack bundle to older suspension saves. Never replace
	# existing part/fastener state, or accept a partially missing bundle.
	if registry.nodes.has(&"hydraulic_floor_jack") and not _has_record(data["items"], "hydraulic_floor_jack") and not _has_record(data["systems"], "vehicle_jack_support"):
		_append_initial(upgraded["items"], initial["items"], "hydraulic_floor_jack")
		_append_initial(upgraded["systems"], initial["systems"], "vehicle_jack_support")
	return upgraded


static func _has_record(records: Array, id: String) -> bool:
	for record: Variant in records:
		if record is Dictionary and record.get("id") == id:
			return true
	return false


static func _append_initial(destination: Array, defaults: Array, id: String) -> void:
	for record: Variant in defaults:
		if record is Dictionary and record.get("id") == id:
			destination.append(record.duplicate(true))
			return
