shader_type spatial;
// Brilho redondo e suave no chão embaixo do item caído (cor da raridade).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float glow = smoothstep(1.0, 0.0, d);
	float ring = smoothstep(0.08, 0.0, abs(d - 0.55)) * 0.35;
	ALBEDO = tint.rgb;
	ALPHA = (glow * glow * 0.28 + ring) * strength * tint.a;
}
