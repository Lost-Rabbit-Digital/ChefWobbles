class_name DumpsterSystem
extends Node3D
## A dumpster system that shrinks and disposes of RigidBody3D objects with audio feedback
##
## This system detects when RigidBody3D objects enter the trash area, plays a shrinking
## animation, triggers random audio feedback, and properly disposes of the objects.

## Emitted when an object begins disposal process
signal object_disposal_started(rigid_body: RigidBody3D)
## Emitted when disposal animation completes
signal object_disposal_completed(rigid_body: RigidBody3D)
## Emitted when disposal process fails
signal disposal_failed(rigid_body: RigidBody3D, reason: String)

## Configuration for disposal behavior
@export_group("Disposal Settings")
@export var shrink_duration: float = 0.8
@export var disposal_delay: float = 0.2
@export var min_object_size: float = 0.01
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK

@export_group("Audio Settings")
@export var disposal_sounds: Array[AudioStream] = []
@export var shrinking_sounds: Array[AudioStream] = []
@export var audio_volume_db: float = 0.0
@export var audio_pitch_scale: float = 1.0
@export var pitch_variation: float = 0.1

@export_group("Detection Settings")
@export var trash_area_collision_mask: int = 1

## Internal components
@onready var trash_area: Area3D = $Base/TrashArea
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

## Track RigidBody3D objects currently being disposed
var disposing_objects: Dictionary = {}

func _ready() -> void:
	_setup_components()
	_connect_signals()
	_validate_setup()

func _setup_components() -> void:
	"""Configure trash area detection and audio components"""
	if trash_area:
		trash_area.collision_mask = trash_area_collision_mask
		trash_area.monitoring = true
		trash_area.monitorable = false
	
	if audio_player:
		audio_player.volume_db = audio_volume_db
		audio_player.pitch_scale = audio_pitch_scale
		audio_player.max_distance = 20.0
		audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

func _connect_signals() -> void:
	"""Connect trash area signal for RigidBody3D detection"""
	if trash_area:
		trash_area.body_entered.connect(_on_trash_area_body_entered)

func _validate_setup() -> void:
	"""Validate that all required components exist"""
	if not trash_area:
		push_error("DumpsterSystem: TrashArea node not found")
	
	if not audio_player:
		push_warning("DumpsterSystem: AudioStreamPlayer3D not found - no audio feedback")
	
	if disposal_sounds.is_empty():
		push_warning("DumpsterSystem: No disposal sounds assigned")
	
	if shrinking_sounds.is_empty():
		push_warning("DumpsterSystem: No shrinking sounds assigned")

func _on_trash_area_body_entered(body: Node3D) -> void:
	"""Handle when a RigidBody3D enters trash area"""
	print("DumpsterSystem: Body entered trash area: ", body.name, " Type: ", body.get_class())
	if body is RigidBody3D:
		print("DumpsterSystem: Confirmed RigidBody3D, attempting disposal")
		_attempt_disposal(body)
	else:
		print("DumpsterSystem: Not a RigidBody3D, ignoring")

func _attempt_disposal(rigid_body: RigidBody3D) -> void:
	"""Attempt to dispose of a RigidBody3D"""
	print("DumpsterSystem: Attempting disposal of: ", rigid_body.name)
	
	if disposing_objects.has(rigid_body):
		print("DumpsterSystem: Object already being disposed: ", rigid_body.name)
		return # Already being disposed
	
	disposing_objects[rigid_body] = true
	print("DumpsterSystem: Added to disposing objects, starting disposal")
	_start_disposal(rigid_body)

