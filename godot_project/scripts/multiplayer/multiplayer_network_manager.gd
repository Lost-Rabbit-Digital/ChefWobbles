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

# Map large peer IDs to simple sequential IDs
var peer_id_map: Dictionary = {}  # large_id -> simple_id
var next_simple_id: int = 1

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# Add this to NetworkManager.gd temporarily
func debug_players_dict(location: String):
	print("=== PLAYERS DICT DEBUG: ", location, " ===")
	print("Local peer: ", multiplayer.get_unique_id())
	print("Is server: ", multiplayer.is_server())
	print("Players dict: ", players)
	print("peer_id_map: ", peer_id_map)
	print("=====================================")

# === HOST/JOIN FUNCTIONS ===
func host_game() -> Error:
	debug_players_dict("host_game_function")
	var error = peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		print("Failed to host game: ", error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Server started on port ", PORT)
	
	# Add host as first player with simple ID 1
	var host_id = 1
	peer_id_map[host_id] = host_id  # Host keeps ID 1
	next_simple_id = 2  # Start clients from ID 2
	players[host_id] = local_player_info.duplicate()
	player_connected.emit(host_id, local_player_info)
	
	return OK

func join_game(ip_address: String = DEFAULT_SERVER_IP) -> Error:
	debug_players_dict("host_game_function")
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
	peer_id_map.clear()
	next_simple_id = 2  # Reset to 2 (host is always 1)
	print("Disconnected from multiplayer session")

func start_multiplayer_game(scene_path: String) -> void:
	if not multiplayer.is_server():
		print("WARNING: Only server can start game")
		return
	
	# Tell all clients to change scene
	_change_scene_for_all.rpc(scene_path)
	
	# Change scene on server
	get_tree().change_scene_to_file(scene_path)

@rpc("call_local", "reliable")
func _change_scene_for_all(scene_path: String) -> void:
	"""Change scene on all clients"""
	print("Changing scene to: ", scene_path)
	get_tree().change_scene_to_file(scene_path)

# === PLAYER SPAWNING ===
func spawn_players_in_scene():
	"""Call this from your game scene's _ready()"""
	if not player_scene:
		print("No player scene assigned to NetworkManager!")
		return
	
	print("Spawning players. Current players: ", players.keys())
	print("Local peer ID: ", multiplayer.get_unique_id())
	
	# Everyone spawns all players, but only has authority over their own
	for simple_id in players:
		add_player_to_scene(simple_id)
		
		# Log which player we have authority over
		var player_node = get_tree().current_scene.get_node_or_null("Player_" + str(simple_id))
		if player_node:
			var has_authority = player_node.is_multiplayer_authority()
			var role = "controls" if has_authority else "sees"
			print("Local peer ", role, " Player_", simple_id)

func add_player_to_scene(simple_id: int):
	# Check if player already exists
	var existing_player = get_tree().current_scene.get_node_or_null("Player_" + str(simple_id))
	if existing_player:
		print("Player ", simple_id, " already exists, skipping spawn")
		return
	
	var player = player_scene.instantiate()
	player.name = "Player_" + str(simple_id)
	
	var game_scene = get_tree().current_scene
	if game_scene:
		game_scene.add_child(player)
		
		# Find the actual peer ID for this simple ID
		var actual_peer_id = _get_actual_peer_id(simple_id)
		
		# CRITICAL: Set authority using the actual peer ID
		player.set_multiplayer_authority(actual_peer_id)
		if player.has_method("set_player_id"):
			player.set_player_id(simple_id)  # Use simple ID for game logic
		
		player.global_position = Vector3(randf_range(-3, 3), 2, randf_range(-3, 3))
		print("Spawned player ", simple_id, " with authority: ", actual_peer_id, " (simple ID: ", simple_id, ")")

func remove_player_from_scene(simple_id: int):
	var player = get_tree().current_scene.get_node_or_null("Player_" + str(simple_id))
	if player:
		player.queue_free()
		print("Removed player ", simple_id)

func _get_actual_peer_id(simple_id: int) -> int:
	"""Get the actual large peer ID from simple ID"""
	for actual_id in peer_id_map:
		if peer_id_map[actual_id] == simple_id:
			return actual_id
	return simple_id  # Fallback

func _get_simple_id(actual_peer_id: int) -> int:
	"""Get simple ID from actual peer ID"""
	if peer_id_map.has(actual_peer_id):
		return peer_id_map[actual_peer_id]
	
	# Special handling for host
	if actual_peer_id == 1:
		peer_id_map[actual_peer_id] = 1
		return 1
	
	# Assign new simple ID for clients (start from 2)
	var simple_id = next_simple_id
	if simple_id == 1:  # Skip 1, it's reserved for host
		simple_id = 2
		next_simple_id = 3
	else:
		next_simple_id += 1
	
	peer_id_map[actual_peer_id] = simple_id
	print("Mapped peer ", actual_peer_id, " to simple ID ", simple_id)
	return simple_id

# === PLAYER MANAGEMENT ===
func set_local_player_info(info: Dictionary) -> void:
	local_player_info.merge(info, true)

func get_player_info(simple_id: int) -> Dictionary:
	return players.get(simple_id, {})

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
func _on_peer_connected(actual_peer_id: int) -> void:
	print("Peer connected: ", actual_peer_id)
	
	if multiplayer.is_server():
		# Server automatically adds new players when they register
		pass

func _on_peer_disconnected(actual_peer_id: int) -> void:
	print("Peer disconnected: ", actual_peer_id)
	
	var simple_id = _get_simple_id(actual_peer_id)
	if players.has(simple_id):
		players.erase(simple_id)
		peer_id_map.erase(actual_peer_id)
		player_disconnected.emit(simple_id)
		remove_player_from_scene(simple_id)

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
	peer_id_map.clear()
	next_simple_id = 2  # Reset to 2 (host is always 1)
	server_disconnected.emit()

# === PLAYER REGISTRATION ===
@rpc("any_peer", "reliable")
func _register_player(player_info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	var actual_peer_id = multiplayer.get_remote_sender_id()
	var simple_id = _get_simple_id(actual_peer_id)
	
	players[simple_id] = player_info
	print("Registered player: ", actual_peer_id, " as simple ID ", simple_id, " - ", player_info)
	
	# Broadcast to all clients using simple ID
	_player_registered.rpc(simple_id, player_info)
	
	# Add to scene if in game
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.scene_file_path.contains("demo_scene"):
		add_player_to_scene(simple_id)

@rpc("call_local", "reliable")
func _player_registered(simple_id: int, player_info: Dictionary) -> void:
	players[simple_id] = player_info
	
	# If this is our own registration, remember our simple ID
	if not multiplayer.is_server():
		var local_peer = multiplayer.get_unique_id()
		# This assumes the most recently registered player is us (the client)
		if simple_id > 1:  # Client IDs start from 2
			peer_id_map[local_peer] = simple_id
			print("Client mapped own peer ", local_peer, " to simple ID ", simple_id)
	
	player_connected.emit(simple_id, player_info)
