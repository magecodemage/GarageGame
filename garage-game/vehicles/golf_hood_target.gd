extends StaticBody3D

var hood: GolfHood


func _ready() -> void:
	InteractionTarget.register(self)


func interaction_primary() -> RigidBody3D:
	hood.set_open(not hood.is_open)
	return null


func interaction_context(_held: RigidBody3D) -> Dictionary:
	return {"title": "Capô", "hint": "[LMB] Fechar" if hood.is_open else "[LMB] Abrir",
		"debug": "Dobradiça real · %.0f° · %s" % [absf(hood.open_degrees), hood.pivot.position]}
