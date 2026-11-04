shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D porcelain : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 chalk : source_color = vec4(0.57, 0.79, 0.18, 1.0);
uniform vec4 ink : source_color = vec4(0.14, 0.04, 0.26, 1.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// Blend cell edges, then fade subpixel tiles. Avoid subtracting nearly equal
	// values: Compatibility's varying precision otherwise bands across broad floors.
	vec2 p = world_position.xz / 3.0;
	vec2 w = max(fwidth(p), vec2(0.0001));
	vec2 edge = min(fract(p), 1.0 - fract(p));
	vec2 inside = smoothstep(vec2(0.0), w, edge);
	float parity = mod(floor(p.x) + floor(p.y), 2.0);
	float checker = mix(0.5, parity, min(inside.x, inside.y));
	checker = mix(checker, 0.5, smoothstep(0.25, 1.0, max(w.x, w.y)));
	vec3 weights = pow(abs(normalize(world_normal)), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 patina = texture(porcelain, world_position.zy * 0.18).rgb * weights.x
		+ texture(porcelain, world_position.xz * 0.18).rgb * weights.y
		+ texture(porcelain, world_position.xy * 0.18).rgb * weights.z;
	vec3 tiles = mix(chalk.rgb, ink.rgb, checker);
	ALBEDO = mix(chalk.rgb, tiles, smoothstep(0.65, 0.95, abs(world_normal.y))) * patina;
	EMISSION = ALBEDO * 0.07;
	ROUGHNESS = 0.72;
}
