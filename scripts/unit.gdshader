shader_type spatial;
// Crowd unit with a procedural run cycle.
// Vertex colour: R = team-coloured part, B = 1 white (eyes) / 0.5 accent
// (backpack, horns) / 0 dark, G = limb id
// (0 body, .25 left leg, .5 right leg, .75 left arm, 1 right arm).
// INSTANCE_CUSTOM.x = per-unit phase so the crowd doesn't run in sync.

uniform vec4 team_color : source_color = vec4(0.2, 0.55, 1.0, 1.0);
uniform vec4 dark_color : source_color = vec4(0.06, 0.07, 0.12, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float run_speed = 15.0;
uniform float model_scale = 1.3;

varying float v_height;

vec3 swing(vec3 v, vec3 pivot, float ang) {
	vec3 p = v - pivot;
	float c = cos(ang);
	float s = sin(ang);
	return pivot + vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

void vertex() {
	float t = TIME * run_speed + INSTANCE_CUSTOM.x;
	float s = sin(t);
	float limb = COLOR.g;
	vec3 v = VERTEX;
	float k = model_scale;
	if (limb > 0.12) {
		if (limb < 0.37) {
			v = swing(v, vec3(-0.085, 0.26, 0.0) * k, s * 0.75);
		} else if (limb < 0.62) {
			v = swing(v, vec3(0.085, 0.26, 0.0) * k, -s * 0.75);
		} else if (limb < 0.87) {
			v = swing(v, vec3(-0.16, 0.51, 0.0) * k, -s * 0.9);
		} else {
			v = swing(v, vec3(0.16, 0.51, 0.0) * k, s * 0.9);
		}
	} else {
		// body bobs twice per stride and leans into the run
		v.y += abs(cos(t)) * 0.07;
		v.x += sin(t) * 0.025 * v.y;
	}
	v.z -= v.y * 0.14;
	v_height = VERTEX.y;
	VERTEX = v;
}

void fragment() {
	vec3 c = dark_color.rgb;
	float team = step(0.5, COLOR.r);
	if (team > 0.5) {
		// glossy toy plastic: lighter on top, darker towards the feet
		float g = clamp(v_height / (0.95 * model_scale), 0.0, 1.0);
		c = team_color.rgb * mix(0.62, 1.15, g);
	} else if (COLOR.b > 0.75) {
		c = vec3(1.0);
	} else if (COLOR.b > 0.25) {
		c = accent_color.rgb;
	}
	float facing_view = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// a dark edge around each runner so they read as characters, not dots
	float edge = 1.0 - smoothstep(0.12, 0.38, facing_view);
	ALBEDO = mix(c, c * 0.28, edge * 0.85);
	ROUGHNESS = mix(0.5, 0.22, team);
	SPECULAR = 0.65;
	float rim = pow(1.0 - facing_view, 2.5);
	EMISSION = team_color.rgb * (0.1 + rim * 0.35) * team * (1.0 - edge);
}
