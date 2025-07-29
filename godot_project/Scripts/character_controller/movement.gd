extends Node3D

# === MOVEMENT CONSTANTS ===
const ACCELERATION = 80.0
const MAX_SPEED = 12.0
const JUMP_STRENGTH = 55.0
const DAMPING = 0.85
const AIR_DAMPING = 0.95

# === ORIGINAL SPRING CONSTANTS (KEPT YOUR VALUES) ===
@export var angular_spring_stiffness: float = 4000.0
@export var angular_spring_damping: float = 80.0
@export var max_angular_force: float = 9999.0

# === AUDIO EXPORTS (UPDATED FOR FOUR SOURCES) ===
@onready var grab_audio = preload("res://audio/sound_effects/plops/plop_1.mp3")
@onready var release_audio = preload("res://audio/sound_effects/plops/plop_2.mp3")
@onready var footstep_audio = preload("res://audio/sound_effects/thuds/thud_1.mp3")

# === STABILITY CONSTANTS ===
const UPRIGHT_FORCE_MULTIPLIER = 1.5
const BALANCE_THRESHOLD = 0.7

# === NODE REFERENCES (KEPT YOUR ORIGINAL PATHS) ===
@onready var on_floor_left = $"Physical/Armature/Skeleton3D/Physical Bone LLeg2/OnFloorLeft"
@onready var on_floor_right = $"Physical/Armature/Skeleton3D/Physical Bone RLeg2/OnFloorRight"
@onready var jump_timer = $Physical/JumpTimer
@onready var physical_skel: Skeleton3D = $Physical/Armature/Skeleton3D
@onready var animated_skel: Skeleton3D = $Animated/Armature/Skeleton3D
@onready var camera_pivot = $CameraPivot
@onready var animation_tree = $Animated/AnimationTree
@onready var physical_bone_body: PhysicalBone3D = $"Physical/Armature/Skeleton3D/Physical Bone Body"

# === AUDIO PLAYERS (UPDATED FOR FOUR SOURCES) ===
@onready var left_hand_audio_player = $"Physical/Armature/Skeleton3D/Physical Bone LArm2/LeftHandAudioPlayer"
@onready var right_hand_audio_player = $"Physical/Armature/Skeleton3D/Physical Bone RArm2/RightHandAudioPlayer"
@onready var left_foot_audio_player = $"Physical/Armature/Skeleton3D/Physical Bone LLeg2/LeftFootAudioPlayer"
@onready var right_foot_audio_player = $"Physical/Armature/Skeleton3D/Physical Bone RLeg2/RightFootAudioPlayer"

# === GRABBING SYSTEM (KEPT YOUR ORIGINAL SYSTEM) ===
@onready var grab_joint_right = $Physical/GrabJointRight
@onready var grab_joint_left = $Physical/GrabJointLeft
@onready var physical_bone_l_arm_2 = $"Physical/Armature/Skeleton3D/Physical Bone LArm2"
@onready var physical_bone_r_arm_2 = $"Physical/Armature/Skeleton3D/Physical Bone RArm2"
@onready var l_grab_area = $"Physical/Armature/Skeleton3D/Physical Bone LArm2/LGrabArea"
@onready var r_grab_area = $"Physical/Armature/Skeleton3D/Physical Bone RArm2/RGrabArea"

# === STATE VARIABLES (UPDATED FOR DUAL HAND TRACKING) ===
var can_jump = true
var is_on_floor = false
var walking = false
var physics_bones = []
@export var ragdoll_mode := false
var active_arm_left = false
var active_arm_right = false

# === DUAL HAND GRABBED OBJECTS ===
var grabbed_object_left = null  # Left hand grabbed object
var grabbed_object_right = null # Right hand grabbed object
var grabbed_object = null       # Keep for backward compatibility (points to left hand)

var grabbing_arm_left = false
var grabbing_arm_right = false
var current_delta: float

# === FOOTSTEP AUDIO VARIABLES (UPDATED FOR LEFT/RIGHT TRACKING) ===
var was_on_floor = false
var footstep_timer = 0.0
var last_footstep_was_left = false  # Track which foot stepped last
const FOOTSTEP_INTERVAL = 0.35  # Time between footsteps when walking

# === NEW SMOOTHING VARIABLES ===
var target_velocity: Vector3 = Vector3.ZERO
var movement_input: Vector3 = Vector3.ZERO

func _ready():
	# Keep your original initialization
	physical_skel.physical_bones_start_simulation()
	physics_bones = physical_skel.get_children().filter(func(x): return x is PhysicalBone3D)

