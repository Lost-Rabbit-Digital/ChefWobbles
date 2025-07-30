extends Node3D

@export var mouse_sensitivity = 0.1  # camera rotation speed
@export var physical_skel: Skeleton3D  # character physical skeleton
@onready var spring_arm = $SpringArm3D
@export var camera_change_rate: float = 1.0
@export var camera_angle_lock: float = 65

var target_node: Node3D  # will be set to the head bone of parent player
var mouse_lock = false  # is mouse locked

func _enter_tree() -> void:
	# Get authority from parent player node (which has the peer ID as name)
	var player_node = get_parent()
	if player_node:
		var authority_id = player_node.name.to_int()
		set_multiplayer_authority(authority_id)
		
		# Find the head bone in this player's hierarchy
		target_node = player_node.get_node_or_null("Physical/Armature/Skeleton3D/Physical Bone Head")
		
		if target_node:
			print("Camera authority set to: ", authority_id, " from parent: ", player_node.name)
			print("Camera will track head bone: ", target_node)
		else:
			print("ERROR: Could not find head bone in player: ", player_node.name)
			# Fallback to tracking the player root
			target_node = player_node
	else:
		print("ERROR: Camera has no parent to get authority from")

func _physics_process(_delta):
	if is_multiplayer_authority():
		for child in physical_skel.get_children():
			# prevent the camera from clipping into the character
			if child is PhysicalBone3D:
				spring_arm.add_excluded_object(child.get_rid())
		
		if target_node != null:
			# lerp position to the target position (head bone)
			global_position = lerp(global_position, target_node.global_position, 0.5)

func _input(event):
	if is_multiplayer_authority():
		# mouse lock
		if Input.is_action_just_pressed("exit_camera"):
			mouse_lock = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			mouse_lock = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# rotate camera
		if event is InputEventMouseMotion and mouse_lock:
			rotation_degrees.y -= mouse_sensitivity * event.relative.x
			rotation_degrees.x -= mouse_sensitivity * event.relative.y
			rotation_degrees.x = clamp(rotation_degrees.x, -camera_angle_lock, camera_angle_lock)
