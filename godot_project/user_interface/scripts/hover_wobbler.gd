extends Button
class_name HoverWobbler

## Simple hover wobble for buttons - wobbles on mouse enter and exit

# Fixed settings
const WOBBLE_STRENGTH: float = 2.0  # degrees of rotation
const WOBBLE_SPEED: float = 3.0    # oscillations per second
const WOBBLE_DURATION: float = 0.5  # duration of wobble effect

# Internal state
var original_rotation: float = 0.0
var is_wobbling: bool = false
var wobble_time: float = 0.0
var wobble_direction: float = 1.0
var ease_tween: Tween

func _ready() -> void:
	# Store original rotation and set pivot to center
	original_rotation = rotation
	pivot_offset = size / 2.0
	
	# Connect hover signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _process(delta: float) -> void:
	if is_wobbling:
		update_wobble(delta)

func _on_mouse_entered() -> void:
	start_wobble()

func _on_mouse_exited() -> void:
	start_wobble()

func start_wobble() -> void:
	# Cancel any existing tween
	if ease_tween:
		ease_tween.kill()
		ease_tween = null
	
	is_wobbling = true
	wobble_time = 0.0
	wobble_direction = 1.0 if randf() > 0.5 else -1.0

func update_wobble(delta: float) -> void:
	wobble_time += delta
	
	if wobble_time >= WOBBLE_DURATION:
		stop_wobble()
	else:
		var progress = wobble_time / WOBBLE_DURATION
		var decay = 1.0 - (progress * progress)
		var wobble_angle = sin(wobble_time * WOBBLE_SPEED * TAU) * deg_to_rad(WOBBLE_STRENGTH)
		
		rotation = original_rotation + (wobble_angle * wobble_direction * decay)

func stop_wobble() -> void:
	is_wobbling = false
	
	ease_tween = create_tween()
	ease_tween.tween_property(self, "rotation", original_rotation, 0.2)
	ease_tween.set_ease(Tween.EASE_OUT)
	ease_tween.set_trans(Tween.TRANS_BACK)
