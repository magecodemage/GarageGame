extends SceneTree
## Four focused checks only. Fixtures position held parts beside their sockets;
## pickup, scroll, dependency checks and placement use the real gameplay APIs.
## Godot --path . --script res://systems/tests/golf_suspension_essential.gd -- --visual
## --case=1..4 repeats only an affected check; --review only refreshes screenshots.

var garage: Node3D
var car: Node3D
var player: FirstPersonPlayer
var carrier: PartCarrier
var save: SaveSystem
var builder: GolfSuspensionBuilder
var camera: Camera3D
var errors: Array[String] = []
var results: Dictionary = {}
var visual := false
var selected := 0
var parked := 0
var inaccessible_bolts: Array[String] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--visual": visual = true
		if arg.begins_with("--case="): selected = int(arg.trim_prefix("--case="))
	run.call_deferred()


func require(value: bool, detail: String) -> bool:
	if not value:
		errors.append(detail)
		push_error(detail)
	return value


func frames(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame


func part(id: String) -> AutomotivePart:
	return save.registry.nodes.get(StringName(id)) as AutomotivePart


func socket(id: String) -> PartSocket:
	return save.registry.nodes.get(StringName(id + "_socket")) as PartSocket


func turn_bolts(id: String, direction: int) -> void:
	for bolt: Fastener in socket(id).fasteners:
		if direction < 0 and not _bolt_visible_from_service_position(bolt):
			inaccessible_bolts.append(str(bolt.fastener_id))
		var wrench: Tool
		for candidate: Tool in (garage.get_node("Toolbox") as Toolbox).tools:
			if candidate.tool_size == bolt.required_tool_size: wrench = candidate
		if not require(wrench != null, "Missing wrench for " + str(bolt.fastener_id)): return
		var slot: Node3D = wrench.placement_socket
		if not require(carrier.pick_up(wrench), "Cannot pick wrench"): return
		var target := bolt.max_tightness if direction > 0 else 0
		while bolt.tightness != target:
			if not require(bolt.interaction_scroll(wrench, direction), "Scroll blocked: " + str(bolt.fastener_id)): break
		carrier.release(false)
		if slot: slot.place_item(wrench, true)


func _bolt_visible_from_service_position(bolt: Fastener) -> bool:
	var target := bolt.global_position
	var blockers: Dictionary = {}
	var on_car: bool = target.z < 1.5
	var center: Vector3 = car.global_position if on_car else target
	for height: float in [0.87, 1.62]:
		for lateral: float in [1.25, 1.6, 1.9, -1.25]:
			for step: int in range(-7, 14):
				var longitudinal := float(step) * 0.1
				var origin := Vector3(center.x + lateral, height, target.z + longitudinal)
				var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | 2 | 32 | 64)
				query.collide_with_areas = true
				var hit := garage.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.get("collider") == bolt: return true
				if hit.get("collider") != null:
					var label: String = str(hit["collider"].name)
					blockers[label] = int(blockers.get(label, 0)) + 1
	if "--inspect-caliper" in OS.get_cmdline_user_args(): print(str(bolt.fastener_id), " blockers ", blockers)
	return false


func remove_part(id: String) -> bool:
	turn_bolts(id, -1)
	var item := part(id)
	var evaluation := item.can_remove()
	if not require(evaluation["allowed"], "Remove " + id + ": " + evaluation["reason"]): return false
	if not require(carrier.pick_up(item), "Pickup failed: " + id): return false
	# Bench fixture: no physics disabled, no direct socket.remove_item bypass.
	item.global_transform = Transform3D(Basis.IDENTITY, Vector3(-1.7 + (parked % 4) * 0.7, 1.1, 2.3 + (parked / 4) * 0.7))
	item.hold_target = item.global_transform
	carrier.release(false)
	parked += 1
	await frames(1)
	return require(not item.installed and not item.freeze and not item.is_held, "Free physics: " + id)


func install_part(id: String) -> bool:
	var item := part(id)
	if not require(carrier.pick_up(item), "Pickup loose " + id): return false
	item.global_transform = socket(id).installation_point.global_transform
	item.global_position += Vector3(0.015, 0.01, 0)
	carrier.refresh_candidate()
	var reason: String = carrier.candidate_failure_reason
	carrier.release()
	if not require(item.installed, "Reinstall " + id + ": " + reason): return false
	if item.required_fasteners > 0:
		require(item.state == AutomotivePart.State.PLACED, "Auto-fastened " + id)
	require(item.transform.is_equal_approx(Transform3D.IDENTITY), "Socket pose " + id)
	turn_bolts(id, 1)
	return require(item.is_secure(), "Fastening " + id)


