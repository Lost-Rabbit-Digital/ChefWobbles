# CollisionAudioManager.gd
# Singleton script - Add to AutoLoad as "CollisionAudio"
extends Node

## Audio bank for different material combinations
@export var audio_banks: Dictionary = {}

## Collision detection settings
@export var min_impact_velocity: float = 2.0  # Minimum speed to trigger sound
@export var max_impact_velocity: float = 20.0  # Maximum for volume scaling
@export var collision_cooldown: float = 0.1  # Prevent audio spam
@export var max_volume: float = 0.8
@export var min_volume: float = 0.1
@export var debug_prints: bool = false  # Toggle debug output

## Internal tracking
var collision_timers: Dictionary = {}  # Object pairs -> last collision time

## Material definitions - extend this for your game
var material_sounds: Dictionary = {
	"metal": ["res://audio/sound_effects/impacts/impact_1.mp3"],
	"wood": ["res://audio/sound_effects/impacts/impact_1.mp3"],
	"stone": ["res://audio/sound_effects/impacts/impact_1.mp3"],
	"glass": ["res://audio/sound_effects/impacts/impact_1.mp3"],
	"plastic": ["res://audio/sound_effects/impacts/impact_1.mp3"],
	"paper": ["res://audio/sound_effects/impacts/impact_1.mp3"],
	"flesh": ["res://audio/sound_effects/impacts/impact_1.mp3"],
	"default": ["res://audio/sound_effects/impacts/impact_1.mp3"]
}

func _ready():
	if debug_prints:
		print("CollisionAudioManager: AutoLoad working! System initialized.")
	
	# Connect to new RigidBody3D nodes automatically
	get_tree().node_added.connect(_on_node_added)
	if debug_prints:
		print("CollisionAudioManager: Connected to node_added signal")
	
	# Scan for existing RigidBody3D nodes
	_scan_existing_rigidbodies()
	
	# Clean up old collision timers periodically
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 5.0
	cleanup_timer.timeout.connect(_cleanup_collision_timers)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)

func _scan_existing_rigidbodies():
	"""Scan the entire scene tree for existing RigidBody3D nodes"""
	if debug_prints:
		print("CollisionAudioManager: Scanning for existing RigidBody3D nodes...")
	var root = get_tree().current_scene
	if root:
		_recursive_scan_for_rigidbodies(root)
	elif debug_prints:
		print("CollisionAudioManager: No current scene found during scan")

func _recursive_scan_for_rigidbodies(node: Node):
	"""Recursively search for RigidBody3D nodes"""
	if node is RigidBody3D:
		if debug_prints:
			print("CollisionAudioManager: Found existing RigidBody3D - ", node.name)
		_setup_rigidbody_collision_detection(node)
	
	# Check all children
	for child in node.get_children():
		_recursive_scan_for_rigidbodies(child)

func _on_node_added(node: Node):
	"""Automatically connect to RigidBody3D collision signals"""
	if node is RigidBody3D:
		if debug_prints:
			print("CollisionAudioManager: Found NEW RigidBody3D - ", node.name)
		# Wait one frame to ensure the node is ready
		await get_tree().process_frame
		if is_instance_valid(node):
			_setup_rigidbody_collision_detection(node)

func _setup_rigidbody_collision_detection(rigidbody: RigidBody3D):
	"""Set up collision detection for a RigidBody3D using proper signals"""
	if debug_prints:
		print("CollisionAudioManager: Setting up collision detection for ", rigidbody.name)
	
	# Enable contact monitoring - REQUIRED for collision signals
	rigidbody.contact_monitor = true
	rigidbody.max_contacts_reported = 10
	if debug_prints:
		print("CollisionAudioManager: Enabled contact monitoring for ", rigidbody.name)
	
	# Connect to the correct collision signals
	if not rigidbody.body_entered.is_connected(_on_rigidbody_collision):
		rigidbody.body_entered.connect(_on_rigidbody_collision.bind(rigidbody))
		if debug_prints:
			print("CollisionAudioManager: Connected body_entered signal for ", rigidbody.name)
	
	if debug_prints:
		print("CollisionAudioManager: Setup complete for ", rigidbody.name)

