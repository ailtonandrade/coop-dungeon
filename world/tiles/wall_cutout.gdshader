// Parede que nunca esconde o herói: abre um buraco redondo (com borda pontilhada) em volta
// de cada jogador desta tela, só nos pedaços da parede que estão entre a câmera e ele.
// Todas as paredes pintadas usam o mesmo material; o CameraOcclusion atualiza as posições.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.75, 0.68, 0.55, 1.0);
// Por jogador: xy = posição na tela (0..1), z = distância até a câmera, w = 1 se existe.
uniform vec4 occlusion_players[4];
// Raio do buraco em fração da altura da tela.
uniform float cutout_radius = 0.11;
uniform float aspect = 1.7778;

void fragment() {
	ALBEDO = albedo.rgb;
	float depth = -VERTEX.z;
	for (int i = 0; i < 4; i++) {
		vec4 p = occlusion_players[i];
		if (p.w > 0.5 && depth < p.z - 0.6) {
			float r = length((SCREEN_UV - p.xy) * vec2(aspect, 1.0)) / cutout_radius;
			if (r < 1.0) {
				float noise = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
				if (r < 0.7 || noise > (r - 0.7) / 0.3) {
					discard;
				}
			}
		}
	}
}
