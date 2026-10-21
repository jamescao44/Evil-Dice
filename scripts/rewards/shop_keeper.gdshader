shader_type canvas_item;
// The source uses palette black as its backdrop; keep all colored sprite pixels.
void fragment() {
	if (max(COLOR.r, max(COLOR.g, COLOR.b)) < 0.01) {
		COLOR.a = 0.0;
	}
}
