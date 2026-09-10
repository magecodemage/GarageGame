class_name SceneSnapshot
extends RefCounted

const VERSION: int = 1


static func capture(registry: SceneRegistry, player: FirstPersonPlayer) -> Dictionary:
	var player_data := SnapshotCodec.pose(player)
	player_data["pitch"] = player.camera.rotation.x
	player_data["crouched"] = player.crouched
	var data: Dictionary = {"version": VERSION, "player": player_data,
		"items": [], "fasteners": [], "toolboxes": []}
	for item in registry.items:
		var record := SnapshotCodec.pose(item)
		record["id"] = str(item.get_persistent_id())
		record["socket"] = str(item.placement_socket.socket_id) if item.placement_socket else ""
		record["installed"] = item is AutomotivePart and item.installed
		record["stored"] = item is Tool and item.stored
		# HELD é salvo como objeto livre, nunca como uma entrada LMB persistida.
		if item is AutomotivePart:
			record["condition"] = item.condition
			record["wear"] = item.wear
			record["metadata"] = item.part_metadata.duplicate(true)
		data["items"].append(record)
	for fastener in registry.fasteners:
		data["fasteners"].append({"id": str(fastener.fastener_id), "tightness": fastener.tightness,
			"installed": fastener.installed, "locked": fastener.locked})
	for toolbox in registry.toolboxes:
		data["toolboxes"].append({"id": str(toolbox.toolbox_id), "open": toolbox.is_open})
	return data


static func apply(data: Dictionary, registry: SceneRegistry, player: FirstPersonPlayer) -> void:
	# Chamado somente depois da validação integral. Primeiro libera vínculos antigos.
	player.interaction.cancel_interaction()
	for fastener in registry.fasteners:
		fastener.set_tightness(0)
	for record: Dictionary in data["items"]:
		var item := registry.nodes[StringName(record["id"])] as Grabbable
		item.restore_free(SnapshotCodec.transform_of(record))
		if item is AutomotivePart:
			item.condition = float(record["condition"])
			item.wear = float(record["wear"])
			item.part_metadata = record["metadata"].duplicate(true)
	for record: Dictionary in data["toolboxes"]:
		var toolbox := registry.nodes[StringName(record["id"])] as Toolbox
		toolbox.set_open(record["open"])
	for record: Dictionary in data["items"]:
		if record["socket"] != "":
			var socket := registry.nodes[StringName(record["socket"])] as SnapSocket
			socket.place_item(registry.nodes[StringName(record["id"])] as Grabbable, true)
	for record: Dictionary in data["fasteners"]:
		var fastener := registry.nodes[StringName(record["id"])] as Fastener
		fastener.installed = record["installed"]
		fastener.locked = record["locked"]
		fastener.set_tightness(int(record["tightness"]))
		fastener.set_active(fastener.active)
	for socket in registry.sockets:
		if socket is PartSocket and socket.installed_part:
			socket.installed_part.refresh_fastening_state()
	var player_data: Dictionary = data["player"]
	player.restore_pose(SnapshotCodec.transform_of(player_data), float(player_data["pitch"]), player_data["crouched"])
