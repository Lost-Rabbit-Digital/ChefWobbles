class_name StoveStation
extends Node3D

## Simplified cooking station that processes FoodItem objects with color-based progression
## Handles audio feedback, timing, and visual quality changes through color tinting

# Audio resources
@export_group("Audio")
@export var cooking_start_audio: AudioStream
@export var stage_change_audio: AudioStream
@export var sizzling_audio: AudioStream

# Cooking timing configuration
@export_group("Cooking Settings")
@export var raw_to_cooking_time: float = 1.5
@export var cooking_to_cooked_time: float = 3.0
@export var cooked_to_burnt_time: float = 3.0

# Node references
@export_group("Node References")
@export var detection_area: Area3D
@export var audio_player: AudioStreamPlayer3D
@export var cooking_timer: Timer

# Food type presets for color progression
enum FoodType {
	MEAT,
	BURGER_BUNS,
	GENERIC
}

# Color configurations for different food types
static var cooking_colors = {
	FoodType.MEAT: {
		"raw": Color.html("#fb9797"),     # Raw pink
		"cooking": Color.html("#d9b399"), # Light brown
		"cooked": Color.html("#8c6b4d"),  # Dark brown
		"burnt": Color.html("#513c27")    # Very dark brown
	},
	FoodType.BURGER_BUNS: {
		"raw": Color.html("#E1C492"),     # Light tan
		"cooking": Color.html("#D4B882"), # Slightly darker
		"cooked": Color.html("#C7A872"),  # Golden brown
		"burnt": Color.html("#8B7355")    # Dark burnt
	},
	FoodType.GENERIC: {
		"raw": Color.html("#FFFFFF"),     # White
		"cooking": Color.html("#FFE4B5"), # Light cooking
		"cooked": Color.html("#DEB887"),  # Burlywood
		"burnt": Color.html("#8B4513")    # Saddle brown
	}
}

# Cooking state tracking
var cooking_items: Array[FoodItem] = []

func _ready() -> void:
	_setup_detection_area()

func _setup_detection_area() -> void:
	"""Connect detection area for food items"""
	detection_area.body_entered.connect(_on_food_entered)
	detection_area.body_exited.connect(_on_food_exited)

func _on_food_entered(body: Node3D) -> void:
	"""Handle food item entering cooking area"""
	var food_item = body as FoodItem
	if not food_item or not food_item.is_available_for_processing():
		return
	
	# If it is a food item and can be processed, begin to cook it
	_start_cooking(food_item)

func _on_food_exited(body: Node3D) -> void:
	"""Handle food item leaving cooking area"""
	var food_item = body as FoodItem
	if not food_item:
		return
	
	# If it's food, stop cooking it
	_stop_cooking(food_item)

func _start_cooking(food_item: FoodItem) -> void:
	"""Begin cooking a food item"""
	if food_item in cooking_items or food_item.is_spoiled():
		return
	
	# Add the cooking item to an array of food_items for processing
	cooking_items.append(food_item)
	# Begin processing the newly added food item
	food_item.start_processing(self)
	# Create a timestamp for when the food begins to cook
	food_item.cooking_start_time = Time.get_ticks_msec() / 1000.0
	
	# Apply initial cooking color
	_update_food_color(food_item)
	
	# Play cooking start sound
	if cooking_start_audio and audio_player:
		audio_player.stream = cooking_start_audio
		audio_player.play()
	
	print("Started cooking: ", food_item.food_name)

func _stop_cooking(food_item: FoodItem) -> void:
	"""Stop cooking a food item"""
	if not food_item in cooking_items:
		return
	
	# Remove the food_item from the cooking_items array
	cooking_items.erase(food_item)
	# Finish the processing of the food_item
	food_item.complete_processing()
	
	print("Completed cooking: ", food_item.food_name)

