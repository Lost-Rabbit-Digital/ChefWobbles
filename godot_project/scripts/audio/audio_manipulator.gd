extends Node
class_name AudioManipulator

# === MODULATION SETTINGS ===
@export_group("Pitch Modulation")
@export var enable_pitch_variation: bool = true
@export var pitch_variance_range: float = 0.15  # ±15% pitch variation
@export var min_pitch: float = 0.7
@export var max_pitch: float = 1.3

@export_group("Volume Modulation") 
@export var enable_volume_variation: bool = true
@export var volume_variance_range: float = 3.0  # ±3dB variation
@export var min_volume_db: float = -10.0
@export var max_volume_db: float = 5.0

@export_group("Audio Effects")
@export var enable_random_start_position: bool = false  # For looping sounds
@export var max_start_offset: float = 0.1  # Max 100ms random start offset

# === AUDIO TYPE PRESETS ===
enum AudioType {
	FOOTSTEPS,
	GRAB_SOUNDS,
	RELEASE_SOUNDS,
	GENERIC
}

# Preset configurations for different audio types
var audio_presets = {
	AudioType.FOOTSTEPS: {
		"pitch_variance": 0.12,
		"volume_variance": 2.5,
		"min_pitch": 0.85,
		"max_pitch": 1.15
	},
	AudioType.GRAB_SOUNDS: {
		"pitch_variance": 0.08,
		"volume_variance": 1.5,
		"min_pitch": 0.9,
		"max_pitch": 1.1
	},
	AudioType.RELEASE_SOUNDS: {
		"pitch_variance": 0.1,
		"volume_variance": 2.0,
		"min_pitch": 0.88,
		"max_pitch": 1.12
	},
	AudioType.GENERIC: {
		"pitch_variance": 0.15,
		"volume_variance": 3.0,
		"min_pitch": 0.7,
		"max_pitch": 1.3
	}
}

# === CORE AUDIO FUNCTIONS ===

## Play audio with automatic modulation based on type
func play_audio(player: AudioStreamPlayer, audio_stream: AudioStream, audio_type: AudioType = AudioType.GENERIC) -> bool:
	if not player or not audio_stream:
		push_warning("AudioManipulator: Invalid player or audio stream provided")
		return false
	
	# Apply the audio stream
	player.stream = audio_stream
	
	# Apply modulations based on type
	apply_modulations(player, audio_type)
	
	# Play the audio
	player.play()
	return true

## Play audio with custom modulation parameters
func play_audio_custom(player: AudioStreamPlayer, audio_stream: AudioStream, 
					  custom_pitch_range: float = 0.15, custom_volume_range: float = 3.0) -> bool:
	if not player or not audio_stream:
		push_warning("AudioManipulator: Invalid player or audio stream provided")
		return false
	
	player.stream = audio_stream
	
	# Apply custom modulations
	apply_custom_modulations(player, custom_pitch_range, custom_volume_range)
	
	player.play()
	return true

## Play audio with precise control over all parameters
func play_audio_precise(player: AudioStreamPlayer, audio_stream: AudioStream,
					   pitch_multiplier: float = 1.0, volume_db: float = 0.0,
					   start_offset: float = 0.0) -> bool:
	if not player or not audio_stream:
		push_warning("AudioManipulator: Invalid player or audio stream provided")
		return false
	
	player.stream = audio_stream
	player.pitch_scale = clamp(pitch_multiplier, 0.1, 4.0)
	player.volume_db = clamp(volume_db, -80.0, 24.0)
	
	player.play(start_offset)
	return true

# === MODULATION FUNCTIONS ===

func apply_modulations(player: AudioStreamPlayer, audio_type: AudioType):
	var preset = audio_presets.get(audio_type, audio_presets[AudioType.GENERIC])
	
	# Apply pitch modulation
	if enable_pitch_variation:
		var pitch_range = preset.get("pitch_variance", pitch_variance_range)
		var min_p = preset.get("min_pitch", min_pitch)
		var max_p = preset.get("max_pitch", max_pitch)
		
		var random_pitch = randf_range(-pitch_range, pitch_range)
		var final_pitch = clamp(1.0 + random_pitch, min_p, max_p)
		player.pitch_scale = final_pitch
	
	# Apply volume modulation
	if enable_volume_variation:
		var volume_range = preset.get("volume_variance", volume_variance_range)
		var random_volume = randf_range(-volume_range, volume_range)
		var final_volume = clamp(player.volume_db + random_volume, min_volume_db, max_volume_db)
		player.volume_db = final_volume

