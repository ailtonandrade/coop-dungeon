shader_type spatial;
// Parede brasileira de periferia: tijolo aparente com reboco caindo (textura que emenda, presa
// no mundo, então qualquer caixa de parede fica certa sem mexer em UV), barro respingado
// embaixo e sujeira escorrendo do alto.
render_mode cull_back;

uniform sampler2D wall_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grime : source_color, filter_linear_mipmap, repeat_enable;
// Metros de parede por repetição da textura.
uniform float tile = 9.75;
uniform float ground_y = 0.0;
// Cor geral (para variar casa a casa).
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y > 0.7) {
		uv = world_pos.xz;
	} else if (n.x > n.z) {
		uv = vec2(world_pos.z, -world_pos.y);
	} else {
		uv = vec2(world_pos.x, -world_pos.y);
	}
	vec3 color = texture(wall_texture, uv / tile).rgb * tint;
	// Barro respingado no rodapé (até ~70 cm) e sujeira escorrendo.
	float height = world_pos.y - ground_y;
	float splash = 1.0 - smoothstep(0.0, 0.7, height + (texture(grime, uv * 0.7).r - 0.5) * 0.4);
	color = mix(color, color * vec3(0.55, 0.47, 0.38), splash * 0.75);
	color *= mix(1.0, texture(grime, uv / 7.0).r, 0.6);
	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
