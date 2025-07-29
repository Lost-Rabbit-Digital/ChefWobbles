# NetworkManager.gd - Modern Godot 4.4+ Multiplayer
# Autoload singleton for robust multiplayer management
extends Node

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_established()
signal connection_failed()
signal all_players_ready()

const PORT = 7777
const MAX_PLAYERS = 4
const DEFAULT_SERVER_IP = "127.0.0.1"

# Player data storage
var players: Dictionary = {}
var local_player_info: Dictionary = {
	"name": "Chef Wobbles",
	"color": Color.WHITE,
	"ready": false
}

# Game state synchronization
var game_started: bool = false
var players_ready_count: int = 0

func _ready() -> void:
	_setup_multiplayer_signals()

func _setup_multiplayer_signals() -> void:
	"""Connect to multiplayer API signals with proper error handling"""
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		return  # Already connected
		
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# === HOST/JOIN FUNCTIONS ===
func host_game() -> Error:
	"""Start hosting with improved error handling"""
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error != OK:
		print("Failed to host game: ", error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Server started on port ", PORT)
	
	# Add host as first player
	var host_id = 1
	players[host_id] = local_player_info.duplicate()
	player_connected.emit(host_id, local_player_info)
	
	return OK

func join_game(ip_address: String = DEFAULT_SERVER_IP) -> Error:
	"""Join with improved connection handling"""
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, PORT)
	
	if error != OK:
		print("Failed to create client: ", error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Attempting to connect to ", ip_address, ":", PORT)
	
	return OK

func disconnect_from_game() -> void:
	"""Clean disconnect from multiplayer session"""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	players.clear()
	game_started = false
	players_ready_count = 0
	print("Disconnected from multiplayer session")

# === PLAYER MANAGEMENT ===
func set_local_player_info(info: Dictionary) -> void:
	"""Update local player information"""
	local_player_info.merge(info, true)

func get_player_info(peer_id: int) -> Dictionary:
	"""Get player information by peer ID"""
	return players.get(peer_id, {})

func is_host() -> bool:
	"""Check if this peer is the host/server"""
	return multiplayer.is_server()

func get_local_peer_id() -> int:
	"""Get local peer ID"""
	return multiplayer.get_unique_id()

# === GAME SESSION MANAGEMENT ===
@rpc("call_local", "reliable")
func start_multiplayer_game(scene_path: String) -> void:
	"""Start the multiplayer game session (host only)"""
	if not multiplayer.is_server():
		print("WARNING: Only server can start game")
		return
	
	game_started = true
	players_ready_count = 0
	
	# Use call_deferred to ensure proper scene transition
	get_tree().call_deferred("change_scene_to_file", scene_path)

@rpc("any_peer", "reliable")
func player_ready_for_game() -> void:
	"""Called when a player finishes loading the game scene"""
	if not multiplayer.is_server():
		return
	
	players_ready_count += 1
	var sender_id = multiplayer.get_remote_sender_id()
	print("Player ", sender_id, " ready. Total: ", players_ready_count, "/", players.size())
	
	if players_ready_count >= players.size():
		_all_players_ready()

func _all_players_ready() -> void:
	"""Handle when all players have loaded the game"""
	players_ready_count = 0
	print("All players ready - initializing game!")
	
	# Small delay to ensure all clients are properly settled
	await get_tree().create_timer(0.1).timeout
	_initialize_game_state.rpc()

@rpc("call_local", "reliable")
func _initialize_game_state() -> void:
	"""Initialize synchronized game state"""
	var game_scene = get_tree().current_scene
	if game_scene and game_scene.has_method("initialize_multiplayer"):
		await get_tree().process_frame  # Ensure scene is fully loaded
		game_scene.initialize_multiplayer()
	
	all_players_ready.emit()

# === SIGNAL HANDLERS ===
func _on_peer_connected(peer_id: int) -> void:
	"""Handle new peer connection"""
	print("Peer connected: ", peer_id)
	
	# Only server registers players initially
	if multiplayer.is_server():
		# Don't automatically add - wait for player registration
		pass

func _on_peer_disconnected(peer_id: int) -> void:
	"""Handle peer disconnection"""
	print("Peer disconnected: ", peer_id)
	
	if players.has(peer_id):
		var player_info = players[peer_id]
		players.erase(peer_id)
		player_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	"""Handle successful connection to server"""
	print("Connected to server!")
	var peer_id = multiplayer.get_unique_id()
	
	# Register ourselves with the server
	_register_player.rpc_id(1, local_player_info)
	connection_established.emit()

func _on_connection_failed() -> void:
	"""Handle failed connection attempt"""
	print("Failed to connect to server")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	"""Handle server disconnection"""
	print("Server disconnected")
	multiplayer.multiplayer_peer = null
	players.clear()
	game_started = false
	players_ready_count = 0
	server_disconnected.emit()

# === PLAYER DATA SYNCHRONIZATION ===
@rpc("any_peer", "reliable")
func _register_player(player_info: Dictionary) -> void:
	"""Register a new player's information (server only)"""
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = player_info
	print("Registered player: ", sender_id, " - ", player_info)
	
	# Broadcast to all clients including sender
	_player_registered.rpc(sender_id, player_info)

@rpc("call_local", "reliable")
func _player_registered(peer_id: int, player_info: Dictionary) -> void:
	"""Notify all clients of new player registration"""
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

# === UTILITY FUNCTIONS ===
func get_all_players() -> Dictionary:
	"""Get all connected players"""
	return players.duplicate()

func get_player_count() -> int:
	"""Get number of connected players"""
	return players.size()

func is_multiplayer_active() -> bool:
	"""Check if multiplayer is currently active"""
	return multiplayer.multiplayer_peer != null
