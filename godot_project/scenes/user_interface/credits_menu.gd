class_name CreditsMenu
extends Control

@export var credits_file_path: String = "res://CREDITS.md"
@export var scroll_speed: float = 15.0
@export var user_idle_timeout: float = 3.0
@export var auto_hide_delay: float = 2.0

@onready var panel: Panel = $Panel
@onready var rich_text: RichTextLabel = $Panel/RichTextLabel

var is_auto_scrolling: bool = false
var is_user_scrolling: bool = false
var user_idle_timer: float = 0.0

var target_scroll: float = 0.0
var current_scroll: float = 0.0
var scroll_velocity: float = 0.0

# Static interface for backwards compatibility
static func show_credits():
	MenuManager.show_menu("CreditsMenu")

static func hide_credits():
	MenuManager.hide_menu("CreditsMenu")

func _ready() -> void:
	# Setup rich text label
	rich_text.bbcode_enabled = true
	rich_text.fit_content = false
	rich_text.scroll_active = true
	rich_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Connect mouse events
	rich_text.mouse_entered.connect(_on_mouse_entered)
	rich_text.mouse_exited.connect(_on_mouse_exited)
	
	# Connect to visibility changes to handle menu showing/hiding
	visibility_changed.connect(_on_visibility_changed)
	
	# Load credits text
	_load_credits_text()

func _on_visibility_changed() -> void:
	"""Handle when the menu becomes visible or hidden"""
	if visible:
		# Menu was shown - reset scroll and start auto-scroll
		_reset_scroll_state()
		_start_auto_scroll()
	else:
		# Menu was hidden - stop all scrolling
		_stop_all_scrolling()

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
	"""Begin automatic scrolling"""
	# Wait for content to be fully loaded
	await get_tree().process_frame
	
	var v_scroll = rich_text.get_v_scroll_bar()
	var max_scroll = v_scroll.max_value - v_scroll.page
	
	if max_scroll <= 0:
		_start_auto_hide_timer()
		return
	
	is_auto_scrolling = true
	target_scroll = max_scroll

func _start_auto_hide_timer() -> void:
	"""Start timer to auto-hide credits when finished"""
	await get_tree().create_timer(auto_hide_delay).timeout
	if visible and not is_user_scrolling:
		MenuManager.hide_menu("CreditsMenu")

func _stop_all_scrolling() -> void:
	"""Stop all scrolling"""
	is_auto_scrolling = false
	is_user_scrolling = false
	scroll_velocity = 0.0

func _process(delta: float) -> void:
	"""Handle scrolling logic"""
	if not visible:
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
	"""Smooth scrolling with constant velocity"""
	var distance_to_target = target_scroll - current_scroll
	
	# Check if we've reached the target
	if abs(distance_to_target) < 1.0:
		current_scroll = target_scroll
		is_auto_scrolling = false
		_start_auto_hide_timer()
		return
	
	# Constant velocity - no deceleration
	var target_velocity = scroll_speed if distance_to_target > 0 else -scroll_speed
	
	# Smooth velocity interpolation for natural movement
	var velocity_lerp_speed = 3.0
	scroll_velocity = lerp(scroll_velocity, target_velocity, velocity_lerp_speed * delta)
	
	# Update position
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
		
		# Sync current_scroll with actual scroll position
		current_scroll = v_scroll.value
		
		var remaining = max_scroll - current_scroll
		
		if remaining > 10:
			is_auto_scrolling = true
			target_scroll = max_scroll
		else:
			_start_auto_hide_timer()

func _on_user_scroll(event: InputEventMouseButton) -> void:
	"""Handle user mouse wheel scrolling"""
	_stop_all_scrolling()
	is_user_scrolling = true
	user_idle_timer = 0.0
	
	var v_scroll = rich_text.get_v_scroll_bar()
	var scroll_amount = v_scroll.step * 3
	
	current_scroll = v_scroll.value
	
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		current_scroll = max(0, current_scroll - scroll_amount)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var max_scroll = v_scroll.max_value - v_scroll.page
		current_scroll = min(max_scroll, current_scroll + scroll_amount)
	
	v_scroll.value = current_scroll

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# Handle mouse wheel scrolling
	if event is InputEventMouseButton and _is_mouse_over_credits():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_user_scroll(event)

func _is_mouse_over_credits() -> bool:
	"""Check if mouse is over the credits area"""
	var mouse_pos = get_global_mouse_position()
	return rich_text.get_global_rect().has_point(mouse_pos)

func _on_mouse_entered() -> void:
	"""Mouse entered credits area"""
	if is_auto_scrolling:
		_stop_all_scrolling()
		is_user_scrolling = true
		user_idle_timer = 0.0

func _on_mouse_exited() -> void:
	"""Mouse left credits area"""
	pass

func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))

func _on_credits_button_pressed() -> void:
	if MenuManager.get_active_menu() == "creditsmenu":
		MenuManager.hide_menu("CreditsMenu")
	else:
		MenuManager.show_menu("CreditsMenu")
