extends Control

var is_showing: bool = false
@export var main_menu_scene: PackedScene

func _process(delta: float) -> void:
	if is_showing:
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause_game"):
		is_showing = !is_showing

func _on_back_button_pressed() -> void:
	is_showing = !is_showing

func _on_leave_game_button_pressed() -> void:
	var error = get_tree().change_scene_to_packed(main_menu_scene)
	if error != OK:
		push_error("Failed to load demo scene: ", error)