func _input(event):
	# Keep your original input handling with dual hand object clearing
	if Input.is_action_just_pressed("ragdoll"):
		ragdoll_mode = bool(1 - int(ragdoll_mode))

	active_arm_left = Input.is_action_pressed("grab_left")
	active_arm_right = Input.is_action_pressed("grab_right")
	
	# Left hand release
	if (not active_arm_left and grabbing_arm_left) or ragdoll_mode:
		grabbing_arm_left = false
		grabbed_object_left = null
		grabbed_object = null  # Clear backward compatibility reference
		grab_joint_left.node_a = NodePath()
		grab_joint_left.node_b = NodePath()
		play_release_audio_left()
		
	# Right hand release
	if (not active_arm_right and grabbing_arm_right) or ragdoll_mode:
		grabbing_arm_right = false
		grabbed_object_right = null
		grab_joint_right.node_a = NodePath()
		grab_joint_right.node_b = NodePath()
		play_release_audio_right()

func _process(delta):
	# Keep your original arm animation system
	var r = clamp((camera_pivot.rotation.x * 2) / (PI) * 2.1, -1, 1)
	if active_arm_left or active_arm_right:
		animation_tree.set("parameters/grab_dir/blend_position", r)
	else:
		animation_tree.set("parameters/grab_dir/blend_position", 0)

func _physics_process(delta):
	current_delta = delta
	
	if not ragdoll_mode:
		update_movement_input()
		update_floor_detection()
		apply_improved_movement(delta)
		handle_jumping()
		update_walking_animation()
		update_character_rotation()
		handle_footstep_audio(delta)

func update_movement_input():
	# Get movement input (keep your original direction system)
	movement_input = Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		movement_input += animated_skel.global_transform.basis.z
		walking = true
	if Input.is_action_pressed("move_left"):
		movement_input += animated_skel.global_transform.basis.x
		walking = true
	if Input.is_action_pressed("move_right"):
		movement_input -= animated_skel.global_transform.basis.x
		walking = true
	if Input.is_action_pressed("move_backward"):
		movement_input -= animated_skel.global_transform.basis.z
		walking = true
	
	if movement_input.length() == 0:
		walking = false
	else:
		movement_input = movement_input.normalized()

func update_floor_detection():
	# Keep your original floor detection system exactly the same
	was_on_floor = is_on_floor  # Store previous state for footstep detection
	is_on_floor = false
	if on_floor_left.is_colliding():
		for i in on_floor_left.get_collision_count():
			if on_floor_left.get_collision_normal(i).y > 0.5:
				is_on_floor = true
				break
	if not is_on_floor: 
		if on_floor_right.is_colliding():
			for i in on_floor_right.get_collision_count():
				if on_floor_right.get_collision_normal(i).y > 0.5:
					is_on_floor = true
					break

func apply_improved_movement(delta):
	if not physical_bone_body:
		return
	
	# Calculate target velocity
	target_velocity = movement_input * MAX_SPEED
	
	# Get current horizontal velocity
	var current_horizontal = Vector3(
		physical_bone_body.linear_velocity.x, 
		0, 
		physical_bone_body.linear_velocity.z
	)
	
	if is_on_floor:
		# Ground movement with acceleration
		var velocity_diff = target_velocity - current_horizontal
		var acceleration_force = velocity_diff * ACCELERATION * delta
		
		# Apply movement force
		physical_bone_body.linear_velocity.x += acceleration_force.x
		physical_bone_body.linear_velocity.z += acceleration_force.z
		
		# Apply ground damping (keep similar to your original)
		physical_bone_body.linear_velocity.x *= DAMPING
		physical_bone_body.linear_velocity.z *= DAMPING
	else:
		# Air movement (more limited control)
		var velocity_diff = target_velocity - current_horizontal
		var air_force = velocity_diff * ACCELERATION * 0.3 * delta
		
		physical_bone_body.linear_velocity.x += air_force.x
		physical_bone_body.linear_velocity.z += air_force.z
		
		# Light air damping
		physical_bone_body.linear_velocity.x *= AIR_DAMPING
		physical_bone_body.linear_velocity.z *= AIR_DAMPING

func handle_jumping():
	# Keep your original jump system exactly the same
	if Input.is_action_pressed("jump"):
		if is_on_floor and can_jump:
			physical_bone_body.linear_velocity.y = JUMP_STRENGTH
			jump_timer.start()
			can_jump = false

func update_walking_animation():
	# Keep your original animation system
	if walking:
		animation_tree.set("parameters/walking/blend_amount", 1)
	else:
		animation_tree.set("parameters/walking/blend_amount", 0)

func update_character_rotation():
	# Keep your original rotation system
	animated_skel.rotation.y = camera_pivot.rotation.y

# === AUDIO FUNCTIONS (USING AUDIOMANIPULATOR WITH SINGLE STREAMS) ===
func play_grab_audio_left():
	if grab_audio and left_hand_audio_player:
		AudioManipulator.play_audio_static(left_hand_audio_player, [grab_audio], AudioManipulator.AudioType.GRAB_SOUNDS)

