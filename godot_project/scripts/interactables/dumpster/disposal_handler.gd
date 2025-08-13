class_name DisposalHandler
extends Node
## Handles the disposal animation and destruction of RigidBody3D objects
##
## Manages mesh shrinking animations, audio coordination, object cleanup,
## and delayed disposal for the dumpster disposal process.

## Signals
signal disposal_started(rigid_body: RigidBody3D)
signal disposal_completed(rigid_body: RigidBody3D)
signal disposal_failed(rigid_body: RigidBody3D, reason: String)
signal object_dropped_in_dumpster(rigid_body: RigidBody3D)

## Export settings
@export_group("Disposal Animation")
@export var shrink_duration: float = 0.8
@export var min_object_size: float = 0.01
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK

@export_group("Timing")
@export var min_wait_time: float = 0.5
@export var max_wait_time: float = 2.5
@export var plop_sound_timing: float = 0.9  # At 90% of shrinking animation

@export_group("Filtering")
@export var ignored_group: String = "non_trashable"

## Internal references
var trash_area: Area3D
var audio_manager: DumpsterAudioManager
var active_disposals: Dictionary = {}
var pending_disposals: Dictionary = {}

func setup(area: Area3D, audio_mgr: DumpsterAudioManager) -> void:
	"""Initialize with required dependencies"""
	trash_area = area
	audio_manager = audio_mgr

func on_body_entered(body: Node3D) -> void:
	"""Handle when a body enters the disposal area"""
	if body is RigidBody3D and _should_dispose_object(body):
		attempt_disposal(body)

func _should_dispose_object(rigid_body: RigidBody3D) -> bool:
	"""Check if object should be disposed (not in non_trashable group)"""
	return not rigid_body.is_in_group(ignored_group)

func attempt_disposal(rigid_body: RigidBody3D) -> void:
	"""Attempt to dispose of a RigidBody3D with immediate start"""
	_start_disposal_with_delay(rigid_body, 0.0)

func force_dispose(rigid_body: RigidBody3D) -> void:
	"""Force disposal from suction system with random delay"""
	var wait_time = randf_range(min_wait_time, max_wait_time)
	_start_disposal_with_delay(rigid_body, wait_time)

func _start_disposal_with_delay(rigid_body: RigidBody3D, delay: float) -> void:
	"""Begin disposal process with optional delay"""
	if active_disposals.has(rigid_body) or pending_disposals.has(rigid_body):
		return # Already being processed
	
	if not is_instance_valid(rigid_body):
		disposal_failed.emit(rigid_body, "Invalid object reference")
		return
	
	# Find mesh instances to animate
	var mesh_instances = _find_mesh_instances(rigid_body)
	if mesh_instances.is_empty():
		disposal_failed.emit(rigid_body, "No MeshInstance3D children found")
		return
	
	if delay > 0.0:
		# Start delay period - object is "dropped" in dumpster
		_start_delay_period(rigid_body, mesh_instances, delay)
	else:
		# Start disposal immediately
		_start_disposal_process(rigid_body, mesh_instances)

func _start_delay_period(rigid_body: RigidBody3D, mesh_instances: Array[MeshInstance3D], delay: float) -> void:
	"""Handle the delay period before disposal starts"""
	# Store pending disposal data
	var pending_data = PendingDisposalData.new()
	pending_data.rigid_body = rigid_body
	pending_data.mesh_instances = mesh_instances
	pending_data.delay_timer = get_tree().create_timer(delay)
	
	pending_disposals[rigid_body] = pending_data
	
	# Emit dropped signal
	object_dropped_in_dumpster.emit(rigid_body)
	
	# Wait for delay to complete
	await pending_data.delay_timer.timeout
	
	# Check if still valid and not cancelled
	if pending_disposals.has(rigid_body) and is_instance_valid(rigid_body):
		pending_disposals.erase(rigid_body)
		_start_disposal_process(rigid_body, mesh_instances)

func _start_disposal_process(rigid_body: RigidBody3D, mesh_instances: Array[MeshInstance3D]) -> void:
	"""Begin the disposal animation sequence"""
	if not is_instance_valid(rigid_body):
		disposal_failed.emit(rigid_body, "Object invalid at disposal start")
		return
	
	# Store original scales
	var original_scales = {}
	for mesh in mesh_instances:
		original_scales[mesh] = mesh.scale
	
	# Create disposal data
	var disposal_data = DisposalData.new()
	disposal_data.rigid_body = rigid_body
	disposal_data.mesh_instances = mesh_instances
	disposal_data.original_scales = original_scales
	disposal_data.tween = get_tree().create_tween()
	
	# Configure tween
	disposal_data.tween.set_ease(ease_type)
	disposal_data.tween.set_trans(trans_type)
	
	# Store in active disposals
	active_disposals[rigid_body] = disposal_data
	
	# Start the process
	disposal_started.emit(rigid_body)
	_animate_disposal(disposal_data)

