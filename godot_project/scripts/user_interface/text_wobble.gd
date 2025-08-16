extends RichTextLabel
class_name TextWobbler

@export var wobble_enabled: bool = true
@export var wobble_strength: float = 5.5  # degrees of rotation
@export var wobble_speed: float = 7.0
@export var wobble_interval_min: float = 1.5
@export var wobble_interval_max: float = 6.0
@export var wobble_duration: float = 0.75

var original_position: Vector2
var original_pivot: Vector2
var wobble_timer: float = 0.0
var current_interval: float = 0.0
var is_wobbling: bool = false
var wobble_start_time: float = 0.0
var random_wobble_direction: float = 0.0

func _ready() -> void:
	original_position = position
	# Set pivot to center of the RichTextLabel
	pivot_offset = size / 2.0
	original_pivot = pivot_offset
	# Set initial random interval
	set_random_interval()

func _process(delta: float) -> void:
	if not wobble_enabled:
		return
	
	wobble_timer += delta
	
	# Check if we should start wobbling
	if not is_wobbling and wobble_timer >= current_interval:
		start_wobble()
	
	# Update wobble if active
	if is_wobbling:
		update_wobble(delta)

func start_wobble() -> void:
	is_wobbling = true
	wobble_start_time = 0.0
	wobble_timer = 0.0
	random_wobble_direction = randf()
	
func update_wobble(delta: float) -> void:
	wobble_start_time += delta
	
	if wobble_start_time >= wobble_duration:
		# Smoothly tween back to original rotation
		is_wobbling = false
		var tween = create_tween()
		tween.tween_property(self, "rotation", 0.0, 0.2)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		wobble_timer = 0.0
		# Set new random interval for next wobble
		set_random_interval()
	else:
		# Calculate rotational wobble (convert degrees to radians)
		var wobble_angle = sin(wobble_start_time * wobble_speed) * deg_to_rad(wobble_strength)
		if random_wobble_direction > 0.5:
			rotation = -wobble_angle
		else:
			rotation = wobble_angle

func trigger_wobble() -> void:
	wobble_timer = current_interval  # Force immediate wobble

func set_random_interval() -> void:
	current_interval = randf_range(wobble_interval_min, wobble_interval_max)

func stop_wobble() -> void:
	wobble_enabled = false
	var tween = create_tween()
	tween.tween_property(self, "rotation", 0.0, 0.3)
	tween.set_ease(Tween.EASE_OUT)
