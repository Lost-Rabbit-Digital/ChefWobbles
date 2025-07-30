extends Control

# === SCENE REFERENCES ===
@export var demo_scene_path: String = "res://scenes/worlds/demo_scene.tscn"
var game_manager: Node3D = null

# === UI REFERENCES ===
@onready var main_menu = $MainMenu
@onready var lobby = $Lobby
@onready var join_dialog = $MainMenu/JoinDialog

# Main Menu UI
@onready var player_name_input = $MainMenu/VBoxContainer/PlayerNameInput
@onready var host_button = $MainMenu/VBoxContainer/HostButton
@onready var join_button = $MainMenu/VBoxContainer/JoinButton
@onready var singleplayer_button = $MainMenu/VBoxContainer/SinglePlayerButton

# Join Dialog UI
@onready var ip_input = $MainMenu/JoinDialog/VBoxContainer/IPInput
@onready var join_confirm_button = $MainMenu/JoinDialog/VBoxContainer/JoinConfirmButton

# Lobby UI
@onready var status_label = $Lobby/VBoxContainer/StatusLabel
@onready var start_game_button = $Lobby/VBoxContainer/HBoxContainer/StartGameButton
@onready var leave_lobby_button = $Lobby/VBoxContainer/HBoxContainer/LeaveLobbyButton
@onready var player_list = $Lobby/VBoxContainer/PlayerList

# Connection UI
@onready var connection_dialog = $ConnectionDialog
@onready var connection_status = $ConnectionStatus

# === PLAYER TRACKING ===
var connected_players: Dictionary = {}
var player_name: String = ""
var is_hosting: bool = false

func _ready():
	print("=== MAIN MENU READY ===")
	_setup_ui_connections()
	_update_connection_status("Ready to connect")
	
	# Set default values
	ip_input.text = "localhost"
	player_name_input.text = "Chef" + str(randi_range(1, 999))

func _setup_ui_connections():
	# Main menu buttons
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	singleplayer_button.pressed.connect(_on_singleplayer_button_pressed)
	
	# Join dialog
	join_confirm_button.pressed.connect(_on_join_confirm_pressed)
	
	# Lobby buttons
	start_game_button.pressed.connect(_on_start_game_pressed)
	leave_lobby_button.pressed.connect(_on_leave_lobby_pressed)

# === MAIN MENU FUNCTIONS ===
func _on_host_button_pressed():
	player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Host"
	
	# Store that we want to host
	is_hosting = true
	_update_connection_status("Preparing to host...")
	
	# Load demo scene and let GameManager handle hosting
	_load_demo_scene_and_host()

func _on_join_button_pressed():
	join_dialog.popup_centered()

func _on_join_confirm_pressed():
	player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player"
	
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "localhost"
	
	join_dialog.hide()
	is_hosting = false
	_update_connection_status("Preparing to join " + ip + "...")
	
	# Load demo scene and let GameManager handle joining
	_load_demo_scene_and_join(ip)

func _on_singleplayer_button_pressed():
	player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Solo Chef"
	
	# Load demo scene for singleplayer
	_load_demo_scene_singleplayer()

func _on_start_game_pressed():
	# This will be implemented when we add lobby functionality
	print("Start game pressed")

func _on_leave_lobby_pressed():
	# This will be implemented when we add lobby functionality  
	print("Leave lobby pressed")

# === SCENE MANAGEMENT ===
func _load_demo_scene_and_host():
	# Store info for GameManager to handle hosting
	get_tree().set_meta("should_host", true)
	get_tree().set_meta("player_name", player_name)
	
	var error = get_tree().change_scene_to_file(demo_scene_path)
	if error != OK:
		print("Failed to load demo scene: ", error)
		_show_error("Failed to load game scene")

func _load_demo_scene_and_join(ip: String):
	# Store info for GameManager to handle joining
	get_tree().set_meta("should_join", true)
	get_tree().set_meta("join_ip", ip)
	get_tree().set_meta("player_name", player_name)
	
	var error = get_tree().change_scene_to_file(demo_scene_path)
	if error != OK:
		print("Failed to load demo scene: ", error)
		_show_error("Failed to load game scene")

func _load_demo_scene_singleplayer():
	# Store info for GameManager
	get_tree().set_meta("singleplayer", true)
	get_tree().set_meta("player_name", player_name)
	
	var error = get_tree().change_scene_to_file(demo_scene_path)
	if error != OK:
		print("Failed to load demo scene: ", error)
		_show_error("Failed to load game scene")

# === UTILITY FUNCTIONS ===
func _update_connection_status(status: String):
	connection_status.text = status

func _show_error(message: String):
	connection_dialog.dialog_text = message
	connection_dialog.popup_centered()
	_update_connection_status("Error: " + message)

func _process(delta):
	var character_preview_texture = $Preview.get_texture()
	$CharacterCustomiser/CharacterPreview.texture = character_preview_texture
	$CharacterCustomiser/CharacterPreview2.texture = character_preview_texture
