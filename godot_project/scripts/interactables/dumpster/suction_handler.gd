class_name SuctionHandler
extends Node
## Handles the suction effect that draws objects toward the disposal area
##
## Creates auto-aim functionality by smoothly tweening objects from the suction
## area into the disposal area with bouncy, natural motion. Includes lid detection
## to enable/disable suction based on dumpster open/closed state.

## Signals
signal object_reached_target(rigid_body: RigidBody3D)
signal suction_started(rigid_body: RigidBody3D)
signal suction_stopped(rigid_body: RigidBody3D)
signal dumpster_opened()
signal dumpster_closed()

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
@export var lid_group: String = "dumpster_lid"

@export_group("Lid Detection")
@export var check_for_lids: bool = true
@export var debug_lid_status: bool = false

## Internal references
var suction_area: Area3D
var trash_area: Area3D
var audio_manager: DumpsterAudioManager
var active_suctions: Dictionary = {}
var lids_in_area: Array[RigidBody3D] = []
var _dumpster_open_state: bool = true

func setup(suction_zone: Area3D, disposal_zone: Area3D, audio_mgr: DumpsterAudioManager) -> void:
	"""Initialize with required dependencies"""
	suction_area = suction_zone
	trash_area = disposal_zone
	audio_manager = audio_mgr

func on_body_entered(body: Node3D) -> void:
	"""Handle when a body enters the suction area"""
	if body is RigidBody3D:
		if _is_lid(body):
			_add_lid_to_area(body)
		elif _should_suction_object(body):
			start_suction(body)

func on_body_exited(body: Node3D) -> void:
	"""Handle when a body exits the suction area"""
	if body is RigidBody3D:
		if _is_lid(body):
			_remove_lid_from_area(body)
		else:
			stop_suction(body)

func _should_suction_object(rigid_body: RigidBody3D) -> bool:
	"""Check if object should be suctioned (not in non_trashable group and dumpster is open)"""
	if rigid_body.is_in_group(ignored_group):
		return false
	
	if check_for_lids and not _dumpster_open_state:
		if debug_lid_status:
			print("SuctionHandler: Suction blocked - dumpster is closed")
		return false
	
	return true

func _is_lid(rigid_body: RigidBody3D) -> bool:
	"""Check if object is a dumpster lid"""
	return rigid_body.is_in_group(lid_group)

func start_suction(rigid_body: RigidBody3D) -> void:
	"""Begin suction effect for a RigidBody3D"""
	if active_suctions.has(rigid_body):
		return # Already being suctioned
	
	if not is_instance_valid(rigid_body):
		return
	
	# Double-check dumpster is open before starting suction
	if check_for_lids and not _dumpster_open_state:
		if debug_lid_status:
			print("SuctionHandler: Cannot start suction - dumpster is closed")
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

func _add_lid_to_area(lid: RigidBody3D) -> void:
	"""Add lid to tracking and update dumpster state"""
	if not lids_in_area.has(lid):
		lids_in_area.append(lid)
		_update_dumpster_state()
		
		if debug_lid_status:
			print("SuctionHandler: Lid entered area - ", lid.name)

func _remove_lid_from_area(lid: RigidBody3D) -> void:
	"""Remove lid from tracking and update dumpster state"""
	if lids_in_area.has(lid):
		lids_in_area.erase(lid)
		_update_dumpster_state()
		
		if debug_lid_status:
			print("SuctionHandler: Lid exited area - ", lid.name)

func _update_dumpster_state() -> void:
	"""Update dumpster open/closed state based on lid presence"""
	var was_open = _dumpster_open_state
	_dumpster_open_state = lids_in_area.is_empty()
	
	# Emit signals when state changes
	if was_open != _dumpster_open_state:
		if _dumpster_open_state:
			dumpster_opened.emit()
			if debug_lid_status:
				print("SuctionHandler: Dumpster opened - suction enabled")
		else:
			dumpster_closed.emit()
			_handle_dumpster_closed()
			if debug_lid_status:
				print("SuctionHandler: Dumpster closed - suction disabled")

func _handle_dumpster_closed() -> void:
	"""Handle when dumpster closes - stop all active suctions"""
	if not active_suctions.is_empty():
		var objects_to_stop = active_suctions.keys()
		for obj in objects_to_stop:
			stop_suction(obj)
		
		if debug_lid_status:
			print("SuctionHandler: Stopped %d active suctions due to lid closure" % objects_to_stop.size())

## Public API
func get_active_count() -> int:
	"""Get number of objects currently being suctioned"""
	return active_suctions.size()

func is_object_suctioned(rigid_body: RigidBody3D) -> bool:
	"""Check if specific object is being suctioned"""
	return active_suctions.has(rigid_body)

func is_dumpster_open() -> bool:
	"""Check if dumpster is open (no lids in suction area)"""
	return _dumpster_open_state

func get_lid_count() -> int:
	"""Get number of lids currently in suction area"""
	return lids_in_area.size()

func get_lids_in_area() -> Array[RigidBody3D]:
	"""Get array of lids currently in suction area"""
	return lids_in_area.duplicate()

func force_dumpster_state(open: bool) -> void:
	"""Force dumpster open/closed state (for testing/special cases)"""
	var was_open = _dumpster_open_state
	_dumpster_open_state = open
	
	if was_open != _dumpster_open_state:
		if _dumpster_open_state:
			dumpster_opened.emit()
		else:
			dumpster_closed.emit()
			_handle_dumpster_closed()

func refresh_lid_detection() -> void:
	"""Manually refresh lid detection (useful after scene changes)"""
	var old_lid_count = lids_in_area.size()
	lids_in_area.clear()
	
	# Re-scan suction area for lids
	if suction_area:
		for body in suction_area.get_overlapping_bodies():
			if body is RigidBody3D and _is_lid(body):
				lids_in_area.append(body)
	
	_update_dumpster_state()
	
	if debug_lid_status:
		print("SuctionHandler: Refreshed lid detection - found %d lids (was %d)" % [lids_in_area.size(), old_lid_count])

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
