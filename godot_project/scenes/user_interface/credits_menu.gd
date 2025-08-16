class_name CreditsMenu
extends Control

@export var credits_file_path: String = "res://CREDITS.md"
@export var slide_duration: float = 0.8
@export var scroll_speed: float = 15.0  # Pixels per second - slower for better readability
@export var user_idle_timeout: float = 3.0
@export var auto_hide_delay: float = 2.0

@onready var panel: Panel = $Panel
@onready var rich_text: RichTextLabel = $Panel/RichTextLabel

var is_sliding_in: bool = false
var is_auto_scrolling: bool = false
var is_user_scrolling: bool = false
var user_idle_timer: float = 0.0
var original_position: Vector2

# Manual interpolation variables - Industry approach
var target_scroll: float = 0.0
var current_scroll: float = 0.0
var scroll_velocity: float = 0.0

func _ready() -> void:
	# Store original position and move off-screen
	original_position = position
	position.x = get_viewport().get_visible_rect().size.x
	
	# Setup rich text label - Critical settings for smooth scrolling
	rich_text.bbcode_enabled = true
	rich_text.fit_content = false  # Must be false for scrolling
	rich_text.scroll_active = true
	rich_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Connect mouse events
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
	
	# Reset scroll state
	_reset_scroll_state()
	
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
	_reset_scroll_state()

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
		
		# Wait for layout to stabilize
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		push_error("Failed to open credits file: " + credits_file_path)

func _reset_scroll_state() -> void:
	"""Reset all scroll-related state"""
	current_scroll = 0.0
	target_scroll = 0.0
	scroll_velocity = 0.0
	var v_scroll = rich_text.get_v_scroll_bar()
	v_scroll.value = 0

func _start_auto_scroll() -> void:
	"""Begin automatic scrolling using industry-standard technique"""
	# Wait for content to be fully loaded
	await get_tree().process_frame
	
	var v_scroll = rich_text.get_v_scroll_bar()
	var max_scroll = v_scroll.max_value - v_scroll.page
	
	print("Max scroll available: ", max_scroll)
	
	if max_scroll <= 0:
		print("No content to scroll, auto-hiding")
		_start_auto_hide_timer()
		return
	
	is_auto_scrolling = true
	target_scroll = max_scroll
	
	print("Starting smooth scroll to: ", target_scroll)

func _start_auto_hide_timer() -> void:
	"""Start timer to auto-hide credits when finished"""
	await get_tree().create_timer(auto_hide_delay).timeout
	if visible and not is_user_scrolling:
		hide_credits()

func _stop_all_scrolling() -> void:
	"""Stop all scrolling"""
	is_auto_scrolling = false
	is_user_scrolling = false
	scroll_velocity = 0.0

func _process(delta: float) -> void:
	"""Manual interpolation approach - Industry standard for smooth scrolling"""
	if not visible or is_sliding_in:
		return
	
	# Handle auto-scrolling with manual interpolation
	if is_auto_scrolling:
		_update_smooth_scroll(delta)
	
	# Handle user idle timeout
	if is_user_scrolling:
		user_idle_timer += delta
		
		if user_idle_timer >= user_idle_timeout:
			is_user_scrolling = false
			user_idle_timer = 0.0
			_resume_auto_scroll()

func _update_smooth_scroll(delta: float) -> void:
	"""Industry-standard smooth scrolling using manual interpolation with velocity"""
	var distance_to_target = target_scroll - current_scroll
	
	# Check if we've reached the target
	if abs(distance_to_target) < 1.0:
		current_scroll = target_scroll
		is_auto_scrolling = false
		_start_auto_hide_timer()
		return
	
	# Use scroll_speed as the base velocity (pixels per second)
	var base_velocity = scroll_speed
	
	# Calculate smooth acceleration towards target
	var acceleration_factor = distance_to_target / target_scroll  # Normalized distance
	var target_velocity = base_velocity * acceleration_factor
	
	# Smooth velocity interpolation for natural movement
	var velocity_lerp_speed = 2.0  # How quickly velocity changes
	scroll_velocity = lerp(scroll_velocity, target_velocity, velocity_lerp_speed * delta)
	
	# Ensure minimum velocity to prevent stalling
	var min_velocity = base_velocity * 0.1
	if abs(scroll_velocity) < min_velocity and abs(distance_to_target) > 10.0:
		scroll_velocity = min_velocity if distance_to_target > 0 else -min_velocity
	
	# Update position using actual scroll_speed
	current_scroll += scroll_velocity * delta
	current_scroll = clamp(current_scroll, 0.0, target_scroll)
	
	# Apply to UI
	var v_scroll = rich_text.get_v_scroll_bar()
	v_scroll.value = current_scroll

func _resume_auto_scroll() -> void:
	"""Resume auto-scrolling from current position"""
	if not is_auto_scrolling:
		var v_scroll = rich_text.get_v_scroll_bar()
		var max_scroll = v_scroll.max_value - v_scroll.page
		var remaining = max_scroll - current_scroll
		
		if remaining > 10:
			is_auto_scrolling = true
			target_scroll = max_scroll
		else:
			_start_auto_hide_timer()

func _input(event: InputEvent) -> void:
	if not visible or is_sliding_in:
		return
		
	# Handle mouse wheel scrolling
	if event is InputEventMouseButton and _is_mouse_over_credits():
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

func _on_user_scroll(event: InputEventMouseButton) -> void:
	"""Handle user mouse wheel scrolling with smooth interpolation"""
	_stop_all_scrolling()
	is_user_scrolling = true
	user_idle_timer = 0.0
	
	var v_scroll = rich_text.get_v_scroll_bar()
	var scroll_amount = v_scroll.step * 3  # Scroll sensitivity
	
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		current_scroll = max(0, current_scroll - scroll_amount)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var max_scroll = v_scroll.max_value - v_scroll.page
		current_scroll = min(max_scroll, current_scroll + scroll_amount)
	
	# Apply immediately for responsive feel
	v_scroll.value = current_scroll

func _on_mouse_entered() -> void:
	"""Mouse entered credits area"""
	if is_auto_scrolling:
		_stop_all_scrolling()
		is_user_scrolling = true
		user_idle_timer = 0.0

func _on_mouse_exited() -> void:
	"""Mouse left credits area"""
	pass

func _on_credits_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		show_credits()
	else:
		hide_credits()
