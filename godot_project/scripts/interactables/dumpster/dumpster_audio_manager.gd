# Audio manager:
# - Stores the catch, shrink, destruction sound effects
# - Manages when to create and play the AudioStreamPlayer3Ds on the object
# - Manages which sound effect is playing at a time
# - Create multiple AudioStreamPlayer3Ds to create overlap in the sfx
# - Default
# Functions exposed to other scripts:
# - Play catch
# - Play shrink
# - Play destruction
#
# Variables hardcoded:
# - catch_sounds Array[AudioStream] = [whoosh.mp3]
# - shrink_sounds Array[AudioStream] [shrink_1.mp3, shrink_2.mp3]
# - destruction_sounds  Array[AudioStream] [plop_3.mp3, plop_4.mp3]
# - 

class_name DumpsterAudioManager
extends Node
## Manages all audio for the dumpster system
##
## Handles both disposal plop sounds and shrinking sounds that play on objects
## during the disposal process, with pitch variation and spatial audio.

# Audio Assets
@onready var destruction_audio: Array[AudioStream] = [preload("res://audio/sound_effects/plops/plop_3.mp3"), preload("res://audio/sound_effects/plops/plop_3.mp3")]
@onready var shrink_audio: Array[AudioStream] = [preload("res://audio/sound_effects/plops/plop_3.mp3"), preload("res://audio/sound_effects/plops/plop_3.mp3")]
@onready var whoosh_audio: Array[AudioStream] = [preload("res://audio/sound_effects/plops/plop_3.mp3")]

# Audio Settings
@export var max_distance: float = 20.0
@onready var sfx_audio_bus: String = "SFX"
# TODO: I want to use the SFX bus later on I'll use the audio manipulator to vary these sounds

## Internal components
@onready var disposal_audio_player: AudioStreamPlayer3D = $DisposalAudioPlayer
# TODO: I don't want an audio player for this, I want the script to dynamically
# create the audio players on the individual rigidbodies, it's fine to leave them
# on the rigidbodies since the disposal_handler will unload the entire rigidbody and
# its children

## Initialize the audio system
func setup() -> void:
	_setup_disposal_player()
	_validate_audio_assets()

## Configure the main disposal audio player
func _setup_disposal_player() -> void:
# TODO: Going to change this structure so that we dynmically create the AudioPlayer3Ds
# on the rigidbodies which are being interacted with
	if not disposal_audio_player:
		disposal_audio_player = AudioStreamPlayer3D.new()
		disposal_audio_player.name = "DisposalAudioPlayer"
		add_child(disposal_audio_player)
	
	disposal_audio_player.max_distance = max_distance # Keep this property
	disposal_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

## Check that audio assets are assigned
func _validate_audio_assets() -> void:
	if destruction_audio.is_empty():
		push_warning("DumpsterAudioManager: No disposal sounds assigned")
	
	if shrink_audio.is_empty():
		push_warning("DumpsterAudioManager: No shrinking sounds assigned")
	
	if whoosh_audio.is_empty():
		push_warning("DumpsterAudioManager: No whoosh sounds assigned")

## Plays a chosen audio effect on the given object
func play_audio_on_object(rigid_body: RigidBody3D, audio_effect: String) -> AudioStreamPlayer3D:
	if not is_instance_valid(rigid_body):
		push_error("Instance is not a valid RigidBody3D")
		return null
		
	
	if audio_effect == "destruction":
		if destruction_audio.is_empty():
			if not is_instance_valid(rigid_body):
				push_error("Instance is not a valid RigidBody3D")
				return null
			push_error("Destruction audio array is empty, no audio files to choose from")
			return null
		
		# Select random shrinking sound
		var random_sound = destruction_audio[randi() % destruction_audio.size()]
		
			# Create audio player for the object
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "DestructionAudioPlayer"
		audio_player.stream = random_sound
		audio_player.max_distance = max_distance
		audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		audio_player.bus = sfx_audio_bus
		
		disposal_audio_player.stream = random_sound
		disposal_audio_player.bus = sfx_audio_bus
		# Play the sound
		disposal_audio_player.play()
	elif audio_effect == "shrink":
		if shrink_audio.is_empty():
			if not is_instance_valid(rigid_body):
				push_error("Instance is not a valid RigidBody3D")
				return null
			push_error("Shrink audio array is empty, no audio files to choose from")
			return null
		
		# Select random shrinking sound
		var random_sound = shrink_audio[randi() % shrink_audio.size()]
		
		# Create audio player for the object
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "ShrinkingAudioPlayer"
		audio_player.stream = random_sound
		audio_player.max_distance = max_distance
		audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		audio_player.bus = sfx_audio_bus
		
		# Add to object and play
		rigid_body.add_child(audio_player)
		audio_player.play()
		
		return audio_player
	elif audio_effect == "whoosh":
		if whoosh_audio.is_empty():
			if not is_instance_valid(rigid_body):
				push_error("Instance is not a valid RigidBody3D")
				return null
			push_error("Whoosh audio array is empty, no audio files to choose from")
			return null
		
		# Select random whoosh sound
		var random_sound = whoosh_audio[randi() % whoosh_audio.size()]
		
		# Create audio player for the object
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "WhooshAudioPlayer"
		audio_player.stream = random_sound
		audio_player.max_distance = max_distance
		audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		audio_player.bus = sfx_audio_bus
		
		# Add to object and play
		rigid_body.add_child(audio_player)
		audio_player.play()
		
		return audio_player
	
	return null

# Utility functions for debugging
## Get number of disposal sounds available
func get_disposal_sound_count() -> int:
	return destruction_audio.size()

## Get number of shrinking sounds available
func get_shrinking_sound_count() -> int:
	return shrink_audio.size()

## Get number of whoosh sounds available
func get_whoosh_sound_count() -> int:
	return whoosh_audio.size()

### Debug functions

## Get current audio system status
func get_audio_status() -> Dictionary:
	return {
		"destruction_audio_count": get_disposal_sound_count(),
		"shrink_audio_count": get_shrinking_sound_count(),
		"whoosh_audio_count": get_whoosh_sound_count(),
		"disposal_player_ready": disposal_audio_player != null
	}
