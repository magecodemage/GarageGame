extends RefCounted


func run(t: SceneTree) -> void:
	t.check(t.save.reset_test_scene(), "J: reset aplica snapshot inicial")
	await t.frames(35)
	t.check(not t.wheel.installed and t.wheel.state == AutomotivePart.State.FREE, "J: roda volta ao chão")
	t.check(t.toolbox.tools.all(func(tool: Tool) -> bool: return tool.stored), "J: todas as chaves voltam aos slots")
	t.check(t.socket.fasteners.all(func(bolt: Fastener) -> bool: return bolt.tightness == 0), "J: bolts resetados")
	var initial_player: Vector3 = SnapshotCodec.to_vector(t.save.initial_snapshot["player"]["position"])
	t.check(t.player.global_position.distance_to(initial_player) < 0.08, "J: jogador volta ao spawn")
	t.socket.place_item(t.wheel, true)
	var levels: Array[int] = [4, 4, 2, 0, 4]
	for index in 5:
		t.socket.fasteners[index].set_tightness(levels[index])
	t.check(is_equal_approx(t.wheel.fastening_ratio, 0.7), "Fixação soma níveis independentes: 14/20 = 0,7")
	t.wheel.condition = 0.72
	t.wheel.wear = 0.1
	t.wheel.part_metadata = {"inspection": "test"}
	var loose_tool: Tool = t.toolbox.tools[0]
	loose_tool.restore_free(Transform3D(Basis.from_euler(Vector3(0, 0.4, 0)), Vector3(-3.2, 0.4, 1.0)))
	t.player.global_position = Vector3(-2.0, 0, 0.2)
	t.player.rotation.y = 0.8
	t.player.camera.rotation.x = -0.5
	await t.frames(50)
	t.check(t.save.save_game(), "I: grava JSON por IDs persistentes")
	t.check(t.save.save_game(), "I: pode substituir save existente")
	var saved: Dictionary = t.save.capture_snapshot()
	t.save.reset_test_scene()
	await t.frames(8)
	t.check(t.save.load_game(), "I: carrega arquivo JSON")
	t.check(t.wheel.installed and t.wheel.state == AutomotivePart.State.PARTIALLY_FASTENED, "I: restaura peça e estado parcial")
	t.check(t.wheel.current_socket == t.socket, "I: restaura vínculo com socket por ID")
	for index in 5:
		t.check(t.socket.fasteners[index].tightness == levels[index], "I: restaura bolt %d independente" % (index + 1))
	t.check(not loose_tool.stored and t.toolbox.tools[1].stored, "I: restaura ferramenta livre e armazenada")
	t.check(is_equal_approx(t.wheel.condition, 0.72) and t.wheel.part_metadata.get("inspection") == "test",
		"I: restaura condição e metadados")
	t.check(t.player.global_position.is_equal_approx(SnapshotCodec.to_vector(saved["player"]["position"])),
		"I: restaura posição do jogador")
	t.check(is_equal_approx(t.player.camera.rotation.x, -0.5), "I: restaura orientação da câmera")
	var invalid: Dictionary = saved.duplicate(true)
	invalid["items"][0]["socket"] = "unknown_socket"
	t.check(not t.save.restore_snapshot(invalid), "Save com socket desconhecido é rejeitado")
	t.check(t.wheel.installed and is_equal_approx(t.wheel.fastening_ratio, 0.7), "Save inválido não altera a garagem")
	invalid = saved.duplicate(true)
	invalid["fasteners"][0]["tightness"] = -1
	t.check(not t.save.restore_snapshot(invalid), "Aperto inválido é rejeitado antes de restaurar")
	var id: StringName = loose_tool.tool_id
	loose_tool.tool_id = t.toolbox.tools[1].tool_id
	t.check(not t.save.validate_scene(), "Validação detecta IDs duplicados")
	loose_tool.tool_id = id
	t.check(t.save.validate_scene(), "Registro volta a validar após corrigir ID")
	t.toolbox.set_open(false)
	t.check(not t.toolbox.tools[1].can_pick_up(), "Caixa fechada bloqueia retirada de ferramenta")
	t.toolbox.set_open(true)
	t.check(t.toolbox.tools[1].can_pick_up(), "Caixa aberta libera ferramenta")
	# Type mismatch, usable e locked são verificados além do tamanho.
	var tool17: Tool = t.toolbox.tools[10]
	tool17.begin_hold(t.player)
	var bolt: Fastener = t.socket.fasteners[3]
	bolt.locked = true
	t.check(not bolt.interaction_scroll(tool17, 1), "Parafuso locked bloqueia ferramenta correta")
	bolt.locked = false
	tool17.spec.usable = false
	t.check(not bolt.interaction_scroll(tool17, 1), "Ferramenta unusable não aperta")
	tool17.spec.usable = true
	tool17.spec.tool_type = &"screwdriver"
	t.check(not bolt.interaction_scroll(tool17, 1), "Tipo errado não aperta mesmo com 17 mm")
	tool17.spec.tool_type = &"wrench"
	tool17.end_hold()
	t.save.reset_test_scene()
	await t.frames(35)
	t.player.global_position = Vector3(-1.7, 0, 2.1)
	await t.begin_grab(t.wheel)
	await t.frames(35)
	t.check(t.save.save_game(), "Save durante hold é permitido")
	t.check(t.save.load_game(), "Load durante hold funciona")
	t.check(not t.wheel.is_held and t.carrier.held_item == null, "Load não restaura um botão LMB preso")
	Input.action_release("primary_interact")
	await t.frames(4)
	var session: Node = t.garage.get_node("GarageSession")
	var event := InputEventAction.new()
	event.action = &"debug_toggle"
	event.pressed = true
	session.handle_shortcut(event)
	t.check(session.hud.debug_enabled, "F3 alterna modo debug")
	session.handle_shortcut(event)
	event.action = &"pause"
	session.handle_shortcut(event)
	t.check(t.paused and not t.player.controls_enabled, "P pausa e libera interação")
	session.handle_shortcut(event)
	t.check(not t.paused and t.player.controls_enabled, "P retoma")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	event.action = &"reset_test_scene"
	session.handle_shortcut(event)
	await t.frames(35)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	t.check(t.toolbox.tools.all(func(tool: Tool) -> bool: return tool.stored), "F8 restaura caixa completa")
	t.check(not t.wheel.installed and t.socket.can_remove(), "F8 restaura roda e cinco bolts")
	await t.capture("reset")
	DirAccess.remove_absolute(t.save.save_path)
