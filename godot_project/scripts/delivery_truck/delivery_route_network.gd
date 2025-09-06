class_name RouteNetwork
extends Node3D

## Automatically discovers and configures all route nodes
## No manual configuration needed - just add nodes as children

signal network_configured(node_count: int)
signal node_visited(node: DeliveryRouteNode)
signal all_nodes_visited()

@export_group("Auto Configuration")
@export var auto_configure_on_ready: bool = true
@export var auto_detect_delivery_markers: bool = true
@export var delivery_marker_name: String = "DeliveryMarker"

@export_group("Network Topology")
@export_enum("Auto Detect", "Linear", "Loop", "Hub", "Grid", "Nearest Neighbor") var network_type: int = 0
@export var max_connection_distance: float = 50.0  # Max distance for auto connections
@export var create_return_paths: bool = true

@export_group("Visual")
@export var show_connections: bool = true
@export var connection_color: Color = Color(0.3, 0.5, 1.0, 0.5)
@export var connection_thickness: float = 0.05

@export_group("Debug")
@export var show_debug_info: bool = false
@export var auto_refresh_in_editor: bool = false

# Internal state
var route_nodes: Dictionary = {}
var node_count: int = 0
var connection_visuals: Array[MeshInstance3D] = []
var delivery_markers: Dictionary = {}  # Node ID -> Marker reference

func _ready():
	add_to_group("route_networks")
	
	if auto_configure_on_ready:
		call_deferred("configure_network")

func configure_network():
	_clear_connection_visuals()
	
	# Auto-discover everything
	_auto_discover_nodes()
	
	if route_nodes.is_empty():
		push_warning("RouteNetwork: No nodes found to configure")
		return
	
	_auto_detect_delivery_points()
	_auto_configure_connections()
	
	if show_connections:
		_create_connection_visuals()
	
	network_configured.emit(node_count)
	
	if show_debug_info:
		print_network_info()

func _auto_discover_nodes():
	"""Automatically discover all route nodes without manual configuration"""
	route_nodes.clear()
	node_count = 0
	
	# Find all Node3D children and convert them to route nodes
	var discovered_nodes: Array[Node3D] = []
	_discover_nodes_recursive(self, discovered_nodes)
	
	# Sort by name for consistent ordering
	discovered_nodes.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	
	# Assign IDs based on discovery order
	for i in range(discovered_nodes.size()):
		var node = discovered_nodes[i]
		var node_id = i + 1
		
		# Ensure it has the DeliveryRouteNode script
		if not node is DeliveryRouteNode:
			_convert_to_route_node(node)
		
		# Configure the node
		node.node_id = str(node_id)
		node.add_to_group("delivery_nodes")
		route_nodes[node_id] = node
		node_count = node_id
	
	print("Auto-discovered %d route nodes" % route_nodes.size())

func _discover_nodes_recursive(parent: Node, discovered: Array[Node3D]):
	"""Recursively find all potential route nodes"""
	for child in parent.get_children():
		# Skip visual/helper nodes
		if child is MeshInstance3D or child is CollisionShape3D or child is Area3D:
			continue
		
		# Skip delivery markers themselves
		if child.name.contains(delivery_marker_name):
			continue
		
		# Found a Node3D that could be a route node
		if child is Node3D:
			# Check if it's already a route node or looks like one
			var is_route_node = (
				child is DeliveryRouteNode or
				child.name.contains("Node") or
				child.name.contains("Point") or
				child.name.contains("Stop") or
				child.name.contains("Waypoint") or
				child.get_child_count() == 0  # Empty Node3D markers
			)
			
			if is_route_node:
				discovered.append(child)
			else:
				# Check children of this node too
				_discover_nodes_recursive(child, discovered)

func _convert_to_route_node(node: Node3D):
	"""Convert a regular Node3D to a DeliveryRouteNode"""
	if node is DeliveryRouteNode:
		return
	
	# Try to load and attach the script
	var script_path = "res://scripts/delivery_truck/delivery_route_node.gd"
	
	# Try common paths if the first doesn't exist
	var possible_paths = [
		script_path,
		"res://delivery_route_node.gd",
		"res://DeliveryRouteNode.gd",
		"res://scripts/DeliveryRouteNode.gd"
	]
	
	for path in possible_paths:
		if ResourceLoader.exists(path):
			node.set_script(load(path))
			if show_debug_info:
				print("Converted %s to DeliveryRouteNode" % node.name)
			return
	
	push_warning("Could not find DeliveryRouteNode script for %s" % node.name)

