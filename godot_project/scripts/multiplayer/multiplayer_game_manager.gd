# MultiplayerGameManager.gd - Using Godot's Built-in Multiplayer Systems
# Attach this to your demo_scene root node
extends Node3D

signal all_players_spawned()

# Reference to your player scene
@export var player_scene: PackedScene

# Built-in Godot multiplayer node - add as child of demo_scene
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

var game_initialized: bool = false

func _ready() -> void:
	_setup_multiplayer()

func _setup_multiplayer() -> void:
	"""Setup using Godot's built-in multiplayer system"""
	
	if not NetworkManager or not NetworkManager.is_multiplayer_active():
		_setup_single_player()
		return
	
	# Connect network events
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Only spawn existing players if we're the server and game isn't initialized yet
	if NetworkManager.is_host():
		# Spawn all connected players
		var all_players = NetworkManager.get_all_players()
		for peer_id in all_players:
			_spawn_player(peer_id)
	
	# Tell NetworkManager we're ready (clients only)
	if not NetworkManager.is_host():
		await get_tree().process_frame
		NetworkManager.player_ready_for_game.rpc_id(1)

func _setup_single_player() -> void:
	"""Setup single player without multiplayer systems"""
	if not player_scene:
		return
		
	var player = player_scene.instantiate()
	player.name = "Player_Local"
	add_child(player, true)  # Force readable name
	
	# Set single player properties
	if player.has_method("set_player_id"):
		player.set_player_id(1)
	
	player.global_position = Vector3(0, 1, 0)
	print("Single player spawned")

func initialize_multiplayer() -> void:
	"""Called when all players are ready"""
	if game_initialized:
		return
		
	print("Initializing multiplayer...")
	game_initialized = true
	all_players_spawned.emit()

# === PLAYER SPAWNING WITH BUILT-IN SYSTEM ===
func _spawn_player(peer_id: int) -> void:
	"""Spawn player using MultiplayerSpawner"""
	if not multiplayer_spawner:
		push_error("No MultiplayerSpawner found! Add one as child of demo_scene")
		return
	
	if not NetworkManager.is_host():
		return  # Only server spawns
	
	# Check if already spawned
	var existing_player = get_node_or_null("Player_" + str(peer_id))
	if existing_player:
		print("Player ", peer_id, " already exists")
		return
	
	# Use Godot's built-in spawner - it handles replication automatically
	var player = multiplayer_spawner.spawn(peer_id)
	if player:
		print("Spawned player ", peer_id, " via MultiplayerSpawner")

func _despawn_player(peer_id: int) -> void:
	"""Remove player when disconnected"""
	var player = get_node_or_null("Player_" + str(peer_id))
	if player:
		player.queue_free()
		print("Despawned player ", peer_id)

# === EVENT HANDLERS ===
func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	"""Handle new player connection"""
	print("Game: Player connected - ", peer_id)
	if game_initialized and NetworkManager.is_host():
		_spawn_player(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	"""Handle player disconnection"""
	print("Game: Player disconnected - ", peer_id)
	_despawn_player(peer_id)

# === UTILITY ===
func get_local_player() -> Node:
	"""Get local player"""
	var local_id = NetworkManager.get_local_peer_id() if NetworkManager else 1
	return get_node_or_null("Player_" + str(local_id))

func get_all_players() -> Array[Node]:
	"""Get all player nodes"""
	var players: Array[Node] = []
	for child in get_children():
		if child.name.begins_with("Player_"):
			players.append(child)
	return players
