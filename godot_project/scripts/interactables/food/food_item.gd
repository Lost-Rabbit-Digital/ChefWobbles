class_name FoodItem
extends RigidBody3D

## Backend class for all food items with dynamic color-based cooking progression
## Uses color theory to create beautiful cooking transitions
## This is a scene-ready class - no derived classes needed anymore

# Signals for cooking/processing systems
signal processing_started(station: Node)
signal processing_completed(station: Node)
signal quality_changed(new_quality: FoodQuality)

# Enums
enum FoodQuality {
	RAW,
	COOKING,
	COOKED,
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

# Export variables
@export_group("Food Properties")
@export var food_type: FoodType = FoodType.MEAT
@export var food_name: String = "Food Item"
@export var base_cooking_time: float = 3.0
@export var spoilage_time: float = 180.0

# Public variables - food stats only
var being_processed: bool = false
var current_quality: FoodQuality = FoodQuality.RAW
var processing_station: Node = null
var cooking_start_time: float = 0.0

# Node references
@export var mesh_instance: MeshInstance3D 
@export var collision_shape: CollisionShape3D 

# Color system for visual feedback
var original_materials: Array[Material] = []
var is_color_system_initialized: bool = false

# Base colors for each food type (these are the "raw" colors)
static var base_food_colors = {
	FoodType.MEAT: Color.html("#ff6b6b"),      # Bright red
	FoodType.VEGETABLE: Color.html("#51cf66"), # Fresh green
	FoodType.DAIRY: Color.html("#f8f9fa"),     # Off-white
	FoodType.GRAIN: Color.html("#ffd43b"),     # Golden yellow
	FoodType.SEASONING: Color.html("#e599f7")  # Light purple
}

func _ready() -> void:
	_setup_food_item()

func _setup_food_item() -> void:
	"""Initialize food item properties"""
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_start_quality_monitoring()
	_initialize_color_system()
	_setup_derived_class()

func _initialize_color_system() -> void:
	"""Store original materials for color tinting"""
	if not mesh_instance:
		return
	
	# Store original materials
	var surface_count = mesh_instance.get_surface_override_material_count()
	if surface_count == 0 and mesh_instance.mesh:
		surface_count = mesh_instance.mesh.get_surface_count()
	
	for i in range(surface_count):
		var material = mesh_instance.get_surface_override_material(i)
		if not material and mesh_instance.mesh:
			material = mesh_instance.mesh.surface_get_material(i)
		
		if material:
			# Create a copy to avoid modifying shared materials
			var material_copy = material.duplicate()
			original_materials.append(material_copy)
			mesh_instance.set_surface_override_material(i, material_copy)
		else:
			# Create a default StandardMaterial3D if none exists
			var default_material = StandardMaterial3D.new()
			default_material.albedo_color = Color.WHITE
			original_materials.append(default_material)
			mesh_instance.set_surface_override_material(i, default_material)
	
	is_color_system_initialized = true
	# Apply initial color
	_update_visual_quality()

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
	"""Handle food spoilage - set to spoiled when time expires"""
	if current_quality != FoodQuality.SPOILED and current_quality != FoodQuality.BURNT:
		_change_quality(FoodQuality.SPOILED)

# Virtual methods for derived classes (keeping for backward compatibility)
func _setup_derived_class() -> void:
	"""Override in derived classes for specific setup"""
	pass

func _on_body_entered(_body: Node) -> void:
	"""Handle collision with other bodies - override for specific behavior"""
	pass

func _on_body_exited(_body: Node) -> void:
	"""Handle leaving collision with other bodies - override for specific behavior"""
	pass

func _update_visual_quality() -> void:
	"""Update visual appearance based on quality using dynamic color theory"""
	if not is_color_system_initialized or not mesh_instance:
		return
	
	var target_color = _get_dynamic_quality_color()
	set_visual_color(target_color)

func _get_dynamic_quality_color() -> Color:
	"""Generate cooking color using color theory based on food type"""
	var base_color = base_food_colors.get(food_type, Color.WHITE)
	
	match current_quality:
		FoodQuality.RAW:
			return base_color
		FoodQuality.COOKING:
			return _apply_cooking_transformation(base_color)
		FoodQuality.COOKED:
			return _apply_cooked_transformation(base_color)
		FoodQuality.BURNT:
			return _apply_burnt_transformation(base_color)
		FoodQuality.SPOILED:
			return _apply_spoiled_transformation(base_color)
		_:
			return base_color

func _apply_cooking_transformation(base_color: Color) -> Color:
	"""Transform color for cooking stage - slightly warmer and darker"""
	var hsv = _rgb_to_hsv(base_color)
	
	# Shift hue slightly towards warmer (orange/red direction)
	hsv.x = fmod(hsv.x + 0.05, 1.0)  # Warmer hue
	hsv.y = min(hsv.y * 1.2, 1.0)    # More saturated
	hsv.z = hsv.z * 0.9               # Slightly darker
	
	return _hsv_to_rgb(hsv)

func _apply_cooked_transformation(base_color: Color) -> Color:
	"""Transform color for cooked stage - rich, appetizing browns"""
	var hsv = _rgb_to_hsv(base_color)
	
	# Shift towards brown/orange range (30-40 degrees in hue)
	hsv.x = 0.08 + (hsv.x * 0.1)     # Brown-orange range
	hsv.y = min(hsv.y * 1.4, 1.0)    # Rich saturation
	hsv.z = hsv.z * 0.7               # Medium darkness
	
