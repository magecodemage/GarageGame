extends StaticBody3D

var panel: GolfBodyPanel


func _ready() -> void:
	InteractionTarget.register(self)


func interaction_primary() -> RigidBody3D:
	panel.set_open(not panel.is_open)
	return null


func interaction_context(_held: RigidBody3D) -> Dictionary:
	return {"title": panel.display_name,
		"hint": "[LMB] Fechar" if panel.is_open else "[LMB] Abrir",
		"debug": "Dobradiça: %s · limite %.0f°" % [panel.system_id, absf(panel.open_degrees)]}