func _update_cooking() -> void:
	"""Update cooking progression for all active items"""
	for food_item in cooking_items:
		if not is_instance_valid(food_item):
			cooking_items.erase(food_item)
			continue
		
		var current_time = Time.get_ticks_msec() / 1000.0
		var cooking_duration = current_time - food_item.cooking_start_time
		
		# Determine current quality based on time
		var new_quality = _get_quality_from_time(cooking_duration)
		var old_quality = food_item.get_quality()
		
		# Update quality if changed
		if new_quality != old_quality:
			food_item.set_cooking_quality(new_quality)
			_update_food_color(food_item)
			_play_stage_sound()
			
			var quality_name = FoodItem.FoodQuality.keys()[new_quality]
			print(food_item.food_name, " -> ", quality_name)

func _get_quality_from_time(duration: float) -> FoodItem.FoodQuality:
	"""Determine quality based on cooking duration"""
	if duration < raw_to_cooking_time:
		return FoodItem.FoodQuality.RAW
	elif duration < raw_to_cooking_time + cooking_to_cooked_time:
		return FoodItem.FoodQuality.COOKING
	elif duration < raw_to_cooking_time + cooking_to_cooked_time + cooked_to_burnt_time:
		return FoodItem.FoodQuality.COOKED
	else:
		return FoodItem.FoodQuality.BURNT

func _update_food_color(food_item: FoodItem) -> void:
	"""Update food item color based on cooking stage"""
	var food_type = _get_food_type(food_item)
	var quality = food_item.get_quality()
	var color_key = _quality_to_color_key(quality)
	
	var target_color = cooking_colors[food_type][color_key]
	_apply_color_to_food(food_item, target_color)

func _get_food_type(food_item: FoodItem) -> FoodType:
	"""Determine food type from food item properties"""
	# This should be expanded based on your FoodItem implementation
	# For now, using a simple name-based approach
	var name = food_item.food_name.to_lower()
	
	if "meat" in name or "patty" in name or "burger" in name:
		return FoodType.MEAT
	elif "bun" in name:
		return FoodType.BURGER_BUNS
	else:
		return FoodType.GENERIC

func _quality_to_color_key(quality: FoodItem.FoodQuality) -> String:
	"""Convert quality enum to color dictionary key"""
	match quality:
		FoodItem.FoodQuality.RAW:
			return "raw"
		FoodItem.FoodQuality.COOKING:
			return "cooking"
		FoodItem.FoodQuality.COOKED:
			return "cooked"
		FoodItem.FoodQuality.BURNT:
			return "burnt"
		_:
			return "raw"

func _apply_color_to_food(food_item: FoodItem, color: Color) -> void:
	"""Apply color tint to food item's visual representation"""
	# This assumes your FoodItem has a method to change its visual color
	# You'll need to implement this based on your FoodItem structure
	if food_item.has_method("set_visual_color"):
		food_item.set_visual_color(color)
	else:
		# Fallback: try to find and modify materials directly
		_tint_food_materials(food_item, color)

func _tint_food_materials(food_item: FoodItem, color: Color) -> void:
	"""Directly tint all materials on the food item"""
	var mesh_nodes = _find_mesh_instances(food_item)
	
	for mesh_instance in mesh_nodes:
		var material_count = mesh_instance.get_surface_override_material_count()
		
		for i in range(material_count):
			var material = mesh_instance.get_surface_override_material(i)
			if material and material is StandardMaterial3D:
				var std_mat = material as StandardMaterial3D
				std_mat.albedo_color = color

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	"""Recursively find all MeshInstance3D nodes"""
	var mesh_instances: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		mesh_instances.append_array(_find_mesh_instances(child))
	
	return mesh_instances

func _play_stage_sound() -> void:
	"""Play stage transition sound"""
	if stage_change_audio and audio_player:
		audio_player.stream = stage_change_audio
		audio_player.play()

# Public API
func is_cooking_item(food_item: FoodItem) -> bool:
	"""Check if food item is currently cooking"""
	return food_item in cooking_items

func get_cooking_progress(food_item: FoodItem) -> float:
	"""Get cooking progress (0.0 to 1.0) for food item"""
	if not food_item in cooking_items:
		return 0.0
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var cooking_duration = current_time - food_item.cooking_start_time
	var total_cooking_time = raw_to_cooking_time + cooking_to_cooked_time + cooked_to_burnt_time
	
	return min(cooking_duration / total_cooking_time, 1.0)

func get_active_cooking_count() -> int:
	"""Get number of items currently cooking"""
	return cooking_items.size()
