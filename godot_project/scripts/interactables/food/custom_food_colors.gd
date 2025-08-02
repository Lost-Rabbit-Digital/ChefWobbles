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
@export var spoiled_color: Color = Color.html("#4A5D23")

func _update_visual_quality() -> void:
	"""Override parent to use custom colors instead of color theory"""
	if not is_color_system_initialized or not mesh_instance:
		return
	
	var target_color = _get_custom_quality_color()
	set_visual_color(target_color)

func _get_custom_quality_color() -> Color:
	"""Get color for current quality using custom defined colors"""
	match current_quality:
		FoodQuality.RAW:
			return raw_color
		FoodQuality.COOKING:
			return cooking_color
		FoodQuality.COOKED:
			return cooked_color
		FoodQuality.BURNT:
			return burnt_color
		FoodQuality.SPOILED:
			return spoiled_color
	
	return Color.WHITE

func set_custom_colors(raw: Color, cooking: Color, cooked: Color, burnt: Color, spoiled: Color) -> void:
	"""Programmatically set all cooking colors"""
	raw_color = raw
	cooking_color = cooking
	cooked_color = cooked
	burnt_color = burnt
	spoiled_color = spoiled
	
	# Apply current color immediately
	_update_visual_quality()
