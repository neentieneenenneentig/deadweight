shader_type spatial;
render_mode diffuse_burley;

uniform vec4 tint : source_color = vec4(0.22, 0.03, 0.4, 1.0);
uniform float dream_time = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Slow phosphorescent currents drawn on a solid surface; no displaced collision or screen copy.
	vec2 p = world_position.xz;
	float wave = sin(p.x * 1.4 + sin(p.y * 0.3 + dream_time * 0.17) * 2.0 - dream_time * 0.22);
	float width = max(fwidth(wave), 0.025);
	float crest = smoothstep(0.88 - width, 0.96 + width, wave);
	ALBEDO = mix(tint.rgb, vec3(0.04, 0.95, 0.68), crest * 0.65);
	EMISSION = vec3(0.03, 0.75, 0.5) * crest * 0.4;
	ROUGHNESS = 0.36;
	METALLIC = 0.2;
}
