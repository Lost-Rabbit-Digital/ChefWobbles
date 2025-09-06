class_name DeliveryRouteNode
extends Node3D

## Route node for 3D delivery system
## Automatically configured by RouteNetwork parent

signal truck_arrived(truck: Node3D)
signal truck_departed(truck: Node3D)

@export_group("Visual")
@export var show_debug_sphere: bool = true
@export var debug_color: Color = Color.CYAN
@export var delivery_color: Color = Color.GREEN
@export var visited_color: Color = Color.GRAY

# Set by RouteNetwork automatically
var node_id: String = ""
var connected_nodes: Array[String] = []
var is_delivery_point: bool = false

# A* pathfinding data
var g_cost: float = 0.0
var h_cost: float = 0.0
var f_cost: float = 0.0
var parent_node: DeliveryRouteNode = null

# Runtime state
var is_visited: bool = false
var visit_count: int = 0

# Visual elements
var debug_mesh: MeshInstance3D = null
var debug_material: StandardMaterial3D = null

func _ready():
	if show_debug_sphere:
		_create_debug_visuals()
	
	# Ensure this node is in the correct group
	add_to_group("delivery_nodes")

func _create_debug_visuals():
	debug_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	debug_mesh.mesh = sphere
	
	debug_material = StandardMaterial3D.new()
	debug_material.albedo_color = debug_color
	debug_material.emission_enabled = true
	debug_material.emission = debug_color
	debug_material.emission_intensity = 0.3
	
	debug_mesh.material_override = debug_material
	add_child(debug_mesh)
	
	_update_visual_state()

func _update_visual_state():
	if not debug_material:
		return
	
	if is_visited:
		debug_material.albedo_color = visited_color
		debug_material.emission = visited_color
	elif is_delivery_point:
		debug_material.albedo_color = delivery_color
		debug_material.emission = delivery_color
	else:
		debug_material.albedo_color = debug_color
		debug_material.emission = debug_color

func reset_pathfinding_data():
	g_cost = 0.0
	h_cost = 0.0
	f_cost = 0.0
	parent_node = null

func mark_visited():
	is_visited = true
	visit_count += 1
	_update_visual_state()

func reset_visited():
	is_visited = false
	visit_count = 0
	_update_visual_state()

func set_as_delivery_point(is_delivery: bool):
	is_delivery_point = is_delivery
	_update_visual_state()

func get_connected_positions() -> Array[Vector3]:
	"""Get global positions of all connected nodes"""
	var positions: Array[Vector3] = []
	for node_id_str in connected_nodes:
		var node = get_node_by_id(node_id_str)
		if node:
			positions.append(node.global_position)
	return positions

func get_node_by_id(id: String) -> DeliveryRouteNode:
	"""Find a node by its ID in the delivery nodes group"""
	var nodes = get_tree().get_nodes_in_group("delivery_nodes")
	for node in nodes:
		if node is DeliveryRouteNode and node.node_id == id:
			return node
	return null

func get_distance_to(other_node: DeliveryRouteNode) -> float:
	"""Calculate distance to another node"""
	if not other_node:
		return INF
	return global_position.distance_to(other_node.global_position)

func is_connected_to(node_id_str: String) -> bool:
	"""Check if this node is connected to another node"""
	return node_id_str in connected_nodes

func _on_truck_enter(truck: Node3D):
	truck_arrived.emit(truck)
	mark_visited()

func _on_truck_exit(truck: Node3D):
	truck_departed.emit(truck)
