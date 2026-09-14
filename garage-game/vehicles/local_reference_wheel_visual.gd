extends Node3D
## Lazy loading keeps authored scenes parseable without the private reference.
## The integration still owns the final per-corner visual and unit transform.

const SOURCE := "res://blender/exports/golf_reference_wheel_fl.glb"


func _ready() -> void:
	# FR/RL/RR visuals may already have been assigned before entering the tree.
	if has_node("GolfWheelMesh"):
		return
	var imported: Node3D
	if ResourceLoader.exists(SOURCE, "PackedScene"):
		var packed := load(SOURCE) as PackedScene
		if packed:
			imported = packed.instantiate() as Node3D
	elif FileAccess.file_exists(SOURCE):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(ProjectSettings.globalize_path(SOURCE), state) == OK:
			imported = document.generate_scene(state)
	if imported == null:
		return
	imported.name = "GolfWheelMesh"
	add_child(imported)