func _start_disposal(rigid_body: RigidBody3D) -> void:
	"""Begin disposal process for RigidBody3D by shrinking its mesh instances"""
	print("DumpsterSystem: Starting disposal for: ", rigid_body.name)
	
	if not is_instance_valid(rigid_body):
		print("DumpsterSystem: RigidBody3D is invalid")
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "Invalid object reference")
		return
	
	# Find all MeshInstance3D children
	var mesh_instances = _find_mesh_instances(rigid_body)
	print("DumpsterSystem: Found ", mesh_instances.size(), " mesh instances")
	
	if mesh_instances.is_empty():
		print("DumpsterSystem: No MeshInstance3D children found for: ", rigid_body.name)
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "No MeshInstance3D children found")
		return
	
	# Store original scales for all mesh instances
	var mesh_data = {}
	for mesh_instance in mesh_instances:
		print("DumpsterSystem: Storing scale for mesh: ", mesh_instance.name, " scale: ", mesh_instance.scale)
		mesh_data[mesh_instance] = mesh_instance.scale
	
	# Create audio player for shrinking sound on the object
	var object_audio_player: AudioStreamPlayer3D = null
	if not shrinking_sounds.is_empty():
		print("DumpsterSystem: Creating audio player with ", shrinking_sounds.size(), " shrinking sounds")
		# Select random shrinking sound
		var random_shrink_sound = shrinking_sounds[randi() % shrinking_sounds.size()]
		
		object_audio_player = AudioStreamPlayer3D.new()
		object_audio_player.name = "ShrinkingAudioPlayer"
		object_audio_player.stream = random_shrink_sound
		object_audio_player.volume_db = audio_volume_db
		object_audio_player.max_distance = 15.0
		object_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		
		# Add pitch variation for shrinking sound too
		if pitch_variation > 0.0:
			var pitch_offset = randf_range(-pitch_variation, pitch_variation)
			object_audio_player.pitch_scale = audio_pitch_scale + pitch_offset
		else:
			object_audio_player.pitch_scale = audio_pitch_scale
		
		rigid_body.add_child(object_audio_player)
		print("DumpsterSystem: Audio player added to object")
	else:
		print("DumpsterSystem: No shrinking sounds available")
	
	# Create tween and bind it to the scene tree to prevent invalidation
	var tween = get_tree().create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)
	print("DumpsterSystem: Tween created")
	
	# Store tween, mesh data, and audio player in disposal tracking
	disposing_objects[rigid_body] = {
		"tween": tween,
		"mesh_instances": mesh_instances,
		"original_scales": mesh_data,
		"audio_player": object_audio_player
	}
	
	# Emit disposal started (but don't play audio yet)
	object_disposal_started.emit(rigid_body)
	print("DumpsterSystem: Starting animation sequence")
	
	# Start disposal sequence
	_animate_disposal(rigid_body, tween, mesh_instances, mesh_data)

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	"""Recursively find all MeshInstance3D nodes under a parent"""
	var mesh_instances: Array[MeshInstance3D] = []
	
	# Check if current node is a MeshInstance3D
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	# Recursively check all children
	for child in node.get_children():
		mesh_instances.append_array(_find_mesh_instances(child))
	
	return mesh_instances

func _animate_disposal(rigid_body: RigidBody3D, tween: Tween, mesh_instances: Array[MeshInstance3D], original_scales: Dictionary) -> void:
	"""Execute the disposal animation sequence on mesh instances"""
	print("DumpsterSystem: _animate_disposal called")
	
	# Get the object's audio player for shrinking sound
	var disposal_data = disposing_objects[rigid_body]
	var object_audio_player = disposal_data.get("audio_player", null)
	
	# Calculate shrink duration based on audio length (default to 0.8s if no audio)
	var actual_shrink_duration = shrink_duration
	if object_audio_player and object_audio_player.stream:
		actual_shrink_duration = object_audio_player.stream.get_length()
		print("DumpsterSystem: Using audio length for shrink duration: ", actual_shrink_duration)
	else:
		print("DumpsterSystem: Using default shrink duration: ", actual_shrink_duration)
	
	# Start shrinking sound on the object itself
	if object_audio_player:
		object_audio_player.play()
		print("DumpsterSystem: Shrinking audio started")
	
	print("DumpsterSystem: Validating mesh instances...")
	
	# Validate all mesh instances before animating
	var valid_meshes: Array[MeshInstance3D] = []
	for mesh_instance in mesh_instances:
		if is_instance_valid(mesh_instance):
			valid_meshes.append(mesh_instance)
		else:
			print("DumpsterSystem: Mesh instance invalid: ", mesh_instance)
	
	print("DumpsterSystem: Found ", valid_meshes.size(), " valid meshes out of ", mesh_instances.size())
	
	if valid_meshes.is_empty():
		print("DumpsterSystem: No valid meshes remaining")
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "No valid mesh instances remaining")
		return
	
	# Check tween validity before adding operations
	if not tween.is_valid():
		print("DumpsterSystem: Tween invalid before adding operations")
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "Tween became invalid")
		return
	
	# Animate all valid mesh instances to minimum size simultaneously
	var tweens_added = 0
	for mesh_instance in valid_meshes:
		if original_scales.has(mesh_instance):
			var original_scale = original_scales[mesh_instance]
			var target_scale = original_scale * min_object_size
			print("DumpsterSystem: Animating mesh from ", original_scale, " to ", target_scale, " over ", actual_shrink_duration, "s")
			tween.parallel().tween_property(mesh_instance, "scale", target_scale, actual_shrink_duration)
			tweens_added += 1
		else:
			print("DumpsterSystem: No original scale stored for mesh: ", mesh_instance)
	
	print("DumpsterSystem: Added ", tweens_added, " tween operations")
	
	if tweens_added == 0:
		print("DumpsterSystem: No tween operations added")
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "No tween operations could be added")
		return
	
	print("DumpsterSystem: Waiting for shrink animation/audio to finish...")
	
	# Wait for animation completion (which should match audio length)
	await tween.finished
	
	print("DumpsterSystem: Shrink animation finished, playing plop sound")
	
	# Check if objects are still valid after animation
	if not is_instance_valid(rigid_body):
		_cleanup_disposal(rigid_body)
		disposal_failed.emit(rigid_body, "Object became invalid after animation")
		return
	
	# Play disposal plop sound immediately after shrinking completes
	_play_disposal_audio()
	
	# Free object immediately when plop starts
	print("DumpsterSystem: Completing disposal")
	_complete_disposal(rigid_body)

