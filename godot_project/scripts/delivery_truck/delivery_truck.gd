class_name DeliveryTruck
extends CharacterBody2D

## Delivery truck that smoothly follows calculated paths
## Handles movement, rotation, and delivery logic

signal arrived_at_destination(node: DeliveryRouteNode)
signal started_delivery(node: DeliveryRouteNode)
signal completed_delivery(node: DeliveryRouteNode)

@export_group("Movement")
@export var move_speed: float = 200.0
@export var rotation_speed: float = 5.0
@export var arrival_threshold: float = 10.0

@export_group("Delivery")
@export var delivery_time: float = 2.0

# Current pathfinding state
var pathfinding_system: PathfindingSystem
var current_path: Array[DeliveryRouteNode] = []
var current_target_index: int = 0
var current_target_node: DeliveryRouteNode = null
var is_moving: bool = false
var is_delivering: bool = false

# Movement tweening
var movement_tween: Tween
var rotation_tween: Tween

func _ready():
	# Get pathfinding system reference
	pathfinding_system = get_tree().get_first_node_in_group("route_manager")
	
	if not pathfinding_system:
		push_error("DeliveryTruck: No PathfindingSystem found in scene")
		return
	
	# Connect signals
	pathfinding_system.path_calculated.connect(_on_path_calculated)
	pathfinding_system.pathfinding_failed.connect(_on_pathfinding_failed)

func move_to_node(target_node_id: String):
	if is_delivering:
		print("Cannot move while delivering")
		return
	
	# Find nearest node to current position
	var nearest_node = pathfinding_system.get_nearest_node_to_position(global_position)
	if not nearest_node:
		print("No route nodes found")
		return
	
	# Calculate path
	print("Calculating path from %s to %s" % [nearest_node.node_id, target_node_id])
	pathfinding_system.calculate_path(nearest_node.node_id, target_node_id)

func move_to_nearest_delivery_point():
	var delivery_nodes = pathfinding_system.get_delivery_nodes()
	if delivery_nodes.is_empty():
		print("No delivery points found")
		return
	
	# Find closest delivery point
	var closest_delivery = delivery_nodes[0]
	var shortest_distance = global_position.distance_to(closest_delivery.global_position)
	
	for delivery_node in delivery_nodes:
		var distance = global_position.distance_to(delivery_node.global_position)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_delivery = delivery_node
	
	move_to_node(closest_delivery.node_id)

func _on_path_calculated(path: Array[DeliveryRouteNode]):
	if path.is_empty():
		return
	
	current_path = path
	current_target_index = 1  # Skip first node (current position)
	is_moving = true
	
	print("Path calculated with %d nodes" % path.size())
	_move_to_next_node()

func _on_pathfinding_failed(start_id: String, target_id: String):
	print("Pathfinding failed: %s -> %s" % [start_id, target_id])
	is_moving = false

func _move_to_next_node():
	if current_target_index >= current_path.size():
		_path_completed()
		return
	
	current_target_node = current_path[current_target_index]
	var target_position = current_target_node.global_position
	
	print("Moving to node: %s" % current_target_node.node_id)
	
	# Calculate movement duration based on distance and speed
	var distance = global_position.distance_to(target_position)
	var duration = distance / move_speed
	
	# Rotate towards target
	_rotate_towards_target(target_position)
	
	# Create smooth movement tween
	if movement_tween:
		movement_tween.kill()
	
	movement_tween = create_tween()
	movement_tween.set_ease(Tween.EASE_IN_OUT)
	movement_tween.set_trans(Tween.TRANS_CUBIC)
	
	movement_tween.tween_property(self, "global_position", target_position, duration)
	movement_tween.tween_callback(_on_node_reached)

func _rotate_towards_target(target_position: Vector2):
	var direction = (target_position - global_position).normalized()
	var target_rotation = direction.angle()
	
	# Handle rotation wrapping
	var current_rot = rotation
	var angle_diff = target_rotation - current_rot
	
	# Choose shortest rotation path
	if angle_diff > PI:
		angle_diff -= 2 * PI
	elif angle_diff < -PI:
		angle_diff += 2 * PI
	
	if rotation_tween:
		rotation_tween.kill()
	
	rotation_tween = create_tween()
	rotation_tween.set_ease(Tween.EASE_OUT)
	rotation_tween.tween_property(self, "rotation", current_rot + angle_diff, 0.3)

func _on_node_reached():
	if not current_target_node:
		return
	
	arrived_at_destination.emit(current_target_node)
	
	# Handle delivery if this is a delivery point
	if current_target_node.is_delivery_point:
		_start_delivery()
	else:
		# Move to next node
		current_target_index += 1
		_move_to_next_node()

func _start_delivery():
	is_delivering = true
	started_delivery.emit(current_target_node)
	
	print("Starting delivery at: %s" % current_target_node.node_id)
	
	# Create delivery timer
	var delivery_timer = get_tree().create_timer(delivery_time)
	delivery_timer.timeout.connect(_complete_delivery)

func _complete_delivery():
	is_delivering = false
	completed_delivery.emit(current_target_node)
	
	print("Completed delivery at: %s" % current_target_node.node_id)
	
	# Continue to next node
	current_target_index += 1
	_move_to_next_node()

func _path_completed():
	is_moving = false
	current_path.clear()
	current_target_index = 0
	current_target_node = null
	
	print("Path completed!")

func stop_movement():
	is_moving = false
	if movement_tween:
		movement_tween.kill()
	if rotation_tween:
		rotation_tween.kill()
	
	current_path.clear()
	current_target_index = 0

# Debug function for manual testing
func _input(event):
	if not Engine.is_editor_hint() and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				move_to_nearest_delivery_point()
			KEY_2:
				stop_movement()
