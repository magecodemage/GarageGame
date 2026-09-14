extends Node
## Assembly only; keeps the current vehicle, save, tools and player scenes.


func _ready() -> void:
	var garage := get_parent() as Node3D
	var loose := Node3D.new()
	loose.name = "LooseServiceItems"
	add_child(loose)
	var jack := (preload("res://tools/floor_jack.tscn") as PackedScene).instantiate() as FloorJack
	jack.position = Vector3(3.75, 0.03, 0.7)
	loose.add_child(jack)
	var support := VehicleJackSupport.new()
	support.name = "VehicleJackSupport"
	support.system_id = &"vehicle_jack_support"
	add_child(support)
	support.configure(garage.get_node("CarPrototype"), jack, loose)
	for corner: String in VehicleJackSupport.PREFIX:
		var id: String = VehicleJackSupport.PREFIX[corner] + "_wheel"
		for node: Node in get_tree().get_nodes_in_group("grabbables"):
			if node is AutomotivePart and str(node.part_id) == id:
				node.removal_guard = func() -> Dictionary:
					return {"allowed": support.can_service(StringName(corner)), "reason": "Levante este lado do veículo primeiro."}
