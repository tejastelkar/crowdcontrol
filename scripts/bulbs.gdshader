shader_type spatial;
render_mode unshaded;
// Marquee bulbs on gate signs: a light chases along the row.

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.5, 1.0);
varying float v_x;

void vertex() {
	v_x = (MODEL_MATRIX * vec4(VERTEX, 1.0)).x;
}

void fragment() {
	float chase = step(0.5, fract(v_x * 0.9 - TIME * 2.2));
	ALBEDO = mix(color.rgb * 0.55, vec3(1.0, 0.98, 0.85), chase);
}
