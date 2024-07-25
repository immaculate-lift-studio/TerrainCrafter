shader_type spatial;
render_mode unshaded,cull_disabled;

uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D albedo_texture : source_color, filter_linear,repeat_disable;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest,repeat_disable;

uniform sampler2D noise_texture;

uniform float speed : hint_range(0.0, 2.0, 0.005) = 0.5;
uniform float distortion : hint_range(0.0, 0.3, 0.005) = 0.03;

uniform vec3 uv1_scale = vec3(1,1,1);
uniform vec3 uv1_offset;


void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;

}

void fragment() {
	vec2 noiseValue  = (texture(noise_texture, UV + (TIME * speed)).rg * 2.0) - 1.0; // Range: -1.0 to 1.0

	vec2 noiseDistortion = (noiseValue * distortion);

	vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV + noiseDistortion);

    ALBEDO = vec3(color.rgb);
	ALPHA = alpha * texture(albedo_texture, UV).r;
}
