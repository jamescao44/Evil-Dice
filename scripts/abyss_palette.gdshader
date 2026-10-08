shader_type canvas_item;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Runtime palette treatment; the downloaded public source stays unmodified.
	vec2 pixel_uv = (floor(UV * 160.0) + 0.5) / 160.0;
	vec4 source = texture(TEXTURE, pixel_uv);
	float shade = clamp(dot(source.rgb, vec3(0.85, 0.7, 0.4)), 0.0, 1.0);
	vec3 jade = mix(vec3(0.025, 0.10, 0.105), vec3(0.63, 0.89, 0.70), pow(shade, 0.72));
	if (source.r > 0.62 && source.r > source.g * 2.3) {
		jade = vec3(0.96, 0.74, 0.36);
	}
	COLOR = vec4(mix(jade, vec3(0.96, 0.57, 0.48), hurt * 0.65), source.a);
}
