# MultiplayerMovement.gd
# Extends your existing movement.gd to add multiplayer synchronization
extends "res://Scripts/character_controller/movement.gd"

# Multiplayer authority and identification
@export var player_id: int = 1
var is_multiplayer_authority: bool = false
var _multiplayer_initialized: bool = false

# Network synchronization variables
var network_position: Vector3
var network_rotation: Vector3
var network_velocity: Vector3
var network_animation_state: Dictionary = {}

# Smoothing for network interpolation
const POSITION_LERP_SPEED: float = 15.0
const ROTATION_LERP_SPEED: float = 10.0

# Timer for network updates
var network_update_timer: float = 0.0
const NETWORK_UPDATE_RATE: float = 1.0 / 20.0  # 20 Hz

# DEBUG: Track position changes
var _last_logged_position: Vector3
var _position_check_timer: float = 0.0

func _ready() -> void:
	# Wait for the node to be properly in the scene tree
	await get_tree().process_frame
	
	# Add to your existing player groups
	add_to_group("players")
	
	# Call original _ready() after we're properly in the scene
	super._ready()
	_setup_multiplayer()

func _setup_multiplayer() -> void:
	"""Initialize multiplayer-specific components"""
	# Set up network authority
	set_multiplayer_authority(player_id)
	
	# Check if multiplayer is available before calling get_unique_id
	if multiplayer and NetworkManager and NetworkManager.is_multiplayer_active():
		is_multiplayer_authority = (get_multiplayer_authority() == multiplayer.get_unique_id())
	else:
		# In single player or if multiplayer not ready, assume authority
		is_multiplayer_authority = true
	
	# Initialize network state - but we'll update position when it's properly set
	network_position = Vector3.ZERO  # Placeholder, will be updated
	network_rotation = rotation
	network_velocity = Vector3.ZERO
	
	print("Multiplayer setup complete. Position: ", global_position)
	
	# Connect to NetworkManager if available
	if NetworkManager:
		NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _physics_process(delta: float) -> void:
	# DEBUG: Continuous position monitoring
	_position_check_timer += delta
	if _position_check_timer >= 0.5:  # Check every 0.5 seconds
		var current_pos = global_position
		if _last_logged_position != Vector3.ZERO and current_pos.distance_to(_last_logged_position) > 0.1:
			print("POSITION DRIFT: ", _last_logged_position, " -> ", current_pos, " (distance: ", current_pos.distance_to(_last_logged_position), ")")
		_last_logged_position = current_pos
		_position_check_timer = 0.0
	
	if not NetworkManager or not NetworkManager.is_multiplayer_active():
		# Single player mode - use original physics
		super._physics_process(delta)
		return
	
	# Only run multiplayer physics if we're properly initialized
	if not _multiplayer_initialized:
		super._physics_process(delta)  # Just run normal physics until ready
		return
	
	if is_multiplayer_authority:
		# This is our player - handle input and physics
		super._physics_process(delta)
		_update_network_state()
		
		# Send updates to other players periodically
		network_update_timer += delta
		if network_update_timer >= NETWORK_UPDATE_RATE:
			_send_player_update()
			network_update_timer = 0.0
	else:
		# This is another player - interpolate to network state
		_interpolate_to_network_state(delta)

func _update_network_state() -> void:
	"""Update our network state variables"""
	network_position = global_position
	network_rotation = rotation
	if physical_bone_body:
		network_velocity = physical_bone_body.linear_velocity
	
	# Update animation state
	network_animation_state = {
		"walking": walking,
		"grabbing_left": grabbing_arm_left,
		"grabbing_right": grabbing_arm_right,
		"ragdoll": ragdoll_mode
	}

@rpc("unreliable")
func _receive_player_update(pos: Vector3, rot: Vector3, vel: Vector3, anim_state: Dictionary) -> void:
	"""Receive player update from network"""
	if is_multiplayer_authority:
		return  # Don't update our own player
	
	network_position = pos
	network_rotation = rot
	network_velocity = vel
	network_animation_state = anim_state
	
	# Apply animation changes
	_apply_network_animation_state()

func _send_player_update() -> void:
	"""Send our player state to other players"""
	_receive_player_update.rpc(
		network_position,
		network_rotation,
		network_velocity,
		network_animation_state
	)

