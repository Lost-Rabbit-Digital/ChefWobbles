
# ==========================
# BurgerPatty.gd
# ==========================
extends FoodItem
class_name BurgerPatty

## Burger patty that can be cooked on stoves
## Demonstrates food-specific cooking behavior

# Cooking materials for each quality level
@export_group("Cooking Materials")
@export var raw_material: Material
@export var cooking_material: Material
@export var perfect_material: Material
@export var overcooked_material: Material
@export var burnt_material: Material

func _setup_derived_class():
	"""Setup burger patty specific properties"""
	super._setup_derived_class()
	
	food_type = FoodType.MEAT
	food_name = "Burger Patty"
	base_cooking_time = 3.0
	spoilage_time = 30.0
	
	# Connect quality changes to visual updates
	quality_changed.connect(_on_quality_changed)

func _on_quality_changed(new_quality: FoodQuality):
	"""Handle quality change visual updates"""
	_update_visual_quality()

func _update_visual_quality():
	"""Update patty material based on cooking quality"""
	if not mesh_instance:
		return
	
	var material_to_use: Material
	
	match current_quality:
		FoodQuality.RAW:
			material_to_use = raw_material
		FoodQuality.PERFECT:
			material_to_use = perfect_material
		FoodQuality.OVERCOOKED:
			material_to_use = overcooked_material
		FoodQuality.BURNT:
			material_to_use = burnt_material
		FoodQuality.SPOILED:
			material_to_use = overcooked_material  # Fallback
	
	if material_to_use:
		mesh_instance.material_override = material_to_use

func _on_body_entered(body: Node):
	"""Handle entering cooking stations"""
	super._on_body_entered(body)
	
	# Check for stove station
	if body is StoveStation and can_interact():
		var stove = body as StoveStation
		stove.start_cooking_food_item(self)

func _on_body_exited(body: Node):
	"""Handle leaving cooking stations"""
	super._on_body_exited(body)
	
	# Check for stove station
	if body is StoveStation:
		var stove = body as StoveStation
		stove.stop_cooking_food_item(self)

# Public API for cooking system
func set_cooking_quality(quality: FoodQuality):
	"""Set quality from cooking system"""
	_change_quality(quality)

func is_cooked_perfectly() -> bool:
	"""Check if patty is cooked perfectly"""
	return current_quality == FoodQuality.PERFECT

func is_overcooked() -> bool:
	"""Check if patty is overcooked or burnt"""
	return current_quality in [FoodQuality.OVERCOOKED, FoodQuality.BURNT]
