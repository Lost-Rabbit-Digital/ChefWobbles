# MultiplayerGameManager.gd
# Main game scene controller for multiplayer functionality
extends Node3D

signal all_players_spawned()
signal game_state_synchronized()

# Player management
@export var player_scene: PackedScene
@export var spawn_points: Array[Vector3] = [
	Vector3(0, 1, 0),
	Vector3(3, 1, 0),
	Vector3(-3, 1, 0),
	Vector3(0, 1, 3)
]

var game_initialized: bool = false

func _ready() -> void:
	_setup_multiplayer_game()

func _setup_multiplayer_game() -> void:
	"""Initialize multiplayer game systems"""
	if not NetworkManager or not NetworkManager.is_multiplayer_active():
		_setup_single_player()
		return
	
	# Connect to network events
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Spawn players for existing connections
	var all_players = NetworkManager.get_all_players()
	for peer_id in all_players:
		_spawn_player(peer_id)
	
	# Tell NetworkManager we're ready (only if we're a client, not the host)
	if NetworkManager.is_multiplayer_active() and not NetworkManager.is_host():
		# Add a small delay to ensure connection is established
		await get_tree().create_timer(0.1).timeout
		if NetworkManager.is_multiplayer_active():
			NetworkManager.player_ready_for_game.rpc_id(1)

func _setup_single_player() -> void:
	"""Setup for single player mode"""
	print("Setting up single player mode")
	
	# In single player, spawn a local player if we have the scene set
	if player_scene:
		_spawn_single_player()
	
	game_initialized = true

func _spawn_single_player() -> void:
	"""Spawn a single player for single player mode"""
	var player_instance = player_scene.instantiate()
	var spawn_position = spawn_points[0] if spawn_points.size() > 0 else Vector3.ZERO
	
	# Configure player
	player_instance.name = "Player_Local"
	
	# Add to scene root for consistent paths
	get_tree().current_scene.add_child(player_instance, true)
	
	# THEN set position
	player_instance.global_position = spawn_position
	
	# Set as local player (ID 1 for single player)
	if player_instance.has_method("set_player_id"):
		player_instance.set_player_id(1)
	
	print("Spawned single player at position ", spawn_position)

func initialize_multiplayer() -> void:
	"""Called by NetworkManager when all players are loaded"""
	if game_initialized:
		return
	
	print("Initializing multiplayer game state")
	
	# Synchronize initial game state
	if NetworkManager and NetworkManager.is_host():
		_broadcast_initial_game_state()
	
	game_initialized = true
	game_state_synchronized.emit()

# === PLAYER SPAWNING ===
func _spawn_player(peer_id: int) -> void:
	"""Spawn a player for the given peer ID"""
	# Check if player already exists using groups
	var existing_players = get_tree().get_nodes_in_group("player_" + str(peer_id))
	if existing_players.size() > 0:
		print("Player ", peer_id, " already spawned")
		return
	
	if not player_scene:
		push_error("MultiplayerGameManager: player_scene not set!")
		return
	
	var player_instance = player_scene.instantiate()
	var spawn_index = randi() % spawn_points.size()  # Random spawn point
	var spawn_position = spawn_points[spawn_index]
	
	# Configure player name
	player_instance.name = "Player_" + str(peer_id)
	
	# Add to scene root instead of GameManager to ensure consistent paths
	get_tree().current_scene.add_child(player_instance, true)
	
	# Set player ID first
	if player_instance.has_method("set_player_id"):
		player_instance.set_player_id(peer_id)
	
	# Add to specific player group
	player_instance.add_to_group("player_" + str(peer_id))
	
	# Wait a frame to ensure multiplayer setup is complete
	await get_tree().process_frame
	
	# THEN set position after everything is ready
	player_instance.global_position = spawn_position
	print("Setting player ", peer_id, " position to: ", spawn_position)
	
	# Initialize the network position after setting spawn position
	if player_instance.has_method("initialize_spawn_position"):
		player_instance.initialize_spawn_position()
	
	# Wait another frame for physics, then force position again
	await get_tree().process_frame
	player_instance.global_position = spawn_position
	print("Force-setting position again to: ", spawn_position)
	print("Final player position: ", player_instance.global_position)
	
	# DEBUG: Check position after a few seconds to see what moved it
	await get_tree().create_timer(3.0).timeout
	print("=== POSITION CHECK AFTER 3 SECONDS ===")
	print("Player ", peer_id, " position after 3 seconds: ", player_instance.global_position)
	print("Expected position was: ", spawn_position)
	if player_instance.global_position.distance_to(spawn_position) > 1.0:
		print("WARNING: Player moved significantly from spawn position!")
	print("=======================================")
	
	print("Spawned player ", peer_id, " at position ", spawn_position)
	
	# Check if all players are spawned using groups
	if NetworkManager and is_all_players_spawned():
		all_players_spawned.emit()