func play_grab_audio_right():
	if grab_audio and right_hand_audio_player:
		AudioManipulator.play_audio_static(right_hand_audio_player, [grab_audio], AudioManipulator.AudioType.GRAB_SOUNDS)

func play_release_audio_left():
	if release_audio and left_hand_audio_player:
		AudioManipulator.play_audio_static(left_hand_audio_player, [release_audio], AudioManipulator.AudioType.RELEASE_SOUNDS)

func play_release_audio_right():
	if release_audio and right_hand_audio_player:
		AudioManipulator.play_audio_static(right_hand_audio_player, [release_audio], AudioManipulator.AudioType.RELEASE_SOUNDS)

func play_footstep_audio_left():
	if footstep_audio and left_foot_audio_player:
		AudioManipulator.play_audio_static(left_foot_audio_player, [footstep_audio], AudioManipulator.AudioType.FOOTSTEPS)

func play_footstep_audio_right():
	if footstep_audio and right_foot_audio_player:
		AudioManipulator.play_audio_static(right_foot_audio_player, [footstep_audio], AudioManipulator.AudioType.FOOTSTEPS)

func handle_footstep_audio(delta):
	# Play footsteps when landing from a jump/fall (alternate feet)
	if is_on_floor and not was_on_floor:
		if last_footstep_was_left:
			play_footstep_audio_right()
			last_footstep_was_left = false
		else:
			play_footstep_audio_left()
			last_footstep_was_left = true
		footstep_timer = 0.0  # Reset timer to prevent immediate repeat
	
	# Play footsteps while walking on ground (alternate feet)
	elif is_on_floor and walking:
		footstep_timer += delta
		if footstep_timer >= FOOTSTEP_INTERVAL:
			if last_footstep_was_left:
				play_footstep_audio_right()
				last_footstep_was_left = false
			else:
				play_footstep_audio_left()
				last_footstep_was_left = true
			footstep_timer = 0.0
	else:
		# Reset timer when not walking or in air
		footstep_timer = 0.0

# Keep your original spring function exactly the same
func hookes_law(displacement: Vector3, current_velocity: Vector3, stiffness: float, damping: float) -> Vector3:
	return (stiffness * displacement) - (damping * current_velocity)

# === UPDATED GRABBING FUNCTIONS WITH DUAL HAND TRACKING ===
func _on_r_grab_area_body_entered(body: Node3D):
	if body is PhysicsBody3D and body.get_parent() != physical_skel:
		if active_arm_right and not grabbing_arm_right:
			grabbing_arm_right = true
			grabbed_object_right = body  # Store right hand object
			grab_joint_right.global_position = r_grab_area.global_position
			grab_joint_right.node_a = physical_bone_r_arm_2.get_path()
			grab_joint_right.node_b = body.get_path()
			play_grab_audio_right()

func _on_l_grab_area_body_entered(body: Node3D):
	if body is PhysicsBody3D and body.get_parent() != physical_skel:
		if active_arm_left and not grabbing_arm_left:
			grabbing_arm_left = true
			grabbed_object_left = body   # Store left hand object
			grabbed_object = body        # Keep backward compatibility
			grab_joint_left.global_position = l_grab_area.global_position
			grab_joint_left.node_a = physical_bone_l_arm_2.get_path()
			grab_joint_left.node_b = body.get_path()
			play_grab_audio_left()

func _on_jump_timer_timeout():
	# Keep your original jump timer
	can_jump = true

# Keep your original skeleton update system exactly the same
func _on_skeleton_3d_skeleton_updated() -> void:
	if not ragdoll_mode:
		for b: PhysicalBone3D in physics_bones:
			if not active_arm_left and b.name.contains("LArm"):
				continue
			if not active_arm_right and b.name.contains("RArm"):
				continue
			
			var target_transform: Transform3D = animated_skel.global_transform * animated_skel.get_bone_global_pose(b.get_bone_id())
			var current_transform: Transform3D = physical_skel.global_transform * physical_skel.get_bone_global_pose(b.get_bone_id())
			var rotation_difference: Basis = (target_transform.basis * current_transform.basis.inverse())
			var torque = hookes_law(rotation_difference.get_euler(), b.angular_velocity, angular_spring_stiffness, angular_spring_damping)
			torque = torque.limit_length(max_angular_force)
			
			b.angular_velocity += torque * current_delta

# === NEW HELPER FUNCTIONS FOR ITEM DISPLAY SYSTEM ===
func get_left_hand_item() -> Node:
	## Returns the object currently held in the left hand
	return grabbed_object_left

func get_right_hand_item() -> Node:
	## Returns the object currently held in the right hand
	return grabbed_object_right

func is_left_hand_grabbing() -> bool:
	## Returns true if left hand is actively grabbing
	return grabbing_arm_left

func is_right_hand_grabbing() -> bool:
	## Returns true if right hand is actively grabbing
	return grabbing_arm_right