func apply_custom_modulations(player: AudioStreamPlayer, pitch_range: float, volume_range: float):
	# Apply pitch modulation
	if enable_pitch_variation:
		var random_pitch = randf_range(-pitch_range, pitch_range)
		var final_pitch = clamp(1.0 + random_pitch, min_pitch, max_pitch)
		player.pitch_scale = final_pitch
	
	# Apply volume modulation
	if enable_volume_variation:
		var random_volume = randf_range(-volume_range, volume_range)
		var final_volume = clamp(player.volume_db + random_volume, min_volume_db, max_volume_db)
		player.volume_db = final_volume

# === UTILITY FUNCTIONS ===

## Generate random modulated values without playing audio
func get_random_pitch(audio_type: AudioType = AudioType.GENERIC) -> float:
	var preset = audio_presets.get(audio_type, audio_presets[AudioType.GENERIC])
	var pitch_range = preset.get("pitch_variance", pitch_variance_range)
	var min_p = preset.get("min_pitch", min_pitch)
	var max_p = preset.get("max_pitch", max_pitch)
	
	var random_pitch = randf_range(-pitch_range, pitch_range)
	return clamp(1.0 + random_pitch, min_p, max_p)

func get_random_volume_db(audio_type: AudioType = AudioType.GENERIC) -> float:
	var preset = audio_presets.get(audio_type, audio_presets[AudioType.GENERIC])
	var volume_range = preset.get("volume_variance", volume_variance_range)
	var random_volume = randf_range(-volume_range, volume_range)
	return clamp(random_volume, min_volume_db, max_volume_db)

## Reset player to default settings
func reset_player(player: AudioStreamPlayer):
	if player:
		player.pitch_scale = 1.0
		player.volume_db = 0.0

## Check if audio is currently playing
func is_playing(player: AudioStreamPlayer) -> bool:
	return player != null and player.playing

## Stop audio with optional fade out
func stop_audio(player: AudioStreamPlayer, fade_duration: float = 0.0):
	if not player:
		return
	
	if fade_duration > 0.0:
		# Create a simple fade out tween
		var tween = create_tween()
		var current_volume = player.volume_db
		tween.tween_property(player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(func(): 
			player.stop()
			player.volume_db = current_volume
		)
	else:
		player.stop()

# === ADVANCED FEATURES ===

## Play audio with randomized start position (good for ambient loops)
func play_audio_with_random_start(player: AudioStreamPlayer, audio_stream: AudioStream, 
								 audio_type: AudioType = AudioType.GENERIC) -> bool:
	if not player or not audio_stream:
		return false
	
	player.stream = audio_stream
	apply_modulations(player, audio_type)
	
	var start_offset = 0.0
	if enable_random_start_position and audio_stream.get_length() > max_start_offset:
		start_offset = randf() * min(max_start_offset, audio_stream.get_length() * 0.1)
	
	player.play(start_offset)
	return true

## Create a sequence of modulated audio plays with delays
func play_audio_sequence(player: AudioStreamPlayer, audio_streams: Array[AudioStream], 
						delays: Array[float], audio_type: AudioType = AudioType.GENERIC):
	if audio_streams.size() != delays.size():
		push_warning("AudioManipulator: Audio streams and delays arrays must be the same size")
		return
	
	for i in range(audio_streams.size()):
		await get_tree().create_timer(delays[i]).timeout
		if audio_streams[i]:
			play_audio(player, audio_streams[i], audio_type)

# === PRESET MANAGEMENT ===

## Update preset values at runtime
func update_preset(audio_type: AudioType, property: String, value: float):
	if audio_presets.has(audio_type):
		audio_presets[audio_type][property] = value

## Get current preset values
func get_preset(audio_type: AudioType) -> Dictionary:
	return audio_presets.get(audio_type, audio_presets[AudioType.GENERIC]).duplicate()
