extends StaticBody3D
class_name StoveStation

## Cooking station that processes FoodItem objects through cooking stages
## Handles audio feedback, timing, and quality progression

# Audio resources
@export_group("Audio")
@export var cooking_start_audio: AudioStream
@export var stage_change_audio: AudioStream  # Plop sound for transitions

# Cooking timing configuration
@export_group("Cooking Settings")
@export var raw_to_cooking_time: float = 0.5
@export var cooking_to_perfect_time: float = 3.0
@export var perfect_to_overcooked_time: float = 2.0
@export var overcooked_to_burnt_time: float = 1.5

# Node references
@onready var cooking_surface: Area3D = $CookingSurface
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
@onready var cooking_timer: Timer = $CookingTimer

# Cooking state tracking
var cooking_items: Dictionary = {}  # food_item -> CookingProgress
var next_cooking_id: int = 0

# Cooking progress data structure
class CookingProgress:
	var food_item: FoodItem
	var time_in_stage: float = 0.0
	var target_quality: FoodItem.FoodQuality
	var cooking_id: int
	
	func _init(item: FoodItem, id: int):
		food_item = item
		cooking_id = id
		target_quality = FoodItem.FoodQuality.RAW

func _ready():
	_setup_cooking_system()
	_validate_resources()

func _setup_cooking_system():
	"""Initialize cooking detection and timing systems"""
	# Setup collision detection
	if not cooking_surface:
		push_error("CookingSurface Area3D not found")
		return
	
	cooking_surface.body_entered.connect(_on_item_entered_surface)
	cooking_surface.body_exited.connect(_on_item_left_surface)
	
	# Setup cooking progression timer
	if not cooking_timer:
		cooking_timer = Timer.new()
		add_child(cooking_timer)
	
	cooking_timer.wait_time = 0.1  # Update every 100ms
	cooking_timer.timeout.connect(_process_cooking_progression)
	cooking_timer.start()

func _validate_resources():
	"""Check for missing audio resources"""
	var missing = []
	if not cooking_start_audio: missing.append("cooking_start_audio")
	if not stage_change_audio: missing.append("stage_change_audio")
	
	if missing.size() > 0:
		push_warning("StoveStation missing audio: " + str(missing))

func _on_item_entered_surface(body: Node3D):
	"""Handle food item entering cooking surface"""
	var food_item = body as FoodItem
	if not food_item or not food_item.can_interact():
		return
	
	start_cooking_food_item(food_item)

func _on_item_left_surface(body: Node3D):
	"""Handle food item leaving cooking surface"""
	var food_item = body as FoodItem
	if not food_item:
		return
	
	stop_cooking_food_item(food_item)

func start_cooking_food_item(food_item: FoodItem):
	"""Begin cooking process for a food item"""
	# Skip if already cooking
	if cooking_items.has(food_item):
		return
	
	# Only cook items that aren't spoiled
	if food_item.is_spoiled():
		return
	
	# Create cooking progress
	var progress = CookingProgress.new(food_item, next_cooking_id)
	next_cooking_id += 1
	cooking_items[food_item] = progress
	
	# Start processing on the food item
	food_item.start_processing(self)
	
	# Play cooking start sound
	_play_audio(cooking_start_audio)
	
	# Set initial target quality
	progress.target_quality = _get_next_quality(food_item.get_quality())
	
	print("Started cooking: ", food_item.food_name, " (ID: ", progress.cooking_id, ")")

func stop_cooking_food_item(food_item: FoodItem):
	"""Stop cooking process for a food item"""
	if not cooking_items.has(food_item):
		return
	
	var progress = cooking_items[food_item]
	cooking_items.erase(food_item)
	
	# Complete processing on food item
	food_item.complete_processing()
	
	print("Stopped cooking: ", food_item.food_name, " (ID: ", progress.cooking_id, ")")

func _process_cooking_progression():
	"""Update cooking progression for all active items"""
	for food_item in cooking_items.keys():
		var progress = cooking_items[food_item]
		
		# Skip if food item was freed
		if not is_instance_valid(food_item):
			cooking_items.erase(food_item)
			continue
		
		# Update cooking time
		progress.time_in_stage += cooking_timer.wait_time
		
		# Check for quality progression
		_check_quality_progression(progress)

func _check_quality_progression(progress: CookingProgress):
	"""Check if food should progress to next quality level"""
	var current_quality = progress.food_item.get_quality()
	var required_time = _get_time_for_transition(current_quality)
	
	if progress.time_in_stage >= required_time:
		_progress_food_quality(progress)

func _progress_food_quality(progress: CookingProgress):
	"""Progress food item to next quality level"""
	var current_quality = progress.food_item.get_quality()
	var next_quality = _get_next_quality(current_quality)
	
	# Update food quality
	progress.food_item.set_cooking_quality(next_quality)
	
	# Reset stage timer and set new target
	progress.time_in_stage = 0.0
	progress.target_quality = _get_next_quality(next_quality)
	
	# Play progression sound
	_play_audio(stage_change_audio)
	
	# Log progression
	var quality_name = FoodItem.FoodQuality.keys()[next_quality]
	print(progress.food_item.food_name, " progressed to: ", quality_name)

func _get_next_quality(current: FoodItem.FoodQuality) -> FoodItem.FoodQuality:
	"""Get the next quality level in cooking progression"""
	match current:
		FoodItem.FoodQuality.RAW:
			return FoodItem.FoodQuality.PERFECT  # Skip intermediate "cooking" stage
		FoodItem.FoodQuality.PERFECT:
			return FoodItem.FoodQuality.OVERCOOKED
		FoodItem.FoodQuality.OVERCOOKED:
			return FoodItem.FoodQuality.BURNT
		_:
			return current  # No further progression

func _get_time_for_transition(from_quality: FoodItem.FoodQuality) -> float:
	"""Get required time for quality transition"""
	match from_quality:
		FoodItem.FoodQuality.RAW:
			return raw_to_cooking_time
		FoodItem.FoodQuality.PERFECT:
			return perfect_to_overcooked_time
		FoodItem.FoodQuality.OVERCOOKED:
			return overcooked_to_burnt_time
		_:
			return 999.0  # No transition

func _play_audio(audio_stream: AudioStream):
	"""Play audio with 3D positioning"""
	if not audio_stream or not audio_player:
		return
	
	audio_player.stream = audio_stream
	audio_player.play()

# Public API for external systems
func is_cooking_item(food_item: FoodItem) -> bool:
	"""Check if specific food item is being cooked"""
	return cooking_items.has(food_item)

func get_cooking_progress(food_item: FoodItem) -> float:
	"""Get cooking progress for specific item (0.0 to 1.0)"""
	if not cooking_items.has(food_item):
		return 0.0
	
	var progress = cooking_items[food_item]
	var current_quality = food_item.get_quality()
	var required_time = _get_time_for_transition(current_quality)
	
	if required_time <= 0.0:
		return 1.0
	
	return min(progress.time_in_stage / required_time, 1.0)

func get_active_cooking_count() -> int:
	"""Get number of items currently being cooked"""
	return cooking_items.size()
