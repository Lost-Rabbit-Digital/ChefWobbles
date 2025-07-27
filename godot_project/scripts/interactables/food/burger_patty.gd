class_name BurgerPatty
extends FoodItem

## Burger patty that can be cooked on stoves
## This is a scene-ready class - attach to RigidBody3D nodes in scenes

# Cooking materials for each quality level
@export_group("Cooking Materials")
@export var raw_material: Material
@export var cooking_material: Material
@export var cooked_material: Material
@export var burnt_material: Material

func _setup_derived_class() -> void:
	"""Setup burger patty specific properties"""
	super._setup_derived_class()
	
	food_type = FoodType.MEAT
	food_name = "Burger Patty"
	base_cooking_time = 3.0
	spoilage_time = 30.0
	
	# Connect quality changes to visual updates
	quality_changed.connect(_on_quality_changed)

func _on_quality_changed(new_quality: FoodQuality) -> void:
	"""Handle quality change visual updates"""
	_update_visual_quality()

func _update_visual_quality() -> void:
	"""Update patty material based on cooking quality"""
	if not mesh_instance:
		return
	
	var material_to_use: Material
	
	match current_quality:
		FoodQuality.RAW:
			material_to_use = raw_material
		FoodQuality.COOKING:
			material_to_use = cooking_material
		FoodQuality.COOKED:
			material_to_use = cooked_material
		FoodQuality.BURNT:
			material_to_use = burnt_material
	
	if material_to_use:
		mesh_instance.material_override = material_to_use

func _on_body_entered(body: Node) -> void:
	"""Handle entering cooking stations"""
	super._on_body_entered(body)
	
	# Check for stove station
	if body is StoveStation and is_available_for_processing():
		var stove = body as StoveStation
		stove.start_cooking_food_item(self)

func _on_body_exited(body: Node) -> void:
	"""Handle leaving cooking stations"""
	super._on_body_exited(body)
	
	# Check for stove station
	if body is StoveStation and is_being_processed():
		var stove = body as StoveStation
		stove.stop_cooking_food_item(self)

# Public API for cooking system
func is_cooked_perfectly() -> bool:
	"""Check if patty is cooked perfectly"""
	return current_quality == FoodQuality.COOKED

func is_burnt() -> bool:
	"""Check if patty is burnt"""
	return current_quality == FoodQuality.BURNT
