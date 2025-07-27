extends Node
class_name AudioManipulator

# === MODULATION SETTINGS ===
@export_group("Pitch Modulation")
@export var enable_pitch_variation: bool = true
@export var pitch_variance_range: float = 0.35  # ±35% pitch variation
@export var min_pitch: float = 0.6
@export var max_pitch: float = 1.4

@export_group("Volume Modulation") 
@export var enable_volume_variation: bool = true
@export var volume_variance_range: float = 1.0  # ±1dB variation
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

# Static preset configurations for different audio types
static var audio_presets = {
	AudioType.FOOTSTEPS: {
		"pitch_variance": 0.35,
		"volume_db": 1.0,
		"min_pitch": 0.85,
		"max_pitch": 1.15
	},
	AudioType.GRAB_SOUNDS: {
		"pitch_variance": 0.35,
		"volume_db": 1.0,
		"min_pitch": 0.85,
		"max_pitch": 1.15
	},
	AudioType.RELEASE_SOUNDS: {
		"pitch_variance": 0.35,
		"volume_db": 1.0,
		"min_pitch": 0.85,
		"max_pitch": 1.15
	},
	AudioType.GENERIC: {
		"pitch_variance": 0.35,
		"volume_db": 1.0,
		"min_pitch": 0.85,
		"max_pitch": 1.15
	}
}

# === CORE AUDIO FUNCTIONS ===

## Static function to play audio with automatic modulation - supports single streams or arrays
static func play_audio_static(player: AudioStreamPlayer3D, audio_source, audio_type: AudioType = AudioType.GENERIC) -> bool:
	if not player:
		push_warning("AudioManipulator: Invalid player provided")
		return false
	
	# Get the actual audio stream to play
	var selected_stream = _select_audio_stream_static(audio_source)
	if not selected_stream:
		push_warning("AudioManipulator: No valid audio stream found")
		return false
	
	# Apply the audio stream
	player.stream = selected_stream
	
	# Apply modulations based on type
	_apply_modulations_static(player, audio_type)
	
	# Play the audio
	player.play()
	return true

# === STATIC MODULATION FUNCTIONS ===

static func _apply_modulations_static(player: AudioStreamPlayer3D, audio_type: AudioType):
	var preset = audio_presets.get(audio_type, audio_presets[AudioType.GENERIC])
	
	# Apply pitch modulation
	var pitch_range = preset.get("pitch_variance", 0.15)
	var min_p = preset.get("min_pitch", 0.7)
	var max_p = preset.get("max_pitch", 1.3)
	
	var random_pitch = randf_range(-pitch_range, pitch_range)
	var final_pitch = clamp(1.0 + random_pitch, min_p, max_p)
	player.pitch_scale = final_pitch
	
	# Apply hardcoded volume for audio type
	var volume_db = preset.get("volume_db", 0.0)
	player.volume_db = volume_db

## Static helper to select audio stream
static func _select_audio_stream_static(audio_source):
	# Handle null input
	if not audio_source:
		return null
	
	# If it's a single AudioStream, return it directly
	if audio_source is AudioStream:
		return audio_source
	
	# If it's an array, select randomly from valid streams
	if audio_source is Array:
		if audio_source.is_empty():
			return null
		
		# Filter out null entries
		var valid_streams = audio_source.filter(func(stream): return stream is AudioStream)
		
		if valid_streams.is_empty():
			return null
		
		# Return random selection
		return valid_streams[randi() % valid_streams.size()]
	
	# Unknown type
	push_warning("AudioManipulator: audio_source must be AudioStream or Array of AudioStream")
	return null

# === INSTANCE METHODS (KEEPING ORIGINAL FOR COMPATIBILITY) ===

## Play audio with automatic modulation based on type - supports single streams or arrays (instance method)
func play_audio(player: AudioStreamPlayer3D, audio_source, audio_type: AudioType = AudioType.GENERIC) -> bool:
	if not player:
		push_warning("AudioManipulator: Invalid player provided")
		return false
	
	# Get the actual audio stream to play
	var selected_stream = _select_audio_stream(audio_source)
	if not selected_stream:
		push_warning("AudioManipulator: No valid audio stream found")
		return false
	
	# Apply the audio stream
	player.stream = selected_stream
	
	# Apply modulations based on type
	apply_modulations(player, audio_type)
	
	# Play the audio
	player.play()
	return true

func apply_modulations(player: AudioStreamPlayer3D, audio_type: AudioType):
	var preset = audio_presets.get(audio_type, audio_presets[AudioType.GENERIC])
	
	# Apply pitch modulation
	if enable_pitch_variation:
		var pitch_range = preset.get("pitch_variance", pitch_variance_range)
		var min_p = preset.get("min_pitch", min_pitch)
		var max_p = preset.get("max_pitch", max_pitch)
		
		var random_pitch = randf_range(-pitch_range, pitch_range)
		var final_pitch = clamp(1.0 + random_pitch, min_p, max_p)
		player.pitch_scale = final_pitch
	
	# Apply hardcoded volume for audio type
	var volume_db = preset.get("volume_db", 0.0)
	player.volume_db = volume_db

## Select a random audio stream from either a single stream or array of streams
func _select_audio_stream(audio_source):
	# Handle null input
	if not audio_source:
		return null
	
	# If it's a single AudioStream, return it directly
	if audio_source is AudioStream:
		return audio_source
	
	# If it's an array, select randomly from valid streams
	if audio_source is Array:
		if audio_source.is_empty():
			return null
		
		# Filter out null entries
		var valid_streams = audio_source.filter(func(stream): return stream is AudioStream)
		
		if valid_streams.is_empty():
			return null
		
		# Return random selection
		return valid_streams[randi() % valid_streams.size()]
	
	# Unknown type
	push_warning("AudioManipulator: audio_source must be AudioStream or Array of AudioStream")
	return null

# === REMAINING METHODS (KEEPING FOR COMPATIBILITY) ===

## Play audio with custom modulation parameters - supports single streams or arrays
func play_audio_custom(player: AudioStreamPlayer3D, audio_source, 
					  custom_pitch_range: float = 0.15, custom_volume_range: float = 3.0) -> bool:
	if not player:
		push_warning("AudioManipulator: Invalid player provided")
		return false
	
	var selected_stream = _select_audio_stream(audio_source)
	if not selected_stream:
		push_warning("AudioManipulator: No valid audio stream found")
		return false
	
	player.stream = selected_stream
	
	# Apply custom modulations
	apply_custom_modulations(player, custom_pitch_range, custom_volume_range)
	
	player.play()
	return true

func apply_custom_modulations(player: AudioStreamPlayer3D, pitch_range: float, volume_range: float):
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

## Reset player to default settings
func reset_player(player: AudioStreamPlayer3D):
	if player:
		player.pitch_scale = 1.0
		player.volume_db = 0.0

## Check if audio is currently playing
func is_playing(player: AudioStreamPlayer3D) -> bool:
	return player != null and player.playing