func case_front_left() -> void:
	car.hood.set_open(true, true)
	var prefix := "front_left_"
	for suffix: String in ["wheel", "brake_caliper", "brake_disc", "cv_axle", "hub", "tie_rod_end", "stabilizer_link", "ball_joint"]:
		if not await remove_part(prefix + suffix): return
	turn_bolts(prefix + "knuckle", -1)
	for suffix: String in ["strut", "spring", "knuckle", "lower_control_arm"]:
		if not await remove_part(prefix + suffix): return
	await frames(70)
	for record: Dictionary in builder.records:
		if record["corner"] == "fl":
			var item := part(record["id"])
			require(item.global_position.is_finite() and item.global_position.y > -0.1 and item.linear_velocity.length() < 6.0,
				"Unstable loose part " + str(record["id"]))
	for suffix: String in ["lower_control_arm", "ball_joint", "spring", "strut", "knuckle", "hub", "cv_axle", "brake_disc", "brake_caliper", "tie_rod_end", "stabilizer_link", "wheel"]:
		if not install_part(prefix + suffix): return
	car.hood.set_open(false, true)
	if not inaccessible_bolts.is_empty():
		print("SERVICE RAY REVIEW: ", inaccessible_bolts)


func case_other_corners() -> void:
	for corner: String in ["fr", "rl", "rr"]:
		var count := 0
		for record: Dictionary in builder.records:
			if record["corner"] != corner: continue
			count += 1
			var item := part(record["id"])
			var mount := socket(record["id"])
			require(item is GolfSuspensionPart and item.installed and item.is_secure(), "Nonfunctional " + str(record["id"]))
			require(mount.installed_part == item and item.get_node("Visual").get_child_count() > 0, "Visual/socket " + str(record["id"]))
			require(item.transform.is_equal_approx(Transform3D.IDENTITY), "Misaligned " + str(record["id"]))
			require(not mount.is_compatible(part("front_left_hub")), "Wrong-side socket " + str(record["id"]))
		require(count == 11, "Expected 11 service parts at " + corner)
	require(builder.parts.size() == 46, "Expected 46 manufactured parts")


func case_save_partial() -> void:
	for suffix: String in ["wheel", "brake_caliper", "brake_disc"]:
		if not await remove_part("front_left_" + suffix): return
	var panel: GolfBodyPanel = car.body_panels["door_fl"]
	panel.set_open(true, true)
	var pose := part("front_left_brake_caliper").global_transform
	require(save.save_game(), "Save partially dismantled suspension")
	require(save.reset_test_scene(), "Reset before load")
	require(save.load_game(), "Load partially dismantled suspension")
	for suffix: String in ["wheel", "brake_caliper", "brake_disc"]:
		require(not part("front_left_" + suffix).installed, "Removed state not restored: " + suffix)
		for bolt: Fastener in socket("front_left_" + suffix).fasteners:
			require(bolt.tightness == 0, "Loose bolt not restored")
	require(part("front_left_brake_caliper").global_transform.is_equal_approx(pose), "Loose part pose roundtrip")
	require(panel.is_open, "Panel open state roundtrip")
	require(part("front_left_spring").installed and part("front_left_strut").is_ancestor_of(part("front_left_spring")), "Nested spring save")
	require(save.reset_test_scene(), "Restore initial layout after save check")


func case_panels() -> void:
	var panels: Array = car.body_panels.values()
	panels.append(car.hood)
	var closed: Dictionary = {}
	for panel: VehicleRuntimeSystem in panels:
		closed[panel] = panel.pivot.transform
		var target: Node = panel.pivot.find_child("*_interaction", true, false)
		if panel is GolfHood: target = panel.pivot.find_child("HoodInteraction", true, false)
		if not require(target != null, "Missing panel interaction " + str(panel.system_id)): continue
		target.interaction_primary()
	await create_timer(0.28).timeout
	for panel: VehicleRuntimeSystem in panels:
		require(panel.is_open and not panel.pivot.transform.is_equal_approx(closed[panel]), "Hinge not moving " + str(panel.system_id))
		require(panel.pivot.position.is_equal_approx(closed[panel].origin), "Hinge origin moved")
	await create_timer(0.5).timeout
	await shot("panels_open_front", Vector3(3.3, 2.35, 3.5), Vector3(0, 0.85, 0.1))
	await shot("panels_open_rear", Vector3(3.2, 2.1, -3.6), Vector3(0, 0.85, -0.5))
	for panel: VehicleRuntimeSystem in panels: panel.set_open(false)
	await create_timer(0.8).timeout
	for panel: VehicleRuntimeSystem in panels:
		require(panel.pivot.transform.is_equal_approx(closed[panel]), "Closed pose mismatch " + str(panel.system_id))
	await shot("panels_closed", Vector3(3.2, 1.65, 3.8), Vector3(0, 0.70, 0))


