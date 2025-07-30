extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene: PackedScene
var player_name: String = ""

func _ready() -> void:
	print("=== GAME MANAGER READY ===")
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	
	# Check if we came from main menu
	if get_tree().has_meta("should_host"):
		player_name = get_tree().get_meta("player_name")
		get_tree().remove_meta("should_host")
		get_tree().remove_meta("player_name")
		print("Main menu requested hosting with name: ", player_name)
		_on_host_button_pressed()
		
	elif get_tree().has_meta("should_join"):
		var ip = get_tree().get_meta("join_ip")
		player_name = get_tree().get_meta("player_name")
		get_tree().remove_meta("should_join")
		get_tree().remove_meta("join_ip")
		get_tree().remove_meta("player_name")
		print("Main menu requested joining ", ip, " with name: ", player_name)
		_on_join_button_pressed_with_ip(ip)
		
	elif get_tree().has_meta("singleplayer"):
		player_name = get_tree().get_meta("player_name")
		get_tree().remove_meta("singleplayer")
		get_tree().remove_meta("player_name")
		print("Main menu requested singleplayer with name: ", player_name)
		_spawn_singleplayer()

func _spawn_singleplayer():
	# Create a single player for offline play
	var player = player_scene.instantiate()
	player.name = "1"
	player.set_multiplayer_authority(1)
	call_deferred("_set_player_spawn_position", player)
	call_deferred("add_child", player)
	print("Spawned single player: ", player_name)

func _add_player(id: int):
	print("_add_player called with ID: ", id, " (Is server: ", multiplayer.is_server(), ")")
	
	if not multiplayer.is_server():
		print("Client tried to spawn player - ignoring")
		return
	
	if get_node_or_null(str(id)):
		print("Player ", id, " already exists, skipping")
		return
	
	var player = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	call_deferred("_set_player_spawn_position", player)
	call_deferred("add_child", player)
	print("Server spawned player: ", id)

func _remove_player(id: int):
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
		print("Removed player: ", id)
		
func _set_player_spawn_position(player: Node3D):
	player.global_position = Vector3(randf_range(-2, 2), 2, randf_range(-2, 2))
	print("Set spawn position for player: ", player.name, " at: ", player.global_position)

# === YOUR LEGACY FUNCTIONS (UNCHANGED) ===
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

# === NEW FUNCTION FOR IP-SPECIFIC JOINING ===
func _on_join_button_pressed_with_ip(ip: String) -> void:
	if peer.get_connection_status() != 0:
		print("Already connected - skipping join process")
		return
	
	print("Creating client for IP: ", ip)
	peer.create_client(ip, 3824)
	multiplayer.multiplayer_peer = peer
	print("Client connecting to server at: ", ip)
