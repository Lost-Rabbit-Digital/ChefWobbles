class_name CustomFoodColors
extends FoodItem

## Custom food item that allows manual color definition for each cooking stage
## Use this when you want specific colors instead of automatic color theory
## Perfect for unique items like burgers, special ingredients, etc.

@export_group("Custom Cooking Colors")
@export var raw_color: Color = Color.WHITE
@export var cooking_color: Color = Color.html("#FFE4B5")  
@export var cooked_color: Color = Color.html("#DEB887")
@export var burnt_color: Color = Color.html("#8B4513")

@export_group("Alternative: Color Array Setup")
@export var use_color_array: bool = false
@export var cooking_stage_colors: Array[Color] = []

func _ready() -> void:
	# Setup color array with defaults if empty
	_initialize_color_array()
	super._ready()

func _initialize_color_array() -> void:
	"""Setup color array with default values if needed"""
	if cooking_stage_colors.size() != 4:
		cooking_stage_colors.clear()
		cooking_stage_colors.append(raw_color)
		cooking_stage_colors.append(cooking_color)
		cooking_stage_colors.append(cooked_color)
		cooking_stage_colors.append(burnt_color)

func _update_visual_quality() -> void:
	"""Override parent to use custom colors instead of color theory"""
	if not is_color_system_initialized or not mesh_instance:
		return
	
	var target_color = _get_custom_quality_color()
	set_visual_color(target_color)

func _get_custom_quality_color() -> Color:
	"""Get color for current quality using custom defined colors"""
	if use_color_array and cooking_stage_colors.size() >= 4:
		# Use array-based colors
		match current_quality:
			FoodQuality.RAW:
				return cooking_stage_colors[0]
			FoodQuality.COOKING:
				return cooking_stage_colors[1]
			FoodQuality.COOKED:
				return cooking_stage_colors[2]
			FoodQuality.BURNT:
				return cooking_stage_colors[3]
	else:
		# Use individual color properties
		match current_quality:
			FoodQuality.RAW:
				return raw_color
			FoodQuality.COOKING:
				return cooking_color
			FoodQuality.COOKED:
				return cooked_color
			FoodQuality.BURNT:
				return burnt_color
	
	return Color.WHITE

func set_custom_colors(raw: Color, cooking: Color, cooked: Color, burnt: Color) -> void:
	"""Programmatically set all cooking colors"""
	raw_color = raw
	cooking_color = cooking
	cooked_color = cooked
	burnt_color = burnt
	
	# Update array if using that system
	if use_color_array:
		cooking_stage_colors[0] = raw
		cooking_stage_colors[1] = cooking
		cooking_stage_colors[2] = cooked
		cooking_stage_colors[3] = burnt
	
	# Apply current color immediately
	_update_visual_quality()

func set_colors_from_array(colors: Array[Color]) -> void:
	"""Set colors from an array of 4 colors"""
	if colors.size() != 4:
		push_error("Color array must contain exactly 4 colors")
		return
	
	cooking_stage_colors = colors.duplicate()
	use_color_array = true
	
	# Apply current color immediately
	_update_visual_quality()

# Convenience methods for common food types
func setup_burger_patty_colors() -> void:
	"""Preset colors for burger patty"""
	set_custom_colors(
		Color.html("#ff6b6b"),  # Raw - bright red
		Color.html("#d4896b"),  # Cooking - reddish brown
		Color.html("#8b5a3c"),  # Cooked - rich brown
		Color.html("#3d2817")   # Burnt - dark brown
	)
	food_name = "Burger Patty"
	food_type = FoodType.MEAT

func setup_burger_bun_colors() -> void:
	"""Preset colors for burger buns"""
	set_custom_colors(
		Color.html("#f5deb3"),  # Raw - wheat color
		Color.html("#daa520"),  # Cooking - golden
		Color.html("#b8860b"),  # Cooked - dark golden
		Color.html("#654321")   # Burnt - dark brown
	)
	food_name = "Burger Bun"
	food_type = FoodType.GRAIN

func setup_cheese_colors() -> void:
	"""Preset colors for cheese"""
	set_custom_colors(
		Color.html("#fff8dc"),  # Raw - cream white
		Color.html("#f0e68c"),  # Cooking - light yellow
		Color.html("#daa520"),  # Cooked - golden
		Color.html("#8b7355")   # Burnt - brown
	)
	food_name = "Cheese"
	food_type = FoodType.DAIRY

func setup_lettuce_colors() -> void:
	"""Preset colors for lettuce (doesn't really cook, but for consistency)"""
	set_custom_colors(
		Color.html("#90ee90"),  # Raw - light green
		Color.html("#7ccd7c"),  # Cooking - slightly darker
		Color.html("#6b8e23"),  # Cooked - olive green
		Color.html("#2f4f2f")   # Burnt - dark green
	)
	food_name = "Lettuce"
	food_type = FoodType.VEGETABLE

func setup_tomato_colors() -> void:
	"""Preset colors for tomato"""
	set_custom_colors(
		Color.html("#ff6347"),  # Raw - tomato red
		Color.html("#e55039"),  # Cooking - deeper red
		Color.html("#c0392b"),  # Cooked - dark red
		Color.html("#7f1d1d")   # Burnt - very dark red
	)
	food_name = "Tomato"
	food_type = FoodType.VEGETABLE
