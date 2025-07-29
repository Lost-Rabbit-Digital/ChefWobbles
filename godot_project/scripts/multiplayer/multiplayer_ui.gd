# MultiplayerUI.gd - Complete UI system for multiplayer lobby and connection management
extends Control

# UI Components
@onready var main_menu: Control = $MainMenu
@onready var lobby: Control = $Lobby
@onready var connection_dialog: AcceptDialog = $ConnectionDialog

# Main Menu UI
@onready var host_button: Button = $MainMenu/VBoxContainer/HostButton
@onready var join_button: Button = $MainMenu/VBoxContainer/JoinButton
@onready var single_player_button: Button = $MainMenu/VBoxContainer/SinglePlayerButton

# Join Game UI
@onready var ip_input: LineEdit = $MainMenu/JoinDialog/VBoxContainer/IPInput
@onready var join_dialog: AcceptDialog = $MainMenu/JoinDialog
@onready var join_confirm_button: Button = $MainMenu/JoinDialog/VBoxContainer/JoinConfirmButton

# Lobby UI - UPDATED FOR VBOXCONTAINER
@onready var player_list: VBoxContainer = $Lobby/VBoxContainer/PlayerList
@onready var start_game_button: Button = $Lobby/VBoxContainer/HBoxContainer/StartGameButton
@onready var leave_lobby_button: Button = $Lobby/VBoxContainer/HBoxContainer/LeaveLobbyButton
@onready var lobby_status_label: Label = $Lobby/VBoxContainer/StatusLabel

# Player customization
@onready var player_name_input: LineEdit = $MainMenu/VBoxContainer/PlayerNameInput

# Connection status
@onready var connection_status: Label = $ConnectionStatus

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	"""Initialize UI components"""
	# Show main menu initially
	_show_main_menu()
	
	# Setup default player name
	if player_name_input:
		player_name_input.text = "Chef " + str(randi() % 1000)
	
	# Initialize connection status
	if connection_status:
		connection_status.text = "Not Connected"

func _connect_signals() -> void:
	"""Connect UI signals"""
	# Main menu buttons
	if host_button:
		host_button.pressed.connect(_on_host_button_pressed)
	if join_button:
		join_button.pressed.connect(_on_join_button_pressed)
	if single_player_button:
		single_player_button.pressed.connect(_on_single_player_button_pressed)
	
	# Join dialog
	if join_confirm_button:
		join_confirm_button.pressed.connect(_on_join_confirm_pressed)
	if join_dialog and join_dialog.has_signal("canceled"):
		join_dialog.canceled.connect(_on_join_cancel_pressed)
	
	# Lobby buttons
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
	if leave_lobby_button:
		leave_lobby_button.pressed.connect(_on_leave_lobby_pressed)
	
	# NetworkManager signals
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.connection_established.connect(_on_connection_established)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)

# === UI STATE MANAGEMENT ===
func _show_main_menu() -> void:
	"""Show the main menu"""
	if main_menu:
		main_menu.visible = true
	if lobby:
		lobby.visible = false
	if join_dialog:
		join_dialog.visible = false

func _show_lobby() -> void:
	"""Show the lobby interface"""
	if main_menu:
		main_menu.visible = false
	if lobby:
		lobby.visible = true
	
	_update_lobby_ui()

func _update_lobby_ui() -> void:
	"""Update lobby UI with current state"""
	if not player_list or not NetworkManager:
		return
	
	# Clear existing player labels - proper VBoxContainer method
	for child in player_list.get_children():
		player_list.remove_child(child)
		child.queue_free()
	
	var players = NetworkManager.get_all_players()
	
	for peer_id in players:
		var player_info = players[peer_id]
		var player_name = player_info.get("name", "Player " + str(peer_id))
		var is_host = peer_id == 1
		
		# Create new label node
		var label = Label.new()
		
		# Set the label text
		if is_host:
			label.text = player_name + " (Host)"
		else:
			label.text = player_name
		
		# Add the label to VBoxContainer
		player_list.add_child(label)
		print("Added label: ", label.text)
	
	# Update start game button (only host can start)
	if start_game_button:
		start_game_button.disabled = not NetworkManager.is_host()
	
	# Update status
	if lobby_status_label:
		var player_count = NetworkManager.get_player_count()
		lobby_status_label.text = "Players: " + str(player_count) + "/4"

# === BUTTON HANDLERS ===
func _on_host_button_pressed() -> void:
	"""Handle host game button press"""
	_update_player_info()
	
	var error = NetworkManager.host_game()
	if error == OK:
		_show_lobby()
		_update_connection_status("Hosting game...")
	else:
		_show_error_dialog("Failed to host game. Error: " + str(error))

