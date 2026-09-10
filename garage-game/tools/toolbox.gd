class_name Toolbox
extends StaticBody3D
## Caixa ancorada na bancada; conteúdo e slots são instâncias configuradas.

@export var toolbox_id: StringName = &"metric_toolbox"
@export var tool_sizes: Array[int] = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 19]
@export var tool_scene: PackedScene
@export var slot_scene: PackedScene
@export var lid: Node3D
@export var lid_body: StaticBody3D
@export var is_open: bool = true

var slots: Array[ToolSlot] = []
var tools: Array[Tool] = []


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("toolboxes")
	InteractionTarget.register(self)
	if lid_body:
		lid_body.set_meta(&"interaction_target", get_meta(&"interaction_target"))
	var container := Node3D.new()
	container.name = "Tools"
	add_child(container)
	for index in tool_sizes.size():
		var size: int = tool_sizes[index]
		var id := StringName("wrench_%dmm" % size)
		var slot := slot_scene.instantiate() as ToolSlot
		slot.name = "Slot%dmm" % size
		slot.socket_id = StringName("%s_%dmm_slot" % [toolbox_id, size])
		slot.socket_type = &"tool_storage"
		slot.expected_tool_id = id
		slot.expected_tool_size = size
		slot.position = Vector3((index % 6 - 2.5) * 0.43, 0.08, (floori(index / 6.0) - 0.5) * 0.44)
		add_child(slot)
		slots.append(slot)
		var tool := tool_scene.instantiate() as Tool
		tool.name = "Wrench%dmm" % size
		tool.tool_id = id
		var tool_spec := ToolSpec.new()
		tool_spec.tool_size = size
		tool_spec.mass_kg = 0.12 + size * 0.014
		tool.spec = tool_spec
		container.add_child(tool)
		slots[index].place_item(tool, true)
		tools.append(tool)
	set_open(is_open)


func get_persistent_id() -> StringName:
	return toolbox_id


func set_open(value: bool) -> void:
	is_open = value
	if lid:
		lid.rotation.x = deg_to_rad(-105.0) if is_open else 0.0
	for slot in slots:
		slot.accessible = is_open
		slot.set_highlight(false)


func interaction_primary() -> RigidBody3D:
	set_open(not is_open)
	return null


func interaction_context(_held: RigidBody3D) -> Dictionary:
	return {"title": "Caixa de ferramentas", "hint": "LMB · Fechar" if is_open else "LMB · Abrir",
		"debug": "ID: %s\nSlots: %d\nAberta: %s" % [toolbox_id, slots.size(), is_open]}


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if toolbox_id.is_empty() or not tool_scene or not slot_scene:
		issues.append("Caixa sem ID/cenas de ferramentas/slots")
	return issues
