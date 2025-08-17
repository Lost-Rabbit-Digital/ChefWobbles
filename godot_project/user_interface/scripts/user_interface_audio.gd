extends Node

# UI Audio Helper - Singleton for playing UI sound effects
# Add this to AutoLoad in Project Settings as "user_interface_audio"

# Hardcoded audio file paths - modify these to match your audio files
const AUDIO_CLIPS = {
	"click": "res://audio/sound_effects/clicks/click_1.mp3",
	"hover": "res://audio/sound_effects/clicks/click_2.mp3", 
	"button_pressed": "res://audio/sound_effects/clicks/click_3.mp3",
	"button_released": "res://audio/sound_effects/clicks/click_4.mp3",
	"error": "res://audio/sound_effects/clicks/click_5.mp3",
	"success": "res://audio/sound_effects/clicks/click_6.mp3",
	"menu_open": "res://audio/sound_effects/clicks/click_7.mp3",
	"menu_close": "res://audio/sound_effects/clicks/click_8.mp3",
	"tab_switch": "res://audio/sound_effects/clicks/click_9.mp3",
	"notification": "res://audio/sound_effects/clicks/click_10.mp3"
}

# Audio settings
@export var max_concurrent_sounds: int = 8

# Internal audio player pool
var audio_players: Array[AudioStreamPlayer] = []
var current_player_index: int = 0

func _ready():
	# Create a pool of AudioStreamPlayer nodes for concurrent playback
	for i in range(max_concurrent_sounds):
		var player = AudioStreamPlayer.new()
		player.bus = "User Interface"
		add_child(player)
		audio_players.append(player)
	
	print("User Interface Audio Helper initialized with %d audio players" % max_concurrent_sounds)

# Main function to play UI sounds
func play_sound(sound_name: String) -> bool:
	if not AUDIO_CLIPS.has(sound_name):
		push_warning("User Interface Audio: Sound '%s' not found in AUDIO_CLIPS" % sound_name)
		return false
	
	var audio_path = AUDIO_CLIPS[sound_name]
	var audio_resource = load(audio_path) as AudioStream
	
	if not audio_resource:
		push_error("User Interface Audio: Failed to load audio file: %s" % audio_path)
		return false
	
	# Get next available audio player (round-robin)
	var player = audio_players[current_player_index]
	current_player_index = (current_player_index + 1) % max_concurrent_sounds
	
	# Configure and play the sound with random pitch variation
	player.stream = audio_resource
	player.pitch_scale = randf_range(0.7, 1.3)
	player.play()
	
	return true

# Convenience functions for common UI sounds
func click() -> bool:
	return play_sound("click")

func hover() -> bool:
	return play_sound("hover")

func button_pressed() -> bool:
	return play_sound("button_pressed")

func button_released() -> bool:
	return play_sound("button_released")

func error() -> bool:
	return play_sound("error")

func success() -> bool:
	return play_sound("success")

func menu_open() -> bool:
	return play_sound("menu_open")

func menu_close() -> bool:
	return play_sound("menu_close")

func tab_switch() -> bool:
	return play_sound("tab_switch")

func ui_notification() -> bool:
	return play_sound("notification")

# Utility functions
func stop_all_sounds():
	for player in audio_players:
		if player.playing:
			player.stop()

func check_if_playing(sound_name: String = "") -> bool:
	if sound_name.is_empty():
		# Check if any sound is playing
		for player in audio_players:
			if player.playing:
				return true
		return false
	else:
		# Check if specific sound is playing (basic implementation)
		var audio_path = AUDIO_CLIPS.get(sound_name, "")
		if audio_path.is_empty():
			return false
		
		var target_resource = load(audio_path) as AudioStream
		for player in audio_players:
			if player.playing and player.stream == target_resource:
				return true
		return false

# Debug function to list all available sounds
func list_sounds() -> Array:
	return AUDIO_CLIPS.keys()