func _on_rigidbody_collision(other_body: Node, collider: RigidBody3D):
	"""Handle RigidBody3D collision using the proper signal"""
	if debug_prints:
		print("CollisionAudioManager: Collision detected!")
		print("  Collider: ", collider.name)
		print("  Other: ", other_body.name)
	
	# Get collision info
	var collision_data = _get_collision_data(collider, other_body)
	if not collision_data:
		if debug_prints:
			print("  No collision data - velocity too low or other issue")
		return
	
	# Check cooldown to prevent audio spam
	var collision_key = _get_collision_key(collider, other_body)
	var time_stamp = Time.get_time_dict_from_system()
	var current_time_seconds = time_stamp.hour * 3600 + time_stamp.minute * 60 + time_stamp.second
	
	if collision_timers.has(collision_key):
		if current_time_seconds - collision_timers[collision_key] < collision_cooldown:
			if debug_prints:
				print("  Collision on cooldown - skipping")
			return
	
	collision_timers[collision_key] = current_time_seconds
	
	# Play appropriate sound
	_play_collision_sound(collision_data)

func _get_collision_data(body1: RigidBody3D, body2: Node) -> Dictionary:
	"""Extract relevant collision information"""
	# Get impact velocity (simplified - using linear velocity magnitude)
	var velocity = body1.linear_velocity.length()
	
	if velocity < min_impact_velocity:
		return {}
	
	# Determine materials
	var material1 = _get_material_type(body1)
	var material2 = _get_material_type(body2)
	
	# Get impact position (approximate using body1's position)
	var impact_position = body1.global_position
	
	return {
		"velocity": velocity,
		"material1": material1,
		"material2": material2,
		"position": impact_position,
		"body1": body1,
		"body2": body2
	}

func _get_material_type(body: Node) -> String:
	"""Determine material type from node groups or name patterns"""
	# Check groups first (recommended approach)
	if body.is_in_group("metal_objects"):
		return "metal"
	elif body.is_in_group("wood_objects"):
		return "wood"
	elif body.is_in_group("stone_objects"):
		return "stone"
	elif body.is_in_group("glass_objects"):
		return "glass"
	elif body.is_in_group("plastic_objects"):
		return "plastic"
	elif body.is_in_group("paper_objects"):
		return "paper"
	elif body.is_in_group("flesh_objects"):
		return "flesh"
	
	# Fallback to name pattern matching
	var name_lower = body.name.to_lower()
	if "metal" in name_lower or "steel" in name_lower:
		return "metal"
	elif "wood" in name_lower or "timber" in name_lower:
		return "wood"
	elif "stone" in name_lower or "rock" in name_lower:
		return "stone"
	elif "glass" in name_lower:
		return "glass"
	elif "plastic" in name_lower:
		return "plastic"
	elif "paper" in name_lower or "cardboard" in name_lower:
		return "paper"
	elif "flesh" in name_lower or "body" in name_lower or "meat" in name_lower:
		return "flesh"
	
	return "default"

