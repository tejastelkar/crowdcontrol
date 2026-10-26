shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Gate panel: tinted glass with glowing edges and diagonal shine sweeping across.

uniform vec4 color : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform float flash = 0.0;
uniform float width = 3.6;
uniform bool hazard = false;

void fragment() {
	vec2 uv = UV;
	float aspect = width / 1.55;
	float diag = uv.x * aspect + uv.y * 0.8 - TIME * 1.4;
	float band = fract(diag * 0.35);
	float shine = smoothstep(0.0, 0.06, band) * (1.0 - smoothstep(0.06, 0.16, band));
	float ex = min(uv.x, 1.0 - uv.x) * aspect;
	float ey = min(uv.y, 1.0 - uv.y);
	float edge = 1.0 - smoothstep(0.0, 0.12, min(ex, ey));
	float fill = mix(0.55, 0.8, uv.y);
	vec3 base = color.rgb;
	if (hazard) {
		// warning stripes on trap gates
		float st = step(0.5, fract((uv.x * aspect - uv.y) * 1.6));
		base = mix(color.rgb, color.rgb * 0.55, st);
	}
	vec3 c = base * (0.85 + flash * 0.8) + vec3(shine * 0.55 + edge * 0.45 + flash * 0.35);
	ALBEDO = c;
	ALPHA = clamp(fill * 0.75 + shine * 0.25 + edge * 0.4 + flash * 0.2, 0.0, 1.0);
}
