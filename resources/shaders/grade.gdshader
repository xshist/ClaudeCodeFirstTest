shader_type canvas_item;
// Цветокоррекция «Пепла и крови»: приглушённые цвета, холодные тени, виньетка, зерно.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float desaturation : hint_range(0.0, 1.0) = 0.32;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
uniform vec3 shadow_tint : source_color = vec3(0.16, 0.15, 0.22);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.95, 0.88);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum), desaturation);
	c = (c - 0.5) * contrast + 0.5;
	c = mix(c * mix(vec3(1.0), shadow_tint * 3.0, 0.25), c * highlight_tint, smoothstep(0.2, 0.8, lum));
	float d = distance(UV, vec2(0.5));
	c *= 1.0 - vignette_strength * smoothstep(0.38, 0.85, d);
	c += (hash(UV * 512.0 + fract(TIME)) - 0.5) * grain_strength;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