	return _hsv_to_rgb(hsv)

func _apply_burnt_transformation(base_color: Color) -> Color:
	"""Transform color for burnt stage - dark, desaturated"""
	var hsv = _rgb_to_hsv(base_color)
	
	# Shift towards dark purples/browns
	hsv.x = 0.02 + (hsv.x * 0.05)    # Very dark brown
	hsv.y = hsv.y * 0.3               # Desaturated
	hsv.z = hsv.z * 0.3               # Very dark
	
	return _hsv_to_rgb(hsv)

func _apply_spoiled_transformation(base_color: Color) -> Color:
	"""Transform color for spoiled stage - sickly green-gray"""
	var hsv = _rgb_to_hsv(base_color)
	
	# Shift towards sickly green-gray
	hsv.x = 0.25 + (hsv.x * 0.1)     # Green-gray range
	hsv.y = hsv.y * 0.4               # Low saturation
	hsv.z = hsv.z * 0.5               # Medium-dark
	
	return _hsv_to_rgb(hsv)

func _rgb_to_hsv(color: Color) -> Vector3:
	"""Convert RGB color to HSV (Hue, Saturation, Value)"""
	var r = color.r
	var g = color.g
	var b = color.b
	
	var max_val = max(r, max(g, b))
	var min_val = min(r, min(g, b))
	var delta = max_val - min_val
	
	var h = 0.0
	var s = 0.0 if max_val == 0.0 else delta / max_val
	var v = max_val
	
	if delta != 0.0:
		if max_val == r:
			h = (g - b) / delta
		elif max_val == g:
			h = 2.0 + (b - r) / delta
		else:
			h = 4.0 + (r - g) / delta
		
		h /= 6.0
		if h < 0.0:
			h += 1.0
	
	return Vector3(h, s, v)

func _hsv_to_rgb(hsv: Vector3) -> Color:
	"""Convert HSV back to RGB color"""
	var h = hsv.x * 6.0
	var s = hsv.y
	var v = hsv.z
	
	var c = v * s
	var x = c * (1.0 - abs(fmod(h, 2.0) - 1.0))
	var m = v - c
	
	var r = 0.0
	var g = 0.0
	var b = 0.0
	
	if h >= 0.0 and h < 1.0:
		r = c; g = x; b = 0.0
	elif h >= 1.0 and h < 2.0:
		r = x; g = c; b = 0.0
	elif h >= 2.0 and h < 3.0:
		r = 0.0; g = c; b = x
	elif h >= 3.0 and h < 4.0:
		r = 0.0; g = x; b = c
	elif h >= 4.0 and h < 5.0:
		r = x; g = 0.0; b = c
	elif h >= 5.0 and h < 6.0:
		r = c; g = 0.0; b = x
	
	return Color(r + m, g + m, b + m, 1.0)

# Processing methods
func start_processing(station: Node) -> bool:
	"""Begin processing at a station"""
	if being_processed:
		return false
	
	processing_station = station
	being_processed = true
	cooking_start_time = Time.get_ticks_msec() / 1000.0
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
	"""Check if food has spoiled"""
	return current_quality == FoodQuality.SPOILED

func is_burnt() -> bool:
	"""Check if food is burnt"""
	return current_quality == FoodQuality.BURNT

func is_ruined() -> bool:
	"""Check if food is spoiled or burnt (unusable)"""
	return current_quality in [FoodQuality.SPOILED, FoodQuality.BURNT]

func is_raw() -> bool:
	"""Check if food is still raw"""
	return current_quality == FoodQuality.RAW

func is_cooking() -> bool:
	"""Check if food is currently cooking"""
	return current_quality == FoodQuality.COOKING

func is_cooked_perfectly() -> bool:
	"""Check if food is cooked perfectly"""
	return current_quality == FoodQuality.COOKED

# Visual methods for color system
func set_visual_color(color: Color) -> void:
	"""Set visual color for the food item"""
	if not is_color_system_initialized or not mesh_instance:
		return
	
	for i in range(original_materials.size()):
		var material = mesh_instance.get_surface_override_material(i)
		if material and material is StandardMaterial3D:
			var std_mat = material as StandardMaterial3D
			std_mat.albedo_color = color

func reset_visual_color() -> void:
	"""Reset to original material colors"""
	if not is_color_system_initialized:
		return
	
	for i in range(original_materials.size()):
		var original_material = original_materials[i]
		if original_material and original_material is StandardMaterial3D:
			var current_material = mesh_instance.get_surface_override_material(i)
			if current_material and current_material is StandardMaterial3D:
				var orig_mat = original_material as StandardMaterial3D
				var curr_mat = current_material as StandardMaterial3D
				curr_mat.albedo_color = orig_mat.albedo_color

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

func get_cooking_description() -> String:
	"""Get human-readable cooking state"""
	match current_quality:
		FoodQuality.RAW:
			return "Fresh and raw"
		FoodQuality.COOKING:
			return "Cooking nicely"
		FoodQuality.COOKED:
			return "Perfectly cooked"
		FoodQuality.BURNT:
			return "Burnt and ruined"
		FoodQuality.SPOILED:
			return "Spoiled and moldy"
		_:
			return "Unknown state"

# Internal methods
func _change_quality(new_quality: FoodQuality) -> void:
	"""Update food quality with validation"""
	if current_quality != new_quality:
		current_quality = new_quality
		quality_changed.emit(new_quality)
		_update_visual_quality()
