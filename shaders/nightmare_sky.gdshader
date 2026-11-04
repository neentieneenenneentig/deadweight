shader_type sky;

uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float storm_time = 0.0;
uniform float sky_energy = 1.0;
uniform float cloud_speed = 0.00025;
uniform float effects_strength = 0.0;

float hash(float n) {
	return fract(sin(n * 127.1 + 41.7) * 43758.5453);
}

// Signed distance around the panorama: effects cross the longitude seam cleanly.
float longitude(float x, float centre) {
	return fract(x - centre + 0.5) - 0.5;
}

vec3 detonation(vec2 uv, float time, float offset) {
	float cycle = floor((time + offset) / 17.0);
	float age = mod(time + offset, 17.0);
	float centre = fract(cycle * 0.618034 + offset * 0.17 + 0.91);
	vec2 p = vec2(longitude(uv.x, centre), (uv.y - 0.495) * 0.65);
	float radius = 0.004 + age * 0.009;
	float d = length(p);
	float envelope = smoothstep(0.0, 0.16, age) * exp(-age * 0.65);
	float fireball = exp(-d * d / (radius * radius));
	float shock = exp(-abs(d - radius * 1.5) * 600.0) * exp(-age * 0.5);
	float plume = exp(-pow(p.x / (0.009 + age * 0.004), 2.0) - pow((p.y + age * 0.002) / 0.026, 2.0));
	float above_horizon = 1.0 - smoothstep(0.50, 0.54, uv.y);
	vec3 flare = mix(vec3(0.7, 0.015, 0.45), vec3(0.3, 0.9, 0.02), hash(cycle + offset));
	return (flare * (fireball * 1.1 + plume * 0.3) + vec3(0.12, 0.45, 0.5) * shock) * envelope * above_horizon;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		// Cheap, stable reflections; transient bolts never bleach the entire world.
		COLOR = textureLod(panorama, SKY_COORDS, 2.0).rgb * sky_energy;
	} else {
		vec2 uv = SKY_COORDS;
		float latitude_mask = sin(uv.y * PI);
		vec2 flow = vec2(storm_time * cloud_speed, 0.0);
		flow += vec2(sin(uv.x * TAU * 3.0 + storm_time * 0.11), cos(uv.x * TAU * 2.0 - storm_time * 0.08)) * vec2(0.006, 0.004) * effects_strength * latitude_mask;
		// Explicit LOD avoids derivative spikes where longitude wraps from 1 to 0.
		vec3 clouds = textureLod(panorama, vec2(uv.x + flow.x, clamp(uv.y + flow.y, 0.001, 0.999)), 0.0).rgb;
		// A faint counter-moving veil gives the painted clouds a second depth layer.
		vec3 veil = textureLod(panorama, vec2(uv.x - storm_time * 0.0007 + 0.31, uv.y), 1.0).rgb;
		clouds += veil * 0.12 * effects_strength * smoothstep(0.1, 0.4, uv.y) * (1.0 - smoothstep(0.45, 0.6, uv.y));
		COLOR = clouds * sky_energy;
		COLOR += (detonation(uv, storm_time, 1.0) + detonation(uv, storm_time, 8.5)) * effects_strength;
	}
}
