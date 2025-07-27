@tool
class_name BaseInteractable
extends RigidBody3D

## Core backend class for all interactable objects in Chef Wobbles
## Provides common functionality for pickup, physics, and interaction
## This is a backend class - never directly instantiate in scenes

# Signals following Godot naming conventions
signal picked_up(by_player: Node)
signal dropped(by_player: Node)
signal interaction_state_changed(new_state: InteractionState)

# Interaction states enum
enum InteractionState {
	FREE,           # Available for interaction
	HELD,           # Being held by player
	BEING_PROCESSED,  # Being processed (cooking, cutting, etc.)
	LOCKED          # Cannot be interacted with
}

# Export groups for editor organization
@export_group("Interaction Settings")
@export var interaction_prompt: String = "Pick up"
@export var can_be_picked_up: bool = true
@export var can_be_thrown: bool = true
@export var max_throw_force: float = 20.0

@export_group("Physics Settings")
@export var pickup_mass_override: float = 0.0  # 0 = use current mass
@export var held_physics_enabled: bool = false
@export var drop_impulse_multiplier: float = 1.0

# Public state variables
var current_state: InteractionState = InteractionState.FREE
var holding_player: Node = null

# Private variables - prefixed with underscore
var _original_collision_layer: int
var _original_collision_mask: int

# Node references using @onready for proper initialization
@onready var mesh_instance: MeshInstance3D = _find_mesh_instance()
@onready var collision_shape: CollisionShape3D = _find_collision_shape()

func _ready() -> void:
	_setup_base_interactable()
	_setup_physics()
	_setup_collision_monitoring()

func _setup_base_interactable() -> void:
	"""Initialize base interactable properties"""
	# Store original collision settings
	_original_collision_layer = collision_layer
	_original_collision_mask = collision_mask
	
	# Connect base signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Call virtual setup method for derived classes
	_setup_derived_class()

func _setup_physics() -> void:
	"""Configure physics properties for interactable objects"""
	# Enable contact monitoring for interaction detection
	contact_monitor = true
	max_contacts_reported = 10
	
	# Set reasonable default physics
	if mass <= 0:
		mass = 1.0

func _setup_collision_monitoring() -> void:
	"""Setup collision layers for interaction system"""
	# Default interactable layer setup
	if collision_layer == 1:  # If using default layer
		collision_layer = 4  # Move to interactables layer
	
	# Allow interaction with world and stations
	collision_mask = 1 + 2  # World + Stations

# Virtual methods for derived classes - using proper Godot virtual pattern
func _setup_derived_class() -> void:
	"""Override in derived classes for specific setup"""
	pass

func _on_interaction_started() -> void:
	"""Override for specific interaction behavior"""
	pass

func _on_interaction_ended() -> void:
	"""Override for specific interaction cleanup"""
	pass

func _on_body_entered(body: Node) -> void:
	"""Handle collision with other bodies - override for specific behavior"""
	pass

func _on_body_exited(body: Node) -> void:
	"""Handle leaving collision with other bodies - override for specific behavior"""
	pass

# Public interaction API - clear method names avoiding conflicts
func can_interact() -> bool:
	"""Check if object can currently be interacted with"""
	return current_state == InteractionState.FREE and can_be_picked_up

func pickup_by_player(player: Node) -> bool:
	"""Handle being picked up by a player"""
	if not can_interact():
		return false
	
	holding_player = player
	_change_state(InteractionState.HELD)
	
	# Disable physics while held
	if not held_physics_enabled:
		freeze = true
	
	# Override mass if specified
	if pickup_mass_override > 0:
		mass = pickup_mass_override
	
	_on_interaction_started()
	picked_up.emit(player)
	
	return true

func drop_by_player(player: Node, drop_position: Vector3, throw_velocity: Vector3 = Vector3.ZERO) -> void:
	"""Handle being dropped by a player"""
	if holding_player != player:
		return
	
	# Restore physics
	freeze = false
	global_position = drop_position
	
	# Apply throw velocity if provided
	if can_be_thrown and throw_velocity.length() > 0:
		var clamped_velocity = throw_velocity.limit_length(max_throw_force)
		linear_velocity = clamped_velocity * drop_impulse_multiplier
	
	# Reset state
	holding_player = null
	_change_state(InteractionState.FREE)
	
	_on_interaction_ended()
	dropped.emit(player)

func lock_interaction(reason: String = "") -> void:
	"""Lock object from interaction"""
	_change_state(InteractionState.LOCKED)

func unlock_interaction() -> void:
	"""Unlock object for interaction"""
	if current_state == InteractionState.LOCKED:
		_change_state(InteractionState.FREE)

func is_being_held() -> bool:
	"""Check if currently being held by player"""
	return current_state == InteractionState.HELD

func is_currently_processing() -> bool:
	"""Check if currently being processed at a station"""
	return current_state == InteractionState.BEING_PROCESSED

# Internal methods - prefixed with underscore
func _change_state(new_state: InteractionState) -> void:
	"""Internal state change with validation"""
	if current_state != new_state:
		current_state = new_state
		interaction_state_changed.emit(new_state)

func _find_mesh_instance() -> MeshInstance3D:
	"""Find MeshInstance3D in node tree"""
	return _find_node_of_type(MeshInstance3D) as MeshInstance3D

func _find_collision_shape() -> CollisionShape3D:
	"""Find CollisionShape3D in node tree"""
	return _find_node_of_type(CollisionShape3D) as CollisionShape3D

func _find_node_of_type(type: Variant) -> Node:
	"""Recursively find node of specific type"""
	if is_instance_of(self, type):
		return self
	
	for child in get_children():
		if is_instance_of(child, type):
			return child
		
		var result = _find_node_in_children(child, type)
		if result:
			return result
	
	return null

func _find_node_in_children(node: Node, type: Variant) -> Node:
	"""Helper for recursive node finding"""
	for child in node.get_children():
		if is_instance_of(child, type):
			return child
		
		var result = _find_node_in_children(child, type)
		if result:
			return result
	
	return null
