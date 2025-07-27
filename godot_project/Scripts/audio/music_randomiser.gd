extends Node

# Steps
# 1. Get all the children nodes of this node
# 2. Place them into an array
# 3. Randomise the order of the array
# 4. Use built-in move_child() to match the children nodes to the array

# Get the children of this node and store them in an array
# [CuddleClouds:<AudioStreamPlayer#36876322340>, 
# DriftingMemories:<AudioStreamPlayer#36909876774>,
# ...:<AudioStreamPlayer#...>]
@onready var children_nodes: Array = get_children()

# Create an array with the size of the children_nodes array
# ['0', '1', '2', '...']
@onready var new_node_positions = range(children_nodes.size())

func _ready() -> void:
	# If there are no children nodes, return null
	if get_child_count() == 0:
		return	
	
	# Shuffle around the order of the songs at the start of the game
	new_node_positions.shuffle()
	
	# Loop through the children node array
	for i in range(children_nodes.size()):
		# For each child, move it to the new node position
		move_child(children_nodes[i], new_node_positions[i])
