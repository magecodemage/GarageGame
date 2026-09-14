class_name SnapshotValidator
extends RefCounted
## Rejeita snapshots incompletos/incompatíveis antes de alterar qualquer corpo.

static func validate(data: Dictionary, registry: SceneRegistry) -> String:
	if data.get("version") != SceneSnapshot.VERSION:
		return "Versão de save incompatível"
	var player: Variant = data.get("player")
	if not player is Dictionary or not _valid_pose(player):
		return "Pose do jogador inválida"
	if not SnapshotCodec.valid_number(player.get("pitch")) or absf(float(player["pitch"])) > PI / 2.0:
		return "Inclinação da câmera inválida"
	if not player.get("crouched") is bool:
		return "Estado de agachamento inválido"
	for key in ["items", "fasteners", "toolboxes", "systems"]:
		if not data.get(key) is Array:
			return "Save incompleto: " + key
	if data["items"].size() != registry.items.size() or data["fasteners"].size() != registry.fasteners.size():
		return "O save não corresponde aos objetos desta cena"
	if data["toolboxes"].size() != registry.toolboxes.size():
		return "Quantidade de caixas incompatível"
	if data["systems"].size() != registry.runtime_systems.size():
		return "Quantidade de sistemas do veículo incompatível"
	var seen: Dictionary = {}
	var occupied: Dictionary = {}
	for value: Variant in data["items"]:
		if not _valid_record(value, registry, seen):
			return "ID de objeto ausente, desconhecido ou repetido"
		var record: Dictionary = value
		var item := registry.nodes[StringName(record["id"])] as Grabbable
		if not item or not _valid_pose(record) or not record.get("socket") is String:
			return "Registro de objeto inválido"
		if not record.get("installed") is bool or not record.get("stored") is bool:
			return "Estado de placement inválido"
		var socket_id: String = record["socket"]
		if socket_id != "":
			var socket := registry.nodes.get(StringName(socket_id)) as SnapSocket
			if not socket or occupied.has(socket_id) or not socket.is_compatible(item):
				return "Socket incompatível, desconhecido ou duplicado"
			occupied[socket_id] = true
		if bool(record["installed"]) != (item is AutomotivePart and socket_id != ""):
			return "Estado de instalação inconsistente"
		if bool(record["stored"]) != (item is Tool and socket_id != ""):
			return "Estado de armazenamento inconsistente"
		if item is AutomotivePart:
			for key in ["condition", "wear"]:
				if not SnapshotCodec.valid_number(record.get(key)) or float(record[key]) < 0.0 or float(record[key]) > 1.0:
					return "Condição/desgaste inválidos"
			if not record.get("metadata") is Dictionary:
				return "Metadados inválidos"
			if not record.get("custom_state") is Dictionary:
				return "Estado específico da peça inválido"
	for value: Variant in data["fasteners"]:
		if not _valid_record(value, registry, seen):
			return "ID de parafuso ausente, desconhecido ou repetido"
		var fastener := registry.nodes[StringName(value["id"])] as Fastener
		if not fastener or not SnapshotCodec.valid_number(value.get("tightness")):
			return "Aperto inválido"
		var amount: float = float(value["tightness"])
		if amount != floorf(amount) or amount < 0 or amount > fastener.max_tightness:
			return "Aperto fora dos limites"
		if not value.get("installed") is bool or not value.get("locked") is bool:
			return "Estado de parafuso inválido"
		for socket in registry.sockets:
			if socket is PartSocket and fastener in socket.fasteners:
				if amount > 0 and not occupied.has(str(socket.socket_id)):
					return "Parafuso apertado sem peça no socket"
	for value: Variant in data["toolboxes"]:
		if not _valid_record(value, registry, seen):
			return "ID de caixa ausente, desconhecido ou repetido"
		if not registry.nodes[StringName(value["id"])] is Toolbox or not value.get("open") is bool:
			return "Estado de caixa inválido"
	for value: Variant in data["systems"]:
		if not _valid_record(value, registry, seen):
			return "ID de sistema ausente, desconhecido ou repetido"
		var system := registry.nodes[StringName(value["id"])] as VehicleRuntimeSystem
		if not system or not value.get("data") is Dictionary:
			return "Estado de sistema inválido"
		var system_error := system.validate_saved_state(value["data"])
		if not system_error.is_empty():
			return system_error
	# Cross-record invariants run only after all item/system records are valid,
	# and still before SceneSnapshot.apply can change any live object.
	for value: Dictionary in data["systems"]:
		var system := registry.nodes[StringName(value["id"])] as VehicleRuntimeSystem
		var snapshot_error := system.validate_saved_snapshot(value["data"], data)
		if not snapshot_error.is_empty():
			return snapshot_error
	return ""


static func _valid_pose(value: Dictionary) -> bool:
	return SnapshotCodec.valid_vector(value.get("position")) and SnapshotCodec.valid_vector(value.get("rotation"))


static func _valid_record(value: Variant, registry: SceneRegistry, seen: Dictionary) -> bool:
	if not value is Dictionary or not value.get("id") is String:
		return false
	var id: StringName = StringName(value["id"])
	if not registry.nodes.has(id) or seen.has(id):
		return false
	seen[id] = true
	return true
