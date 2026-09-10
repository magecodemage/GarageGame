class_name PartSocket
extends SnapSocket

@export var compatible_part_types: Array[StringName] = []
@export var requires_fasteners: bool = true
@export var fastener_root: Node3D
@export var initial_part: AutomotivePart

var fasteners: Array[Fastener] = []
var installed_part: AutomotivePart:
	get: return installed_item as AutomotivePart


func _ready() -> void:
	super._ready()
	if fastener_root:
		for child in fastener_root.get_children():
			if child is Fastener:
				fasteners.append(child)
				child.fastener_changed.connect(_on_fastener_changed)
	item_placed.connect(_on_item_placed)
	item_removed.connect(_on_item_removed)
	if initial_part:
		_place_initial_part.call_deferred()


func is_compatible(item: Grabbable) -> bool:
	if not item is AutomotivePart:
		return false
	var part := item as AutomotivePart
	return part.part_type in compatible_part_types and socket_type in part.compatible_socket_types and (
		part.required_fasteners == 0 or (
			requires_fasteners and part.required_fasteners == fasteners.size()))


func can_snap(item: Grabbable) -> bool:
	if item is AutomotivePart and not item.can_install(self)["allowed"]:
		return false
	return super.can_snap(item)


func place_item(item: Grabbable, restoring: bool = false) -> bool:
	if not restoring and item is AutomotivePart and not item.can_install(self)["allowed"]:
		return false
	return super.place_item(item, restoring)


func can_remove() -> bool:
	for fastener in fasteners:
		if fastener.tightness > 0:
			return false
	return true


func get_tight_fastener_count() -> int:
	var count: int = 0
	for fastener in fasteners:
		if fastener.tightness > 0:
			count += 1
	return count


func get_fully_tight_fastener_count() -> int:
	var count: int = 0
	for fastener in fasteners:
		if fastener.tightness == fastener.max_tightness:
			count += 1
	return count


func remove_item() -> void:
	if not can_remove():
		return
	super.remove_item()


func get_fastening_ratio() -> float:
	if not occupied:
		return 0.0
	if not requires_fasteners:
		return 1.0
	var total: int = 0
	var maximum: int = 0
	for fastener in fasteners:
		total += fastener.tightness if fastener.installed else 0
		maximum += fastener.max_tightness
	return float(total) / float(maximum) if maximum > 0 else 0.0


func _on_item_placed(_item: Grabbable) -> void:
	for fastener in fasteners:
		fastener.set_active(true)
	installed_part.refresh_fastening_state()


func _on_item_removed(_item: Grabbable) -> void:
	for fastener in fasteners:
		fastener.set_active(false)


func _on_fastener_changed(_fastener: Fastener) -> void:
	if installed_part:
		installed_part.refresh_fastening_state()


func _place_initial_part() -> void:
	if initial_part and not occupied:
		place_item(initial_part, true)


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if compatible_part_types.is_empty():
		issues.append("Socket sem tipos de peça aceitos: " + name)
	if requires_fasteners and fasteners.is_empty():
		issues.append("Socket requer parafusos, mas não tem nenhum: " + name)
	return issues
