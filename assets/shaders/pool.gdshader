shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// true のとき水面、false のときプールサイド（台座）として塗る
uniform bool is_water = false;
// 水面の長方形の中心（ワールドXZ）
uniform vec2 pool_center = vec2(-207.759, -178.832);
// 長辺の向き（単位ベクトル、ワールドXZ）
uniform vec2 pool_long_axis = vec2(0.2664, -0.9639);
// 水面の半分の大きさ（x が短辺方向、y が長辺方向、メートル）
uniform vec2 pool_half_size = vec2(6.69, 12.705);
// 水の色
uniform vec4 water_color : source_color = vec4(0.55, 0.82, 0.92, 1.0);
// コースラインの色
uniform vec4 lane_color : source_color = vec4(0.12, 0.30, 0.62, 1.0);
// コースの数
uniform int lane_count = 6;
// コースラインの太さ（メートル）
uniform float lane_line_width = 0.25;
// コースラインが壁の手前で止まる距離（メートル）
uniform float lane_line_end = 2.0;
// コースラインの端のT字の横棒の長さ（メートル）
uniform float lane_cross_length = 1.0;
// 水面の縁の白い部分の色
uniform vec4 coping_color : source_color = vec4(0.93, 0.93, 0.90, 1.0);
// 縁の白い部分の幅（メートル）
uniform float coping_width = 0.5;
// プールサイドのコンクリートの色
uniform vec4 deck_color : source_color = vec4(0.62, 0.56, 0.48, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 水面の長方形の中心からの位置を、短辺方向 s と長辺方向 l に分ける
	vec2 d = world_pos.xz - pool_center;
	vec2 short_axis = vec2(-pool_long_axis.y, pool_long_axis.x);
	float s = dot(d, short_axis);
	float l = dot(d, pool_long_axis);
	vec3 albedo;
	if (is_water) {
		// 一番近いコースの中心までの距離 ds
		float lane_w = 2.0 * pool_half_size.x / float(lane_count);
		float k = (s + pool_half_size.x) / lane_w - 0.5;
		float kc = clamp(round(k), 0.0, float(lane_count - 1));
		float ds = abs(k - kc) * lane_w;
		float end_l = pool_half_size.y - lane_line_end;
		// 縦のコースラインと、その両端のT字の横棒
		bool line_body = ds < lane_line_width * 0.5 && abs(l) < end_l;
		bool line_cross = abs(abs(l) - end_l) < lane_line_width * 0.5 && ds < lane_cross_length * 0.5;
		albedo = (line_body || line_cross) ? lane_color.rgb : water_color.rgb;
	} else {
		// 水面の周りの白い縁（穴の内側の壁も含めて白くなる）
		bool in_coping = abs(s) < pool_half_size.x + coping_width && abs(l) < pool_half_size.y + coping_width;
		albedo = in_coping ? coping_color.rgb : deck_color.rgb;
	}
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
