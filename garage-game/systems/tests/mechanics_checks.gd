extends RefCounted


func run(t: SceneTree) -> void:
	var wheel: AutomotivePart = t.part(&"front_left_wheel")
	var disc: AutomotivePart = t.part(&"front_left_brake_disc")
	var caliper: AutomotivePart = t.part(&"front_left_brake_caliper")
	var battery: AutomotivePart = t.part(&"battery")
	var wheel_socket: PartSocket = t.socket_by_id(&"front_left_wheel_socket")
	var disc_socket: PartSocket = t.socket_by_id(&"front_left_brake_disc_socket")
	var caliper_socket: PartSocket = t.socket_by_id(&"front_left_brake_caliper_socket")
	var battery_socket: PartSocket = t.socket_by_id(&"battery_mount")

	t.check(not wheel.can_remove()["allowed"], "TEST 1: roda apertada não pode ser removida")
	t.check(wheel.can_remove()["reason"].contains("Afrouxe"), "HUD explica os parafusos que bloqueiam a roda")
	for bolt in wheel_socket.fasteners:
		bolt.set_tightness(0)
	t.check(wheel.can_remove()["allowed"], "TEST 2: roda é removível após soltar todos os parafusos")
	t.check(wheel.begin_hold(t.player), "Remoção da roda usa a interação genérica")
	wheel.end_hold()
	t.check(not wheel.installed and not wheel_socket.occupied, "Roda deixa seu socket")
	var free_context: Dictionary = wheel.interaction_context(null)
	t.check(free_context["detail"] == "Livre" and free_context["debug"].contains("AutomotivePart"),
		"Inspeção mostra estado e classe sem poluir o HUD normal")

	var disc_block := disc.can_remove()
	t.check(not disc_block["allowed"], "TEST 3: disco permanece bloqueado pela pinça")
	t.check(disc_block["reason"].begins_with("Remova "), "Dependência produz motivo legível para o disco")
	for bolt in caliper_socket.fasteners:
		bolt.set_tightness(0)
	t.check(caliper.can_remove()["allowed"], "TEST 4: pinça é removível com seus dois parafusos soltos")
	t.check(caliper.begin_hold(t.player), "Pinça sai pelo mesmo fluxo de AutomotivePart")
	caliper.end_hold()
	t.check(disc.can_remove()["allowed"], "TEST 5: disco é removível depois da pinça")
	t.check(disc_socket.fasteners.all(func(bolt: Fastener) -> bool: return bolt.tightness == 0),
		"Parafusos configuráveis do disco estão soltos")

	var wheel_bolt: Fastener = wheel_socket.fasteners[0]
	wheel_socket.place_item(wheel, true)
	wheel_bolt.set_tightness(3)
	var wrong_tool: Tool = t.tool_by_size(17)
	wrong_tool.begin_hold(t.player)
	t.check(not wheel_bolt.interaction_scroll(wrong_tool, -1) and wheel_bolt.tightness == 3,
		"TEST 6: ferramenta errada não altera o parafuso")
	wrong_tool.end_hold()
	var correct_tool: Tool = t.tool_by_size(19)
	correct_tool.begin_hold(t.player)
	t.check(wheel_bolt.interaction_scroll(correct_tool, -1) and wheel_bolt.tightness == 2,
		"TEST 7: ferramenta correta altera exatamente um nível por scroll")
	correct_tool.end_hold()

	t.check(not battery.can_remove()["allowed"], "TEST 8: suporte apertado bloqueia a bateria")
	for bolt in battery_socket.fasteners:
		bolt.set_tightness(0)
	t.check(battery.can_remove()["allowed"], "TEST 9: bateria é removível após soltar o suporte")

	t.check(wheel.is_partially_secure(), "MechanicalState reconhece peça parcialmente presa")
	t.check(battery.is_loose(), "MechanicalState reconhece peça instalada e solta")
	t.check(t.mechanical_state.get_loose_parts().has(battery), "Estado central consulta peças soltas")
	t.check(t.mechanical_state.get_partially_secure_parts().has(wheel), "Estado central consulta peças parciais")
	var readiness: float = t.mechanical_state.get_vehicle_readiness()
	t.check(readiness >= 0.0 and readiness <= 1.0, "Vehicle readiness permanece entre 0 e 1")
	t.check(not disc_socket.is_compatible(wheel), "Socket rejeita peça de tipo incompatível")
