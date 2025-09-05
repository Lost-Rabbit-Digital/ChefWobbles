extends Node
class_name AccoladeWobbler

## Simple hover wobble for any Control node - wobbles on mouse enter and exit
## Automatically applies to all nodes in the "accolade" group

# Fixed settings
const WOBBLE_STRENGTH: float = 7.0  # degrees of rotation
const WOBBLE_SPEED: float = 3.0     # oscillations per second
const WOBBLE_DURATION: float = 0.6   # duration of wobble effect

# Internal state for each accolade
var accolade_data: Dictionary = {}

func _ready() -> void:
	# Find all accolade nodes and set them up
	setup_accolades()

func setup_accolades() -> void:
	var accolades = get_tree().get_nodes_in_group("accolades")
	
	for accolade in accolades:
		if accolade is Control:
			setup_single_accolade(accolade)

func setup_single_accolade(accolade: Control) -> void:
	# Store original rotation and set pivot to center
	var original_rotation = accolade.rotation
	accolade.pivot_offset = accolade.size / 2.0
	
	# Enable mouse detection
	accolade.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Initialize data for this accolade
	accolade_data[accolade] = {
		"original_rotation": original_rotation,
		"is_wobbling": false,
		"wobble_time": 0.0,
		"wobble_direction": 1.0,
		"ease_tween": null
	}
	
	# Connect hover signals
	accolade.mouse_entered.connect(_on_mouse_entered.bind(accolade))
	accolade.mouse_exited.connect(_on_mouse_exited.bind(accolade))

func _process(delta: float) -> void:
	# Update wobble for all wobbling accolades
	for accolade in accolade_data:
		if accolade_data[accolade]["is_wobbling"]:
			update_wobble(accolade, delta)

func _on_mouse_entered(accolade: Control) -> void:
	start_wobble(accolade)

func _on_mouse_exited(accolade: Control) -> void:
	start_wobble(accolade)

func start_wobble(accolade: Control) -> void:
	if not accolade_data.has(accolade):
		return
	
	var data = accolade_data[accolade]
	
	# Cancel any existing tween
	if data["ease_tween"]:
		data["ease_tween"].kill()
		data["ease_tween"] = null
	
	data["is_wobbling"] = true
	data["wobble_time"] = 0.0
	data["wobble_direction"] = 1.0 if randf() > 0.5 else -1.0

func update_wobble(accolade: Control, delta: float) -> void:
	var data = accolade_data[accolade]
	data["wobble_time"] += delta
	
	if data["wobble_time"] >= WOBBLE_DURATION:
		stop_wobble(accolade)
	else:
		var progress = data["wobble_time"] / WOBBLE_DURATION
		var decay = 1.0 - (progress * progress)
		var wobble_angle = sin(data["wobble_time"] * WOBBLE_SPEED * TAU) * deg_to_rad(WOBBLE_STRENGTH)
		
		accolade.rotation = data["original_rotation"] + (wobble_angle * data["wobble_direction"] * decay)

func stop_wobble(accolade: Control) -> void:
	var data = accolade_data[accolade]
	data["is_wobbling"] = false
	
	data["ease_tween"] = create_tween()
	data["ease_tween"].tween_property(accolade, "rotation", data["original_rotation"], 0.2)
	data["ease_tween"].set_ease(Tween.EASE_OUT)
	data["ease_tween"].set_trans(Tween.TRANS_BACK)
