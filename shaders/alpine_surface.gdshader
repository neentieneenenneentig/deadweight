shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D slate : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.6, 0.7, 0.8, 1.0);
uniform bool vertex_tint = false;
uniform float snow_amount = 0.9;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 stone = texture(slate, world_position.zy * 0.14).rgb * weights.x
		+ texture(slate, world_position.xz * 0.14).rgb * weights.y
		+ texture(slate, world_position.xy * 0.14).rgb * weights.z;
	float brush = dot(stone, vec3(0.333));
	float drift = sin(world_position.x * 0.19 + sin(world_position.z * 0.11) * 2.0) * 0.035;
	float cover = smoothstep(0.54, 0.83, n.y + (brush - 0.25) * 0.5 + drift) * snow_amount;
	vec3 base = vertex_tint ? COLOR.rgb : tint.rgb;
	vec3 snow = base * (0.91 + brush * 0.18 + drift);
	vec3 rock = stone * mix(vec3(1.2), base * 1.6, 0.35);
	ALBEDO = mix(rock, snow, cover);
	ROUGHNESS = 0.94;
}
