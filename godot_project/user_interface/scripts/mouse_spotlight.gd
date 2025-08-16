class_name SpotlightController
extends Control

@export var spotlight_enabled: bool = true
@export var smooth_follow: bool = true
@export var follow_speed: float = 8.0
@export var mouse_sensitivity: float = 1.0

var shader_material: ShaderMaterial
var target_mouse_pos: Vector2
var current_mouse_pos: Vector2

func _ready() -> void:
	# Get the shader material
	if material and material is ShaderMaterial:
		shader_material = material as ShaderMaterial
	else:
		push_error("SpotlightController: No ShaderMaterial found!")
		return
	
	# Initialize mouse position to center
	target_mouse_pos = Vector2(0.5, 0.5)
	current_mouse_pos = target_mouse_pos
	
	# Set initial shader parameters
	_update_shader_mouse_position(current_mouse_pos)

func _input(event: InputEvent) -> void:
	if not spotlight_enabled or not shader_material:
		return
	
	# Track mouse movement
	if event is InputEventMouseMotion:
		_update_mouse_position(event.global_position)

func _process(delta: float) -> void:
	if not spotlight_enabled or not shader_material:
		return
	
	# Smooth mouse following
	if smooth_follow:
		current_mouse_pos = current_mouse_pos.lerp(target_mouse_pos, follow_speed * delta)
	else:
		current_mouse_pos = target_mouse_pos
	
	# Update shader
	_update_shader_mouse_position(current_mouse_pos)

func _update_mouse_position(global_mouse_pos: Vector2) -> void:
	# Convert global mouse position to UV coordinates (0-1 range)
	var local_pos = global_mouse_pos - global_position
	var uv_pos = Vector2(
		local_pos.x / size.x,
		local_pos.y / size.y
	)
	
	# Apply sensitivity and clamp to valid range
	target_mouse_pos = uv_pos * mouse_sensitivity
	target_mouse_pos = Vector2(
		clamp(target_mouse_pos.x, 0.0, 1.0),
		clamp(target_mouse_pos.y, 0.0, 1.0)
	)

func _update_shader_mouse_position(uv_pos: Vector2) -> void:
	if shader_material and shader_material.shader:
		shader_material.set_shader_parameter("mouse_position", uv_pos)

# Public methods for dynamic control
func set_spotlight_radius(radius: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("spotlight_radius", radius)

func set_spotlight_softness(softness: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("spotlight_softness", softness)

func set_opacity_range(min_opacity: float, max_opacity: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("min_opacity", min_opacity)
		shader_material.set_shader_parameter("max_opacity", max_opacity)

func enable_animation(speed: float, pulse_intensity: float = 0.1) -> void:
	if shader_material:
		shader_material.set_shader_parameter("animation_speed", speed)
		shader_material.set_shader_parameter("pulse_intensity", pulse_intensity)

func disable_animation() -> void:
	if shader_material:
		shader_material.set_shader_parameter("animation_speed", 0.0)
		shader_material.set_shader_parameter("pulse_intensity", 0.0)

func toggle_invert_effect(invert: bool) -> void:
	if shader_material:
		shader_material.set_shader_parameter("invert_effect", invert)

func enable_spotlight() -> void:
	spotlight_enabled = true

func disable_spotlight() -> void:
	spotlight_enabled = false
	if shader_material:
		# Reset to full opacity when disabled
		shader_material.set_shader_parameter("mouse_position", Vector2(0.5, 0.5))
		shader_material.set_shader_parameter("min_opacity", 1.0)