func _auto_detect_delivery_points():
	"""Automatically detect delivery points based on child markers"""
	if not auto_detect_delivery_markers:
		return
	
	delivery_markers.clear()
	
	# Look for delivery markers in each route node
	for node_id in route_nodes:
		var node = route_nodes[node_id]
		node.is_delivery_point = false  # Reset first
		
		# Check if this node has a delivery marker child
		for child in node.get_children():
			if child.name.contains(delivery_marker_name) or child is Marker3D:
				node.is_delivery_point = true
				delivery_markers[node_id] = child
				if show_debug_info:
					print("Node %s marked as delivery point (found marker: %s)" % [node_id, child.name])
				break
		
		# Also check if the node name itself indicates delivery
		if node.name.contains("Delivery") or node.name.contains("Stop"):
			node.is_delivery_point = true
			if show_debug_info:
				print("Node %s marked as delivery point (name match)" % node_id)

func _auto_configure_connections():
	"""Automatically determine the best connection topology"""
	# Clear existing connections
	for node in route_nodes.values():
		node.connected_nodes.clear()
	
	match network_type:
		0:  # Auto Detect - choose based on node layout
			_auto_detect_topology()
		1:  # Linear
			_setup_linear_connections()
		2:  # Loop
			_setup_loop_connections()
		3:  # Hub
			_setup_hub_connections()
		4:  # Grid
			_setup_grid_connections()
		5:  # Nearest Neighbor
			_setup_nearest_neighbor_connections()
	
	if create_return_paths:
		_make_connections_bidirectional()

func _auto_detect_topology():
	"""Intelligently detect the best topology based on node positions"""
	if node_count <= 0:
		return
	
	# Analyze node positions to determine best topology
	var positions: Array[Vector3] = []
	for node in route_nodes.values():
		positions.append(node.global_position)
	
	# Check if nodes form a rough line
	if _is_linear_layout(positions):
		if show_debug_info:
			print("Auto-detected: Linear topology")
		_setup_linear_connections()
	# Check if nodes form a grid
	elif _is_grid_layout(positions):
		if show_debug_info:
			print("Auto-detected: Grid topology")
		_setup_grid_connections()
	# Default to nearest neighbor for complex layouts
	else:
		if show_debug_info:
			print("Auto-detected: Nearest neighbor topology")
		_setup_nearest_neighbor_connections()

func _is_linear_layout(positions: Array[Vector3]) -> bool:
	"""Check if nodes roughly form a line"""
	if positions.size() < 3:
		return true
	
	# Calculate variance from a fitted line
	# Simplified: check if most nodes are within a corridor
	var min_pos = positions[0]
	var max_pos = positions[0]
	
	for pos in positions:
		min_pos = Vector3(
			min(min_pos.x, pos.x),
			min_pos.y,  # Ignore Y
			min(min_pos.z, pos.z)
		)
		max_pos = Vector3(
			max(max_pos.x, pos.x),
			max_pos.y,  # Ignore Y
			max(max_pos.z, pos.z)
		)
	
	var extent = max_pos - min_pos
	var max_extent = max(extent.x, extent.z)
	var min_extent = min(extent.x, extent.z)
	
	# Linear if one dimension is much larger than the other
	return min_extent < max_extent * 0.3

func _is_grid_layout(positions: Array[Vector3]) -> bool:
	"""Check if nodes form a rough grid"""
	if positions.size() < 4:
		return false
	
	# Check if nodes align to a grid pattern
	var x_positions = {}
	var z_positions = {}
	var threshold = 2.0  # Alignment threshold
	
	for pos in positions:
		# Group similar X positions
		var found_x = false
		for x in x_positions:
			if abs(pos.x - x) < threshold:
				x_positions[x] += 1
				found_x = true
				break
		if not found_x:
			x_positions[pos.x] = 1
		
		# Group similar Z positions
		var found_z = false
		for z in z_positions:
			if abs(pos.z - z) < threshold:
				z_positions[z] += 1
				found_z = true
				break
		if not found_z:
			z_positions[pos.z] = 1
	
	# Grid if we have clear rows and columns
	var rows = x_positions.size()
	var cols = z_positions.size()
	return rows > 1 and cols > 1 and rows * cols >= positions.size() * 0.7

