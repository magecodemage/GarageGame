class_name InteractionAudio
extends AudioStreamPlayer3D
## Slots vazios são válidos. Nenhum asset externo é necessário.

@export var pickup_sound: AudioStream
@export var drop_sound: AudioStream
@export var snap_sound: AudioStream
@export var tighten_sound: AudioStream
@export var loosen_sound: AudioStream
@export var impact_sound: AudioStream

var _last_impact_ms: int = -1000


func cue(action: StringName) -> void:
	var clip: AudioStream
	match action:
		&"pickup": clip = pickup_sound
		&"drop": clip = drop_sound
		&"snap": clip = snap_sound
		&"tighten": clip = tighten_sound
		&"loosen": clip = loosen_sound
		&"impact":
			if Time.get_ticks_msec() - _last_impact_ms < 250:
				return
			_last_impact_ms = Time.get_ticks_msec()
			clip = impact_sound
	if clip:
		stream = clip
		play()
