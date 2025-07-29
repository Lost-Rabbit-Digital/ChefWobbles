# NetworkManager.gd
# Autoload singleton for multiplayer management
extends Node

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_established()
signal connection_failed()

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
var players_loaded: int = 0

func _ready() -> void:
	_setup_multiplayer_signals()

func _setup_multiplayer_signals() -> void:
	"""Connect to multiplayer API signals"""
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# === HOST/JOIN FUNCTIONS ===
func host_game() -> Error:
	"""Start hosting a multiplayer game"""
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error != OK:
		print("Failed to host game: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Server started on port ", PORT)
	
	# Add host as first player
	players[1] = local_player_info.duplicate()
	player_connected.emit(1, local_player_info)
	
	return OK

func join_game(ip_address: String = DEFAULT_SERVER_IP) -> Error:
	"""Join an existing multiplayer game"""
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, PORT)
	
	if error != OK:
		print("Failed to join game: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Attempting to connect to ", ip_address, ":", PORT)
	
	return OK

func disconnect_from_game() -> void:
	"""Disconnect from current multiplayer session"""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	players.clear()
	game_started = false
	players_loaded = 0
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
	"""Start the multiplayer game session"""
	if not multiplayer.is_server():
		return  # Only server can start game
	
	game_started = true
	get_tree().change_scene_to_file(scene_path)

@rpc("any_peer", "call_local", "reliable")
func player_ready_for_game() -> void:
	"""Called when a player finishes loading the game scene"""
	if not multiplayer.is_server():
		return
	
	players_loaded += 1
	print("Player loaded. Total: ", players_loaded, "/", players.size())
	
	if players_loaded >= players.size():
		_all_players_loaded()

func _all_players_loaded() -> void:
	"""Handle when all players have loaded the game"""
	players_loaded = 0
	print("All players loaded - starting game!")
	_initialize_game_state.rpc()

@rpc("call_local", "reliable")
func _initialize_game_state() -> void:
	"""Initialize synchronized game state"""
	# Find the game scene and initialize multiplayer components
	var game_scene = get_tree().current_scene
	if game_scene.has_method("initialize_multiplayer"):
		game_scene.initialize_multiplayer()

# === SIGNAL HANDLERS ===
func _on_peer_connected(peer_id: int) -> void:
	"""Handle new peer connection"""
	print("Peer connected: ", peer_id)
	
	# Send our player info to the new peer
	if multiplayer.is_server():
		_register_player.rpc_id(peer_id, local_player_info)

func _on_peer_disconnected(peer_id: int) -> void:
	"""Handle peer disconnection"""
	print("Peer disconnected: ", peer_id)
	
	if players.has(peer_id):
		var _player_info = players[peer_id]
		players.erase(peer_id)
		player_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	"""Handle successful connection to server"""
	print("Connected to server!")
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = local_player_info.duplicate()
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
	server_disconnected.emit()

# === PLAYER DATA SYNCHRONIZATION ===
@rpc("any_peer", "reliable")
func _register_player(player_info: Dictionary) -> void:
	"""Register a new player's information"""
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = player_info
	print("Registered player: ", sender_id, " - ", player_info)
	player_connected.emit(sender_id, player_info)

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
