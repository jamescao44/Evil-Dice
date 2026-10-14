shader_type canvas_item;
// Match only the tarot sprite sheets; shared canvases also draw text and relics.
void fragment() {
	vec4 ink = COLOR;
	if (textureSize(TEXTURE, 0) == ivec2(73, 113)) {
		float grey = dot(ink.rgb, vec3(0.2126, 0.7152, 0.0722));
		ink.rgb = mix(vec3(grey), ink.rgb, 0.38);
	}
	COLOR = ink;
}