func _setup_linear_connections():
	"""Connect nodes in sequence based on position"""
	var sorted_nodes = route_nodes.values()
	
	# Sort by position along major axis
	sorted_nodes.sort_custom(func(a, b):
		var a_pos = a.global_position
		var b_pos = b.global_position
		# Sort by X, then Z if X is similar
		if abs(a_pos.x - b_pos.x) > 1.0:
			return a_pos.x < b_pos.x
		return a_pos.z < b_pos.z
	)
	
	# Connect in sequence
	for i in range(sorted_nodes.size()):
		var node = sorted_nodes[i]
		node.connected_nodes.clear()
		
		if i > 0:
			node.connected_nodes.append(sorted_nodes[i-1].node_id)
		if i < sorted_nodes.size() - 1:
			node.connected_nodes.append(sorted_nodes[i+1].node_id)

func _setup_loop_connections():
	"""Connect nodes in a loop"""
	_setup_linear_connections()
	
	# Connect first and last
	var sorted_nodes = route_nodes.values()
	sorted_nodes.sort_custom(func(a, b):
		return a.node_id.to_int() < b.node_id.to_int()
	)
	
	if sorted_nodes.size() > 2:
		var first = sorted_nodes[0]
		var last = sorted_nodes[-1]
		
		if not first.connected_nodes.has(last.node_id):
			first.connected_nodes.append(last.node_id)
		if not last.connected_nodes.has(first.node_id):
			last.connected_nodes.append(first.node_id)

func _setup_hub_connections():
	"""Connect all nodes to the most central node"""
	# Find the most central node
	var center_node = _find_center_node()
	if not center_node:
		_setup_nearest_neighbor_connections()
		return
	
	for node in route_nodes.values():
		node.connected_nodes.clear()
		if node != center_node:
			node.connected_nodes.append(center_node.node_id)
			if not center_node.connected_nodes.has(node.node_id):
				center_node.connected_nodes.append(node.node_id)

func _find_center_node() -> DeliveryRouteNode:
	"""Find the most centrally located node"""
	var min_total_dist = INF
	var center_node = null
	
	for node in route_nodes.values():
		var total_dist = 0.0
		for other in route_nodes.values():
			if node != other:
				total_dist += node.global_position.distance_to(other.global_position)
		
		if total_dist < min_total_dist:
			min_total_dist = total_dist
			center_node = node
	
	return center_node

func _setup_grid_connections():
	"""Connect nodes in a grid pattern"""
	# Sort nodes into a grid
	var sorted_nodes = route_nodes.values()
	var grid_size = ceil(sqrt(sorted_nodes.size()))
	
	# Sort by position to form grid
	sorted_nodes.sort_custom(func(a, b):
		if abs(a.global_position.z - b.global_position.z) > 2.0:
			return a.global_position.z < b.global_position.z
		return a.global_position.x < b.global_position.x
	)
	
	# Connect grid neighbors
	for i in range(sorted_nodes.size()):
		var node = sorted_nodes[i]
		node.connected_nodes.clear()
		
		var row = i / int(grid_size)
		var col = i % int(grid_size)
		
		# Connect to adjacent nodes
		var neighbors = [
			i - grid_size,  # Above
			i + grid_size,  # Below
			i - 1 if col > 0 else -1,  # Left
			i + 1 if col < grid_size - 1 else -1  # Right
		]
		
		for n in neighbors:
			if n >= 0 and n < sorted_nodes.size():
				var neighbor = sorted_nodes[n]
				if node.global_position.distance_to(neighbor.global_position) <= max_connection_distance:
					node.connected_nodes.append(neighbor.node_id)

