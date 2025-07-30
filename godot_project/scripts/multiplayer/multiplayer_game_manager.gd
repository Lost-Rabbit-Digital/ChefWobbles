extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene: PackedScene

func _ready() -> void:
	print("=== GAME MANAGER READY ===")
	# Connect signals for multiplayer events - ONLY ONCE
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)

func _add_player(id: int):
	print("_add_player called with ID: ", id, " (Is server: ", multiplayer.is_server(), ")")
	
	# Only the SERVER should spawn players to avoid duplicates
	if not multiplayer.is_server():
		print("Client tried to spawn player - ignoring")
		return
	
	# Don't add duplicate players
	if get_node_or_null(str(id)):
		print("Player ", id, " already exists, skipping")
		return
	
	# Create a player node from our scene
	var player = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player)
	print("Server spawned player: ", id)

func _remove_player(id: int):
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
		print("Removed player: ", id)

func _on_join_button_pressed() -> void:
	if peer.get_connection_status() != 0:
		print("Already connected - skipping join process")
		return
	
	print("Creating client...")
	peer.create_client("localhost", 3824)
	multiplayer.multiplayer_peer = peer
	print("Client connecting to server...")

func _on_host_button_pressed() -> void:
	if peer.get_connection_status() != 0:
		print("Already hosting - skipping host setup")
		return
	
	print("Creating server...")
	peer.create_server(3824)
	multiplayer.multiplayer_peer = peer
	
	print("Server created - spawning host player with ID 1")
	# Host spawns themselves immediately with ID 1
	_add_player(1)
