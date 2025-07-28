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

## Internal tracking
var collision_timers: Dictionary = {}  # Object pairs -> last collision time
var audio_pool: Array[AudioStreamPlayer3D] = []  # Pooled audio players
var pool_index: int = 0

## Material definitions - extend this for your game
var material_sounds: Dictionary = {
	"metal": ["res://audio/impacts/metal_clang_01.ogg", "res://audio/impacts/metal_clang_02.ogg"],
	"wood": ["res://audio/impacts/wood_thunk_01.ogg", "res://audio/impacts/wood_knock_02.ogg"],
	"stone": ["res://audio/impacts/stone_crack_01.ogg", "res://audio/impacts/rock_hit_02.ogg"],
	"glass": ["res://audio/impacts/glass_break_01.ogg", "res://audio/impacts/glass_shatter_02.ogg"],
	"plastic": ["res://audio/impacts/plastic_tap_01.ogg", "res://audio/impacts/plastic_hit_02.ogg"],
	"default": ["res://audio/impacts/generic_thud_01.ogg", "res://audio/impacts/generic_impact_02.ogg"]
}

func _ready():
	# Initialize audio pool
	_create_audio_pool(20)  # Adjust pool size based on your needs
	
	# Connect to new RigidBody3D nodes automatically
	get_tree().node_added.connect(_on_node_added)
	
	# Clean up old collision timers periodically
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 5.0
	cleanup_timer.timeout.connect(_cleanup_collision_timers)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)

func _create_audio_pool(size: int):
	"""Create a pool of reusable AudioStreamPlayer3D nodes"""
	for i in size:
		var player = AudioStreamPlayer3D.new()
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.max_distance = 50.0
		player.unit_size = 10.0
		add_child(player)
		audio_pool.append(player)

func _on_node_added(node: Node):
	"""Automatically connect to RigidBody3D collision signals"""
	if node is RigidBody3D:
		# Wait one frame to ensure the node is ready
		await get_tree().process_frame
		if is_instance_valid(node):
			node.body_entered.connect(_on_collision.bind(node))

func _on_collision(collider: RigidBody3D, other_body: Node):
	"""Handle collision between two bodies"""
	# Get collision info
	var collision_data = _get_collision_data(collider, other_body)
	if not collision_data:
		return
	
	# Check cooldown to prevent audio spam
	var collision_key = _get_collision_key(collider, other_body)
	var current_time = Time.get_time_dict_from_system()
	var time_stamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second + current_time.millisecond * 0.001
	
	if collision_timers.has(collision_key):
		if time_stamp - collision_timers[collision_key] < collision_cooldown:
			return
	
	collision_timers[collision_key] = time_stamp
	
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
	
	return "default"

func _play_collision_sound(collision_data: Dictionary):
	"""Play appropriate collision sound based on materials and impact"""
	var material_combo = _get_material_combination(collision_data.material1, collision_data.material2)
	var sound_files = _get_sounds_for_materials(material_combo)
	
	if sound_files.is_empty():
		return
	
	# Select random sound from appropriate set
	var sound_file = sound_files[randi() % sound_files.size()]
	var audio_stream = load(sound_file) as AudioStream
	
	if not audio_stream:
		push_warning("Could not load audio file: " + sound_file)
		return
	
	# Get available audio player from pool
	var player = _get_audio_player()
	if not player:
		return
	
	# Configure player
	player.global_position = collision_data.position
	player.stream = audio_stream
	
	# Scale volume based on impact velocity
	var volume_scale = remap(collision_data.velocity, min_impact_velocity, max_impact_velocity, min_volume, max_volume)
	player.volume_db = linear_to_db(clamp(volume_scale, min_volume, max_volume))
	
	# Add slight pitch variation for more natural sound
	player.pitch_scale = randf_range(0.9, 1.1)
	
	player.play()

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

func _get_audio_player() -> AudioStreamPlayer3D:
	"""Get next available audio player from pool"""
	for i in audio_pool.size():
		var player = audio_pool[(pool_index + i) % audio_pool.size()]
		if not player.playing:
			pool_index = (pool_index + i + 1) % audio_pool.size()
			return player
	
	# All players busy, return the next one anyway (will interrupt)
	var player = audio_pool[pool_index]
	pool_index = (pool_index + 1) % audio_pool.size()
	return player

func _get_collision_key(body1: Node, body2: Node) -> String:
	"""Create unique key for collision pair"""
	var id1 = body1.get_instance_id()
	var id2 = body2.get_instance_id()
	if id1 > id2:
		return str(id2) + "_" + str(id1)
	return str(id1) + "_" + str(id2)

func _cleanup_collision_timers():
	"""Remove old collision timer entries"""
	var current_time = Time.get_time_dict_from_system()
	var time_stamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	var keys_to_remove = []
	for key in collision_timers:
		if time_stamp - collision_timers[key] > 10.0:  # Remove entries older than 10 seconds
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
