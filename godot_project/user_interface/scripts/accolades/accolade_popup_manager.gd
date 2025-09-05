extends Node2D
class_name AccoladePopupManager

## Shows accolade popup scenes above the mouse while hovering
## Automatically applies to all nodes in the "accolade" group

# Configuration
const POPUP_OFFSET: Vector2 = Vector2(0, -64)  # Offset above mouse cursor
const FADE_DURATION: float = 0.15               # Duration for fade in/out

# Popup state
var popup_node: Control
var fade_tween: Tween
var current_hovered_accolade: Control = null
var popup_scene: PackedScene

func _ready() -> void:
	# Create the shared popup node
	create_popup_node()
	
	# Set up all accolades
	setup_accolades()

func create_popup_node() -> void:
	# Load the popup scene
	popup_scene = load("res://user_interface/scenes/accolade_popup.tscn")
	if not popup_scene:
		push_error("Could not load accolade_popup.tscn")
		return
	
	# Instantiate the popup scene
	popup_node = popup_scene.instantiate()
	popup_node.visible = false
	popup_node.modulate.a = 0.0
	popup_node.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't interfere with mouse
	
	# Add to scene tree at root level to avoid clipping
	get_tree().current_scene.call_deferred("add_child", popup_node)

func setup_accolades() -> void:
	var accolades = get_tree().get_nodes_in_group("accolades")
	
	for accolade in accolades:
		if accolade is Control:
			setup_single_accolade(accolade)

func setup_single_accolade(accolade: Control) -> void:
	# Enable mouse detection
	accolade.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect hover signals
	accolade.mouse_entered.connect(_on_accolade_mouse_entered.bind(accolade))
	accolade.mouse_exited.connect(_on_accolade_mouse_exited.bind(accolade))

func _process(_delta: float) -> void:
	if popup_node and popup_node.visible and current_hovered_accolade:
		# Update popup position to follow mouse
		var mouse_pos = get_global_mouse_position()
		popup_node.global_position = mouse_pos + POPUP_OFFSET

func _on_accolade_mouse_entered(accolade: Control) -> void:
	current_hovered_accolade = accolade
	show_popup()

func _on_accolade_mouse_exited(accolade: Control) -> void:
	if current_hovered_accolade == accolade:
		current_hovered_accolade = null
		hide_popup()

func show_popup() -> void:
	if not popup_node:
		return
	
	# Cancel any existing fade
	if fade_tween:
		fade_tween.kill()
	
	# Position popup above mouse
	var mouse_pos = get_global_mouse_position()
	popup_node.global_position = mouse_pos + POPUP_OFFSET - (popup_node.size / 2)
	popup_node.visible = true
	
	# Fade in
	fade_tween = create_tween()
	fade_tween.tween_property(popup_node, "modulate:a", 1.0, FADE_DURATION)
	fade_tween.set_ease(Tween.EASE_OUT)

func hide_popup() -> void:
	if not popup_node:
		return
	
	# Cancel any existing fade
	if fade_tween:
		fade_tween.kill()
	
	# Fade out
	fade_tween = create_tween()
	fade_tween.tween_property(popup_node, "modulate:a", 0.0, FADE_DURATION)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_callback(func(): popup_node.visible = false)

func _exit_tree() -> void:
	# Clean up popup node when this manager is removed
	if popup_node and is_instance_valid(popup_node):
		popup_node.queue_free()
