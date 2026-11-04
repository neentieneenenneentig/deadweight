shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// A geyser column: streaky, translucent steam that fades out at both ends, so it never reads as a
// solid pillar. UV.y runs along the column.
void fragment() {
	float streak = 0.55 + 0.45 * sin(UV.x * 6.2832 * 5.0 + UV.y * 9.0 - TIME * 7.0);
	float fade = smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	ALBEDO = vec3(0.92, 0.96, 1.0);
	ALPHA = 0.55 * streak * fade;
}
