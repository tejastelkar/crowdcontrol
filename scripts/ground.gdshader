shader_type spatial;
// Ground with soft colour patches so it doesn't read as one flat colour.

uniform vec4 color : source_color = vec4(0.42, 0.76, 0.32, 1.0);
uniform float patch_scale = 0.12;
varying vec2 v_world;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float n = noise(v_world * patch_scale) * 0.6 + noise(v_world * patch_scale * 3.7) * 0.4;
	float fine = noise(v_world * 2.5);
	vec3 c = color.rgb * (0.86 + n * 0.24) * (0.97 + fine * 0.06);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
