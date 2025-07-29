# MultiplayerMovement.gd - Updated version that extends your existing movement
# Replace your existing multiplayer_movement.gd with this
extends "res://scripts/character_controller/movement.gd"

@export var player_id: int = 1

func _ready() -> void:
	# Call parent setup first to initialize your movement system
	super._ready()
	_setup_multiplayer()

func _setup_multiplayer() -> void:
	"""Setup multiplayer authority and groups"""
	# Set authority based on peer ID from node name
	var peer_id = name.get_slice("_", 1).to_int()
	if peer_id > 0:
		player_id = peer_id
	
	set_multiplayer_authority(player_id)
	
	# Add to groups for easy finding
	add_to_group("players")
	add_to_group("player_" + str(player_id))
	
	print("Player ", player_id, " ready with authority: ", is_multiplayer_authority())

func set_player_id(new_id: int) -> void:
	"""Set player ID and update authority"""
	player_id = new_id
	name = "Player_" + str(player_id)
	
	# Update multiplayer authority
	set_multiplayer_authority(player_id)
	
	# Update groups
	remove_from_group("player_" + str(player_id))
	add_to_group("player_" + str(new_id))

func _physics_process(delta: float) -> void:
	# Only run physics on the authority (the player who owns this character)
	if is_multiplayer_authority():
		super._physics_process(delta)
	
	# Position automatically syncs via Godot's built-in multiplayer

func _input(event: InputEvent) -> void:
	# Only process input if we have authority
	if not is_multiplayer_authority():
		return
	
	# Call parent input handling for your movement system
	super._input(event)
	
	# Handle grab inputs with RPCs for multiplayer sync
	_handle_multiplayer_grab_inputs(event)

func _handle_multiplayer_grab_inputs(event: InputEvent) -> void:
	"""Handle grab inputs with multiplayer synchronization"""
	if event.is_action_pressed("grab_left"):
		_try_grab_left()
	elif event.is_action_released("grab_left"):
		_release_left.rpc()
	elif event.is_action_pressed("grab_right"):
		_try_grab_right()
	elif event.is_action_released("grab_right"):
		_release_right.rpc()

# === GRAB SYSTEM WITH MULTIPLAYER ===
func _try_grab_left() -> void:
	"""Try to grab with left hand"""
	if grabbing_arm_left or not l_grab_area:
		return
	
	var targets = l_grab_area.get_overlapping_bodies()
	for target in targets:
		if target.is_in_group("grabbable") and target != self:
			_grab_left.rpc(target.get_path())
			return

func _try_grab_right() -> void:
	"""Try to grab with right hand"""
	if grabbing_arm_right or not r_grab_area:
		return
	
	var targets = r_grab_area.get_overlapping_bodies()
	for target in targets:
		if target.is_in_group("grabbable") and target != self:
			_grab_right.rpc(target.get_path())
			return

@rpc("call_local", "reliable")
func _grab_left(target_path: NodePath) -> void:
	"""Grab with left hand - synced across network"""
	var target = get_node_or_null(target_path)
	if not target or grabbing_arm_left:
		return
	
	grabbing_arm_left = true
	grabbed_object_left = target
	grabbed_object = target  # Backward compatibility with your system
	
	if grab_joint_left and physical_bone_l_arm_2:
		grab_joint_left.global_position = l_grab_area.global_position
		grab_joint_left.node_a = grab_joint_left.get_path_to(physical_bone_l_arm_2)
		grab_joint_left.node_b = grab_joint_left.get_path_to(target)

@rpc("call_local", "reliable")
func _grab_right(target_path: NodePath) -> void:
	"""Grab with right hand - synced across network"""
	var target = get_node_or_null(target_path)
	if not target or grabbing_arm_right:
		return
	
	grabbing_arm_right = true
	grabbed_object_right = target
	
	if grab_joint_right and physical_bone_r_arm_2:
		grab_joint_right.global_position = r_grab_area.global_position
		grab_joint_right.node_a = grab_joint_right.get_path_to(physical_bone_r_arm_2)
		grab_joint_right.node_b = grab_joint_right.get_path_to(target)

@rpc("call_local", "reliable")
func _release_left() -> void:
	"""Release left hand - synced across network"""
	if not grabbing_arm_left:
		return
	
	grabbing_arm_left = false
	grabbed_object_left = null
	grabbed_object = null
	
	if grab_joint_left:
		grab_joint_left.node_a = NodePath()
		grab_joint_left.node_b = NodePath()

@rpc("call_local", "reliable")
func _release_right() -> void:
	"""Release right hand - synced across network"""
	if not grabbing_arm_right:
		return
	
	grabbing_arm_right = false
	grabbed_object_right = null
	
	if grab_joint_right:
		grab_joint_right.node_a = NodePath()
		grab_joint_right.node_b = NodePath()

# === UTILITY ===
func get_player_id() -> int:
	return player_id

func is_local_player() -> bool:
	return is_multiplayer_authority()
