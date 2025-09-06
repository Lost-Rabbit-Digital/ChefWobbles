class_name DeliveryTruck
extends Node3D

## Autonomous 3D delivery truck that automatically follows RouteNetwork
## No manual route configuration needed - discovers network automatically

signal arrived_at_destination(node: DeliveryRouteNode)
signal started_delivery(node: DeliveryRouteNode)
signal completed_delivery(node: DeliveryRouteNode)
signal visited_node(node: DeliveryRouteNode)
signal completed_full_route()

@export_group("Movement")
@export var move_speed: float = 5.0
@export var rotation_speed: float = 3.0
@export var arrival_threshold: float = 1.0
@export var height_offset: float = 0.5  # Height above nodes

@export_group("Delivery")
@export var delivery_time: float = 2.0
@export var visit_time: float = 0.5  # Time spent at non-delivery nodes

@export_group("Auto Pilot")
@export var auto_start: bool = true
@export var auto_restart_delay: float = 3.0

@export_group("Route Behavior")
## What to visit: All nodes, delivery points only, or custom
@export_enum("All Nodes", "Delivery Only", "Custom Route") var visit_mode: int = 0
## How to traverse: Sequential, random, or shortest path
@export_enum("Sequential", "Random", "Shortest Path") var traverse_mode: int = 0
## Loop continuously through route
@export var loop_route: bool = true
## Custom route (only used if visit_mode is Custom Route)
@export var custom_route: Array[String] = []

# Network reference
var route_network: RouteNetwork = null
var route_nodes: Dictionary = {}

# Pathfinding
var current_path: Array[DeliveryRouteNode] = []
var current_target_index: int = 0
var current_target_node: DeliveryRouteNode = null

# Movement state
var is_moving: bool = false
var is_delivering: bool = false
var is_visiting: bool = false
var movement_tween: Tween

# Route management
var delivery_queue: Array[String] = []
var current_delivery_index: int = 0
var visited_nodes: Dictionary = {}
var total_distance_traveled: float = 0.0

func _ready():
	call_deferred("_initialize_system")

func _initialize_system():
	if not _connect_to_network():
		push_warning("DeliveryTruck: No RouteNetwork found in scene")
		return
	
	if auto_start and route_network:
		_start_auto_pilot()

func _connect_to_network() -> bool:
	# Try multiple methods to find RouteNetwork
	route_network = _find_route_network()
	
	if not route_network:
		return false
	
	# Connect to network signals if available
	if not route_network.network_configured.is_connected(_on_network_configured):
		route_network.network_configured.connect(_on_network_configured)
	
	# Get nodes from network
	_sync_with_network()
	
	print("DeliveryTruck connected to RouteNetwork with %d nodes" % route_nodes.size())
	return true

func _find_route_network() -> RouteNetwork:
	# Method 1: Check if we're a child of RouteNetwork
	var parent = get_parent()
	if parent is RouteNetwork:
		return parent
	
	# Method 2: Check ancestors
	var current = parent
	while current:
		if current is RouteNetwork:
			return current
		current = current.get_parent()
	
	# Method 3: Find in scene via group
	var networks = get_tree().get_nodes_in_group("route_networks")
	if not networks.is_empty():
		return networks[0]
	
	# Method 4: Find first RouteNetwork in scene
	var all_nodes = get_tree().get_nodes_in_group("delivery_nodes")
	for node in all_nodes:
		var node_parent = node.get_parent()
		if node_parent is RouteNetwork:
			return node_parent
	
	return null

func _sync_with_network():
	if not route_network:
		return
	
	route_nodes.clear()
	var network_nodes = route_network.get_all_nodes()
	
	for node in network_nodes:
		if node and node.node_id != "":
			route_nodes[node.node_id] = node

func _on_network_configured(node_count: int):
	print("Network reconfigured with %d nodes, updating truck route" % node_count)
	_sync_with_network()
	
	# Restart if we were running
	if is_moving or is_delivering or is_visiting:
		restart()

# === PATHFINDING ===

func find_path(start_id: String, target_id: String) -> Array[DeliveryRouteNode]:
	var start_node = route_nodes.get(start_id)
	var target_node = route_nodes.get(target_id)
	
	if not start_node or not target_node:
		return []
	
	# Direct connection check first (optimization)
	if start_node.is_connected_to(target_id):
		return [start_node, target_node]
	
	# Reset pathfinding data
	for node in route_nodes.values():
		node.reset_pathfinding_data()
	
	# A* pathfinding
	var open_list: Array[DeliveryRouteNode] = [start_node]
	var closed_list: Array[DeliveryRouteNode] = []
	
	start_node.g_cost = 0.0
	start_node.h_cost = start_node.global_position.distance_to(target_node.global_position)
	start_node.f_cost = start_node.h_cost
	
	while not open_list.is_empty():
		var current = _get_lowest_f_cost(open_list)
		open_list.erase(current)
		closed_list.append(current)
		
		if current == target_node:
			return _build_path(start_node, target_node)
		
		for neighbor_id in current.connected_nodes:
			var neighbor = route_nodes.get(neighbor_id)
			if not neighbor or neighbor in closed_list:
				continue
			
			var new_g_cost = current.g_cost + current.get_distance_to(neighbor)
			
			if neighbor not in open_list or new_g_cost < neighbor.g_cost:
				neighbor.g_cost = new_g_cost
				neighbor.h_cost = neighbor.global_position.distance_to(target_node.global_position)
				neighbor.f_cost = neighbor.g_cost + neighbor.h_cost
				neighbor.parent_node = current
				
				if neighbor not in open_list:
					open_list.append(neighbor)
	
	return []

