# MultiplayerMovement.gd - With proper MultiplayerSpawner integration
extends "res://scripts/character_controller/movement.gd"

@export var player_id: int = 1

# MultiplayerSpawner integration
static func spawn_custom(data: Variant) -> Node:
	"""Static spawn function for MultiplayerSpawner"""
	var player_scene = preload("res://scenes/character.tscn")
	var player = player_scene.instantiate()
	
	if data is Array and data.size() >= 2:
		var actual_peer_id = data[0]
		var simple_id = data[1]
		
		player.name = "Player_" + str(simple_id)
		player.set_multiplayer_authority(actual_peer_id)
		if player.has_method("set_player_id"):
			player.set_player_id(simple_id)
		player.global_position = Vector3(randf_range(-3, 3), 2, randf_range(-3, 3))
		
		print("Custom spawned Player ", simple_id, " with authority ", actual_peer_id)
	
	return player

func _ready() -> void:
	# Call parent setup first to initialize your movement system
	super._ready()
	_setup_multiplayer()

func _setup_multiplayer() -> void:
	"""Setup multiplayer authority and groups"""
	
	# If not spawned via custom spawner, use fallback method
	if player_id == 1:  # Default value means not set by spawner
		var name_parts = name.split("_")
		if name_parts.size() >= 2:
			player_id = name_parts[1].to_int()
		
		add_to_group("players")
		add_to_group("player_" + str(player_id))
		
		print("Player ", player_id, " ready. Authority will be set by NetworkManager.")

func set_player_id(new_id: int) -> void:
	"""Set player ID - called by NetworkManager after authority is set"""
	var old_id = player_id
	player_id = new_id
	
	# Update groups
	if old_id > 0:
		remove_from_group("player_" + str(old_id))
	add_to_group("player_" + str(new_id))
	
	# Log after authority is set
	await get_tree().process_frame
	print("Player ID set: ", new_id, " Authority: ", get_multiplayer_authority(), " Has authority: ", is_multiplayer_authority(), " (Local peer: ", multiplayer.get_unique_id(), ")")

func _physics_process(delta: float) -> void:
	# Only run physics on the authority (the player who owns this character)
	if is_multiplayer_authority():
		super._physics_process(delta)

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
	if not has_method("l_grab_area") or grabbing_arm_left or not l_grab_area:
		return
	
	var targets = l_grab_area.get_overlapping_bodies()
	for target in targets:
		if target.is_in_group("grabbable") and target != self:
			_grab_left.rpc(target.get_path())
			return

func _try_grab_right() -> void:
	"""Try to grab with right hand"""
	if not has_method("r_grab_area") or grabbing_arm_right or not r_grab_area:
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
	if not target or not has_method("grabbing_arm_left") or grabbing_arm_left:
		return
	
	grabbing_arm_left = true
	grabbed_object_left = target
	grabbed_object = target  # Backward compatibility with your system
	
	if has_method("grab_joint_left") and grab_joint_left and has_method("physical_bone_l_arm_2") and physical_bone_l_arm_2:
		grab_joint_left.global_position = l_grab_area.global_position
		grab_joint_left.node_a = grab_joint_left.get_path_to(physical_bone_l_arm_2)
		grab_joint_left.node_b = grab_joint_left.get_path_to(target)

@rpc("call_local", "reliable")
func _grab_right(target_path: NodePath) -> void:
	"""Grab with right hand - synced across network"""
	var target = get_node_or_null(target_path)
	if not target or not has_method("grabbing_arm_right") or grabbing_arm_right:
		return
	
	grabbing_arm_right = true
	grabbed_object_right = target
	
	if has_method("grab_joint_right") and grab_joint_right and has_method("physical_bone_r_arm_2") and physical_bone_r_arm_2:
		grab_joint_right.global_position = r_grab_area.global_position
		grab_joint_right.node_a = grab_joint_right.get_path_to(physical_bone_r_arm_2)
		grab_joint_right.node_b = grab_joint_right.get_path_to(target)

@rpc("call_local", "reliable")
func _release_left() -> void:
	"""Release left hand - synced across network"""
	if not has_method("grabbing_arm_left") or not grabbing_arm_left:
		return
	
	grabbing_arm_left = false
	grabbed_object_left = null
	grabbed_object = null
	
	if has_method("grab_joint_left") and grab_joint_left:
		grab_joint_left.node_a = NodePath()
		grab_joint_left.node_b = NodePath()

@rpc("call_local", "reliable")
func _release_right() -> void:
	"""Release right hand - synced across network"""
	if not has_method("grabbing_arm_right") or not grabbing_arm_right:
		return
	
	grabbing_arm_right = false
	grabbed_object_right = null
	
	if has_method("grab_joint_right") and grab_joint_right:
		grab_joint_right.node_a = NodePath()
		grab_joint_right.node_b = NodePath()

# === UTILITY ===
func get_player_id() -> int:
	return player_id

func is_local_player() -> bool:
	return is_multiplayer_authority()
