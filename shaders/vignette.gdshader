shader_type canvas_item;
// Red edges while standing outside the zone.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.85, 0.05, 0.1, 1.0);

void fragment() {
	float d = length((UV - vec2(0.5)) * vec2(1.4, 1.0));
	float edge = smoothstep(0.35, 0.8, d);
	float pulse = 0.75 + 0.25 * sin(TIME * 6.0);
	COLOR = vec4(tint.rgb, amount * edge * pulse);
}
