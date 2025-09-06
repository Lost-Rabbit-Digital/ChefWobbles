extends Control

var is_paused: bool = false
@export var main_menu_scene: PackedScene

@onready var main_menu: Panel = $MainPanel
@onready var accolades_menu: Panel = $AccoladesPanel
@onready var controls_menu: Panel = $ControlsPanel
@onready var settings_menu: Panel = $SettingsPanel

func _ready() -> void:
	if !is_paused:
		main_menu.visible = false
		accolades_menu.visible = false
		controls_menu.visible = false
		settings_menu.visible = false
	
func _process(delta: float) -> void:
	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause_game"):
		is_paused = !is_paused
		if is_paused:
			main_menu.visible = true
		else:
			main_menu.visible = false
			accolades_menu.visible = false
			controls_menu.visible = false
			settings_menu.visible = false

func _on_back_button_pressed() -> void:
	is_paused = !is_paused
	if is_paused:
		main_menu.visible = true
	else:
		main_menu.visible = false
		accolades_menu.visible = false
		controls_menu.visible = false
		settings_menu.visible = false

func _on_leave_game_button_pressed() -> void:
	var error = get_tree().change_scene_to_packed(main_menu_scene)
	if error != OK:
		push_error("Failed to load demo scene: ", error)


func _on_accolade_back_button_pressed() -> void:
	main_menu.visible = true
	accolades_menu.visible = false
	controls_menu.visible = false

func _on_accolades_button_pressed() -> void:
	accolades_menu.visible = true
	main_menu.visible = false
	controls_menu.visible = false


func _on_controls_back_button_pressed() -> void:
	main_menu.visible = true
	accolades_menu.visible = false
	controls_menu.visible = false

func _on_controls_button_pressed() -> void:
	main_menu.visible = false
	accolades_menu.visible = false
	controls_menu.visible = true


func _on_settings_button_pressed() -> void:
	main_menu.visible = false
	accolades_menu.visible = false
	controls_menu.visible = false
	settings_menu.visible = true

func _on_settings_back_button_pressed() -> void:
	main_menu.visible = true
	accolades_menu.visible = false
	controls_menu.visible = false
	settings_menu.visible = false
