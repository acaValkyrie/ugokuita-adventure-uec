// プールの水面の形（背景の波＋機体が水面を通過したときの波紋）。底の光の網目とコースラインのゆがみを、この水面の傾きと曲がり方から計算する

// 波紋の発生点（xy: ワールドXZ、z: 発生した時刻、w: 強さ。w が0の要素は使わない）
uniform vec4 ripples[8];
// 波紋の時計の今の時刻（スクリプトが毎フレーム渡す。ripples の z と同じ時計）
uniform float ripple_now = 0.0;
// 強さ1のときの波紋の高さ（メートル）
uniform float ripple_height = 0.08;
// 波紋が広がる速さ（m/s）
uniform float ripple_speed = 1.1;
// 波紋が消えるまでの時間（秒）
uniform float ripple_lifetime = 4.3;
// 波紋の束の幅（メートル）
uniform float ripple_width = 0.85;
// 波紋の輪と輪の間隔（メートル）
uniform float ripple_wavelength = 1.0;
// 背景の波の高さ（一番長い波の振幅、メートル）
uniform float wave_height = 0.125;
// 背景の波長の最小（メートル）
uniform float wave_length_min = 1.1;
// 背景の波長の最大（メートル）
uniform float wave_length_max = 1.95;
// 背景の波の速さ倍率
uniform float wave_speed = 0.55;
// 水深（背景の波の速さの計算に使う、メートル）
uniform float water_depth = 0.5;

// 背景の波の方向のばらつき
const float WAVE_JITTER[8] = float[8](0.31, -0.22, 0.12, 0.40, -0.35, 0.05, -0.12, 0.27);
// 背景の波の位相
const float WAVE_PHASE[8] = float[8](0.7, 2.9, 5.1, 1.3, 4.2, 6.0, 3.4, 0.2);

// 水面の傾き grad（dh/dx, dh/dz）と曲がり方 hess（x: d2h/dx2, y: d2h/dz2, z: d2h/dxdz）を求める（bg_t は TIME * wave_speed）
void pool_surface(vec2 p, float bg_t, out vec2 grad, out vec3 hess) {
	grad = vec2(0.0);
	hess = vec3(0.0);
	// 背景の波（波長の違う8本の波を重ねる）
	for (int i = 0; i < 8; i++) {
		float u = float((i * 3) % 8) / 7.0;
		float lam = wave_length_min + (max(wave_length_max, wave_length_min + 0.01) - wave_length_min) * u;
		float th = (float(i) + WAVE_JITTER[i]) * 6.2831853 / 8.0;
		float k = 6.2831853 / lam;
		vec2 kv = k * vec2(cos(th), sin(th));
		float w = sqrt(9.81 * k * tanh(k * water_depth));
		float a = wave_height * lam / max(wave_length_max, wave_length_min + 0.01);
		float ph = dot(kv, p) - w * bg_t + WAVE_PHASE[i];
		grad += a * cos(ph) * kv;
		float c = -a * sin(ph);
		hess += c * vec3(kv.x * kv.x, kv.y * kv.y, kv.x * kv.y);
	}
	// 波紋（発生点から広がる輪の束）
	for (int i = 0; i < 8; i++) {
		vec4 r = ripples[i];
		float age = ripple_now - r.z;
		if (!(r.w > 0.0 && age >= 0.0 && age < ripple_lifetime)) {
			continue;
		}
		vec2 d = p - r.xy;
		float rr = max(length(d), 0.001);
		vec2 rh = d / rr;
		float x = rr - ripple_speed * age;
		float S = r.w * ripple_height * (1.0 - age / ripple_lifetime);
		float W2 = ripple_width * ripple_width;
		float kap = 6.2831853 / ripple_wavelength;
		float g = exp(-(x * x) / W2);
		float g1 = -2.0 * x / W2 * g;
		float g2 = (-2.0 / W2 + 4.0 * x * x / (W2 * W2)) * g;
		float cs = cos(kap * x);
		float sn = sin(kap * x);
		float f1 = S * (g1 * cs - g * kap * sn);
		float f2 = S * (g2 * cs - 2.0 * g1 * kap * sn - g * kap * kap * cs);
		float q = f1 / rr;
		grad += f1 * rh;
		hess += vec3(f2 * rh.x * rh.x + q * (1.0 - rh.x * rh.x), f2 * rh.y * rh.y + q * (1.0 - rh.y * rh.y), (f2 - q) * rh.x * rh.y);
	}
}
