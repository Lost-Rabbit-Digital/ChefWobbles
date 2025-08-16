shader_type canvas_item;

// Authentic halftone controls
uniform float fade_distance : hint_range(0.05, 0.8) = 0.25;
uniform float halftone_frequency : hint_range(8.0, 40.0) = 18.0;
uniform float dot_scale : hint_range(0.6, 2.0) = 1.4;
uniform float gradient_power : hint_range(0.8, 3.0) = 1.6;
uniform float dot_roundness : hint_range(0.7, 1.0) = 0.95;
uniform float row_offset : hint_range(0.0, 1.0) = 0.5;
uniform bool use_staggered_rows = true;

// Edge selection controls
uniform bool affect_left_edge = true;
uniform bool affect_right_edge = false;
uniform bool affect_top_edge = false;
uniform bool affect_bottom_edge = false;

// Calculate distance to selected edges
float get_selective_edge_distance(vec2 uv) {
    float min_distance = 2.0;
    
    if (affect_left_edge) min_distance = min(min_distance, uv.x);
    if (affect_right_edge) min_distance = min(min_distance, 1.0 - uv.x);
    if (affect_top_edge) min_distance = min(min_distance, 1.0 - uv.y);
    if (affect_bottom_edge) min_distance = min(min_distance, uv.y);
    
    if (!affect_left_edge && !affect_right_edge && !affect_top_edge && !affect_bottom_edge) {
        return 2.0;
    }
    
    return min_distance;
}

// Authentic halftone dot generation with row staggering
float halftone_dot(vec2 uv, float density) {
    // Create grid with proper halftone frequency
    vec2 grid_uv = uv * halftone_frequency;
    vec2 grid_id = floor(grid_uv);
    vec2 grid_pos = fract(grid_uv);
    
    // Add horizontal offset for alternating rows (brick pattern)
    if (use_staggered_rows) {
        if (mod(grid_id.y, 2.0) > 0.5) {
            grid_pos.x = fract(grid_pos.x + row_offset);
        }
    }
    
    // Center position in grid cell
    vec2 center = vec2(0.5);
    vec2 delta = grid_pos - center;
    
    // Calculate distance from center
    float dist = length(delta);
    
    // Create dot size based on density (halftone principle)
    // Higher density = larger dots (darker areas)
    // Lower density = smaller dots (lighter areas)
    float dot_radius = density * dot_scale * 0.5;
    
    // Create the dot with proper roundness
    float dot_edge = dot_radius * dot_roundness;
    float dot_alpha = 1.0 - smoothstep(dot_edge - 0.05, dot_edge + 0.05, dist);
    
    return dot_alpha;
}

// Calculate halftone density based on distance from edge
float calculate_halftone_density(float edge_distance) {
    if (edge_distance >= fade_distance) {
        return 1.0; // Solid area
    }
    
    // Normalize distance (0 at edge, 1 at fade distance)
    float normalized = edge_distance / fade_distance;
    
    // Apply power curve for natural halftone transition
    float density = pow(normalized, gradient_power);
    
    return clamp(density, 0.0, 1.0);
}

// Smooth transition to solid
float blend_to_solid_area(float halftone_alpha, float density, float edge_distance) {
    // Create smooth transition zone near solid area
    float transition_zone = fade_distance * 0.2;
    
    if (edge_distance > (fade_distance - transition_zone)) {
        float blend_factor = (edge_distance - (fade_distance - transition_zone)) / transition_zone;
        blend_factor = smoothstep(0.0, 1.0, blend_factor);
        
        // Blend from halftone to solid
        halftone_alpha = mix(halftone_alpha, 1.0, blend_factor);
    }
    
    return halftone_alpha;
}

void fragment() {
    vec2 uv = UV;
    
    // Get distance to selected edges
    float edge_distance = get_selective_edge_distance(uv);
    
    // Calculate halftone density (how "dark" this area should be)
    float halftone_density = calculate_halftone_density(edge_distance);
    
    // Generate authentic halftone pattern
    float halftone_alpha = halftone_dot(uv, halftone_density);
    
    // Smooth transition to solid area
    halftone_alpha = blend_to_solid_area(halftone_alpha, halftone_density, edge_distance);
    
    // Areas beyond fade distance are completely solid
    if (edge_distance >= fade_distance) {
        halftone_alpha = 1.0;
    }
    
    // Apply the authentic halftone effect
    COLOR = vec4(COLOR.rgb, COLOR.a * halftone_alpha);
}