func _on_join_button_pressed() -> void:
	"""Handle join game button press"""
	if join_dialog:
		join_dialog.popup_centered()
	
	if ip_input:
		ip_input.text = NetworkManager.DEFAULT_SERVER_IP
		ip_input.grab_focus()

func _on_single_player_button_pressed() -> void:
	"""Handle single player button press"""
	_update_player_info()
	get_tree().change_scene_to_file("res://scenes/worlds/demo_scene.tscn")

func _on_join_confirm_pressed() -> void:
	"""Handle join confirmation"""
	if not ip_input:
		return
	
	var ip_address = ip_input.text.strip_edges()
	if ip_address.is_empty():
		ip_address = NetworkManager.DEFAULT_SERVER_IP
	
	_update_player_info()
	
	var error = NetworkManager.join_game(ip_address)
	if error == OK:
		_update_connection_status("Connecting to " + ip_address + "...")
		if join_dialog:
			join_dialog.hide()
	else:
		_show_error_dialog("Failed to connect. Error: " + str(error))

func _on_join_cancel_pressed() -> void:
	"""Handle join cancellation"""
	if join_dialog:
		join_dialog.hide()

func _on_start_game_pressed() -> void:
	"""Handle start game button press (host only)"""
	if not NetworkManager.is_host():
		return
	
	# Check minimum players
	if NetworkManager.get_player_count() < 1:
		_show_error_dialog("Need at least 1 player to start!")
		return
	
	# Start the game
	NetworkManager.start_multiplayer_game("res://scenes/worlds/demo_scene.tscn")

func _on_leave_lobby_pressed() -> void:
	"""Handle leave lobby button press"""
	NetworkManager.disconnect_from_game()
	_show_main_menu()
	_update_connection_status("Disconnected")

# === NETWORK EVENT HANDLERS ===
func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	"""Handle player connection"""
	_update_lobby_ui()
	_update_connection_status("Player joined: " + player_info.get("name", str(peer_id)))

func _on_player_disconnected(peer_id: int) -> void:
	"""Handle player disconnection"""
	_update_lobby_ui()
	_update_connection_status("Player left: " + str(peer_id))

func _on_connection_established() -> void:
	"""Handle successful connection"""
	_show_lobby()
	_update_connection_status("Connected to server")

func _on_connection_failed() -> void:
	"""Handle connection failure"""
	_show_error_dialog("Failed to connect to server")
	_update_connection_status("Connection failed")

func _on_server_disconnected() -> void:
	"""Handle server disconnection"""
	_show_main_menu()
	_show_error_dialog("Disconnected from server")
	_update_connection_status("Server disconnected")

# === UTILITY FUNCTIONS ===
func _update_player_info() -> void:
	"""Update local player information"""
	if not player_name_input:
		return
	
	var player_info = {
		"name": player_name_input.text.strip_edges(),
		"color": Color(randf(), randf(), randf())
	}
	
	if player_info.name.is_empty():
		player_info.name = "Chef " + str(randi() % 1000)
	
	NetworkManager.set_local_player_info(player_info)

func _update_connection_status(status: String) -> void:
	"""Update connection status display"""
	if connection_status:
		connection_status.text = status
	print("Connection Status: ", status)

func _show_error_dialog(message: String) -> void:
	"""Show error dialog with message"""
	if connection_dialog:
		connection_dialog.dialog_text = message
		connection_dialog.popup_centered()
	else:
		print("Error: ", message)

# === INPUT HANDLING ===
func _input(event: InputEvent) -> void:
	"""Handle global input events"""
	if event.is_action_pressed("ui_cancel"):
		if lobby and lobby.visible:
			_on_leave_lobby_pressed()
		elif join_dialog and join_dialog.visible:
			_on_join_cancel_pressed()
	
	elif event.is_action_pressed("ui_accept"):
		if join_dialog and join_dialog.visible:
			_on_join_confirm_pressed()

# === DEBUG FUNCTIONS ===
func _on_debug_button_pressed() -> void:
	"""Debug function for testing"""
	print("=== MULTIPLAYER UI DEBUG ===")
	print("NetworkManager active: ", NetworkManager.is_multiplayer_active())
	print("Is host: ", NetworkManager.is_host())
	print("Player count: ", NetworkManager.get_player_count())
	print("Local peer ID: ", NetworkManager.get_local_peer_id())
	print("=============================")

# === SCENE TRANSITIONS ===
func transition_to_game() -> void:
	"""Transition from lobby to game scene"""
	_update_connection_status("Loading game...")

func return_to_lobby() -> void:
	"""Return from game to lobby"""
	_show_lobby()
	_update_connection_status("Returned to lobby")
