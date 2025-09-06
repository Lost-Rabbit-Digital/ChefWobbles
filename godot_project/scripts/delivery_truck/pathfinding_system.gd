class_name PathfindingSystem
extends Node

## A* pathfinding system for delivery route navigation
## Manages route calculation between delivery nodes

signal path_calculated(path: Array[DeliveryRouteNode])
signal pathfinding_failed(start_id: String, target_id: String)

var route_nodes: Dictionary = {}

func _ready():
	add_to_group("route_manager")
	call_deferred("_initialize_route_network")

func _initialize_route_network():
	# Collect all DeliveryRouteNode instances
	var nodes = get_tree().get_nodes_in_group("delivery_nodes")
	if nodes.is_empty():
		# Fallback: search for nodes by class
		nodes = find_all_delivery_nodes()
	
	for node in nodes:
		if node is DeliveryRouteNode:
			register_node(node)
	
	print("Pathfinding system initialized with %d nodes" % route_nodes.size())

func find_all_delivery_nodes() -> Array:
	var found_nodes: Array = []
	var root = get_tree().current_scene
	_recursive_find_delivery_nodes(root, found_nodes)
	return found_nodes

func _recursive_find_delivery_nodes(node: Node, found_nodes: Array):
	if node is DeliveryRouteNode:
		found_nodes.append(node)
		node.add_to_group("delivery_nodes")
	
	for child in node.get_children():
		_recursive_find_delivery_nodes(child, found_nodes)

func register_node(node: DeliveryRouteNode):
	route_nodes[node.node_id] = node

func get_node_by_id(node_id: String) -> DeliveryRouteNode:
	return route_nodes.get(node_id)

func calculate_path(start_id: String, target_id: String) -> Array[DeliveryRouteNode]:
	var start_node = get_node_by_id(start_id)
	var target_node = get_node_by_id(target_id)
	
	if not start_node or not target_node:
		pathfinding_failed.emit(start_id, target_id)
		return []
	
	return _find_path_astar(start_node, target_node)

func _find_path_astar(start: DeliveryRouteNode, target: DeliveryRouteNode) -> Array[DeliveryRouteNode]:
	# Reset all nodes
	for node in route_nodes.values():
		node.reset_pathfinding_data()
	
	var open_set: Array[DeliveryRouteNode] = [start]
	var closed_set: Array[DeliveryRouteNode] = []
	
	start.g_cost = 0.0
	start.h_cost = start.get_distance_to(target)
	start.calculate_f_cost()
	
	while not open_set.is_empty():
		# Find node with lowest f_cost
		var current_node = _get_lowest_f_cost_node(open_set)
		open_set.erase(current_node)
		closed_set.append(current_node)
		
		# Check if we reached the target
		if current_node == target:
			return _reconstruct_path(start, target)
		
		# Check all neighbors
		for neighbor_id in current_node.connected_nodes:
			var neighbor = get_node_by_id(neighbor_id)
			if not neighbor or neighbor in closed_set:
				continue
			
			var tentative_g_cost = current_node.g_cost + current_node.get_distance_to(neighbor)
			
			if neighbor not in open_set:
				open_set.append(neighbor)
			elif tentative_g_cost >= neighbor.g_cost:
				continue
			
			neighbor.parent_node = current_node
			neighbor.g_cost = tentative_g_cost
			neighbor.h_cost = neighbor.get_distance_to(target)
			neighbor.calculate_f_cost()
	
	# No path found
	pathfinding_failed.emit(start.node_id, target.node_id)
	return []

func _get_lowest_f_cost_node(nodes: Array[DeliveryRouteNode]) -> DeliveryRouteNode:
	var lowest_node = nodes[0]
	for node in nodes:
		if node.f_cost < lowest_node.f_cost:
			lowest_node = node
		elif node.f_cost == lowest_node.f_cost and node.h_cost < lowest_node.h_cost:
			lowest_node = node
	return lowest_node

func _reconstruct_path(start: DeliveryRouteNode, target: DeliveryRouteNode) -> Array[DeliveryRouteNode]:
	var path: Array[DeliveryRouteNode] = []
	var current_node = target
	
	while current_node != start:
		path.append(current_node)
		current_node = current_node.parent_node
		
		# Safety check to prevent infinite loops
		if current_node == null:
			print("Path reconstruction failed - broken parent chain")
			return []
	
	path.append(start)
	path.reverse()
	
	path_calculated.emit(path)
	return path

func get_nearest_node_to_position(world_position: Vector2) -> DeliveryRouteNode:
	var nearest_node: DeliveryRouteNode = null
	var shortest_distance: float = INF
	
	for node in route_nodes.values():
		var distance = world_position.distance_to(node.global_position)
		if distance < shortest_distance:
			shortest_distance = distance
			nearest_node = node
	
	return nearest_node

func get_delivery_nodes() -> Array[DeliveryRouteNode]:
	var delivery_nodes: Array[DeliveryRouteNode] = []
	for node in route_nodes.values():
		if node.is_delivery_point:
			delivery_nodes.append(node)
	return delivery_nodes
