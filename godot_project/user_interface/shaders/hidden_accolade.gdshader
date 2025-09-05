shader_type canvas_item;

// Adjustable parameters
uniform float transparency : hint_range(0.0, 1.0) = 0.5;
uniform float grayscale_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float brightness_reduction : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // Sample the original texture
    vec4 original_color = texture(TEXTURE, UV);
    
    // Calculate grayscale using luminance weights
    // These weights account for human eye sensitivity to different colors
    float grayscale_value = dot(original_color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Create grayscale color
    vec3 grayscale_color = vec3(grayscale_value);
    
    // Blend between original and grayscale based on intensity
    vec3 final_color = mix(original_color.rgb, grayscale_color, grayscale_intensity);
    
    // Darken the final color to match the "locked" appearance
    final_color *= (1.0 - brightness_reduction);
    
    // Apply transparency while preserving original alpha
    COLOR = vec4(final_color, original_color.a * transparency);
}