extends Node

## Children Node Randomiser Script
##
## Randomises which AudioStreamPlayer child has autoplay enabled at start.
## Targets AudioStreamPlayer nodes on the Music bus only.
##
## USAGE:
##   1. Attach to parent node containing AudioStreamPlayer children
##   2. Ensure AudioStreamPlayer children use "Music" bus
##   3. Script automatically randomises on scene load
##
## EXAMPLE SCENE STRUCTURE:
##   MusicManager (Node) [This Script Attached]
##   -> Track01 (AudioStreamPlayer, Bus: Music)
##   -> Track02 (AudioStreamPlayer, Bus: Music)
##   -> Track03 (AudioStreamPlayer, Bus: Music)

@export_group("Randomisation Settings")
## Enable or disable the randomisation system entirely
@export var enable_randomisation: bool = true

@export_group("Debug Options")
## Print information about the randomisation process
@export var enable_debug_output: bool = true

func _enter_tree() -> void:
	randomise_autoplay_selection()

## Randomly selects one Music bus AudioStreamPlayer child to enable autoplay
##
## Disables autoplay on all Music bus AudioStreamPlayer children, then
## randomly selects one to re-enable autoplay for controlled playback.
func randomise_autoplay_selection():
	if not enable_randomisation:
		if enable_debug_output:
			print("Randomisation disabled - skipping")
		return

	# Filter for AudioStreamPlayer instances on Music bus
	var audio_players = []
	for child in get_children():
		if child is AudioStreamPlayer and child.bus == "Music":
			audio_players.append(child)
			child.autoplay = false
   
	# Randomise and enable autoplay on selected player
	if audio_players.size() > 0:
		audio_players.shuffle()
		audio_players[0].autoplay = true
		
	# Print the song which played
	print("Now playing: ", audio_players[0].name)
	
	if enable_debug_output:
		print("Autoplay enabled for: ", audio_players[0].name)
	elif enable_debug_output:
		print("Warning: No AudioStreamPlayer children found on Music bus")
