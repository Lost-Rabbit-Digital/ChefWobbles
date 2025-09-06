class_name DeliveryRouteNode
extends Node2D

## Represents a single waypoint in the delivery route network
## Handles connections to other nodes and pathfinding data

@export var node_id: String = ""
@export var connected_nodes: Array[String] = []
@export var is_delivery_point: bool = false
@export var delivery_data: Dictionary = {}

# Pathfinding properties
var g_cost: float = 0.0  # Distance from start
var h_cost: float = 0.0  # Distance to target
var f_cost: float = 0.0  # Total cost
var parent_node: DeliveryRouteNode = null

# Visual feedback
@export var node_color: Color = Color.CYAN
@export var delivery_color: Color = Color.ORANGE
@export var radius: float = 20.0

func _ready():
	if node_id.is_empty():
		node_id = name
	
	# Set visual appearance based on node type
	queue_redraw()

func _draw():
	var color = delivery_color if is_delivery_point else node_color
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius - 3, Color.WHITE, false, 2.0)

func get_connected_node_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var route_manager = get_tree().get_first_node_in_group("route_manager")
	
	if route_manager:
		for node_id_str in connected_nodes:
			var node = route_manager.get_node_by_id(node_id_str)
			if node:
				positions.append(node.global_position)
	
	return positions

func get_distance_to(target_node: DeliveryRouteNode) -> float:
	return global_position.distance_to(target_node.global_position)

func reset_pathfinding_data():
	g_cost = 0.0
	h_cost = 0.0
	f_cost = 0.0
	parent_node = null

func calculate_f_cost():
	f_cost = g_cost + h_cost

func is_connected_to(other_node_id: String) -> bool:
	return connected_nodes.has(other_node_id)

# Helper function for debugging
func get_info() -> String:
	return "Node: %s, Connections: %s, Delivery: %s" % [
		node_id, 
		str(connected_nodes), 
		str(is_delivery_point)
	]
