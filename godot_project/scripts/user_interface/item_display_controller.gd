class_name DualHandItemDisplayController
extends Control

## GUI controller that displays held items for both hands
## Integrates with movement controller that has left/right hand grabbing

@export_group("References")
@export var left_hand_label: Label
@export var right_hand_label: Label
@export var movement_controller: Node

@export_group("Display Settings")
@export var show_empty_message: bool = true
@export var empty_message: String = "No Item"
@export var update_frequency: float = 0.1
@export var fade_duration: float = 0.3

@export_group("Debug")
@export var debug_mode: bool = false
@export var print_detection_info: bool = false

@export_group("Visual Effects")
@export var animate_changes: bool = true
@export var scale_on_change: bool = true
@export var change_scale: float = 1.2

# Internal state
var current_left_item_name: String = ""
var current_right_item_name: String = ""
var update_timer: Timer
var left_tween: Tween
var right_tween: Tween

func _ready() -> void:
	_setup_components()
	_validate_setup()

func _setup_components() -> void:
	# Create update timer
	update_timer = Timer.new()
	update_timer.wait_time = update_frequency
	update_timer.timeout.connect(_update_item_displays)
	update_timer.autostart = true
	add_child(update_timer)
	
	# Create tweens for animations
	if animate_changes:
		left_tween = create_tween()
		left_tween.set_loops()
		right_tween = create_tween()
		right_tween.set_loops()

func _validate_setup() -> void:
	if not left_hand_label:
		push_error("DualHandItemDisplayController: left_hand_label not assigned!")
		return
	
	if not right_hand_label:
		push_error("DualHandItemDisplayController: right_hand_label not assigned!")
		return
	
	if not movement_controller:
		push_warning("DualHandItemDisplayController: movement_controller not assigned. Auto-detecting...")
		_auto_detect_movement_controller()

func _auto_detect_movement_controller() -> void:
	# Try to find movement controller in common locations
	var potential_controllers = [
		get_node_or_null("../Player"),
		get_node_or_null("../../Player"),
		get_node_or_null("../Character"),
		get_node_or_null("../../Character"),
		get_node_or_null("/root/Main/Player"),
		get_node_or_null("/root/Player"),
		get_tree().get_first_node_in_group("player"),
		get_tree().get_first_node_in_group("character")
	]
	
	for controller in potential_controllers:
		if controller and _is_valid_movement_controller(controller):
			movement_controller = controller
			if debug_mode:
				print("DualHandItemDisplayController: Auto-detected movement controller: ", controller.name)
			return
	
	if debug_mode:
		print("DualHandItemDisplayController: No movement controller found, manual assignment required")

func _is_valid_movement_controller(controller: Node) -> bool:
	# Check if the controller has dual-hand grabbing capabilities
	var has_dual_hand_capability = (
		("grabbing_arm_left" in controller and "grabbing_arm_right" in controller) or
		("grabbed_object_left" in controller and "grabbed_object_right" in controller) or
		"grabbed_object" in controller  # Single item fallback
	)
	
	if debug_mode and print_detection_info:
		print("Checking controller: ", controller.name)
		print("  Has grabbing_arm_left: ", "grabbing_arm_left" in controller)
		print("  Has grabbing_arm_right: ", "grabbing_arm_right" in controller)
		print("  Has grabbed_object: ", "grabbed_object" in controller)
		print("  Has dual hand capability: ", has_dual_hand_capability)
	
	return has_dual_hand_capability

func _update_item_displays() -> void:
	if not movement_controller or not left_hand_label or not right_hand_label:
		return
	
	# Update left hand
	var new_left_name = _get_left_hand_item_name()
	if new_left_name != current_left_item_name:
		_handle_item_change(new_left_name, true)  # true = left hand
	
	# Update right hand
	var new_right_name = _get_right_hand_item_name()
	if new_right_name != current_right_item_name:
		_handle_item_change(new_right_name, false)  # false = right hand

func _get_left_hand_item_name() -> String:
	if not movement_controller:
		return ""
	
	# Check if left hand is actively grabbing
	var is_grabbing_left = false
	if "grabbing_arm_left" in movement_controller:
		is_grabbing_left = movement_controller.get("grabbing_arm_left")
	
	# If not grabbing, return empty message
	if not is_grabbing_left:
		return empty_message if show_empty_message else ""
	
	# Get the grabbed object (your controller uses grabbed_object for left hand)
	var item = null
	if "grabbed_object" in movement_controller:
		item = movement_controller.get("grabbed_object")
	elif "grabbed_object_left" in movement_controller:
		item = movement_controller.get("grabbed_object_left")
	
	if debug_mode and print_detection_info:
		print("Left hand - grabbing: ", is_grabbing_left, ", item: ", item)
	
	if not item:
		return empty_message if show_empty_message else ""
	
	return _clean_node_name(item.name)