func _interpolate_to_network_state(delta: float) -> void:
	"""Smoothly interpolate to network position for other players"""
	if not physical_bone_body:
		return
	
	# Interpolate position
	global_position = global_position.lerp(network_position, POSITION_LERP_SPEED * delta)
	
	# Interpolate rotation
	rotation = rotation.lerp(network_rotation, ROTATION_LERP_SPEED * delta)
	
	# Set velocity for physics simulation
	if network_velocity.length() > 0.1:
		physical_bone_body.linear_velocity = physical_bone_body.linear_velocity.lerp(
			network_velocity, 5.0 * delta
		)

func _apply_network_animation_state() -> void:
	"""Apply animation state from network"""
	if not animation_tree:
		return
	
	walking = network_animation_state.get("walking", false)
	var net_grabbing_left = network_animation_state.get("grabbing_left", false)
	var net_grabbing_right = network_animation_state.get("grabbing_right", false)
	
	# Update animations
	if walking:
		animation_tree.set("parameters/walking/blend_amount", 1)
	else:
		animation_tree.set("parameters/walking/blend_amount", 0)
	
	# Handle grab animations
	if net_grabbing_left or net_grabbing_right:
		var r = clamp((camera_pivot.rotation.x * 2) / (PI) * 2.1, -1, 1)
		animation_tree.set("parameters/grab_dir/blend_position", r)
	else:
		animation_tree.set("parameters/grab_dir/blend_position", 0)

# === MULTIPLAYER INPUT HANDLING ===
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority:
		return  # Only process input for our own player
	
	super._input(event)
	
	# Send grab/release events immediately for responsiveness
	if event.is_action_pressed("grab_left"):
		_handle_grab_input.rpc("left", true)
	elif event.is_action_released("grab_left"):
		_handle_grab_input.rpc("left", false)
	elif event.is_action_pressed("grab_right"):
		_handle_grab_input.rpc("right", true)
	elif event.is_action_released("grab_right"):
		_handle_grab_input.rpc("right", false)

@rpc("call_local", "reliable")
func _handle_grab_input(hand: String, pressed: bool) -> void:
	"""Handle grab input events across network"""
	if hand == "left":
		if pressed and not grabbing_arm_left:
			_try_grab_left()
		elif not pressed and grabbing_arm_left:
			_release_left()
	elif hand == "right":
		if pressed and not grabbing_arm_right:
			_try_grab_right()
		elif not pressed and grabbing_arm_right:
			_release_right()

func _try_grab_left() -> void:
	"""Attempt to grab with left hand"""
	if l_grab_area and l_grab_area.has_method("get_overlapping_bodies"):
		var bodies = l_grab_area.get_overlapping_bodies()
		for body in bodies:
			if body is PhysicsBody3D and body.get_parent() != physical_skel:
				# Check if it's grabbable using your existing group
				if body.is_in_group("grabbable"):
					_perform_grab_by_group("left", body)
					break

func _try_grab_right() -> void:
	"""Attempt to grab with right hand"""
	if r_grab_area and r_grab_area.has_method("get_overlapping_bodies"):
		var bodies = r_grab_area.get_overlapping_bodies()
		for body in bodies:
			if body is PhysicsBody3D and body.get_parent() != physical_skel:
				# Check if it's grabbable using your existing group
				if body.is_in_group("grabbable"):
					_perform_grab_by_group("right", body)
					break

func _perform_grab_by_group(hand: String, target_object: Node) -> void:
	"""Helper to create unique group ID and call RPC"""
	# Create a unique group ID for this grab
	var unique_id = "grab_target_" + str(target_object.get_instance_id())
	target_object.add_to_group(unique_id)
	
	# Call the RPC with the group ID
	_perform_grab_by_group_rpc.rpc(hand, unique_id)
	
	# Clean up the temporary group after a short delay
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(target_object):
		target_object.remove_from_group(unique_id)

