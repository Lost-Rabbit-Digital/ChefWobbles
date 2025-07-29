# NetworkManager.gd - Simplified replacement for your existing NetworkManager
# Autoload singleton for straightforward multiplayer
extends Node

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_established()
signal connection_failed()

const PORT = 7777
const MAX_PLAYERS = 4
const DEFAULT_SERVER_IP = "127.0.0.1"

@onready var player_scene = preload("res://scenes/character.tscn")

var peer = ENetMultiplayerPeer.new()
var players: Dictionary = {}
var local_player_info: Dictionary = {
	"name": "Chef Wobbles",
	"color": Color.WHITE
}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# === HOST/JOIN FUNCTIONS ===
func host_game() -> Error:
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
	var error = peer.create_client(ip_address, PORT)
	if error != OK:
		print("Failed to create client: ", error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Attempting to connect to ", ip_address, ":", PORT)
	
	return OK

func disconnect_from_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	players.clear()
	print("Disconnected from multiplayer session")

func start_multiplayer_game(scene_path: String) -> void:
	if not multiplayer.is_server():
		print("WARNING: Only server can start game")
		return
	
	get_tree().change_scene_to_file(scene_path)

# === PLAYER SPAWNING ===
func spawn_players_in_scene():
	"""Call this from your game scene's _ready()"""
	if not player_scene:
		print("No player scene assigned to NetworkManager!")
		return
	
	for peer_id in players:
		add_player_to_scene(peer_id)

func add_player_to_scene(peer_id: int):
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	
	var game_scene = get_tree().current_scene
	if game_scene:
		game_scene.add_child(player)
		player.global_position = Vector3(randf_range(-3, 3), 2, randf_range(-3, 3))
		print("Spawned player ", peer_id)

func remove_player_from_scene(peer_id: int):
	var player = get_tree().current_scene.get_node_or_null("Player_" + str(peer_id))
	if player:
		player.queue_free()
		print("Removed player ", peer_id)

# === PLAYER MANAGEMENT ===
func set_local_player_info(info: Dictionary) -> void:
	local_player_info.merge(info, true)

func get_player_info(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

func is_host() -> bool:
	return multiplayer.is_server()

func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()

func get_all_players() -> Dictionary:
	return players.duplicate()

func get_player_count() -> int:
	return players.size()

func is_multiplayer_active() -> bool:
	return multiplayer.multiplayer_peer != null

# === SIGNAL HANDLERS ===
func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)
	
	if multiplayer.is_server():
		# Server automatically adds new players when they register
		pass

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
	
	if players.has(peer_id):
		players.erase(peer_id)
		player_disconnected.emit(peer_id)
		remove_player_from_scene(peer_id)

func _on_connected_to_server() -> void:
	print("Connected to server!")
	
	# Register with server
	_register_player.rpc_id(1, local_player_info)
	connection_established.emit()

func _on_connection_failed() -> void:
	print("Failed to connect to server")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("Server disconnected")
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

# === PLAYER REGISTRATION ===
@rpc("any_peer", "reliable")
func _register_player(player_info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = player_info
	print("Registered player: ", sender_id, " - ", player_info)
	
	# Broadcast to all clients
	_player_registered.rpc(sender_id, player_info)
	
	# Add to scene if in game
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.scene_file_path.contains("demo_scene"):
		add_player_to_scene(sender_id)

@rpc("call_local", "reliable")
func _player_registered(peer_id: int, player_info: Dictionary) -> void:
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)