func _complete_disposal(rigid_body: RigidBody3D) -> void:
	"""Complete the disposal process and cleanup object with all its children"""
	if is_instance_valid(rigid_body):
		object_disposal_completed.emit(rigid_body)
		
		# The queue_free() will automatically handle all children including audio players
		rigid_body.queue_free()
	
	_cleanup_disposal(rigid_body)

func _cleanup_disposal(rigid_body: RigidBody3D) -> void:
	"""Clean up disposal tracking data"""
	if disposing_objects.has(rigid_body):
		var disposal_data = disposing_objects[rigid_body]
		if disposal_data is Dictionary and disposal_data.has("tween"):
			var tween = disposal_data["tween"]
			if tween and tween.is_valid():
				tween.kill()
		elif disposal_data and disposal_data.is_valid():
			# Handle legacy format (direct tween storage)
			disposal_data.kill()
		disposing_objects.erase(rigid_body)

func _play_disposal_audio() -> void:
	"""Play random disposal sound effect with pitch variation"""
	if not audio_player or disposal_sounds.is_empty():
		return
	
	# Select random sound from array
	var random_sound = disposal_sounds[randi() % disposal_sounds.size()]
	audio_player.stream = random_sound
	
	# Add pitch variation for more natural sound
	if pitch_variation > 0.0:
		var pitch_offset = randf_range(-pitch_variation, pitch_variation)
		audio_player.pitch_scale = audio_pitch_scale + pitch_offset
	else:
		audio_player.pitch_scale = audio_pitch_scale
	
	audio_player.play()

## Public API for external control
func set_disposal_enabled(enabled: bool) -> void:
	"""Enable or disable disposal detection"""
	if trash_area:
		trash_area.monitoring = enabled

func is_disposal_enabled() -> bool:
	"""Check if disposal detection is active"""
	return trash_area and trash_area.monitoring

func get_disposing_count() -> int:
	"""Get number of objects currently being disposed"""
	return disposing_objects.size()

func force_dispose_object(rigid_body: RigidBody3D) -> void:
	"""Force disposal of specific RigidBody3D regardless of location"""
	_attempt_disposal(rigid_body)

func cancel_disposal(rigid_body: RigidBody3D) -> void:
	"""Cancel ongoing disposal of specific object"""
	if not disposing_objects.has(rigid_body):
		return
	
	_cleanup_disposal(rigid_body)
	disposal_failed.emit(rigid_body, "Disposal cancelled")

func cancel_all_disposals() -> void:
	"""Cancel all active disposals"""
	var objects_to_cancel = disposing_objects.keys()
	for rigid_body in objects_to_cancel:
		cancel_disposal(rigid_body)