@rpc("call_local", "reliable")
func _perform_grab_by_group_rpc(hand: String, target_group_id: String) -> void:
	"""Perform grab action using group-based targeting"""
	# Find the target object by its unique group
	var targets = get_tree().get_nodes_in_group(target_group_id)
	var target = targets[0] if targets.size() > 0 else null
	
	if not target:
		print("Grab target not found in group: ", target_group_id)
		return
	
	if hand == "left" and not grabbing_arm_left:
		grabbing_arm_left = true
		grabbed_object_left = target
		grabbed_object = target  # Backward compatibility
		
		if grab_joint_left and physical_bone_l_arm_2:
			grab_joint_left.global_position = l_grab_area.global_position
			grab_joint_left.node_a = grab_joint_left.get_path_to(physical_bone_l_arm_2)
			grab_joint_left.node_b = grab_joint_left.get_path_to(target)
		
		play_grab_audio_left()
		
	elif hand == "right" and not grabbing_arm_right:
		grabbing_arm_right = true
		grabbed_object_right = target
		
		if grab_joint_right and physical_bone_r_arm_2:
			grab_joint_right.global_position = r_grab_area.global_position
			grab_joint_right.node_a = grab_joint_right.get_path_to(physical_bone_r_arm_2)
			grab_joint_right.node_b = grab_joint_right.get_path_to(target)
		
		play_grab_audio_right()

func _release_left() -> void:
	"""Release left hand grab"""
	if grabbing_arm_left:
		_perform_release.rpc("left")

func _release_right() -> void:
	"""Release right hand grab"""
	if grabbing_arm_right:
		_perform_release.rpc("right")

@rpc("call_local", "reliable")
func _perform_release(hand: String) -> void:
	"""Perform release action synchronized across network"""
	if hand == "left" and grabbing_arm_left:
		grabbing_arm_left = false
		grabbed_object_left = null
		grabbed_object = null
		
		if grab_joint_left:
			grab_joint_left.node_a = NodePath()
			grab_joint_left.node_b = NodePath()
		
		play_release_audio_left()
		
	elif hand == "right" and grabbing_arm_right:
		grabbing_arm_right = false
		grabbed_object_right = null
		
		if grab_joint_right:
			grab_joint_right.node_a = NodePath()
			grab_joint_right.node_b = NodePath()
		
		play_release_audio_right()

# === MULTIPLAYER EVENTS ===
func _on_player_disconnected(peer_id: int) -> void:
	"""Handle player disconnection cleanup"""
	if peer_id == player_id:
		# This player disconnected - clean up
		queue_free()

# === UTILITY FUNCTIONS ===
func get_player_id() -> int:
	"""Get this player's network ID"""
	return player_id

func set_player_id(id: int) -> void:
	"""Set this player's network ID"""
	player_id = id
	set_multiplayer_authority(id)
	
	# Add to appropriate player groups based on authority
	if multiplayer and NetworkManager and NetworkManager.is_multiplayer_active():
		is_multiplayer_authority = (get_multiplayer_authority() == multiplayer.get_unique_id())
		
		# Add to local or remote players group
		if is_multiplayer_authority:
			add_to_group("local_players")
		else:
			add_to_group("remote_players")
	else:
		# In single player or if multiplayer not ready, assume authority for local player
		is_multiplayer_authority = true
		add_to_group("local_players")

func is_local_player() -> bool:
	"""Check if this is the local player"""
	return is_multiplayer_authority

# Add this new function to be called from GameManager after setting position
func initialize_spawn_position() -> void:
	"""Called by GameManager after spawn position is set"""
	network_position = global_position
	_last_logged_position = global_position  # Initialize debug tracking
	_multiplayer_initialized = true  # Mark as ready for multiplayer sync
	print("Network position initialized to: ", network_position)
	print("Player authority status: ", is_multiplayer_authority)
	print("Multiplayer system ready for player ", player_id)

# === UTILITY FUNCTIONS WITH GROUPS ===
func get_all_players() -> Array[Node]:
	"""Get all players using groups"""
	return get_tree().get_nodes_in_group("players")

func get_local_players() -> Array[Node]:
	"""Get local players using groups"""
	return get_tree().get_nodes_in_group("local_players")

func get_remote_players() -> Array[Node]:
	"""Get remote players using groups"""
	return get_tree().get_nodes_in_group("remote_players")

func get_grabbable_objects() -> Array[Node]:
	"""Get all grabbable objects using groups"""
	return get_tree().get_nodes_in_group("grabbable")
