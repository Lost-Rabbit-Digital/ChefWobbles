extends Node

# Figuring out colors:
# - Instead of swapping materials I want to tint it with a list of pre-defined hues

# - Could also use textures since that's what I will be creating in BlockBench anyway, 
# unless I want to skip that BlockBench method, but I enjoy it so I won't.

# - Retrieve a color from a texture? Or dynamically create a material with a given 
# texture?

# - I use a palette.md in my project_management dir to track all used colors, 
# they're stored in html hexadecimal format, we could use the Color.html() 
# function to use them directly to tint the food items being cooked

# - Each food item will have four stages: Raw, Cooking, Cooked, and Burnt.

# - Will these be full color changes or tints on the base color? Full color changes
# would be easier to manage and fit the style closer.

# - Large enum of variables for each type of food item, starting with a 
# default and burger.



# === FOOD TYPE PRESETS ===
enum FoodType {
  MEAT,
  BURGER_BUNS,
  GENERIC
}

# Static preset configurations for different audio types
static var cooking_presets = {
  FoodType.MEAT: {
	"stage_1": Color.html("#fb9797"), # Raw
	"stage_2": Color.html("#d9b399"), # Cooking
	"stage_3": Color.html("#8c6b4d"), # Cooked
	"stage_4": Color.html("#513c27")  # Burnt
  },
  FoodType.BURGER_BUNS: {
	"stage_1": Color.html("#E1C492"),
	"stage_2": Color.html("#E1C492"),
	"stage_3": Color.html("#E1C492"),
	"stage_4": Color.html("#E1C492")
  },
  FoodType.GENERIC: {
	"stage_1": Color.html("#fb9797"),
	"stage_2": Color.html("#fb9797"),
	"stage_3": Color.html("#fb9797"),
	"stage_4": Color.html("#fb9797")
  }
}
