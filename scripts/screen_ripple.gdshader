shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 origin = vec2(0.5);
uniform vec2 canvas_size = vec2(1280.0, 800.0);
uniform float progress = 0.0;
uniform float strength = 16.0;
uniform float glow = 0.13;

void fragment() {
	vec2 delta = (SCREEN_UV - origin) * canvas_size;
	float distance_from_impact = length(delta);
	vec2 direction = delta / max(distance_from_impact, 1.0);
	// Reach even the farthest HUD corner when dropped near an edge.
	vec2 far_corner = max(origin, vec2(1.0) - origin) * canvas_size;
	float reach = length(far_corner) + 180.0;
	float width = min(canvas_size.x, canvas_size.y) * 0.16;
	float behind = distance_from_impact - progress * reach;
	float envelope = exp(-pow(behind / width, 2.0) * 2.0);
	float fade = smoothstep(0.0, 0.06, progress) * (1.0 - smoothstep(0.65, 1.0, progress));
	float wave = sin(behind / width * 10.0);
	vec2 offset = direction * wave * envelope * fade * strength / canvas_size;
	// Fade displacement at screen edges; never pull black pixels into the UI.
	vec2 edge = min(SCREEN_UV, vec2(1.0) - SCREEN_UV) * canvas_size;
	offset *= smoothstep(0.0, 24.0, min(edge.x, edge.y));
	vec2 uv = clamp(SCREEN_UV + offset, SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
	vec4 scene = texture(screen_texture, uv);
	float crest = pow(max(wave, 0.0), 5.0) * envelope * fade;
	COLOR = vec4(scene.rgb + vec3(1.0, 0.73, 0.3) * crest * glow, 1.0);
}
