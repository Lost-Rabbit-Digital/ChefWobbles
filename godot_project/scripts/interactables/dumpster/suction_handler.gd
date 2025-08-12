class_name SuctionHandler
extends Node
## Handles the suction effect that draws objects toward the disposal area
##
## Creates auto-aim functionality by smoothly tweening objects from the suction
## area into the disposal area with bouncy, natural motion.

## Signals
signal object_reached_target(rigid_body: RigidBody3D)
signal suction_started(rigid_body: RigidBody3D)
signal suction_stopped(rigid_body: RigidBody3D)

## Export settings
@export_group("Suction Physics")
@export var velocity_dampening: float = 0.3
@export var gravity_reduction: float = 0.5
@export var linear_damp_override: float = 5.0
@export var angular_damp_override: float = 5.0

@export_group("Suction Animation")
@export var suction_duration: float = 1.5
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_BOUNCE
@export var target_offset: Vector3 = Vector3(0, 0.5, 0)
@export var add_rotation: bool = true
@export var rotation_strength: float = 1.0

@export_group("Filtering")
@export var ignored_group: String = "non_trashable"

## Internal references
var suction_area: Area3D
var trash_area: Area3D
var audio_manager: DumpsterAudioManager
var active_suctions: Dictionary = {}

func setup(suction_zone: Area3D, disposal_zone: Area3D, audio_mgr: DumpsterAudioManager) -> void:
	"""Initialize with required dependencies"""
	suction_area = suction_zone
	trash_area = disposal_zone
	audio_manager = audio_mgr

func on_body_entered(body: Node3D) -> void:
	"""Handle when a body enters the suction area"""
	if body is RigidBody3D and _should_suction_object(body):
		start_suction(body)

func on_body_exited(body: Node3D) -> void:
	"""Handle when a body exits the suction area"""
	if body is RigidBody3D:
		stop_suction(body)

func _should_suction_object(rigid_body: RigidBody3D) -> bool:
	"""Check if object should be suctioned (not in non_trashable group)"""
	return not rigid_body.is_in_group(ignored_group)

func start_suction(rigid_body: RigidBody3D) -> void:
	"""Begin suction effect for a RigidBody3D"""
	if active_suctions.has(rigid_body):
		return # Already being suctioned
	
	if not is_instance_valid(rigid_body):
		return
	
	# Create suction data
	var suction_data = SuctionData.new()
	suction_data.rigid_body = rigid_body
	suction_data.original_gravity_scale = rigid_body.gravity_scale
	suction_data.original_linear_damp = rigid_body.linear_damp
	suction_data.original_angular_damp = rigid_body.angular_damp
	
	# Modify physics for smoother suction
	rigid_body.gravity_scale *= gravity_reduction
	rigid_body.linear_damp = max(rigid_body.linear_damp, linear_damp_override)
	rigid_body.angular_damp = max(rigid_body.angular_damp, angular_damp_override)
	
	# Calculate target position
	var target_position = trash_area.global_position + target_offset
	suction_data.target_position = target_position
	
	# Create and configure tween
	suction_data.tween = get_tree().create_tween()
	suction_data.tween.set_ease(ease_type)
	suction_data.tween.set_trans(trans_type)
	
	# Store in active suctions
	active_suctions[rigid_body] = suction_data
	
	# Play whoosh sound when suction starts
	if audio_manager:
		var whoosh_player = audio_manager.play_whoosh_sound_on_object(rigid_body)
		suction_data.whoosh_audio_player = whoosh_player
	
	# Start animation
	_animate_suction(suction_data)
	
	# Emit signal
	suction_started.emit(rigid_body)

func _animate_suction(suction_data: SuctionData) -> void:
	"""Execute the suction animation"""
	var rigid_body = suction_data.rigid_body
	var target_pos = suction_data.target_position
	
	# Animate position
	suction_data.tween.tween_property(rigid_body, "global_position", target_pos, suction_duration)
	
	# Add rotation if enabled
	if add_rotation:
		var current_rotation = rigid_body.rotation
		var rotation_amount = rotation_strength
		var target_rotation = current_rotation + Vector3(
			randf_range(-rotation_amount, rotation_amount),
			randf_range(-rotation_amount * 2, rotation_amount * 2),
			randf_range(-rotation_amount, rotation_amount)
		)
		suction_data.tween.parallel().tween_property(
			rigid_body, "rotation", target_rotation, suction_duration
		)
	
	# Wait for completion or interruption
	await suction_data.tween.finished
	
	# Check if object reached target (wasn't interrupted)
	if active_suctions.has(rigid_body):
		_handle_suction_completion(suction_data)

func _handle_suction_completion(suction_data: SuctionData) -> void:
	"""Handle when suction animation completes naturally"""
	var rigid_body = suction_data.rigid_body
	
	# Clean up suction
	_cleanup_suction(rigid_body)
	
	# Signal that object reached target for disposal
	object_reached_target.emit(rigid_body)

func stop_suction(rigid_body: RigidBody3D) -> void:
	"""Stop suction effect and restore physics"""
	if not active_suctions.has(rigid_body):
		return
	
	var suction_data = active_suctions[rigid_body]
	
	# Kill the tween
	if suction_data.tween and suction_data.tween.is_valid():
		suction_data.tween.kill()
	
	# Restore physics if object still exists
	if is_instance_valid(rigid_body):
		rigid_body.gravity_scale = suction_data.original_gravity_scale
		rigid_body.linear_damp = suction_data.original_linear_damp
		rigid_body.angular_damp = suction_data.original_angular_damp
	
	# Clean up
	_cleanup_suction(rigid_body)
	
	# Emit signal
	suction_stopped.emit(rigid_body)

func _cleanup_suction(rigid_body: RigidBody3D) -> void:
	"""Clean up suction tracking data"""
	active_suctions.erase(rigid_body)

## Public API
func get_active_count() -> int:
	"""Get number of objects currently being suctioned"""
	return active_suctions.size()

func is_object_suctioned(rigid_body: RigidBody3D) -> bool:
	"""Check if specific object is being suctioned"""
	return active_suctions.has(rigid_body)

func cancel_all() -> void:
	"""Cancel all active suctions"""
	var objects_to_cancel = active_suctions.keys()
	for obj in objects_to_cancel:
		stop_suction(obj)

func get_suction_progress(rigid_body: RigidBody3D) -> float:
	"""Get suction progress for specific object (0.0 to 1.0)"""
	if not active_suctions.has(rigid_body):
		return 0.0
	
	var suction_data = active_suctions[rigid_body]
	if not suction_data.tween or not suction_data.tween.is_valid():
		return 0.0
	
	# This is approximate since Godot doesn't expose tween progress directly
	var start_pos = suction_data.rigid_body.global_position
	var target_pos = suction_data.target_position
	var distance_to_target = start_pos.distance_to(target_pos)
	var max_distance = 10.0 # Approximate max suction distance
	
	return 1.0 - (distance_to_target / max_distance)

## Internal data class
class SuctionData:
	var rigid_body: RigidBody3D
	var tween: Tween
	var target_position: Vector3
	var original_gravity_scale: float
	var original_linear_damp: float
	var original_angular_damp: float
	var whoosh_audio_player: AudioStreamPlayer3D
