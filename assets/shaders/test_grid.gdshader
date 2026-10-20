// テスト用ステージの床。1m ごとに細い線、10m ごとに太い線を引く
shader_type spatial;

varying vec3 world_pos;

const vec3 base_color = vec3(0.36, 0.37, 0.38);
const vec3 line_color = vec3(0.48);
const vec3 line_color_major = vec3(0.62);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;

	// 1m ごとの細い線
	vec2 g1 = abs(fract(p - 0.5) - 0.5) / fwidth(p);
	float l1 = 1.0 - min(min(g1.x, g1.y), 1.0);

	// 10m ごとの太い線
	vec2 p10 = p / 10.0;
	vec2 g10 = abs(fract(p10 - 0.5) - 0.5) / fwidth(p10);
	float l10 = 1.0 - min(min(g10.x, g10.y) * 0.5, 1.0);

	vec3 col = base_color;
	col = mix(col, line_color, l1);
	col = mix(col, line_color_major, l10);

	ALBEDO = col;
	ROUGHNESS = 0.9;
}
