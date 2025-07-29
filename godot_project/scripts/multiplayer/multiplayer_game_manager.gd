# Add this to your demo_scene.gd or create a new script for demo_scene
# This replaces your complex MultiplayerGameManager
extends Node3D

func _ready() -> void:
	_setup_multiplayer()

func _setup_multiplayer() -> void:
	"""Setup multiplayer or single player"""
	
	if not NetworkManager or not NetworkManager.is_multiplayer_active():
		_setup_single_player()
		return
	
	# Connect network events for cleanup
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Wait a frame for network setup, then spawn players
	await get_tree().process_frame
	NetworkManager.debug_players_dict("spawn_players_in_scene")
	NetworkManager.spawn_players_in_scene()

func _setup_single_player() -> void:
	"""Setup single player without multiplayer"""
	if not NetworkManager.player_scene:
		return
	
	var player = NetworkManager.player_scene.instantiate()
	player.name = "Player_Local"
	add_child(player)
	player.global_position = Vector3(0, 2, 0)
	print("Single player spawned")

func _on_player_disconnected(peer_id: int) -> void:
	"""Handle player disconnection cleanup"""
	print("Player ", peer_id, " disconnected from game")
