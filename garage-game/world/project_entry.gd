extends Control
## Publication guard only: no substitute car, gameplay or reference download.

const GARAGE := "res://world/garage_golf_test.tscn"
const REQUIRED_LOCAL_FILES: Array[String] = [
	"res://blender/exports/golf_reference_panels.glb",
	"res://blender/exports/golf_reference_wheel_fl.glb",
	"res://blender/exports/golf_reference_wheel_fr.glb",
	"res://blender/exports/golf_reference_wheel_rl.glb",
	"res://blender/exports/golf_reference_wheel_rr.glb",
	"res://blender/exports/golf_suspension_parts.glb",
	"res://vehicles/golf_suspension_manifest.json",
	"res://blender/reports/golf_reference_panels.json",
	"res://blender/exports/floor_jack.glb",
]


func _ready() -> void:
	_launch_if_ready.call_deferred()


func _launch_if_ready() -> void:
	var missing := PackedStringArray()
	for path: String in REQUIRED_LOCAL_FILES:
		if FileAccess.file_exists(path):
			continue
		if path.ends_with(".glb") and ResourceLoader.exists(path, "PackedScene"):
			continue
		missing.append(path.trim_prefix("res://"))
	if not missing.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		$Margin/Message.text = "GarageGame\n\nModelo de referência local necessário.\nConsulte docs/GIT_REFERENCE_SETUP.md para preparar os arquivos.\n\nO Git contém o código e as cenas, mas não distribui o Golf.\nNenhum carro substituto foi carregado.\n\nArquivos ausentes:\n" + "\n".join(missing)
		return
	var error := get_tree().change_scene_to_file(GARAGE)
	if error != OK:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		$Margin/Message.text = "Não foi possível abrir a garagem atual (erro %d).\nConsulte docs/GIT_REFERENCE_SETUP.md e a saída do Godot." % error
