extends RefCounted


func run(t: SceneTree) -> void:
	await t.begin_grab(t.wheel)
	t.check(not t.wheel.freeze and t.wheel.get_parent() == t.garage, "Hold mantém física sem parenting à câmera")
	await t.frames(45)
	t.check(t.wheel.global_position.y > 0.35, "Força levanta a roda suavemente")
	t.check(t.wheel.linear_velocity.length() < 4.2, "Velocidade do hold permanece limitada")
	var camera_before: Vector3 = t.player.camera.rotation
	var yaw_before: float = t.player.rotation.y
	var item_basis: Basis = t.wheel.global_basis
	Input.action_press("secondary_interact")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 35)
	t.player._unhandled_input(motion)
	await t.frames(35)
	Input.action_release("secondary_interact")
	t.check(t.player.camera.rotation.is_equal_approx(camera_before) and is_equal_approx(t.player.rotation.y, yaw_before),
		"RMB + mouse não gira a câmera")
	t.check(not t.wheel.global_basis.is_equal_approx(item_basis), "RMB + mouse rotaciona fisicamente a peça")
	await t.carry_to(Vector3(-1.35, 0, 0.1), t.socket.global_position)
	t.check(t.carrier.candidate == t.socket, "A: aproximação física destaca socket compatível")
	t.check(t.last_context.get("hint") == "Solte LMB para instalar", "A: HUD orienta soltar LMB")
	await t.capture("snap_ready")
	await t.release_grab()
	t.check(t.wheel.installed and t.wheel.state == AutomotivePart.State.PLACED, "A: soltar encaixa em PLACED")
	t.check(t.carrier.held_item == null, "LMB released sempre encerra hold")
	t.check(t.wheel.can_pick_up(), "Peça apenas encaixada com zero aperto pode ser retirada")
	t.socket.fasteners[0].set_tightness(1)
	t.aim_at(t.socket.global_position + Vector3(-0.13, 0, 0))
	await t.frames(4)
	await t.press(&"primary_interact")
	t.check(t.wheel.installed and t.carrier.held_item == null, "B: um parafuso acima de zero bloqueia retirada")
	t.check(t.last_context.get("hint", "").contains("Afrouxe todos os 5"), "B: HUD explica bloqueio")
	t.socket.fasteners[0].set_tightness(0)
	var wrench15: Tool = await t.grab_tool(15)
	t.aim_at(t.socket.fasteners[0].global_position)
	await t.frames(5)
	t.check(t.interaction.ray.get_collider() == t.socket.fasteners[0], "RayCast seleciona parafuso individual")
	await t.scroll(1, 4)
	t.check(t.socket.fasteners[0].tightness == 0, "C: chave 15 não aperta parafuso 17")
	t.check(t.last_context.get("hint", "").contains("17 mm"), "C: HUD informa tamanho necessário")
	# Guarda a 15 no slot correto, por proximidade, sem mirar o slot.
	var slot_position: Vector3 = t.toolbox.slots[9].global_position
	var storage_aim: Vector3 = slot_position + Vector3(-0.38, 0.5, 0)
	await t.carry_to(Vector3(slot_position.x - 0.38, 0, slot_position.z + 1.2), storage_aim)
	t.aim_at(storage_aim)
	await t.frames(65)
	# Alvo de hold configurável aproxima a chave ao slot sem teleporte do item.
	t.carrier.hold_distance = 1.2
	await t.frames(65)
	var could_store: bool = t.carrier.candidate == t.toolbox.slots[9]
	await t.release_grab()
	t.check(could_store and wrench15.stored, "Slot guarda a chave correta ao soltar")
	t.carrier.hold_distance = 1.35
	# Chave 17: todos os eventos de scroll preservados, mesmo no mesmo frame.
	var wrench17: Tool = await t.grab_tool(17)
	for index in 5:
		var bolt: Fastener = t.socket.fasteners[index]
		t.aim_at(bolt.global_position)
		await t.frames(4)
		t.check(t.interaction.ray.get_collider() == bolt, "RayCast distingue bolt %d" % (index + 1))
		for amount in range(1, 5):
			await t.scroll(1)
			t.check(bolt.tightness == amount, "D/E: bolt %d = %d/4" % [index + 1, amount])
		await t.scroll(1)
		t.check(bolt.tightness == 4, "Aperto não ultrapassa máximo")
	t.check(t.wheel.fastened and is_equal_approx(t.wheel.get_fastening_ratio(), 1.0), "E: cinco bolts completos = FASTENED")
	await t.capture("fastened")
	for index in 4:
		t.aim_at(t.socket.fasteners[index].global_position)
		await t.frames(3)
		await t.scroll(-1, 4)
	t.check(t.wheel.state == AutomotivePart.State.PARTIALLY_FASTENED, "Aperto parcial atualiza estado")
	t.check(not t.wheel.can_pick_up(), "F: último parafuso apertado impede retirada")
	t.aim_at(t.socket.fasteners[4].global_position)
	await t.frames(3)
	await t.scroll(-1, 5)
	t.check(t.socket.fasteners[4].tightness == 0, "Afrouxar nunca gera valor negativo")
	t.check(t.wheel.can_pick_up() and is_zero_approx(t.wheel.fastening_ratio), "G: todos em zero liberam remoção")
	await t.release_grab()
	await t.begin_grab(t.wheel)
	t.check(not t.wheel.installed and t.wheel.current_socket == null, "G: LMB remove do socket")
	t.check(t.wheel.state == AutomotivePart.State.HELD and not t.socket.occupied, "Socket libera vaga na remoção")
	await t.carry_to(Vector3(-2.8, 0, 1.5), Vector3(-3.0, 0.8, 0))
	await t.release_grab()
	await t.frames(140)
	t.check(t.wheel.state == AutomotivePart.State.FREE and not t.wheel.freeze, "H: soltar devolve física normal")
	t.check(t.wheel.global_position.y > 0.08 and t.wheel.linear_velocity.length() < 0.4, "H: roda repousa sem explosão")
	# Parede não deve capturar a peça; soltar ainda encerra hold.
	t.player.global_position = t.wheel.global_position + Vector3(0, -t.wheel.global_position.y, 1.5)
	await t.begin_grab(t.wheel)
	await t.carry_to(Vector3(-5.5, 0, 1.5), Vector3(-7, 1.3, 1.5))
	await t.release_grab()
	t.check(t.carrier.held_item == null and not t.wheel.is_held, "LMB release junto da parede não mantém hold")
	t.check(t.wheel.global_position.x > -5.9, "Corpo não atravessa a parede")
	await t.frames(20)
	t.check(t.wheel.linear_velocity.length() < 4.0, "Soltura junto ao obstáculo não lança a peça")
	t.check(not t.toolbox.slots[0].is_compatible(wrench17), "Slot errado rejeita ferramenta")
