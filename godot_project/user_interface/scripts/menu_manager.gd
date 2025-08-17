class_name MenuManager
extends Control

# Static instance for global access
static var instance: MenuManager

@export var slide_duration: float = 0.8

# Array of all managed menus - assign in editor
@export var managed_menus: Array[Control] = []

# Dictionary to track menu states and original positions
var menu_data: Dictionary = {}
var currently_active_menu: String = ""

# Static interface
static func show_menu(menu_name: String):
	if instance:
		instance.internal_show_menu(menu_name)
	else:
		push_error("MenuManager instance not found. Make sure it's in the scene tree.")

static func hide_menu(menu_name: String):
	if instance:
		instance.internal_hide_menu(menu_name)
	else:
		push_error("MenuManager instance not found.")

static func hide_all():
	if instance:
		instance.hide_all_menus()
	else:
		push_error("MenuManager instance not found.")

static func toggle(menu_name: String):
	if instance:
		instance.toggle_menu(menu_name)
	else:
		push_error("MenuManager instance not found.")

static func get_active_menu() -> String:
	if instance:
		return instance.currently_active_menu
	return ""

func _ready() -> void:
	# Register this instance for static access
	MenuManager.instance = self
	
	# Initialize all managed menus
	_initialize_menus()

func _exit_tree() -> void:
	# Clean up static reference
	if MenuManager.instance == self:
		MenuManager.instance = null

func _initialize_menus() -> void:
	"""Setup all managed menus with their original positions"""
	for menu in managed_menus:
		if not menu:
			continue
			
		var menu_name = menu.name.to_lower()
		
		# Store original position and setup initial state
		menu_data[menu_name] = {
			"control": menu,
			"original_position": menu.position,
			"is_sliding": false
		}
		
		# Move menu off-screen to the right
		menu.position.x = get_viewport().get_visible_rect().size.x
		menu.visible = false
		
		print("Initialized menu: ", menu_name)

func internal_show_menu(menu_name: String) -> void:
	"""Show specified menu and hide all others"""
	var target_menu_name = menu_name.to_lower()
	
	if not menu_data.has(target_menu_name):
		push_error("Menu '" + menu_name + "' not found in managed menus")
		return
	
	var target_menu_data = menu_data[target_menu_name]
	
	# Don't show if already sliding in
	if target_menu_data.is_sliding:
		return
	
	# Hide all other menus first
	_hide_all_except(target_menu_name)
	
	# Show the target menu
	await _slide_in_menu(target_menu_name)
	currently_active_menu = target_menu_name

func internal_hide_menu(menu_name: String) -> void:
	"""Hide specified menu"""
	var target_menu_name = menu_name.to_lower()
	
	if not menu_data.has(target_menu_name):
		push_error("Menu '" + menu_name + "' not found in managed menus")
		return
	
	await _slide_out_menu(target_menu_name)
	
	if currently_active_menu == target_menu_name:
		currently_active_menu = ""

func hide_all_menus() -> void:
	"""Hide all managed menus"""
	for menu_name in menu_data.keys():
		if menu_data[menu_name].control.visible:
			_slide_out_menu(menu_name)
	
	currently_active_menu = ""

func toggle_menu(menu_name: String) -> void:
	"""Toggle specified menu visibility"""
	var target_menu_name = menu_name.to_lower()
	
	if not menu_data.has(target_menu_name):
		push_error("Menu '" + menu_name + "' not found in managed menus")
		return
	
	var menu_control = menu_data[target_menu_name].control
	
	if menu_control.visible and not menu_data[target_menu_name].is_sliding:
		hide_menu(target_menu_name)
	else:
		show_menu(target_menu_name)

func _hide_all_except(exception_menu: String) -> void:
	"""Hide all menus except the specified one"""
	for menu_name in menu_data.keys():
		if menu_name != exception_menu and menu_data[menu_name].control.visible:
			_slide_out_menu(menu_name)

func _slide_in_menu(menu_name: String) -> void:
	"""Slide menu in from the right"""
	var menu_info = menu_data[menu_name]
	var menu_control = menu_info.control
	
	menu_info.is_sliding = true
	menu_control.visible = true
	
	# Create slide-in animation
	var slide_tween = create_tween()
	slide_tween.set_ease(Tween.EASE_OUT)
	slide_tween.set_trans(Tween.TRANS_CUBIC)
	
	slide_tween.tween_property(
		menu_control, 
		"position", 
		menu_info.original_position, 
		slide_duration
	)
	
	await slide_tween.finished
	menu_info.is_sliding = false

func _slide_out_menu(menu_name: String) -> void:
	"""Slide menu out to the right"""
	var menu_info = menu_data[menu_name]
	var menu_control = menu_info.control
	
	if not menu_control.visible:
		return
	
	menu_info.is_sliding = true
	
	# Create slide-out animation
	var slide_tween = create_tween()
	slide_tween.set_ease(Tween.EASE_IN)
	slide_tween.set_trans(Tween.TRANS_CUBIC)
	
	var screen_width = get_viewport().get_visible_rect().size.x
	slide_tween.tween_property(
		menu_control, 
		"position:x", 
		screen_width, 
		slide_duration
	)
	
	await slide_tween.finished
	menu_control.visible = false
	menu_info.is_sliding = false

func _input(event: InputEvent) -> void:
	"""Handle global input like ESC key"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and currently_active_menu != "":
			hide_menu(currently_active_menu)

# Utility functions for getting menu info
func is_menu_visible(menu_name: String) -> bool:
	"""Check if a specific menu is visible"""
	var target_menu_name = menu_name.to_lower()
	if menu_data.has(target_menu_name):
		return menu_data[target_menu_name].control.visible
	return false

func is_any_menu_sliding() -> bool:
	"""Check if any menu is currently sliding"""
	for menu_info in menu_data.values():
		if menu_info.is_sliding:
			return true
	return false

func get_managed_menu_names() -> Array[String]:
	"""Get list of all managed menu names"""
	var names: Array[String] = []
	for name in menu_data.keys():
		names.append(name)
	return names
