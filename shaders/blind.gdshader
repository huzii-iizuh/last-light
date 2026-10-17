shader_type canvas_item;
// Shadow blindness: the screen drowns in violet-black, leaving only a small hole in the middle.

uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= 1.6;
	float d = length(p);
	float hole = smoothstep(0.06, 0.32, d);
	float a = amount * mix(0.88, 1.0, hole);
	COLOR = vec4(0.03, 0.0, 0.06, a);
}
