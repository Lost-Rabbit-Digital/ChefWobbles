extends Node3D

# === ROTATION SETTINGS ===
@export var rotation_speed_x: float = 0.25  # Rotation speed around X axis (radians per second)
@export var rotation_speed_y: float = 0.25  # Rotation speed around Y axis (radians per second)
@export var rotation_speed_z: float = 0.25  # Rotation speed around Z axis (radians per second)
@export var enabled: bool = true

# === DIRECTION VARIABLES ===
var direction_x: float
var direction_y: float
var direction_z: float

func _ready():
	print("Rotator ready on: ", name)
	# Randomly choose directions for each axis (1 or -1)
	direction_x = 1.0 if randf() > 0.5 else -1.0
	direction_y = 1.0 if randf() > 0.5 else -1.0
	direction_z = 1.0 if randf() > 0.5 else -1.0

func _process(delta):
	if not enabled:
		return
	
	# Rotate around all axes with random directions
	rotate_x(direction_x * rotation_speed_x * delta)
	rotate_y(direction_y * rotation_speed_y * delta)
	rotate_z(direction_z * rotation_speed_z * delta)
