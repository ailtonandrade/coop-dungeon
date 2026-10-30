shader_type canvas_item;
// Por cima do fundo do menu: vinheta nas bordas, linhas de tela velha e um chiado leve.

uniform float vignette = 0.75;
uniform float scanlines = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float edge = distance(uv, vec2(0.5)) * 1.35;
	float dark = smoothstep(0.45, 1.1, edge) * vignette;
	float lines = sin(FRAGCOORD.y * 1.6) * 0.5 + 0.5;
	float grain = hash(FRAGCOORD.xy + fract(TIME) * 100.0) - 0.5;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(dark + lines * scanlines + grain * 0.04, 0.0, 1.0));
}
