shader_type spatial;
// Poça d'água: espelho escuro no chão, com borda irregular (o formato vem do ruído na posição
// do mundo, então cada poça sai diferente). Opaca de propósito (descarta fora da poça em vez de
// ficar transparente) para entrar no reflexo de tela (SSR) e espelhar o neon. Com chuva
// ("rain" 0..1, posto pelo clima) cresce um pouco e ganha ondinhas.
render_mode cull_back, depth_draw_opaque;

uniform sampler2D shape_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_noise : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float fill : hint_range(0.0, 1.0) = 0.55;
// Brilho do letreiro de neon mais perto espelhado na água (cor e força; posto pela poça). Funciona
// em qualquer placa de vídeo, até sem o reflexo de tela.
instance uniform vec4 glow : source_color = vec4(0.0);
// Cor do céu da hora (posta pelo relógio do mundo): a água espelha o céu.
uniform vec3 sky : source_color = vec3(0.25, 0.27, 0.32);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radial = 1.0 - clamp(length(centered), 0.0, 1.0);
	float n = texture(shape_noise, world_pos.xz * 0.23).r;
	float mask = radial * 1.25 + (n - 0.5) * 0.9;
	if (mask < 1.0 - (fill + rain * 0.18)) {
		discard;
	}
	vec2 flow = world_pos.xz * 0.9;
	vec3 ripple_a = texture(ripple_noise, flow + vec2(TIME * 0.06, TIME * 0.045)).rgb;
	vec3 ripple_b = texture(ripple_noise, flow * 1.7 - vec2(TIME * 0.05, TIME * 0.07)).rgb;
	vec3 ripple = normalize(mix(ripple_a, ripple_b, 0.5) * 2.0 - 1.0);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), ripple * 0.5 + 0.5, 0.12 + rain * 0.55);
	// Borda: a água vai ficando mais rasa (mais clara, com cara de chão molhado).
	float depth = clamp((mask - (1.0 - (fill + rain * 0.18))) * 5.0, 0.0, 1.0);
	ALBEDO = mix(vec3(0.11, 0.105, 0.1), vec3(0.03, 0.035, 0.045), depth);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float smear = texture(shape_noise, world_pos.xz * vec2(0.6, 1.6) + vec2(0.0, TIME * 0.02)).r;
	EMISSION = glow.rgb * glow.a * depth * (0.35 + 0.65 * smear) * (0.6 + fresnel)
			+ sky * depth * (1.0 + 1.0 * fresnel) * (0.85 + 0.3 * smear);
	ROUGHNESS = 0.03 + rain * 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
