class_name CreditsMenu
extends Control

@export var credits_file_path: String = "res://CREDITS.md"
@export var slide_duration: float = 0.8
@export var scroll_speed: float = 50.0
@export var user_idle_timeout: float = 3.0
@export var auto_hide_delay: float = 2.0

@onready var panel: Panel = $Panel
@onready var rich_text: RichTextLabel = $Panel/RichTextLabel

var is_sliding_in: bool = false
var is_auto_scrolling: bool = false
var is_user_scrolling: bool = false
var user_idle_timer: float = 0.0
var auto_hide_timer: float = 0.0
var original_position: Vector2
var target_scroll_position: float = 0.0
var scroll_tween: Tween

func _ready() -> void:
	# Store original position and move off-screen
	original_position = position
	position.x = get_viewport().get_visible_rect().size.x
	
	# Setup rich text label
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.scroll_active = false
	
	# Connect mouse events for user interaction
	rich_text.mouse_entered.connect(_on_mouse_entered)
	rich_text.mouse_exited.connect(_on_mouse_exited)
	
	# Load credits text
	_load_credits_text()

func show_credits() -> void:
	"""Slide in from right and start auto-scrolling"""
	if is_sliding_in:
		return
		
	is_sliding_in = true
	visible = true
	
	# Slide in animation
	var slide_tween = create_tween()
	slide_tween.set_ease(Tween.EASE_OUT)
	slide_tween.set_trans(Tween.TRANS_CUBIC)
	
	slide_tween.tween_property(self, "position", original_position, slide_duration)
	await slide_tween.finished
	
	is_sliding_in = false
	_start_auto_scroll()

func hide_credits() -> void:
	"""Slide out to the right"""
	_stop_all_scrolling()
	
	var slide_tween = create_tween()
	slide_tween.set_ease(Tween.EASE_IN)
	slide_tween.set_trans(Tween.TRANS_CUBIC)
	
	slide_tween.tween_property(self, "position:x", get_viewport().get_visible_rect().size.x, slide_duration)
	await slide_tween.finished
	
	visible = false
	rich_text.scroll_to_line(0)

func _load_credits_text() -> void:
	"""Load credits from text file"""
	if not FileAccess.file_exists(credits_file_path):
		push_error("Credits file not found: " + credits_file_path)
		rich_text.text = "[center]Credits file not found[/center]"
		return
	
	var file = FileAccess.open(credits_file_path, FileAccess.READ)
	if file:
		rich_text.text = file.get_as_text()
		file.close()
		
		# Wait a frame for the text to be processed
		await get_tree().process_frame
		_calculate_scroll_target()
	else:
		push_error("Failed to open credits file: " + credits_file_path)

func _calculate_scroll_target() -> void:
	"""Calculate how far we need to scroll to show all content"""
	var content_height = rich_text.get_content_height()
	var visible_height = rich_text.size.y
	target_scroll_position = max(0, content_height - visible_height)

func _start_auto_scroll() -> void:
	"""Begin automatic scrolling"""
	if target_scroll_position <= 0:
		# No need to scroll, start auto-hide timer
		_start_auto_hide_timer()
		return
	
	is_auto_scrolling = true
	rich_text.scroll_active = true
	
	# Calculate scroll duration based on content length
	var scroll_duration = target_scroll_position / scroll_speed
	
	scroll_tween = create_tween()
	scroll_tween.set_ease(Tween.EASE_IN)
	
	scroll_tween.tween_method(_update_scroll, 0.0, target_scroll_position, scroll_duration)
	await scroll_tween.finished
	
	if is_auto_scrolling:  # Check if still auto-scrolling (user might have taken over)
		_start_auto_hide_timer()

func _start_auto_hide_timer() -> void:
	"""Start timer to auto-hide credits when finished"""
	auto_hide_timer = auto_hide_delay
	
	var hide_tween = create_tween()
	hide_tween.tween_callback(hide_credits).set_delay(auto_hide_delay)

func _update_scroll(scroll_pos: float) -> void:
	"""Update scroll position during animation"""
	rich_text.scroll_to_line(int(scroll_pos / rich_text.get_theme_default_font().get_height()))

func _stop_all_scrolling() -> void:
	"""Stop all scrolling animations"""
	is_auto_scrolling = false
	is_user_scrolling = false
	
	if scroll_tween:
		scroll_tween.kill()
		scroll_tween = null

func _input(event: InputEvent) -> void:
	if not visible or is_sliding_in:
		return
		
	# Handle mouse wheel scrolling
	if event is InputEventMouseMotion and _is_mouse_over_credits():
		_on_user_interaction()
	elif event is InputEventMouseButton and _is_mouse_over_credits():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_user_scroll(event)
	
	# Handle escape key to close credits
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_credits()

func _is_mouse_over_credits() -> bool:
	"""Check if mouse is over the credits area"""
	var mouse_pos = get_global_mouse_position()
	return rich_text.get_global_rect().has_point(mouse_pos)

func _on_user_interaction() -> void:
	"""Handle any user interaction"""
	if is_auto_scrolling:
		_stop_all_scrolling()
		is_user_scrolling = true
	
	user_idle_timer = 0.0

func _on_user_scroll(event: InputEventMouseButton) -> void:
	"""Handle user mouse wheel scrolling"""
	_on_user_interaction()
	
	var scroll_delta = 0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_delta = -3
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_delta = 3
	
	# Manual scroll
	var current_line = rich_text.get_v_scroll_bar().value / rich_text.get_theme_default_font().get_height()
	var new_line = clamp(current_line + scroll_delta, 0, rich_text.get_line_count())
	rich_text.scroll_to_line(int(new_line))

func _on_mouse_entered() -> void:
	"""Mouse entered credits area"""
	_on_user_interaction()

func _on_mouse_exited() -> void:
	"""Mouse left credits area"""
	pass

func _process(delta: float) -> void:
	if not visible or is_sliding_in:
		return
	
	# Handle user idle timeout
	if is_user_scrolling:
		user_idle_timer += delta
		
		if user_idle_timer >= user_idle_timeout:
			is_user_scrolling = false
			user_idle_timer = 0.0
			
			# Resume auto-scrolling from current position
			_resume_auto_scroll()

func _resume_auto_scroll() -> void:
	"""Resume auto-scrolling from current position"""
	var current_scroll = rich_text.get_v_scroll_bar().value
	var remaining_scroll = target_scroll_position - current_scroll
	
	if remaining_scroll <= 0:
		_start_auto_hide_timer()
		return
	
	is_auto_scrolling = true
	var remaining_duration = remaining_scroll / scroll_speed
	
	scroll_tween = create_tween()
	scroll_tween.set_ease(Tween.EASE_IN)
	
	scroll_tween.tween_method(_update_scroll, current_scroll, target_scroll_position, remaining_duration)
	await scroll_tween.finished
	
	if is_auto_scrolling:
		_start_auto_hide_timer()


func _on_credits_button_pressed() -> void:
	show_credits()
