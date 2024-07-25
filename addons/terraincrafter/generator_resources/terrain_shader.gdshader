shader_type spatial;

uniform sampler2D texture_low : source_color;
uniform sampler2D texture_medium : source_color;
uniform sampler2D texture_high : source_color;

uniform float low_height : hint_range(-400.0, 100.0) = 10.0;
uniform float medium_height : hint_range(-400.0, 100.0) = 50.0;
uniform float high_height : hint_range(-400.0, 100.0) = 90.0;
uniform float blend_range : hint_range(0.0, 50.0) = 5.0;

uniform vec2 uv_scale_low = vec2(1.0, 1.0);
uniform vec2 uv_scale_medium = vec2(1.0, 1.0);
uniform vec2 uv_scale_high = vec2(1.0, 1.0);

uniform float roughness_low : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_medium : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_high : hint_range(0.0, 1.0) = 1.0;

uniform float specular_low : hint_range(0.0, 1.0) = 0.0;
uniform float specular_medium : hint_range(0.0, 1.0) = 0.0;
uniform float specular_high : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float height = world_position.y;

    vec4 low_tex = texture(texture_low, UV * uv_scale_low);
    vec4 medium_tex = texture(texture_medium, UV * uv_scale_medium);
    vec4 high_tex = texture(texture_high, UV * uv_scale_high);

    // Blending logic
    vec4 color = vec4(0.0);
    float roughness = 1.0;
    float specular = 0.0;

    if (height < medium_height) {
        // Blend between low and medium
        float blend_factor = smoothstep(low_height + blend_range, medium_height, height);
        color = mix(low_tex, medium_tex, blend_factor);
        roughness = mix(roughness_low, roughness_medium, blend_factor);
        specular = mix(specular_low, specular_medium, blend_factor);
    } else {
        // Blend between medium and high
        float blend_factor = smoothstep(medium_height + blend_range, high_height, height);
        color = mix(medium_tex, high_tex, blend_factor);
        roughness = mix(roughness_medium, roughness_high, blend_factor);
        specular = mix(specular_medium, specular_high, blend_factor);
    }

    ALBEDO = color.rgb;
    ROUGHNESS = roughness;
    SPECULAR = specular;
}
