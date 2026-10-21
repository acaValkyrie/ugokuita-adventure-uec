shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_toon, specular_disabled;

// プールの水面。上から見た面は半透明の水色、下から見た面は屈折した空・太陽・全反射を描く
#include "res://assets/shaders/pool_ripples.gdshaderinc"

// 水面の色（アルファが不透明度。上から見たとき）
uniform vec4 water_color : source_color = vec4(0.45, 0.78, 0.92, 0.45);
// 水面から太陽へ向かう方向（スクリプトが渡す）
uniform vec3 sun_direction = vec3(0.4, 0.8, 0.45);
// 下から見て空が透けて見えるところの色
uniform vec4 under_sky_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
// 全反射して水の中（白い底や壁）が映るところの色
uniform vec4 under_deep_color : source_color = vec4(0.32, 0.64, 0.80, 1.0);
// 太陽の光の色
uniform vec4 under_sun_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 太陽の芯の鋭さ（大きいほど小さい）
uniform float under_sun_power = 300.0;
// 太陽の芯の明るさ
uniform float under_sun_strength = 4.0;
// 太陽の周りのにじみの広がり。小さいほど広い
uniform float under_halo_power = 8.0;
// 太陽の周りのにじみの明るさ
uniform float under_halo_strength = 0.5;
// 波で光が集まる筋の出やすさ（底の caustic_focus と同じ考え方）
uniform float under_glint_focus = 0.3;
// 光が集まる筋の明るさ
uniform float under_glint_gain = 0.25;
// スネルの窓の縁のぼかし幅
uniform float under_window_edge = 0.2;
// 下から見たときの不透明度
uniform float under_alpha = 0.9;
// 下から見たときの水面の傾きの倍率（背景の波の傾きは底の光の網目用に強いので、水面の向きには弱めて使う）
uniform float under_normal_scale = 0.15;
// 細かい波の高さ [m]
uniform float fine_wave_height = 0.004;
// 細かい波の波長の最小 [m]
uniform float fine_wave_length_min = 0.12;
// 細かい波の波長の最大 [m]
uniform float fine_wave_length_max = 0.45;
// 細かい波の速さ倍率
uniform float fine_wave_speed = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 下から見た水面に足す細かい波の傾き（底の光の網目には使わない）
vec2 fine_wave_grad(vec2 p, float t) {
	vec2 g = vec2(0.0);
	for (int i = 0; i < 6; i++) {
		float u = float((i * 5) % 6) / 5.0;
		float lam = mix(fine_wave_length_min, fine_wave_length_max, u);
		float th = (float(i) * 1.7 + 0.4) * 6.2831853 / 6.0;
		float k = 6.2831853 / lam;
		vec2 kv = k * vec2(cos(th), sin(th));
		// 深い水の分散（波長の短い波は遅い）
		float w = sqrt(9.81 * k);
		float a = fine_wave_height * lam / fine_wave_length_max;
		float ph = dot(kv, p) - w * t * fine_wave_speed + float(i) * 2.3;
		g += a * cos(ph) * kv;
	}
	return g;
}

void fragment() {
	if (FRONT_FACING) {
		ALBEDO = water_color.rgb;
		ALPHA = water_color.a;
	} else {
		// 水面の傾きと曲がり方（背景の波）
		vec2 grad;
		vec3 hess;
		pool_surface(world_pos.xz, TIME * wave_speed, grad, hess);
		// 大きな波（弱めて使う）に細かい波を足して、水面の向きを決める
		vec2 slope = grad * under_normal_scale + fine_wave_grad(world_pos.xz, TIME);
		vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
		// カメラから水面へ向かう視線を、水から空気へ屈折させる（屈折率 1.333）
		vec3 dir = normalize(world_pos - INV_VIEW_MATRIX[3].xyz);
		float eta = 1.333;
		float cosi = dot(dir, n);
		float k = 1.0 - eta * eta * (1.0 - cosi * cosi);
		// k が 0 以下なら全反射（スネルの窓の外）
		float window = smoothstep(0.0, under_window_edge, k);
		vec3 t = normalize(eta * dir + (sqrt(max(k, 0.0)) - eta * cosi) * n);
		// 太陽の方向に近いほど明るい（鋭い芯と、周りのにじみ）
		float sun_dot = max(dot(t, normalize(sun_direction)), 0.0);
		vec3 sky = under_sky_color.rgb + under_sun_color.rgb * (under_sun_strength * pow(sun_dot, under_sun_power) + under_halo_strength * pow(sun_dot, under_halo_power));
		vec3 col = mix(under_deep_color.rgb, sky, window);
		// 波で光が集まる筋
		float ja = 1.0 - under_glint_focus * hess.x;
		float jd = 1.0 - under_glint_focus * hess.y;
		float jb = -under_glint_focus * hess.z;
		float intensity = 1.0 / max(abs(ja * jd - jb * jb), 0.05);
		col += under_sun_color.rgb * clamp((intensity - 1.0) * under_glint_gain, 0.0, 1.0) * window;
		ALBEDO = vec3(0.0);
		EMISSION = col;
		ALPHA = under_alpha;
	}
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
