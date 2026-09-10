class_name EngineAudio
extends Node
## Slots vazios: adicionar sons depois não exige alterar o EngineController.

@export var starter_player: AudioStreamPlayer3D
@export var engine_player: AudioStreamPlayer3D
@export var one_shot_player: AudioStreamPlayer3D
@export var starter_sound: AudioStream
@export var engine_idle_sound: AudioStream
@export var engine_running_sound: AudioStream
@export var engine_shutdown_sound: AudioStream
@export var failed_starter_sound: AudioStream


func set_starter_active(active: bool) -> void:
	_set_loop(starter_player, starter_sound, active)


func set_engine_active(active: bool, high_rpm: bool = false) -> void:
	_set_loop(engine_player, engine_running_sound if high_rpm else engine_idle_sound, active)


func play_shutdown() -> void:
	_play_once(engine_shutdown_sound)


func play_failed_start() -> void:
	_play_once(failed_starter_sound)


func _set_loop(player: AudioStreamPlayer3D, stream: AudioStream, active: bool) -> void:
	if not player:
		return
	if not active:
		player.stop()
	elif stream and (not player.playing or player.stream != stream):
		player.stream = stream
		player.play()


func _play_once(stream: AudioStream) -> void:
	if one_shot_player and stream:
		one_shot_player.stream = stream
		one_shot_player.play()
