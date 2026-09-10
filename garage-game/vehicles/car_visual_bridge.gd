class_name CarVisualBridge
extends Node3D

@export var hood_open_degrees: float = -58.0
@export_file("*.glb") var glb_path: String = "res://blender/exports/car_main.glb"
@export var hidden_imported_parts: PackedStringArray = [
	"wheel_fl",
	"suspension_fl",
	"battery",
	"battery_positive_terminal",
	"battery_negative_terminal",
	"radiator",
	"airbox",
	"alternator",
	"starter_motor",
]


func _ready() -> void:
	_load_glb()
	call_deferred("_configure_imported_visual")


func _load_glb() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var absolute_path := ProjectSettings.globalize_path(glb_path)
	var error := document.append_from_file(absolute_path, state)
	if error != OK:
		push_error("Unable to load car visual GLB: %s (error %d)" % [glb_path, error])
		return
	var imported_scene := document.generate_scene(state)
	if imported_scene == null:
		push_error("Unable to generate car visual scene from: " + glb_path)
		return
	imported_scene.name = "ImportedCar"
	add_child(imported_scene)


func _configure_imported_visual() -> void:
	for object_name: String in hidden_imported_parts:
		var imported_node := find_child(object_name, true, false) as Node3D
		if imported_node != null:
			imported_node.visible = false
	var imported_hood := find_child("hood", true, false) as Node3D
	if imported_hood != null:
		imported_hood.rotation_degrees.x = hood_open_degrees
