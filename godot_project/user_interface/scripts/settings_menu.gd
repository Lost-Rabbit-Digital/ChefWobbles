class_name SettingsMenu
extends Control

@export var slide_duration: float = 0.8
@export var auto_hide_delay: float = 2.0

@onready var panel: Panel = $Panel

var is_sliding_in: bool = false
var original_position: Vector2

func _ready() -> void:
	# Store original position and move off-screen (same as credits)
	original_position = position
	position.x = get_viewport().get_visible_rect().size.x
	
	# Start hidden (this was missing in your original)
	visible = false

func show_settings() -> void:
	"""Slide in from right - matches credits menu exactly"""
	if is_sliding_in:
		return
		
	is_sliding_in = true
	visible = true
	
	# Slide in animation (identical to credits)
	var slide_tween = create_tween()
	slide_tween.set_ease(Tween.EASE_OUT)
	slide_tween.set_trans(Tween.TRANS_CUBIC)
	
	slide_tween.tween_property(self, "position", original_position, slide_duration)
	await slide_tween.finished
	
	is_sliding_in = false
	start_auto_hide_timer()

func hide_settings() -> void:
	"""Slide out to the right - matches credits menu exactly"""
	var slide_tween = create_tween()
	slide_tween.set_ease(Tween.EASE_IN)
	slide_tween.set_trans(Tween.TRANS_CUBIC)
	
	slide_tween.tween_property(self, "position:x", get_viewport().get_visible_rect().size.x, slide_duration)
	await slide_tween.finished
	
	visible = false

func start_auto_hide_timer() -> void:
	"""Start timer to auto-hide settings when finished"""
	if auto_hide_delay <= 0:
		return
		
	await get_tree().create_timer(auto_hide_delay).timeout
	if visible:
		hide_settings()

func _input(event: InputEvent) -> void:
	"""Handle escape key to close settings - same as credits"""
	if not visible or is_sliding_in:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_settings()

# This function name MUST match your button's signal connection
func _on_settings_button_toggled(toggled_on: bool) -> void:
	"""Handle settings button toggle - identical pattern to credits"""
	if toggled_on:
		show_settings()
	else:
		hide_settings()
