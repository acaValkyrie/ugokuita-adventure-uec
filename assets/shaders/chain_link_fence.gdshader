shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_toon, specular_disabled;

// 金網の色（水色）
uniform vec4 wire_color : source_color = vec4(0.42, 0.74, 0.86, 1.0);
// 支柱と上下の横棒の色
uniform vec4 frame_color : source_color = vec4(0.36, 0.64, 0.76, 1.0);
// 菱形の網目1つの対角の長さ（メートル）
uniform float cell_size = 0.25;
// 針金の太さ（メートル）
uniform float wire_width = 0.02;
// 支柱の間隔（メートル）
uniform float post_spacing = 2.5;
// 支柱の太さ（メートル）
uniform float post_width = 0.06;
// 上下の横棒の太さ（メートル）
uniform float rail_height = 0.06;
// フェンス下端のワールドY（メートル）
uniform float fence_bottom_y = 0.0;
// フェンス上端のワールドY（メートル）
uniform float fence_top_y = 5.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 周期1の線のうち、幅 w（周期に対する割合）の部分が画素を覆う割合を返す
float line_coverage(float x, float w) {
	float d = abs(fract(x + 0.5) - 0.5);
	float fw = fwidth(x);
	float cov = 1.0 - smoothstep(w * 0.5 - fw, w * 0.5 + fw, d);
	// 遠くでメッシュの1マスが約2ピクセルより小さくなったら、平均の被覆率に切り替えてちらつき（モアレ）を防ぐ
	return mix(cov, w, clamp(fw * 2.0, 0.0, 1.0));
}

void fragment() {
	vec3 n = normalize(world_normal);
	// 幅0.1mの上面・下面は枠の色で塗りつぶす
	if (abs(n.y) > 0.7) {
		ALBEDO = frame_color.rgb;
		ALPHA = 1.0;
	} else {
		// 壁に沿った水平方向の座標 u と、高さ v
		vec2 t = normalize(vec2(-n.z, n.x));
		float u = dot(world_pos.xz, t);
		float v = world_pos.y;
		// 斜め2方向の線を重ねて菱形の網目にする
		float a = (u + v) / cell_size;
		float b = (u - v) / cell_size;
		float w = wire_width / cell_size;
		float wire = 1.0 - (1.0 - line_coverage(a, w)) * (1.0 - line_coverage(b, w));
		// 支柱と上下の横棒
		float post = line_coverage(u / post_spacing, post_width / post_spacing);
		float rail = (v < fence_bottom_y + rail_height || v > fence_top_y - rail_height) ? 1.0 : 0.0;
		float frame = max(post, rail);
		ALBEDO = mix(wire_color.rgb, frame_color.rgb, frame);
		ALPHA = max(wire, frame);
	}
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
