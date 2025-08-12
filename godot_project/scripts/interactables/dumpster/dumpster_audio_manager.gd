class_name DumpsterAudioManager
extends Node
## Manages all audio for the dumpster system
##
## Handles both disposal plop sounds and shrinking sounds that play on objects
## during the disposal process, with pitch variation and spatial audio.

## Export settings
@export_group("Audio Assets")
@export var disposal_sounds: Array[AudioStream] = []
@export var shrinking_sounds: Array[AudioStream] = []
@export var whoosh_sounds: Array[AudioStream] = []

@export_group("Audio Settings")
@export var audio_volume_db: float = 0.0
@export var audio_pitch_scale: float = 1.0
@export var pitch_variation: float = 0.1
@export var max_distance: float = 20.0
@export var shrinking_max_distance: float = 15.0

## Internal components
@onready var disposal_audio_player: AudioStreamPlayer3D = $DisposalAudioPlayer

func setup() -> void:
	"""Initialize the audio system"""
	_setup_disposal_player()
	_validate_audio_assets()

func _setup_disposal_player() -> void:
	"""Configure the main disposal audio player"""
	if not disposal_audio_player:
		disposal_audio_player = AudioStreamPlayer3D.new()
		disposal_audio_player.name = "DisposalAudioPlayer"
		add_child(disposal_audio_player)
	
	disposal_audio_player.volume_db = audio_volume_db
	disposal_audio_player.pitch_scale = audio_pitch_scale
	disposal_audio_player.max_distance = max_distance
	disposal_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

func _validate_audio_assets() -> void:
	"""Check that audio assets are assigned"""
	if disposal_sounds.is_empty():
		push_warning("DumpsterAudioManager: No disposal sounds assigned")
	
	if shrinking_sounds.is_empty():
		push_warning("DumpsterAudioManager: No shrinking sounds assigned")
	
	if whoosh_sounds.is_empty():
		push_warning("DumpsterAudioManager: No whoosh sounds assigned")

func play_disposal_sound() -> void:
	"""Play a random disposal/plop sound from the dumpster"""
	if disposal_sounds.is_empty() or not disposal_audio_player:
		return
	
	# Select random disposal sound
	var random_sound = disposal_sounds[randi() % disposal_sounds.size()]
	disposal_audio_player.stream = random_sound
	
	# Apply pitch variation
	_apply_pitch_variation(disposal_audio_player)
	
	# Play the sound
	disposal_audio_player.play()

func play_shrinking_sound_on_object(rigid_body: RigidBody3D) -> AudioStreamPlayer3D:
	"""Create and play a shrinking sound on the specified object"""
	if shrinking_sounds.is_empty() or not is_instance_valid(rigid_body):
		return null
	
	# Select random shrinking sound
	var random_sound = shrinking_sounds[randi() % shrinking_sounds.size()]
	
	# Create audio player for the object
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "ShrinkingAudioPlayer"
	audio_player.stream = random_sound
	audio_player.volume_db = audio_volume_db
	audio_player.max_distance = shrinking_max_distance
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	# Apply pitch variation
	_apply_pitch_variation(audio_player)
	
	# Add to object and play
	rigid_body.add_child(audio_player)
	audio_player.play()
	
	return audio_player

func _apply_pitch_variation(audio_player: AudioStreamPlayer3D) -> void:
	"""Apply random pitch variation to an audio player"""
	if pitch_variation > 0.0:
		var pitch_offset = randf_range(-pitch_variation, pitch_variation)
		audio_player.pitch_scale = audio_pitch_scale + pitch_offset
	else:
		audio_player.pitch_scale = audio_pitch_scale

func play_whoosh_sound_on_object(rigid_body: RigidBody3D) -> AudioStreamPlayer3D:
	"""Create and play a whoosh sound on the specified object during suction"""
	if whoosh_sounds.is_empty() or not is_instance_valid(rigid_body):
		return null
	
	# Select random whoosh sound
	var random_sound = whoosh_sounds[randi() % whoosh_sounds.size()]
	
	# Create audio player for the object
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "WhooshAudioPlayer"
	audio_player.stream = random_sound
	audio_player.volume_db = audio_volume_db
	audio_player.max_distance = shrinking_max_distance
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	# Apply pitch variation
	_apply_pitch_variation(audio_player)
	
	# Add to object and play
	rigid_body.add_child(audio_player)
	audio_player.play()
	
	return audio_player
## Sound preview functions for editor/testing
func preview_disposal_sound() -> void:
	"""Play a random disposal sound for testing"""
	play_disposal_sound()

func preview_shrinking_sound() -> void:
	"""Play a random shrinking sound for testing"""
	if shrinking_sounds.is_empty():
		return
	
	var random_sound = shrinking_sounds[randi() % shrinking_sounds.size()]
	
	# Create temporary player for preview
	var temp_player = AudioStreamPlayer3D.new()
	temp_player.stream = random_sound
	temp_player.volume_db = audio_volume_db
	_apply_pitch_variation(temp_player)
	
	add_child(temp_player)
	temp_player.play()
	
	# Clean up after playing
	await temp_player.finished
	temp_player.queue_free()

func preview_whoosh_sound() -> void:
	"""Play a random whoosh sound for testing"""
	if whoosh_sounds.is_empty():
		return
	
	var random_sound = whoosh_sounds[randi() % whoosh_sounds.size()]
	
	# Create temporary player for preview
	var temp_player = AudioStreamPlayer3D.new()
	temp_player.stream = random_sound
	temp_player.volume_db = audio_volume_db
	_apply_pitch_variation(temp_player)
	
	add_child(temp_player)
	temp_player.play()
	
	# Clean up after playing
	await temp_player.finished
	temp_player.queue_free()
## Utility functions
func get_disposal_sound_count() -> int:
	"""Get number of disposal sounds available"""
	return disposal_sounds.size()

func get_shrinking_sound_count() -> int:
	"""Get number of shrinking sounds available"""
	return shrinking_sounds.size()

func get_whoosh_sound_count() -> int:
	"""Get number of whoosh sounds available"""
	return whoosh_sounds.size()

func set_global_volume(volume_db: float) -> void:
	"""Set volume for all audio players"""
	audio_volume_db = volume_db
	if disposal_audio_player:
		disposal_audio_player.volume_db = volume_db

func set_global_pitch(pitch: float) -> void:
	"""Set base pitch for all audio players"""
	audio_pitch_scale = pitch
	if disposal_audio_player:
		disposal_audio_player.pitch_scale = pitch

func mute_all() -> void:
	"""Mute all dumpster audio"""
	if disposal_audio_player:
		disposal_audio_player.volume_db = -80.0

func unmute_all() -> void:
	"""Restore normal volume"""
	if disposal_audio_player:
		disposal_audio_player.volume_db = audio_volume_db

## Debug functions
func get_audio_status() -> Dictionary:
	"""Get current audio system status"""
	return {
		"disposal_sounds_count": get_disposal_sound_count(),
		"shrinking_sounds_count": get_shrinking_sound_count(),
		"whoosh_sounds_count": get_whoosh_sound_count(),
		"volume_db": audio_volume_db,
		"pitch_scale": audio_pitch_scale,
		"pitch_variation": pitch_variation,
		"disposal_player_ready": disposal_audio_player != null
	}
