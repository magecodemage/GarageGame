extends Toolbox
## Variant only: the old toolbox and its existing IDs remain unchanged.


func _ready() -> void:
	tool_sizes.assign([6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21])
	super._ready()
	# Fifteen tools fit inside the same real tray in two rows, not a third row
	# outside its rim. Moving a slot also moves its already stored tool.
	for index: int in slots.size():
		slots[index].position = Vector3((index % 8 - 3.5) * 0.33, 0.08, (floori(index / 8.0) - 0.5) * 0.44)