func _animate_disposal(disposal_data: DisposalData) -> void:
	"""Execute the disposal animation with timed plop sound"""
	var rigid_body = disposal_data.rigid_body
	
	# Start shrinking audio
	if audio_manager:
		var audio_player = audio_manager.play_shrinking_sound_on_object(rigid_body)
		disposal_data.audio_player = audio_player
		
		# Use audio length for animation duration if available
		if audio_player and audio_player.stream:
			var audio_duration = audio_player.stream.get_length()
			disposal_data.actual_duration = audio_duration
		else:
			disposal_data.actual_duration = shrink_duration
	else:
		disposal_data.actual_duration = shrink_duration
	
	# Schedule plop sound at 90% completion
	_schedule_plop_sound(disposal_data)
	
	# Animate all mesh instances
	var tweens_added = 0
	for mesh in disposal_data.mesh_instances:
		if is_instance_valid(mesh) and disposal_data.original_scales.has(mesh):
			var original_scale = disposal_data.original_scales[mesh]
			var target_scale = original_scale * min_object_size
			disposal_data.tween.parallel().tween_property(
				mesh, "scale", target_scale, disposal_data.actual_duration
			)
			tweens_added += 1
	
	if tweens_added == 0:
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "No meshes could be animated")
		return
	
	# Wait for animation completion
	await disposal_data.tween.finished
	
	# Complete disposal
	_complete_disposal(disposal_data)

func _schedule_plop_sound(disposal_data: DisposalData) -> void:
	"""Schedule the plop sound to play at specified timing"""
	if not audio_manager:
		return
	
	var plop_delay = disposal_data.actual_duration * plop_sound_timing
	var plop_timer = get_tree().create_timer(plop_delay)
	disposal_data.plop_timer = plop_timer
	
	# Wait for the timer and play plop sound
	plop_timer.timeout.connect(func(): _play_plop_sound(disposal_data), CONNECT_ONE_SHOT)

func _play_plop_sound(disposal_data: DisposalData) -> void:
	"""Play the plop sound if disposal is still active"""
	if active_disposals.has(disposal_data.rigid_body) and audio_manager:
		audio_manager.play_disposal_sound()

func _complete_disposal(disposal_data: DisposalData) -> void:
	"""Complete the disposal process"""
	var rigid_body = disposal_data.rigid_body
	
	if not is_instance_valid(rigid_body):
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "Object invalid at completion")
		return
	
	# Emit completion signal
	disposal_completed.emit(rigid_body)
	
	# Clean up and destroy object
	_cleanup_disposal(rigid_body)
	rigid_body.queue_free()

func _cleanup_disposal(rigid_body: RigidBody3D) -> void:
	"""Clean up disposal tracking data"""
	if active_disposals.has(rigid_body):
		var disposal_data = active_disposals[rigid_body]
		if disposal_data.tween and disposal_data.tween.is_valid():
			disposal_data.tween.kill()
		active_disposals.erase(rigid_body)
	
	if pending_disposals.has(rigid_body):
		pending_disposals.erase(rigid_body)

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	"""Recursively find all MeshInstance3D nodes"""
	var meshes: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		meshes.append(node)
	
	for child in node.get_children():
		meshes.append_array(_find_mesh_instances(child))
	
	return meshes

## Public API
func get_active_count() -> int:
	"""Get number of active disposals"""
	return active_disposals.size()

func get_pending_count() -> int:
	"""Get number of pending disposals (waiting)"""
	return pending_disposals.size()

func cancel_disposal(rigid_body: RigidBody3D) -> void:
	"""Cancel specific disposal"""
	if active_disposals.has(rigid_body):
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "Disposal cancelled")
	elif pending_disposals.has(rigid_body):
		pending_disposals.erase(rigid_body)
		disposal_failed.emit(rigid_body, "Pending disposal cancelled")

func cancel_all() -> void:
	"""Cancel all active and pending disposals"""
	var objects_to_cancel = active_disposals.keys() + pending_disposals.keys()
	for obj in objects_to_cancel:
		cancel_disposal(obj)

## Internal data classes
class DisposalData:
	var rigid_body: RigidBody3D
	var mesh_instances: Array[MeshInstance3D]
	var original_scales: Dictionary
	var tween: Tween
	var audio_player: AudioStreamPlayer3D
	var actual_duration: float
	var plop_timer: SceneTreeTimer

class PendingDisposalData:
	var rigid_body: RigidBody3D
	var mesh_instances: Array[MeshInstance3D]
	var delay_timer: SceneTreeTimer
