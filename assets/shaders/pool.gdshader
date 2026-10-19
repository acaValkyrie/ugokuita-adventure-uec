shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// true のときプールの底（コースラインを描く）、false のときプールサイド（台座）として塗る
uniform bool is_floor = false;
// 水面の長方形の中心（ワールドXZ）
uniform vec2 pool_center = vec2(-207.759, -178.832);
// 長辺の向き（単位ベクトル、ワールドXZ）
uniform vec2 pool_long_axis = vec2(0.2664, -0.9639);
// 水面の半分の大きさ（x が短辺方向、y が長辺方向、メートル）
uniform vec2 pool_half_size = vec2(6.69, 12.705);
// プールの底の色
uniform vec4 floor_color : source_color = vec4(0.18, 0.70, 0.86, 1.0);
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

// 光の網目の色
uniform vec4 caustic_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 光の網目を底の色に足す強さ
uniform float caustic_strength = 0.6;
// 光の網目を自分で光らせる強さ（影の中でもくすまないように）
uniform float caustic_emission = 0.25;
// 光の網目の1マスの大きさ（メートル）
uniform float caustic_scale = 1.2;
// 光の網目が動く速さ
uniform float caustic_speed = 0.6;
// 光の網目の線の太さ（1マスに対する割合）
uniform float caustic_width = 0.08;
// コースラインが揺れる幅（メートル）
uniform float wobble_amount = 0.06;
// コースラインが揺れる速さ
uniform float wobble_speed = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 2次元の乱数（0以上1未満の vec2 を返す）
vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// 光の網目を1層ぶん作る（p は1マス=1の単位、t は時間）
float caustic_layer(vec2 p, float t) {
	// 線がうねるように座標をゆがめる
	p += 0.30 * vec2(sin(p.y * 1.7 + t * 0.9), sin(p.x * 1.9 - t * 0.8));
	p += 0.15 * vec2(sin(p.y * 3.1 - t * 1.3), sin(p.x * 2.7 + t * 1.1));
	// 動くボロノイ。一番近い点までの距離 F1 と二番目に近い点までの距離 F2 を求める
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = 0.5 + 0.4 * sin(t + 6.2831 * hash2(cell + vec2(float(x), float(y))));
			float dist = length(vec2(float(x), float(y)) + o - f);
			if (dist < f1) {
				f2 = f1;
				f1 = dist;
			} else if (dist < f2) {
				f2 = dist;
			}
		}
	}
	// 境目（F2 と F1 の差が小さいところ）を明るい線にする
	float edge = f2 - f1;
	return pow(clamp(1.0 - edge / caustic_width, 0.0, 1.0), 2.0);
}

void fragment() {
	// 水面の長方形の中心からの位置を、短辺方向 s と長辺方向 l に分ける
	vec2 d = world_pos.xz - pool_center;
	vec2 short_axis = vec2(-pool_long_axis.y, pool_long_axis.x);
	float s = dot(d, short_axis);
	float l = dot(d, pool_long_axis);
	vec3 albedo;
	vec3 emission = vec3(0.0);
	if (is_floor) {
		// 水面の揺れで底の線がゆがんで見える
		float wt = TIME * wobble_speed;
		s += wobble_amount * sin(l * 1.3 + wt);
		l += wobble_amount * sin(s * 1.1 - wt * 0.8);
		// 一番近いコースの中心までの距離 ds
		float lane_w = 2.0 * pool_half_size.x / float(lane_count);
		float k = (s + pool_half_size.x) / lane_w - 0.5;
		float kc = clamp(round(k), 0.0, float(lane_count - 1));
		float ds = abs(k - kc) * lane_w;
		float end_l = pool_half_size.y - lane_line_end;
		// 縦のコースラインと、その両端のT字の横棒
		bool line_body = ds < lane_line_width * 0.5 && abs(l) < end_l;
		bool line_cross = abs(abs(l) - end_l) < lane_line_width * 0.5 && ds < lane_cross_length * 0.5;
		albedo = (line_body || line_cross) ? lane_color.rgb : floor_color.rgb;
		// 水面を通った光の網目（ワールド座標で作るので揺れの影響を受けない）
		vec2 cp = world_pos.xz / caustic_scale;
		float ct = TIME * caustic_speed;
		float c = max(caustic_layer(cp, ct), 0.7 * caustic_layer(cp * 1.7 + vec2(3.1, 7.4), ct * 1.3));
		albedo += caustic_color.rgb * c * caustic_strength;
		emission = caustic_color.rgb * c * caustic_emission;
	} else {
		// 水面の周りの白い縁（穴の内側の壁も含めて白くなる）
		bool in_coping = abs(s) < pool_half_size.x + coping_width && abs(l) < pool_half_size.y + coping_width;
		albedo = in_coping ? coping_color.rgb : deck_color.rgb;
	}
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