func _play_collision_sound(collision_data: Dictionary):
	"""Play appropriate collision sound using AudioManipulator with proper stream loading"""
	var material_combo = _get_material_combination(collision_data.material1, collision_data.material2)
	var sound_files = _get_sounds_for_materials(material_combo)
	
	# Debug print for impact information
	if debug_prints:
		print("COLLISION IMPACT:")
		print("  Body 1: ", collision_data.body1.name, " (", collision_data.material1, ")")
		print("  Body 2: ", collision_data.body2.name, " (", collision_data.material2, ")")
		print("  Velocity: ", "%.2f" % collision_data.velocity)
		print("  Material Combo: ", material_combo)
		print("  Position: ", collision_data.position)
		print("  Sound files: ", sound_files)
		print("  ---")
	
	if sound_files.is_empty():
		if debug_prints:
			print("  No sound files found for material combo: ", material_combo)
		return
	
	# Convert file paths to AudioStream objects (this is what AudioManipulator expects!)
	var audio_streams = []
	for sound_file in sound_files:
		var audio_stream = load(sound_file) as AudioStream
		if audio_stream:
			audio_streams.append(audio_stream)
		elif debug_prints:
			print("  Failed to load audio file: ", sound_file)
	
	if audio_streams.is_empty():
		if debug_prints:
			print("  No valid audio streams could be loaded")
		return
	
	# Create a new AudioStreamPlayer3D for this collision
	var player = AudioStreamPlayer3D.new()
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.max_distance = 50.0
	player.unit_size = 10.0
	
	# Add to scene first, THEN set position
	add_child(player)
	player.global_position = collision_data.position
	
	if debug_prints:
		print("  Loaded ", audio_streams.size(), " audio streams")
		print("  Using AudioManipulator with IMPACTS preset")
	
	# Now use AudioManipulator with actual AudioStream objects (not file paths!)
	var success = AudioManipulator.play_audio_static(player, audio_streams, AudioManipulator.AudioType.IMPACTS)
	
	if not success and debug_prints:
		print("  AudioManipulator failed to play audio")
	
	# Override volume based on impact velocity (after AudioManipulator sets its preset)
	var volume_scale = remap(collision_data.velocity, min_impact_velocity, max_impact_velocity, min_volume, max_volume)
	var final_volume = clamp(volume_scale, min_volume, max_volume)
	var volume_db = linear_to_db(final_volume)
	
	# Blend our velocity-based volume with AudioManipulator's preset
	player.volume_db = player.volume_db + volume_db - linear_to_db(1.0)  # Adjust from the preset
	
	if debug_prints:
		print("  Final volume_db: ", player.volume_db)
		print("  Pitch scale: ", player.pitch_scale)
	
	# Remove the player after the audio finishes
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 5.0  # Safe cleanup time
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_cleanup_audio_player.bind(player, cleanup_timer))
	add_child(cleanup_timer)
	cleanup_timer.start()

func _cleanup_audio_player(player: AudioStreamPlayer3D, timer: Timer):
	"""Clean up temporary audio player"""
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()

func _get_material_combination(mat1: String, mat2: String) -> String:
	"""Create a consistent material combination key"""
	var materials = [mat1, mat2]
	materials.sort()
	return materials[0] + "_" + materials[1]

func _get_sounds_for_materials(material_combo: String) -> Array:
	"""Get appropriate sounds for material combination"""
	# Check for specific combination first
	if audio_banks.has(material_combo):
		return audio_banks[material_combo]
	
	# Fall back to individual materials
	var materials = material_combo.split("_")
	for material in materials:
		if material_sounds.has(material):
			return material_sounds[material]
	
	# Default fallback
	return material_sounds["default"]

func _get_collision_key(body1: Node, body2: Node) -> String:
	"""Create unique key for collision pair"""
	var id1 = body1.get_instance_id()
	var id2 = body2.get_instance_id()
	if id1 > id2:
		return str(id2) + "_" + str(id1)
	return str(id1) + "_" + str(id2)

func _cleanup_collision_timers():
	"""Remove old collision timer entries"""
	var time_stamp = Time.get_time_dict_from_system()
	var current_time_seconds = time_stamp.hour * 3600 + time_stamp.minute * 60 + time_stamp.second
	
	var keys_to_remove = []
	for key in collision_timers:
		if current_time_seconds - collision_timers[key] > 10.0:  # Remove entries older than 10 seconds
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		collision_timers.erase(key)

## Public API for custom material registration
func register_material_sounds(material: String, sound_files: Array):
	"""Register custom material sounds"""
	material_sounds[material] = sound_files

func register_material_combination(mat1: String, mat2: String, sound_files: Array):
	"""Register sounds for specific material combinations"""
	var combo_key = _get_material_combination(mat1, mat2)
	audio_banks[combo_key] = sound_files
