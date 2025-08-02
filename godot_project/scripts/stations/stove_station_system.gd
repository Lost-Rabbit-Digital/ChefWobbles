class_name StoveStation
extends Node3D

## Simplified cooking station that processes FoodItem objects
## Handles audio feedback and timing - lets FoodItem handle its own visuals

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

# Cooking state tracking
var cooking_items: Array[FoodItem] = []

func _ready() -> void:
	_setup_detection_area()
	_setup_cooking_timer()

func _setup_detection_area() -> void:
	"""Connect detection area for food items"""
	detection_area.body_entered.connect(_on_food_entered)
	detection_area.body_exited.connect(_on_food_exited)

func _setup_cooking_timer() -> void:
	"""Setup timer for continuous cooking updates"""
	if not cooking_timer:
		cooking_timer = Timer.new()
		add_child(cooking_timer)
	
	cooking_timer.wait_time = 0.1  # Update every 100ms for smooth progression
	cooking_timer.timeout.connect(_update_cooking)
	cooking_timer.start()

func _on_food_entered(body: Node3D) -> void:
	"""Handle food item entering cooking area"""
	var food_item = body as FoodItem
	if not food_item or not food_item.is_available_for_processing():
		return
	
	_start_cooking(food_item)

func _on_food_exited(body: Node3D) -> void:
	"""Handle food item leaving cooking area"""
	var food_item = body as FoodItem
	if not food_item:
		return
	
	_stop_cooking(food_item)

func _start_cooking(food_item: FoodItem) -> void:
	"""Begin cooking a food item"""
	if food_item in cooking_items or food_item.is_spoiled():
		return
	
	# Add to cooking array
	cooking_items.append(food_item)
	
	# Start processing on the food item
	food_item.start_processing(self)
	
	# Set cooking start time
	food_item.cooking_start_time = Time.get_ticks_msec() / 1000.0
	
	# Play cooking start sound
	if cooking_start_audio and audio_player:
		audio_player.stream = cooking_start_audio
		audio_player.play()
	
	print("Started cooking: ", food_item.food_name)

func _stop_cooking(food_item: FoodItem) -> void:
	"""Stop cooking a food item"""
	if not food_item in cooking_items:
		return
	
	# Remove from cooking array
	cooking_items.erase(food_item)
	
	# Complete processing on food item
	food_item.complete_processing()
	
	print("Stopped cooking: ", food_item.food_name)

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
		
		# Update quality if changed - FoodItem will handle visual updates automatically
		if new_quality != old_quality:
			food_item.set_cooking_quality(new_quality)
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

func get_cooking_time_remaining(food_item: FoodItem) -> float:
	"""Get estimated time until food reaches next stage"""
	if not food_item in cooking_items:
		return 0.0
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var cooking_duration = current_time - food_item.cooking_start_time
	var current_quality = food_item.get_quality()
	
	match current_quality:
		FoodItem.FoodQuality.RAW:
			return max(0.0, raw_to_cooking_time - cooking_duration)
		FoodItem.FoodQuality.COOKING:
			return max(0.0, (raw_to_cooking_time + cooking_to_cooked_time) - cooking_duration)
		FoodItem.FoodQuality.COOKED:
			return max(0.0, (raw_to_cooking_time + cooking_to_cooked_time + cooked_to_burnt_time) - cooking_duration)
		_:
			return 0.0
