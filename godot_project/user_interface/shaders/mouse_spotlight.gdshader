shader_type canvas_item;

// Spotlight controls
uniform float spotlight_radius : hint_range(50.0, 500.0) = 150.0;
uniform float spotlight_softness : hint_range(10.0, 200.0) = 80.0;
uniform float min_opacity : hint_range(0.0, 1.0) = 0.2;
uniform float max_opacity : hint_range(0.0, 1.0) = 0.8;
uniform vec2 mouse_position = vec2(0.5, 0.5);
uniform bool invert_effect = true;
uniform float animation_speed : hint_range(0.0, 5.0) = 0.0;
uniform float pulse_intensity : hint_range(0.0, 0.5) = 0.0;

// Calculate smooth circular gradient
float circular_gradient(vec2 pixel_pos, vec2 center_pixel, float radius, float softness) {
    float distance_to_center = length(pixel_pos - center_pixel);
    
    // Add subtle animation if enabled
    float animated_radius = radius;
    if (animation_speed > 0.0) {
        float pulse = sin(TIME * animation_speed) * pulse_intensity;
        animated_radius = radius * (1.0 + pulse);
    }
    
    // Create smooth falloff
    float gradient = 1.0 - smoothstep(
        animated_radius - softness, 
        animated_radius + softness, 
        distance_to_center
    );
    
    return gradient;
}

// Advanced spotlight with multiple quality options
float advanced_spotlight(vec2 pixel_pos, vec2 center_pixel) {
    float gradient = circular_gradient(pixel_pos, center_pixel, spotlight_radius, spotlight_softness);
    
    // Apply easing curve for more natural falloff
    gradient = smoothstep(0.0, 1.0, gradient);
    
    // Map gradient to opacity range
    float opacity = mix(min_opacity, max_opacity, gradient);
    
    // Invert effect if requested (spotlight becomes dark circle)
    if (invert_effect) {
        opacity = max_opacity - (opacity - min_opacity);
    }
    
    return clamp(opacity, 0.0, 1.0);
}

void fragment() {
    vec2 uv = UV;
    
    // Calculate pixel positions (SCREEN_PIXEL_SIZE only available in fragment)
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 pixel_pos = uv * screen_size;
    vec2 center_pixel = mouse_position * screen_size;
    
    // Calculate spotlight opacity at this pixel
    float spotlight_opacity = advanced_spotlight(pixel_pos, center_pixel);
    
    // Apply spotlight effect to the panel
    float final_alpha = COLOR.a * spotlight_opacity;
    COLOR = vec4(COLOR.rgb, final_alpha);
}