func _get_lowest_f_cost(nodes: Array[DeliveryRouteNode]) -> DeliveryRouteNode:
	var lowest = nodes[0]
	for node in nodes:
		if node.f_cost < lowest.f_cost:
			lowest = node
	return lowest

func _build_path(start: DeliveryRouteNode, target: DeliveryRouteNode) -> Array[DeliveryRouteNode]:
	var path: Array[DeliveryRouteNode] = []
	var current = target
	
	while current != start and current != null:
		path.append(current)
		current = current.parent_node
	
	path.append(start)
	path.reverse()
	return path

func get_nearest_node() -> DeliveryRouteNode:
	var nearest: DeliveryRouteNode = null
	var min_distance = INF
	
	for node in route_nodes.values():
		var distance = global_position.distance_to(node.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = node
	
	return nearest

# === MOVEMENT SYSTEM ===

func move_to_node(target_id: String):
	if is_delivering or is_visiting:
		return
	
	var nearest = get_nearest_node()
	if not nearest:
		push_warning("No route nodes available")
		return
	
	# Check if we're already at the target
	if nearest.node_id == target_id:
		current_target_node = nearest
		_on_waypoint_reached()
		return
	
	var path = find_path(nearest.node_id, target_id)
	if path.is_empty():
		push_warning("No path found to node %s" % target_id)
		_move_to_next_delivery()  # Skip to next
		return
	
	current_path = path
	current_target_index = 1  # Skip starting node since we're already there
	is_moving = true
	
	_move_to_next_waypoint()

func _move_to_next_waypoint():
	if current_target_index >= current_path.size():
		_complete_path()
		return
	
	current_target_node = current_path[current_target_index]
	var target_pos = current_target_node.global_position + Vector3(0, height_offset, 0)
	
	# Calculate movement
	var start_pos = global_position
	var distance = start_pos.distance_to(target_pos)
	var move_time = distance / move_speed
	
	if move_time < 0.01:  # Already at destination
		_on_waypoint_reached()
		return
	
	total_distance_traveled += distance
	
	# Calculate rotation
	var look_dir = (target_pos - start_pos).normalized()
	look_dir.y = 0  # Keep truck level
	if look_dir.length() > 0.01:
		var target_transform = transform.looking_at(start_pos + look_dir, Vector3.UP)
		
		if movement_tween:
			movement_tween.kill()
		
		movement_tween = create_tween()
		movement_tween.set_parallel(true)
		movement_tween.set_ease(Tween.EASE_IN_OUT)
		movement_tween.tween_property(self, "global_position", target_pos, move_time)
		movement_tween.tween_property(self, "transform:basis", target_transform.basis, min(move_time * 0.5, 1.0))
		movement_tween.set_parallel(false)
		movement_tween.tween_callback(_on_waypoint_reached)
	else:
		# Just move without rotation
		if movement_tween:
			movement_tween.kill()
		
		movement_tween = create_tween()
		movement_tween.tween_property(self, "global_position", target_pos, move_time)
		movement_tween.tween_callback(_on_waypoint_reached)

func _on_waypoint_reached():
	if not current_target_node:
		return
	
	arrived_at_destination.emit(current_target_node)
	
	# Check if this is the final destination
	if current_target_index == current_path.size() - 1:
		# Mark as visited
		visited_nodes[current_target_node.node_id] = true
		current_target_node.mark_visited()
		
		if current_target_node.is_delivery_point:
			_start_delivery()
		else:
			_start_visit()
	else:
		# Just a waypoint, continue moving
		current_target_index += 1
		_move_to_next_waypoint()

func _start_visit():
	is_visiting = true
	visited_node.emit(current_target_node)
	
	await get_tree().create_timer(visit_time).timeout
	_complete_visit()

func _complete_visit():
	is_visiting = false
	current_delivery_index += 1
	_move_to_next_delivery()

func _start_delivery():
	is_delivering = true
	started_delivery.emit(current_target_node)
	
	await get_tree().create_timer(delivery_time).timeout
	_complete_delivery()

func _complete_delivery():
	is_delivering = false
	completed_delivery.emit(current_target_node)
	
	current_delivery_index += 1
	_move_to_next_delivery()

func _complete_path():
	is_moving = false
	current_path.clear()
	current_target_index = 0
	current_target_node = null

# === AUTO-PILOT ===

func _start_auto_pilot():
	if not route_network:
		if not _connect_to_network():
			return
	
	_build_delivery_queue()
	
	if not delivery_queue.is_empty():
		print("Auto-pilot: Starting route with %d stops" % delivery_queue.size())
		current_delivery_index = 0
		visited_nodes.clear()
		total_distance_traveled = 0.0
		_move_to_next_delivery()
	else:
		push_warning("No valid route nodes found to visit")

func _build_delivery_queue():
	delivery_queue.clear()
	
	# Get nodes based on visit mode
	var nodes_to_visit: Array[DeliveryRouteNode] = []
	
	match visit_mode:
		0:  # All Nodes
			nodes_to_visit = route_network.get_all_nodes()
		1:  # Delivery Only
			nodes_to_visit = route_network.get_delivery_nodes()
			if nodes_to_visit.is_empty():
				push_warning("No delivery points set, visiting all nodes instead")
				nodes_to_visit = route_network.get_all_nodes()
		2:  # Custom Route
			if not custom_route.is_empty():
				delivery_queue = custom_route.duplicate()
				return
			else:
				push_warning("Custom route empty, visiting all nodes")
				nodes_to_visit = route_network.get_all_nodes()
	
	# Sort based on traverse mode
	match traverse_mode:
		0:  # Sequential (by node ID)
			nodes_to_visit.sort_custom(func(a, b): 
				return a.node_id.to_int() < b.node_id.to_int()
			)
		1:  # Random
			nodes_to_visit.shuffle()
		2:  # Shortest Path (greedy nearest neighbor)
			nodes_to_visit = _build_shortest_path_route(nodes_to_visit)
	
	# Build queue from sorted nodes
	for node in nodes_to_visit:
		delivery_queue.append(node.node_id)

func _build_shortest_path_route(nodes: Array[DeliveryRouteNode]) -> Array[DeliveryRouteNode]:
	if nodes.is_empty():
		return nodes
	
	var ordered: Array[DeliveryRouteNode] = []
	var remaining = nodes.duplicate()
	
	# Start from nearest node to truck
	var current_pos = global_position
	var nearest_idx = 0
	var nearest_dist = INF
	
	for i in range(remaining.size()):
		var dist = current_pos.distance_to(remaining[i].global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_idx = i
	
	var current = remaining[nearest_idx]
	ordered.append(current)
	remaining.remove_at(nearest_idx)
	
	# Greedy nearest neighbor
	while not remaining.is_empty():
		nearest_idx = 0
		nearest_dist = INF
		
		for i in range(remaining.size()):
			var dist = current.global_position.distance_to(remaining[i].global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_idx = i
		
		current = remaining[nearest_idx]
		ordered.append(current)
		remaining.remove_at(nearest_idx)
	
	return ordered

func _move_to_next_delivery():
	if current_delivery_index >= delivery_queue.size():
		_on_route_complete()
		return
	
	var target_id = delivery_queue[current_delivery_index]
	var node = route_nodes.get(target_id)
	
	if node:
		var status = " [DELIVERY]" if node.is_delivery_point else ""
		print("Stop %d/%d: Node %s%s" % [
			current_delivery_index + 1,
			delivery_queue.size(),
			target_id,
			status
		])
		move_to_node(target_id)
	else:
		push_warning("Node %s not found, skipping" % target_id)
		current_delivery_index += 1
		_move_to_next_delivery()

func _on_route_complete():
	print("Route complete! Visited %d nodes, traveled %.1fm" % [
		visited_nodes.size(), 
		total_distance_traveled
	])
	completed_full_route.emit()
	
	if loop_route:
		_restart_cycle()

func _restart_cycle():
	current_delivery_index = 0
	visited_nodes.clear()
	
	# Reset visual states
	if route_network:
		route_network.reset_all_visited()
	
	print("Restarting route in %.1f seconds..." % auto_restart_delay)
	await get_tree().create_timer(auto_restart_delay).timeout
	
	# Rebuild in case network changed
	_sync_with_network()
	_build_delivery_queue()
	_move_to_next_delivery()

# === PUBLIC METHODS ===

func stop():
	is_moving = false
	is_delivering = false
	is_visiting = false
	
	if movement_tween:
		movement_tween.kill()
	
	current_path.clear()

func restart():
	stop()
	_start_auto_pilot()

func get_network() -> RouteNetwork:
	return route_network

func get_visited_count() -> int:
	return visited_nodes.size()

func get_remaining_stops() -> int:
	return max(0, delivery_queue.size() - current_delivery_index)

func get_current_destination() -> String:
	if current_delivery_index < delivery_queue.size():
		return delivery_queue[current_delivery_index]
	return ""

func get_total_distance() -> float:
	return total_distance_traveled

func get_progress_percent() -> float:
	if delivery_queue.is_empty():
		return 0.0
	return float(current_delivery_index) / float(delivery_queue.size()) * 100.0
