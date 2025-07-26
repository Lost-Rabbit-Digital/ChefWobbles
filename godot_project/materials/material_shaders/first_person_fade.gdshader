shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Uniforms for controlling the fade effect
uniform float fade_distance : hint_range(0.0, 2.0) = 0.8; // Distance from camera where fade starts
uniform float fade_falloff : hint_range(0.1, 5.0) = 2.0; // How quickly it fades
uniform float dot_scale : hint_range(1.0, 50.0) = 20.0; // Size of the halftone dots
uniform float dot_smoothness : hint_range(0.01, 0.5) = 0.1; // Smoothness of dot edges
uniform bool use_halftone_pattern = true; // Toggle between smooth fade and halftone

// Material properties
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

// Camera detection
uniform bool only_fade_for_player_camera = true;
uniform float camera_fov_threshold : hint_range(60.0, 120.0) = 100.0; // FOV to identify player camera

varying vec3 world_pos;
varying vec3 view_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Halftone pattern function
float halftone_pattern(vec2 uv, float value) {
    vec2 pattern_uv = uv * dot_scale;
    vec2 pattern_center = floor(pattern_uv) + vec2(0.5);
    float pattern_distance = length(pattern_uv - pattern_center);

    // Create circular dots that get smaller as value decreases
    float dot_radius = (1.0 - value) * 0.5;
    float dot = smoothstep(dot_radius - dot_smoothness, dot_radius + dot_smoothness, pattern_distance);

    return dot;
}

void fragment() {
    // Get camera position in world space
    vec3 camera_world_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // Calculate distance from fragment to camera
    float distance_to_camera = length(world_pos - camera_world_pos);

    // Check if we should apply fade (optional FOV check)
    bool should_fade = true;
    if (only_fade_for_player_camera) {
        // Get camera FOV from projection matrix
        float fov = degrees(2.0 * atan(1.0 / PROJECTION_MATRIX[1][1]));
        should_fade = fov >= camera_fov_threshold - 5.0 && fov <= camera_fov_threshold + 5.0;
    }

    // Calculate fade factor
    float fade_factor = 1.0;
    if (should_fade) {
        fade_factor = smoothstep(0.0, fade_distance, distance_to_camera);
        fade_factor = pow(fade_factor, fade_falloff);
    }

    // Apply halftone pattern if enabled
    if (use_halftone_pattern && should_fade) {
        // Use screen space for stable pattern
        vec2 screen_uv = SCREEN_UV;
        fade_factor = halftone_pattern(screen_uv, fade_factor);
    }

    // Sample base texture
    vec4 albedo_tex = texture(texture_albedo, UV);

    // Set material properties
    ALBEDO = albedo.rgb * albedo_tex.rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    ALPHA = albedo_tex.a * albedo.a * fade_factor;

    // Enable alpha scissor for cleaner edges
    ALPHA_SCISSOR_THRESHOLD = 0.01;
}