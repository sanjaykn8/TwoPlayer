class_name Sfx
extends RefCounted
## Fire-and-forget sound effects from existing project audio. Limits how many play at once so
## bursts (e.g. six coins at the same moment) never become excessively loud.
## Mixer buses and volume settings are Phase 9.

const COIN := preload("res://assets/sounds/coin.wav")
const POWER_UP := preload("res://assets/sounds/power_up.wav")
const TAP := preload("res://assets/sounds/tap.wav")
const HURT := preload("res://assets/sounds/hurt.wav")
const EXPLOSION := preload("res://assets/sounds/explosion.wav")
const MAX_VOICES := 4

static var _playing := 0


static func play(stream: AudioStream, context: Node, volume_db := -8.0, pitch := 1.0) -> void:
	if stream == null or context == null or not context.is_inside_tree() or _playing >= MAX_VOICES:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	var tree := context.get_tree()
	tree.root.add_child(player)
	_playing += 1
	player.play()
	# Free the player after the sound's length (works even where `finished` never fires,
	# e.g. the headless test audio driver).
	var length := stream.get_length() / maxf(pitch, 0.01) + 0.05
	tree.create_timer(length, false).timeout.connect(func() -> void:
		_playing = maxi(_playing - 1, 0)
		if is_instance_valid(player):
			player.queue_free())
