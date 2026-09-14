class_name SaveSystem
extends Node

signal feedback(message: String)

@export var scene_root: Node3D
@export var player: FirstPersonPlayer
@export var save_path: String = "user://garage_slice_v3.json"
@export var reset_nodes: Array[Node3D] = []

var registry := SceneRegistry.new()
var initial_snapshot: Dictionary = {}
var _initial_node_transforms: Dictionary = {}


func initialize() -> void:
	if validate_scene():
		initial_snapshot = capture_snapshot()
		_initial_node_transforms.clear()
		for node: Node3D in reset_nodes:
			if is_instance_valid(node):
				_initial_node_transforms[node] = node.global_transform


func validate_scene() -> bool:
	var valid: bool = registry.rebuild(scene_root)
	for issue in registry.issues:
		push_warning(issue)
	return valid


func capture_snapshot() -> Dictionary:
	return SceneSnapshot.capture(registry, player)


func restore_snapshot(data: Dictionary) -> bool:
	if not validate_scene():
		feedback.emit("Cena inválida; consulte os avisos")
		return false
	var upgraded: Dictionary = SnapshotMigration.with_scene_additions(data, initial_snapshot, registry)
	var error: String = SnapshotValidator.validate(upgraded, registry)
	if not error.is_empty():
		push_warning(error)
		feedback.emit(error)
		return false
	SceneSnapshot.apply(upgraded, registry, player)
	return true


func save_game() -> bool:
	if not validate_scene():
		feedback.emit("Save cancelado: IDs/configuração inválidos")
		return false
	var data: Dictionary = capture_snapshot()
	var validation: String = SnapshotValidator.validate(data, registry)
	if not validation.is_empty():
		feedback.emit(validation)
		return false
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if not file:
		feedback.emit("Não foi possível gravar o save")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		feedback.emit("Erro ao gravar o save")
		return false
	var result: Error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if result != OK:
		feedback.emit("Não foi possível substituir o save")
		return false
	feedback.emit("Garagem salva")
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		feedback.emit("Nenhum save encontrado")
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file or file.get_length() > 4 * 1024 * 1024:
		feedback.emit("Save ilegível ou grande demais")
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		feedback.emit("Save inválido; nada foi alterado")
		return false
	if not restore_snapshot(parser.data):
		return false
	feedback.emit("Garagem carregada")
	return true


func reset_test_scene() -> bool:
	if initial_snapshot.is_empty() or not restore_snapshot(initial_snapshot.duplicate(true)):
		return false
	for node: Variant in _initial_node_transforms:
		if is_instance_valid(node):
			node.global_transform = _initial_node_transforms[node]
	feedback.emit("Protótipo restaurado")
	return true