func _despawn_player(peer_id: int) -> void:
	"""Remove a player when they disconnect using groups"""
	var players_to_remove = get_tree().get_nodes_in_group("player_" + str(peer_id))
	
	for player in players_to_remove:
		if is_instance_valid(player):
			player.queue_free()
		
		print("Despawned player ", peer_id)

# === GAME STATE SYNCHRONIZATION ===
func _broadcast_initial_game_state() -> void:
	"""Broadcast initial game state to all clients (server only)"""
	if not NetworkManager or not NetworkManager.is_host():
		return
	
	var game_state = _gather_game_state()
	_receive_game_state.rpc(game_state)

func _gather_game_state() -> Dictionary:
	"""Gather current game state for synchronization"""
	var state = {
		"players": get_all_multiplayer_players().size(),
		"timestamp": Time.get_time_dict_from_system()
	}
	
	return state

@rpc("call_local", "reliable")
func _receive_game_state(game_state: Dictionary) -> void:
	"""Receive and apply game state from server"""
	if NetworkManager and NetworkManager.is_host():
		return  # Server doesn't need to receive its own state
	
	print("Applying game state from server: ", game_state)

# === EVENT HANDLERS ===
func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	"""Handle new player connection"""
	print("Game: Player connected - ", peer_id, " (", player_info.get("name", "Unknown"), ")")
	_spawn_player(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	"""Handle player disconnection"""
	print("Game: Player disconnected - ", peer_id)
	_despawn_player(peer_id)

# === GAME CONTROL ===
func start_game() -> void:
	"""Start the multiplayer game session"""
	print("Starting multiplayer game!")
	
	# Enable gameplay systems
	_enable_gameplay_systems()

func _enable_gameplay_systems() -> void:
	"""Enable all gameplay systems for multiplayer"""
	# Enable player interactions
	var all_players = get_all_multiplayer_players()
	for player in all_players:
		if player.has_method("set_input_enabled"):
			player.set_input_enabled(true)

func end_game() -> void:
	"""End the current game session"""
	print("Ending multiplayer game")
	
	if NetworkManager and NetworkManager.is_host():
		_broadcast_game_end.rpc()

@rpc("call_local", "reliable")
func _broadcast_game_end() -> void:
	"""Broadcast game end to all players"""
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/user_interface/main_menu.tscn")

# === UTILITY FUNCTIONS WITH GROUPS ===
func get_local_player() -> Node:
	"""Get the local player instance using groups"""
	var local_players = get_tree().get_nodes_in_group("local_players")
	return local_players[0] if local_players.size() > 0 else null

func get_player_by_id(peer_id: int) -> Node:
	"""Get player instance by peer ID using groups"""
	var players = get_tree().get_nodes_in_group("player_" + str(peer_id))
	return players[0] if players.size() > 0 else null

func get_all_multiplayer_players() -> Array[Node]:
	"""Get all multiplayer players using groups"""
	return get_tree().get_nodes_in_group("players")

func is_all_players_spawned() -> bool:
	"""Check if all players have been spawned using groups"""
	if not NetworkManager:
		return true
	var spawned_count = get_tree().get_nodes_in_group("players").size()
	return spawned_count == NetworkManager.get_player_count()

func get_grabbable_objects() -> Array[Node]:
	"""Get all grabbable objects in the scene"""
	return get_tree().get_nodes_in_group("grabbable")

func get_players_near_position(pos: Vector3, radius: float = 10.0) -> Array[Node]:
	"""Get players within radius using groups"""
	var nearby_players: Array[Node] = []
	var all_players = get_all_multiplayer_players()
	
	for player in all_players:
		if player.global_position.distance_to(pos) <= radius:
			nearby_players.append(player)
	
	return nearby_players

# === DEBUG FUNCTIONS ===
func debug_print_game_state() -> void:
	"""Print current game state for debugging"""
	print("=== MULTIPLAYER GAME STATE ===")
	var player_count = NetworkManager.get_player_count() if NetworkManager else 0
	var all_players = get_all_multiplayer_players()
	print("Players spawned: ", all_players.size(), "/", player_count)
	print("Game initialized: ", game_initialized)
	
	for player in all_players:
		var player_id = player.get_player_id() if player.has_method("get_player_id") else "Unknown"
		print("  Player ", player_id, ": ", player.name, " at ", player.global_position)
	
	print("================================")
