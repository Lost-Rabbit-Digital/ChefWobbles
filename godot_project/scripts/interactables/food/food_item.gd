
# ==========================
# FoodItem.gd
# ==========================
extends BaseInteractable
class_name FoodItem

## Base class for all food items that can be cooked, cut, or processed
## Extends BaseInteractable with food-specific functionality

signal processing_started(station: Node)
signal processing_completed(station: Node)
signal quality_changed(new_quality: FoodQuality)

enum FoodQuality {
	RAW,
	PERFECT,
	OVERCOOKED,
	BURNT,
	SPOILED
}

enum FoodType {
	MEAT,
	VEGETABLE,
	DAIRY,
	GRAIN,
	SEASONING
}

# Food properties
@export_group("Food Properties")
@export var food_type: FoodType = FoodType.MEAT
@export var food_name: String = "Food Item"
@export var base_cooking_time: float = 3.0
@export var spoilage_time: float = 60.0

# Processing state
var current_quality: FoodQuality = FoodQuality.RAW
var processing_station: Node = null
var quality_timer: float = 0.0

func _setup_derived_class():
	"""Setup food-specific properties"""
	interaction_prompt = "Pick up " + food_name
	
	# Start quality degradation timer
	_start_quality_monitoring()

func _start_quality_monitoring():
	"""Begin monitoring food quality over time"""
	# Create timer for spoilage if needed
	if spoilage_time > 0:
		var spoilage_timer = Timer.new()
		add_child(spoilage_timer)
		spoilage_timer.wait_time = spoilage_time
		spoilage_timer.one_shot = true
		spoilage_timer.timeout.connect(_on_spoilage_timer_timeout)
		spoilage_timer.start()

func _on_spoilage_timer_timeout():
	"""Handle food spoilage"""
	if current_quality != FoodQuality.SPOILED:
		_change_quality(FoodQuality.SPOILED)

func start_processing(station: Node):
	"""Begin processing at a station"""
	if processing_station:
		return false
	
	processing_station = station
	_change_state(InteractionState.PROCESSING)
	processing_started.emit(station)
	return true

func complete_processing():
	"""Complete processing and return to free state"""
	if processing_station:
		var station = processing_station
		processing_station = null
		_change_state(InteractionState.FREE)
		processing_completed.emit(station)

func get_quality() -> FoodQuality:
	"""Get current food quality"""
	return current_quality

func is_edible() -> bool:
	"""Check if food is in edible state"""
	return current_quality in [FoodQuality.RAW, FoodQuality.PERFECT, FoodQuality.OVERCOOKED]

func is_spoiled() -> bool:
	"""Check if food has spoiled"""
	return current_quality == FoodQuality.SPOILED

func _change_quality(new_quality: FoodQuality):
	"""Update food quality with validation"""
	if current_quality != new_quality:
		current_quality = new_quality
		quality_changed.emit(new_quality)
		_update_visual_quality()

func _update_visual_quality():
	"""Update visual appearance based on quality - override in derived classes"""
	pass
