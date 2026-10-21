shader_type spatial;

#include "res://assets/shaders/pool_ripples.gdshaderinc"

// true のときプールの底（コースラインを描く）、false のときプールサイド（台座）として塗る
uniform bool is_floor = false;
// 水面の長方形の中心（ワールドXZ）
uniform vec2 pool_center = vec2(-207.759, -178.832);
// 長辺の向き（単位ベクトル、ワールドXZ）
uniform vec2 pool_long_axis = vec2(0.2664, -0.9639);
// 水面の半分の大きさ（x が短辺方向、y が長辺方向、メートル）
uniform vec2 pool_half_size = vec2(6.69, 12.705);
// プールの底の色（白い塗装）
uniform vec4 floor_color : source_color = vec4(0.93, 0.93, 0.90, 1.0);
// コースラインの色
uniform vec4 lane_color : source_color = vec4(0.12, 0.30, 0.62, 1.0);
// コースラインを描くか（噴水の底では描かない）
uniform bool draw_lanes = true;
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
// 光の網目の明るさ（太陽の光に対する割合。影の中では0になる）
uniform float caustic_strength = 1.0;
// 光の集まりやすさ（水深×(1−1/屈折率) に当たる。大きいほど網目が鋭くなる）
uniform float caustic_focus = 0.105;
// 光の集まり具合を明るさにする倍率
uniform float caustic_gain = 0.15;
// 光が集まる線の中心の明るさの上限（集まり具合の上限）
uniform float caustic_max = 100.0;
// 光が散る（暗くなる）ところの底の色の倍率
uniform float defocus_shade = 0.85;
// 太陽の影の濃さ（DirectionalLight3D の shadow_opacity と同じ値）。影の中で光の網目がちょうど0になるように使う
uniform float sun_shadow_opacity = 0.85;
// 水面の高さ（ワールドY）。これより下の面には、深さに応じて水の色を足す
uniform float water_surface_y = 0.5;
// 水の色（深いところほどこの色に近づく）
uniform vec4 water_tint_color : source_color = vec4(0.25, 0.65, 0.85, 1.0);
// 水が光を吸う強さ [1/m]。深さ d で 1 − exp(−強さ × d) の割合だけ水の色にする。0 のときは足さない（噴水）
uniform float water_absorption = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;
// fragment() で求めた光の網目の強さを light() に渡す
varying float caustic_v;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	caustic_v = 0.0;
	// 水面の長方形の中心からの位置を、短辺方向 s と長辺方向 l に分ける
	vec2 d = world_pos.xz - pool_center;
	vec2 short_axis = vec2(-pool_long_axis.y, pool_long_axis.x);
	float s = dot(d, short_axis);
	float l = dot(d, pool_long_axis);
	vec3 albedo;
	if (is_floor) {
		// 水面の傾きと曲がり方（背景の波＋波紋）
		vec2 grad;
		vec3 hess;
		pool_surface(world_pos.xz, TIME * wave_speed, grad, hess);
		// コースラインは、水面の傾きで光が曲がった分だけずれて見える
		vec2 seen = world_pos.xz - caustic_focus * grad;
		vec2 sd = seen - pool_center;
		s = dot(sd, short_axis);
		l = dot(sd, pool_long_axis);
		// 一番近いコースの中心までの距離 ds
		float lane_w = 2.0 * pool_half_size.x / float(lane_count);
		float k = (s + pool_half_size.x) / lane_w - 0.5;
		float kc = clamp(round(k), 0.0, float(lane_count - 1));
		float ds = abs(k - kc) * lane_w;
		float end_l = pool_half_size.y - lane_line_end;
		// 縦のコースラインと、その両端のT字の横棒
		bool line_body = ds < lane_line_width * 0.5 && abs(l) < end_l;
		bool line_cross = abs(abs(l) - end_l) < lane_line_width * 0.5 && ds < lane_cross_length * 0.5;
		albedo = (draw_lanes && (line_body || line_cross)) ? lane_color.rgb : floor_color.rgb;
		// 底への光の写り方（ヤコビ行列 J = I − focus × 曲がり方）。行列式が0に近いところに光が集まる。明るさは light() で足す
		float ja = 1.0 - caustic_focus * hess.x;
		float jd = 1.0 - caustic_focus * hess.y;
		float jb = -caustic_focus * hess.z;
		float intensity = 1.0 / max(abs(ja * jd - jb * jb), 1.0 / caustic_max);
		caustic_v = clamp((intensity - 1.0) * caustic_gain, 0.0, 1.5);
		// 光が散るところは少し暗くする
		albedo *= mix(1.0, defocus_shade, clamp(1.0 - intensity, 0.0, 1.0));
	} else {
		// 水面の周りの白い縁（穴の内側の壁も含めて白くなる）
		bool in_coping = abs(s) < pool_half_size.x + coping_width && abs(l) < pool_half_size.y + coping_width;
		albedo = in_coping ? coping_color.rgb : deck_color.rgb;
	}
	// 水面より下は、深さに応じて水の色に近づける
	float tint_depth = max(water_surface_y - world_pos.y, 0.0);
	albedo = mix(albedo, water_tint_color.rgb, 1.0 - exp(-water_absorption * tint_depth));
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

// 組み込みの diffuse_toon は使わず、light() で同じトゥーンの拡散光を自前で作る
void light() {
	// diffuse_toon と同じトゥーンの拡散光（ROUGHNESS=1 なので smoothstep(-1, 1, N・L)）
	float ndotl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += smoothstep(-ROUGHNESS, max(ROUGHNESS, 0.01), ndotl) * ATTENUATION * LIGHT_COLOR / PI;
	// 光の網目は底の色に関係なく白く足す。影の中でも shadow_opacity の分だけ光が残るので、それを差し引いて影の中ではちょうど0にする
	float lit = clamp((ATTENUATION - (1.0 - sun_shadow_opacity)) / sun_shadow_opacity, 0.0, 1.0);
	SPECULAR_LIGHT += caustic_color.rgb * caustic_v * caustic_strength * clamp(ndotl, 0.0, 1.0) * lit * LIGHT_COLOR / PI;
}