func _setup_nearest_neighbor_connections():
	"""Connect each node to its nearest neighbors"""
	for node in route_nodes.values():
		node.connected_nodes.clear()
		
		# Find nearest neighbors
		var distances = []
		for other in route_nodes.values():
			if node != other:
				var dist = node.global_position.distance_to(other.global_position)
				if dist <= max_connection_distance:
					distances.append({"node": other, "distance": dist})
		
		# Sort by distance
		distances.sort_custom(func(a, b): return a.distance < b.distance)
		
		# Connect to 2-4 nearest neighbors
		var max_connections = min(3, distances.size())
		for i in range(max_connections):
			node.connected_nodes.append(distances[i].node.node_id)

func _make_connections_bidirectional():
	"""Ensure all connections are two-way"""
	for node in route_nodes.values():
		for connected_id in node.connected_nodes:
			var other = get_node_by_id(connected_id)
			if other and not other.connected_nodes.has(node.node_id):
				other.connected_nodes.append(node.node_id)

func _create_connection_visuals():
	_clear_connection_visuals()
	
	var drawn = {}
	
	for node in route_nodes.values():
		for connected_id in node.connected_nodes:
			var other = get_node_by_id(connected_id)
			if not other:
				continue
			
			# Avoid duplicates
			var key = "%s-%s" % [
				min(node.node_id, connected_id),
				max(node.node_id, connected_id)
			]
			if drawn.has(key):
				continue
			drawn[key] = true
			
			var line = _create_line_mesh(node, other)
			if line:
				connection_visuals.append(line)
				add_child(line)

func _create_line_mesh(start_node: Node3D, end_node: Node3D) -> MeshInstance3D:
	var start_pos = start_node.global_position
	var end_pos = end_node.global_position
	var distance = start_pos.distance_to(end_pos)
	
	if distance < 0.01:
		return null
	
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.height = distance
	cylinder.top_radius = connection_thickness
	cylinder.bottom_radius = connection_thickness
	
	mesh_instance.mesh = cylinder
	mesh_instance.global_position = (start_pos + end_pos) / 2.0
	
	# Safe rotation
	var direction = (end_pos - start_pos).normalized()
	var axis = Vector3.UP.cross(direction).normalized()
	if axis.length() > 0.001:
		var angle = Vector3.UP.angle_to(direction)
		mesh_instance.global_transform.basis = Basis(axis, angle)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = connection_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	mesh_instance.top_level = true
	
	return mesh_instance

func _clear_connection_visuals():
	for visual in connection_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	connection_visuals.clear()

# === PUBLIC API ===

func get_node_by_id(node_id: String) -> DeliveryRouteNode:
	return route_nodes.get(node_id.to_int())

func get_all_nodes() -> Array[DeliveryRouteNode]:
	var nodes: Array[DeliveryRouteNode] = []
	for node in route_nodes.values():
		nodes.append(node)
	return nodes

func get_delivery_nodes() -> Array[DeliveryRouteNode]:
	var nodes: Array[DeliveryRouteNode] = []
	for node in route_nodes.values():
		if node.is_delivery_point:
			nodes.append(node)
	return nodes

func reset_all_visited():
	for node in route_nodes.values():
		if node.has_method("reset_visited"):
			node.reset_visited()

func validate_network() -> bool:
	var issues = []
	
	for node in route_nodes.values():
		if node.connected_nodes.is_empty():
			issues.append("Node %s has no connections" % node.node_id)
	
	if not issues.is_empty():
		print("Network validation issues:")
		for issue in issues:
			print("  - " + issue)
		return false
	
	return true

func print_network_info():
	print("\n=== ROUTE NETWORK INFO ===")
	print("Nodes: %d" % node_count)
	print("Topology: %s" % ["Auto", "Linear", "Loop", "Hub", "Grid", "Nearest"][network_type])
	
	var delivery_count = 0
	for node in route_nodes.values():
		var connections = ", ".join(node.connected_nodes)
		var status = " [DELIVERY]" if node.is_delivery_point else ""
		print("  %s (%s) -> [%s]%s" % [node.name, node.node_id, connections, status])
		if node.is_delivery_point:
			delivery_count += 1
	
	print("Delivery points: %d" % delivery_count)
	print("========================\n")

func _process(delta):
	if auto_refresh_in_editor and Engine.is_editor_hint():
		configure_network()