func shot(label: String, position: Vector3, target: Vector3) -> void:
	if not visual: return
	camera.global_position = car.to_global(position)
	camera.look_at(car.to_global(target))
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://blender/previews_suspension/" + label + ".png")


func review() -> void:
	# Screenshot setup only, not repeated gameplay assertions. Remove actual wheels
	# so their own socket fasteners deactivate, rather than hiding overlapping meshes.
	var original := save.capture_snapshot()
	for prefix: String in ["front_left", "front_right", "rear_left", "rear_right"]:
		for bolt: Fastener in socket(prefix + "_wheel").fasteners: bolt.set_tightness(0)
		part(prefix + "_wheel").restore_free(Transform3D(Basis.IDENTITY, Vector3(-4, 0.7, 3.0 + parked * 0.3)))
		parked += 1
	await shot("front_suspension", Vector3(2.0, 0.65, 1.7), Vector3(0.57, 0.48, 1.19))
	await shot("rear_suspension", Vector3(2.0, 0.57, -1.75), Vector3(0.55, 0.38, -1.31))
	var body: Node3D = car.get_node("CarVisual")
	body.hide()
	await shot("suspension_layout_body_hidden", Vector3(2.9, 1.75, 3.3), Vector3(0, 0.43, 0))
	body.show()
	save.restore_snapshot(original)
	await shot("all_installed", Vector3(3.2, 1.65, 3.8), Vector3(0, 0.70, 0))


func run() -> void:
	garage = (load("res://world/garage_golf_test.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	current_scene = garage
	car = garage.get_node("CarPrototype")
	player = garage.get_node("Player")
	carrier = player.interaction.carrier
	save = garage.get_node("SaveSystem")
	save.save_path = "user://suspension_essential_validation.json"
	await frames(8)
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(garage.get_node("Toolbox") as Toolbox).set_open(true)
	builder = car.suspension_builder
	if "--inspect-caliper" in OS.get_cmdline_user_args():
		await remove_part("front_left_wheel")
		for bolt: Fastener in socket("front_left_brake_caliper").fasteners:
			print("Reachable: ", _bolt_visible_from_service_position(bolt))
		quit()
		return
	if not require(save.validate_scene(), "Scene registry invalid"):
		quit(1)
		return
	if visual:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://blender/previews_suspension"))
		root.size = Vector2i(1280, 800)
		player.get_node("HUD").hide()
		camera = Camera3D.new()
		camera.fov = 48.0
		garage.add_child(camera)
		camera.make_current()
		var light := OmniLight3D.new()
		light.light_energy = 1.4
		light.omni_range = 5.0
		light.position = Vector3(2.5, 0.85, 0)
		car.add_child(light)
	if not "--review" in OS.get_cmdline_user_args():
		var cases: Array[Callable] = [case_front_left, case_other_corners, case_save_partial, case_panels]
		for i: int in cases.size():
			if selected != 0 and selected != i + 1: continue
			var before := errors.size()
			await cases[i].call()
			results[str(i + 1)] = "PASS" if errors.size() == before else "FAIL"
			print("ESSENTIAL CASE ", i + 1, ": ", results[str(i + 1)])
			if errors.size() > before: break
	if visual: await review()
	if not results.is_empty():
		var report := FileAccess.open("res://.godot/suspension_essential_case_%d.json" % selected, FileAccess.WRITE)
		report.store_string(JSON.stringify({"cases": results, "errors": errors,
			"service_ray_review": inaccessible_bolts,
			"limitations": ["Source has two side doors, not four; door_rl/door_rr absent", "Fixture-driven API checks, not manual carrying/access ergonomics"]}, "\t"))
		print("SUSPENSION ESSENTIAL: ", JSON.stringify(results), " errors=", errors.size())
	else:
		print("SUSPENSION REVIEW: screenshots refreshed; no functional tests rerun")
	quit(0 if errors.is_empty() else 1)
