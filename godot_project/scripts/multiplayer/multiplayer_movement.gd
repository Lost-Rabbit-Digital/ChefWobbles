# SimpleMovement.gd - Fixed to show movement on all clients
extends "res://scripts/character_controller/movement.gd"

@onready var displayed_player_name: Label3D = $CameraPivot/PlayerName

func _enter_tree() -> void:
	# Set authority based on node name (peer ID)
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	print("Player ready: ", name, " Authority: ", get_multiplayer_authority())
	
	# Set player name for the authority owner
	if is_multiplayer_authority():
		displayed_player_name.text = str(get_multiplayer_authority())
	
	# IMPORTANT: Call parent setup for ALL players, not just authority
	# This ensures physics and animation systems work on all clients
	super._ready()

func _process(delta: float) -> void:
	# Process animation/visual updates for ALL players
	super._process(delta)

func _physics_process(delta: float) -> void:
	# Physics should run for ALL players to show movement
	# Only INPUT is restricted to authority
	super._physics_process(delta)

func _input(event: InputEvent) -> void:
	# Only process input if we have authority
	if is_multiplayer_authority():
		super._input(event)
