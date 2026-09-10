extends Node
## Atalhos de desenvolvimento isolados do Player e dos sistemas mecânicos.

@export var save_system: SaveSystem
@export var player: FirstPersonPlayer
@export var hud: InteractionHUD


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_system.feedback.connect(hud.notify)
	save_system.initialize.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if handle_shortcut(event):
		get_viewport().set_input_as_handled()


func handle_shortcut(event: InputEvent) -> bool:
	if event.is_action_pressed("debug_toggle"):
		hud.debug_enabled = not hud.debug_enabled
	elif event.is_action_pressed("pause"):
		var will_pause: bool = not get_tree().paused
		player.set_controls_enabled(not will_pause)
		get_tree().paused = will_pause
		hud.notify("Pausado · P para continuar" if will_pause else "Continuar")
	elif event.is_action_pressed("save_game"):
		save_system.save_game()
	elif event.is_action_pressed("load_game"):
		save_system.load_game()
	elif event.is_action_pressed("reset_test_scene"):
		get_tree().paused = false
		for mode in get_tree().get_nodes_in_group("engine_test_modes"):
			mode.reset_mode()
		save_system.reset_test_scene()
		player.set_controls_enabled(true)
	else:
		return false
	return true
