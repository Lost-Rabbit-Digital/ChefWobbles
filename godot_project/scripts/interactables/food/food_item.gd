class_name FoodItem
extends RigidBody3D

## Backend class for all food items that can be cooked, cut, or processed
## Tracks food stats and cooking states only - no interaction handling
## This is a backend class - use specific food classes in scenes

# Signals for cooking/processing systems
signal processing_started(station: Node)
signal processing_completed(station: Node)
signal quality_changed(new_quality: FoodQuality)

# Enums
enum FoodQuality {
	RAW,
	COOKING,
	COOKED,
	BURNT
}

enum FoodType {
	MEAT,
	VEGETABLE,
	DAIRY,
	GRAIN,
	SEASONING
}

# Export variables
@export_group("Food Properties")
@export var food_type: FoodType = FoodType.MEAT
@export var food_name: String = "Food Item"
@export var base_cooking_time: float = 3.0
@export var spoilage_time: float = 60.0

# Public variables - food stats only
var being_processed: bool = false
var current_quality: FoodQuality = FoodQuality.RAW
var processing_station: Node = null

# @onready variables
@export var mesh_instance: MeshInstance3D 
@export var collision_shape: CollisionShape3D 

func _ready() -> void:
	_setup_food_item()

func _setup_food_item() -> void:
	"""Initialize food item properties"""
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_start_quality_monitoring()
	_setup_derived_class()

func _start_quality_monitoring() -> void:
	"""Begin monitoring food quality over time"""
	if spoilage_time > 0:
		var spoilage_timer = Timer.new()
		add_child(spoilage_timer)
		spoilage_timer.wait_time = spoilage_time
		spoilage_timer.one_shot = true
		spoilage_timer.timeout.connect(_on_spoilage_timer_timeout)
		spoilage_timer.start()

func _on_spoilage_timer_timeout() -> void:
	"""Handle food spoilage - set to burnt when spoiled"""
	if current_quality != FoodQuality.BURNT:
		_change_quality(FoodQuality.BURNT)

# Virtual methods for derived classes
func _setup_derived_class() -> void:
	"""Override in derived classes for specific setup"""
	pass

func _on_body_entered(body: Node) -> void:
	"""Handle collision with other bodies - override for specific behavior"""
	pass

func _on_body_exited(body: Node) -> void:
	"""Handle leaving collision with other bodies - override for specific behavior"""
	pass

func _update_visual_quality() -> void:
	"""Update visual appearance based on quality - override in derived classes"""
	pass

# Processing methods
func start_processing(station: Node) -> bool:
	"""Begin processing at a station"""
	if being_processed:
		return false
	
	processing_station = station
	being_processed = true
	processing_started.emit(station)
	return true

func complete_processing() -> void:
	"""Complete processing and return to free state"""
	if being_processed:
		var station = processing_station
		processing_station = null
		being_processed = false
		processing_completed.emit(station)

func stop_processing() -> void:
	"""Stop processing without completing"""
	if being_processed:
		processing_station = null
		being_processed = false

# Quality methods
func get_quality() -> FoodQuality:
	"""Get current food quality"""
	return current_quality

func set_cooking_quality(quality: FoodQuality) -> void:
	"""Set quality from cooking system"""
	_change_quality(quality)

func is_edible() -> bool:
	"""Check if food is in edible state"""
	return current_quality in [FoodQuality.RAW, FoodQuality.COOKING, FoodQuality.COOKED]

func is_spoiled() -> bool:
	"""Check if food has spoiled or burnt"""
	return current_quality == FoodQuality.BURNT

# State query methods
func is_being_processed() -> bool:
	"""Check if currently being processed at a station"""
	return being_processed

func is_available_for_processing() -> bool:
	"""Check if available for processing"""
	return not being_processed

func get_processing_station() -> Node:
	"""Get reference to station processing this food"""
	return processing_station

# Food stats methods
func get_food_name() -> String:
	"""Get display name of food"""
	return food_name

func get_food_type() -> FoodType:
	"""Get food type enum"""
	return food_type

func get_base_cooking_time() -> float:
	"""Get base cooking time for this food"""
	return base_cooking_time

func get_spoilage_time() -> float:
	"""Get spoilage time for this food"""
	return spoilage_time

# Internal methods
func _change_quality(new_quality: FoodQuality) -> void:
	"""Update food quality with validation"""
	if current_quality != new_quality:
		current_quality = new_quality
		quality_changed.emit(new_quality)
		_update_visual_quality()