func _get_right_hand_item_name() -> String:
	if not movement_controller:
		return ""
	
	# Check if right hand is actively grabbing
	var is_grabbing_right = false
	if "grabbing_arm_right" in movement_controller:
		is_grabbing_right = movement_controller.get("grabbing_arm_right")
	
	# If not grabbing, return empty message
	if not is_grabbing_right:
		return empty_message if show_empty_message else ""
	
	# For right hand, we need to track what's being grabbed
	# Your current system only stores left hand grabs in grabbed_object
	# We'll need to extend this or track right hand grabs differently
	var item = null
	if "grabbed_object_right" in movement_controller:
		item = movement_controller.get("grabbed_object_right")
	
	if debug_mode and print_detection_info:
		print("Right hand - grabbing: ", is_grabbing_right, ", item: ", item)
	
	if not item:
		# If grabbing but no specific right hand object, show generic message
		if is_grabbing_right:
			return "Grabbed Item"
		return empty_message if show_empty_message else ""
	
	return _clean_node_name(item.name)

func _clean_node_name(node_name: String) -> String:
	# Convert camelCase to readable format
	# "BurgerPatty" -> "Burger Patty"
	# "BurgerPatty2" -> "Burger Patty 2"
	
	var result = ""
	for i in node_name.length():
		var char = node_name[i]
		if i > 0 and char.to_upper() == char and not char.is_valid_int():
			result += " "
		result += char
	
	# Add space before numbers
	var clean_name = ""
	for i in result.length():
		var char = result[i]
		if i > 0 and char.is_valid_int() and not result[i-1].is_valid_int():
			clean_name += " "
		clean_name += char
	
	return clean_name.strip_edges()

func _handle_item_change(new_name: String, is_left_hand: bool) -> void:
	if is_left_hand:
		current_left_item_name = new_name
		if animate_changes and left_tween:
			_animate_label_change(new_name, left_hand_label, left_tween)
		else:
			left_hand_label.text = new_name
	else:
		current_right_item_name = new_name
		if animate_changes and right_tween:
			_animate_label_change(new_name, right_hand_label, right_tween)
		else:
			right_hand_label.text = new_name

func _animate_label_change(new_text: String, label: Label, tween: Tween) -> void:
	if not tween:
		label.text = new_text
		return
	
	tween.kill()
	if label == left_hand_label:
		left_tween = create_tween()
		tween = left_tween
	else:
		right_tween = create_tween()
		tween = right_tween
	
	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, fade_duration * 0.5)
	
	# Scale effect
	if scale_on_change:
		tween.parallel().tween_property(label, "scale", Vector2(change_scale, change_scale), fade_duration * 0.5)
	
	# Change text and fade back in
	tween.tween_callback(func(): label.text = new_text)
	tween.tween_property(label, "modulate:a", 1.0, fade_duration * 0.5)
	
	# Reset scale
	if scale_on_change:
		tween.parallel().tween_property(label, "scale", Vector2.ONE, fade_duration * 0.5)

# Public interface for manual control
func set_left_hand_text(text: String) -> void:
	## Manually set the left hand label text
	if text != current_left_item_name:
		_handle_item_change(text, true)

func set_right_hand_text(text: String) -> void:
	## Manually set the right hand label text
	if text != current_right_item_name:
		_handle_item_change(text, false)

func force_update() -> void:
	## Force an immediate update of both displays
	_update_item_displays()

func set_update_frequency(frequency: float) -> void:
	## Change how often the displays update
	update_frequency = frequency
	if update_timer:
		update_timer.wait_time = frequency

# Helper functions for movement controller integration
func get_left_hand_grabbing_state() -> bool:
	if movement_controller and "grabbing_arm_left" in movement_controller:
		return movement_controller.get("grabbing_arm_left")
	return false

func get_right_hand_grabbing_state() -> bool:
	if movement_controller and "grabbing_arm_right" in movement_controller:
		return movement_controller.get("grabbing_arm_right")
	return false
