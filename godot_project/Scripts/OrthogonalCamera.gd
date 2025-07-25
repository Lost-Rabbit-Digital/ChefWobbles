extends Node3D

@export var target_node: Node3D# target position (to follow the character)

@export var mouse_sensitivity = 0.1# camera rotation speed

@export var ortho_camera: Camera3D
@export var camera_angle_vertical: float = -25.0

@export var camera_change_rate: float = 5.0

@export var minimum_arm_distance: float = 5
@export var maximum_arm_distance: float = 45


@onready var spring_arm = $SpringArm3D


func _physics_process(delta):
	if target_node != null:
		# lerp position to the target position
		global_position = lerp(global_position,target_node.global_position,0.5)
	
	# Always clamp the camera
	rotation_degrees.x = clamp(rotation_degrees.x, camera_angle_vertical, camera_angle_vertical)
	spring_arm.spring_length = clamp(spring_arm.spring_length, minimum_arm_distance, maximum_arm_distance)
	
	if Input.is_action_pressed("rotate_camera_left"):
		rotation_degrees.y -= camera_change_rate
	elif Input.is_action_pressed("rotate_camera_right"):
		rotation_degrees.y += camera_change_rate
	elif Input.is_action_just_pressed("camera_zoom_in"):
		if (spring_arm.spring_length - camera_change_rate) > minimum_arm_distance:
			spring_arm.spring_length -= camera_change_rate
	elif Input.is_action_just_pressed("camera_zoom_out"):
		if (spring_arm.spring_length + camera_change_rate) < maximum_arm_distance:
			spring_arm.spring_length += camera_change_rate
